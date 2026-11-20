-- Позитивные и негативные тесты выполняются автоматически.
-- Все изменения откатываются; значения последовательностей не откатываются.
BEGIN;

CREATE TEMP TABLE constraint_results (
    test_name TEXT,
    variant TEXT,
    passed BOOLEAN,
    details TEXT
);

-- Вставка только переданных полей; остальные получают DEFAULT.
CREATE FUNCTION pg_temp.insert_row(p_table REGCLASS, p_row JSONB)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    columns_sql TEXT;
    inserted JSONB;
BEGIN
    SELECT string_agg(format('%I', key), ', ' ORDER BY key)
    INTO columns_sql FROM jsonb_object_keys(p_row) AS keys(key);

    EXECUTE format(
        'INSERT INTO %s AS inserted (%s) OVERRIDING SYSTEM VALUE '
        'SELECT %s FROM jsonb_populate_record(NULL::%s, $1) '
        'RETURNING to_jsonb(inserted)',
        p_table, columns_sql, columns_sql, p_table
    ) INTO inserted USING p_row;
    RETURN inserted;
END;
$$;

-- Проверка SQLSTATE, имени constraint или столбца NOT NULL.
CREATE FUNCTION pg_temp.check_case(
    p_table REGCLASS,
    p_row JSONB,
    p_label TEXT,
    p_state TEXT DEFAULT '00000',
    p_constraint TEXT DEFAULT NULL,
    p_column TEXT DEFAULT NULL,
    p_parent_default JSONB DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    actual_state TEXT := '00000';
    actual_constraint TEXT;
    actual_column TEXT;
    message TEXT;
    parent_row JSONB;
    fk RECORD;
    ok BOOLEAN;
BEGIN
    BEGIN
        -- payments_paid_at_check иначе первым отклоняет неизвестный статус.
        IF p_constraint = 'payments_status_check' THEN
            ALTER TABLE payments DROP CONSTRAINT payments_paid_at_check;
        END IF;

        IF p_parent_default IS NULL THEN
            PERFORM pg_temp.insert_row(p_table, p_row);
        ELSE
            SELECT c.confrelid::REGCLASS AS parent_table,
                child.attname AS child_column, parent.attname AS parent_column
            INTO STRICT fk FROM pg_constraint c
            JOIN pg_attribute child ON child.attrelid = c.conrelid AND child.attnum = c.conkey[1]
            JOIN pg_attribute parent ON parent.attrelid = c.confrelid AND parent.attnum = c.confkey[1]
            WHERE c.conrelid = p_table AND c.conname = p_constraint;

            parent_row := pg_temp.insert_row(fk.parent_table, p_parent_default);
            IF p_state = '23503' THEN
                PERFORM pg_temp.insert_row(p_table,
                    p_row || jsonb_build_object(fk.child_column, parent_row -> fk.parent_column));
            END IF;
            EXECUTE format('DELETE FROM %s WHERE %I = $1', fk.parent_table, fk.parent_column)
                USING (parent_row ->> fk.parent_column)::BIGINT;
        END IF;

        -- Исключение откатывает и успешную вставку, и временный ALTER TABLE.
        RAISE SQLSTATE 'ZX001';
    EXCEPTION
        WHEN SQLSTATE 'ZX001' THEN NULL;
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS actual_state = RETURNED_SQLSTATE,
                actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME,
                message = MESSAGE_TEXT;
    END;

    ok := actual_state = p_state
        AND (p_state = '00000' OR p_constraint IS NULL OR actual_constraint = p_constraint)
        AND (p_column IS NULL OR actual_column = p_column);
    INSERT INTO constraint_results VALUES (
        p_label,
        CASE WHEN p_state = '00000' THEN 'позитивный' ELSE 'негативный' END,
        COALESCE(ok, FALSE),
        CASE WHEN ok THEN NULL ELSE format(
            'Ожидалось: %s, %s. Получено: %s, %s. %s',
            p_state, COALESCE(p_constraint, p_column, ''), actual_state,
            COALESCE(NULLIF(actual_constraint, ''), actual_column, ''), COALESCE(message, '')
        ) END
    );
END;
$$;

DO $$
DECLARE
    prefix TEXT := '__constraints_' || txid_current();
    period_start TIMESTAMPTZ := '2035-05-01 10:00+03';
    period_end TIMESTAMPTZ := '2035-05-01 11:00+03';
    next_end TIMESTAMPTZ := '2035-05-01 12:00+03';
    users_default JSONB;
    roles_default JSONB;
    user_roles_default JSONB;
    tariff_plans_default JSONB;
    tariff_prices_default JSONB;
    coworking_sections_default JSONB;
    coworking_places_default JSONB;
    bookings_default JSONB;
    place_tariff_assignments_default JSONB;
    section_tariff_assignments_default JSONB;
    payments_default JSONB;
    defaults JSONB;
    fixtures JSONB := '{}';
    other_user JSONB;
    other_section JSONB;
    invalid_checks JSONB;
    table_name TEXT;
    table_oid REGCLASS;
    default_row JSONB;
    bad_patch JSONB;
    good_patch JSONB;
    expected_state TEXT;
    missing_id BIGINT;
    label TEXT;
    column_info RECORD;
    constraint_info RECORD;
    extra RECORD;
BEGIN
    -- Корректные записи и связанные исходные данные.
    users_default := jsonb_build_object('login', prefix || '_new_user',
        'full_name', 'Тестовый пользователь', 'phone', NULL, 'email', 'test@example.org');
    fixtures := fixtures || jsonb_build_object('users', pg_temp.insert_row('users',
        users_default || jsonb_build_object('login', prefix || '_base_user')));
    other_user := pg_temp.insert_row('users',
        users_default || jsonb_build_object('login', prefix || '_other_user'));

    roles_default := jsonb_build_object('name', prefix || '_new_role');
    fixtures := fixtures || jsonb_build_object('roles', pg_temp.insert_row('roles',
        roles_default || jsonb_build_object('name', prefix || '_base_role')));

    user_roles_default := jsonb_build_object('role_id', fixtures #> '{roles,role_id}',
        'user_id', other_user -> 'user_id', 'assigned_by', fixtures #> '{users,user_id}',
        'valid_from', period_start, 'valid_to', 'infinity');
    fixtures := fixtures || jsonb_build_object('user_roles', pg_temp.insert_row('user_roles',
        user_roles_default || jsonb_build_object('user_id', fixtures #> '{users,user_id}')));

    tariff_plans_default := jsonb_build_object('name', prefix || '_new_tariff',
        'created_at', CURRENT_TIMESTAMP);
    fixtures := fixtures || jsonb_build_object('tariff_plans', pg_temp.insert_row('tariff_plans',
        tariff_plans_default || jsonb_build_object('name', prefix || '_base_tariff')));

    tariff_prices_default := jsonb_build_object('tariff_plan_id', fixtures #> '{tariff_plans,tariff_plan_id}',
        'price', 100, 'price_unit', 'hour', 'valid_from', period_end, 'valid_to', next_end,
        'assigned_by', fixtures #> '{users,user_id}', 'created_at', CURRENT_TIMESTAMP);
    fixtures := fixtures || jsonb_build_object('tariff_prices', pg_temp.insert_row('tariff_prices',
        tariff_prices_default || jsonb_build_object('valid_from', period_start, 'valid_to', period_end)));

    coworking_sections_default := jsonb_build_object('name', prefix || '_new_section');
    fixtures := fixtures || jsonb_build_object('coworking_sections', pg_temp.insert_row('coworking_sections',
        coworking_sections_default || jsonb_build_object('name', prefix || '_base_section')));
    other_section := pg_temp.insert_row('coworking_sections',
        coworking_sections_default || jsonb_build_object('name', prefix || '_other_section'));

    coworking_places_default := jsonb_build_object('name', prefix || '_new_place',
        'section_id', fixtures #> '{coworking_sections,section_id}', 'status', 'available',
        'characteristics', '{"equipment": ["monitor"]}'::JSONB);
    fixtures := fixtures || jsonb_build_object('coworking_places', pg_temp.insert_row('coworking_places',
        coworking_places_default || jsonb_build_object('name', prefix || '_base_place')));

    bookings_default := jsonb_build_object('user_id', fixtures #> '{users,user_id}',
        'place_id', fixtures #> '{coworking_places,place_id}', 'starts_at', period_end,
        'ends_at', next_end, 'status', 'pending_payment', 'total_price', 100,
        'arrived_at', NULL, 'departed_at', NULL);
    fixtures := fixtures || jsonb_build_object('bookings', pg_temp.insert_row('bookings',
        bookings_default || jsonb_build_object('starts_at', period_start, 'ends_at', period_end,
            'status', 'confirmed')));

    place_tariff_assignments_default := jsonb_build_object(
        'tariff_plan_id', fixtures #> '{tariff_plans,tariff_plan_id}',
        'place_id', fixtures #> '{coworking_places,place_id}',
        'starts_at', period_end, 'ends_at', next_end,
        'assigned_by', fixtures #> '{users,user_id}', 'created_at', CURRENT_TIMESTAMP);
    fixtures := fixtures || jsonb_build_object('place_tariff_assignments',
        pg_temp.insert_row('place_tariff_assignments', place_tariff_assignments_default
            || jsonb_build_object('starts_at', period_start, 'ends_at', period_end)));

    section_tariff_assignments_default := jsonb_build_object(
        'tariff_plan_id', fixtures #> '{tariff_plans,tariff_plan_id}',
        'section_id', fixtures #> '{coworking_sections,section_id}',
        'starts_at', period_end, 'ends_at', next_end,
        'assigned_by', fixtures #> '{users,user_id}', 'created_at', CURRENT_TIMESTAMP);
    fixtures := fixtures || jsonb_build_object('section_tariff_assignments',
        pg_temp.insert_row('section_tariff_assignments', section_tariff_assignments_default
            || jsonb_build_object('starts_at', period_start, 'ends_at', period_end)));

    payments_default := jsonb_build_object('booking_id', fixtures #> '{bookings,booking_id}',
        'amount', 100, 'status', 'pending', 'created_at', CURRENT_TIMESTAMP, 'paid_at', NULL);
    fixtures := fixtures || jsonb_build_object('payments', pg_temp.insert_row('payments', payments_default));

    defaults := jsonb_build_object(
        'users', users_default, 'roles', roles_default, 'user_roles', user_roles_default,
        'tariff_plans', tariff_plans_default, 'tariff_prices', tariff_prices_default,
        'coworking_sections', coworking_sections_default, 'coworking_places', coworking_places_default,
        'bookings', bookings_default, 'place_tariff_assignments', place_tariff_assignments_default,
        'section_tariff_assignments', section_tariff_assignments_default, 'payments', payments_default);

    -- CHECK: заменяем только значения, нарушающие правило.
    invalid_checks := jsonb_build_object(
        'users_login_check', jsonb_build_object('login', ' '),
        'users_full_name_check', jsonb_build_object('full_name', ' '),
        'users_at_least_one_contact_check', jsonb_build_object('phone', NULL, 'email', NULL),
        'roles_name_check', jsonb_build_object('name', ' '),
        'user_roles_period_check', jsonb_build_object('valid_to', period_start),
        'tariff_plans_name_check', jsonb_build_object('name', ' '),
        'tariff_prices_price_check', jsonb_build_object('price', -1),
        'tariff_prices_unit_check', jsonb_build_object('price_unit', ' '),
        'tariff_prices_period_check', jsonb_build_object('valid_to', period_end),
        'coworking_sections_name_check', jsonb_build_object('name', ' '),
        'coworking_places_name_check', jsonb_build_object('name', ' '),
        'coworking_places_status_check', jsonb_build_object('status', 'unknown'),
        'coworking_places_characteristics_check', jsonb_build_object('characteristics', '[]'::JSONB),
        'bookings_period_check', jsonb_build_object('ends_at', period_end),
        'bookings_status_check', jsonb_build_object('status', 'unknown'),
        'bookings_total_price_check', jsonb_build_object('total_price', -1),
        'bookings_attendance_check', jsonb_build_object('departed_at', period_end),
        'place_tariff_assignments_period_check', jsonb_build_object('ends_at', period_end),
        'section_tariff_assignments_period_check', jsonb_build_object('ends_at', period_end),
        'payments_amount_check', jsonb_build_object('amount', -1),
        'payments_status_check', jsonb_build_object('status', 'unknown'),
        'payments_paid_at_check', jsonb_build_object('status', 'succeeded', 'paid_at', NULL));

    FOR table_name, default_row IN SELECT key, value FROM jsonb_each(defaults)
    LOOP
        table_oid := format('public.%I', table_name)::REGCLASS;

        -- NOT NULL: корректная запись и NULL в каждом обязательном столбце.
        FOR column_info IN SELECT attname FROM pg_attribute
            WHERE attrelid = table_oid AND attnum > 0 AND NOT attisdropped AND attnotnull
        LOOP
            label := format('NOT NULL %s.%s', table_name, column_info.attname);
            PERFORM pg_temp.check_case(table_oid, default_row, label);
            PERFORM pg_temp.check_case(table_oid,
                default_row || jsonb_build_object(column_info.attname, NULL),
                label, '23502', p_column => column_info.attname);
        END LOOP;

        FOR constraint_info IN SELECT * FROM pg_constraint
            WHERE conrelid = table_oid AND contype IN ('p', 'u', 'f', 'c', 'x')
            ORDER BY conname
        LOOP
            label := constraint_info.conname;
            good_patch := '{}';
            CASE constraint_info.contype
                WHEN 'p', 'u' THEN
                    -- PRIMARY KEY / UNIQUE: повторяем ключ исходной записи.
                    SELECT jsonb_object_agg(a.attname, fixtures -> table_name -> a.attname)
                    INTO bad_patch FROM pg_attribute a
                    WHERE a.attrelid = table_oid AND a.attnum = ANY(constraint_info.conkey);
                    expected_state := '23505';
                    IF label = 'coworking_places_name_section_key' THEN
                        good_patch := jsonb_build_object('name', fixtures #> '{coworking_places,name}',
                            'section_id', other_section -> 'section_id');
                    END IF;
                WHEN 'f' THEN
                    -- FOREIGN KEY: отсутствующий родитель.
                    SELECT child.attname AS child_column, parent.attname AS parent_column
                    INTO column_info FROM pg_attribute child, pg_attribute parent
                    WHERE child.attrelid = table_oid AND child.attnum = constraint_info.conkey[1]
                        AND parent.attrelid = constraint_info.confrelid
                        AND parent.attnum = constraint_info.confkey[1];
                    EXECUTE format('SELECT COALESCE(MAX(%I), 0) + 1 FROM %s',
                        column_info.parent_column, constraint_info.confrelid::REGCLASS) INTO missing_id;
                    bad_patch := jsonb_build_object(column_info.child_column, missing_id);
                    expected_state := '23503';
                WHEN 'c' THEN
                    IF NOT invalid_checks ? label THEN
                        RAISE EXCEPTION 'Нет негативных данных для %', label;
                    END IF;
                    bad_patch := invalid_checks -> label;
                    expected_state := '23514';
                    IF label = 'bookings_attendance_check' THEN
                        good_patch := jsonb_build_object('arrived_at', period_end, 'departed_at', next_end);
                    ELSIF label = 'payments_paid_at_check' THEN
                        good_patch := jsonb_build_object('status', 'succeeded', 'paid_at', CURRENT_TIMESTAMP);
                    END IF;
                WHEN 'x' THEN
                    -- EXCLUDE: соседний период допустим, пересекающийся — нет.
                    bad_patch := jsonb_build_object(
                        CASE WHEN table_name = 'tariff_prices' THEN 'valid_from' ELSE 'starts_at' END,
                        period_start + INTERVAL '30 minutes');
                    expected_state := '23P01';
            END CASE;

            PERFORM pg_temp.check_case(table_oid, default_row || good_patch, label,
                p_constraint => label);
            PERFORM pg_temp.check_case(table_oid, default_row || bad_patch, label,
                expected_state, label);

            IF constraint_info.contype = 'f' THEN
                -- ON DELETE RESTRICT: родитель без потомка и с потомком.
                IF constraint_info.confdeltype <> 'r' THEN
                    RAISE EXCEPTION 'Ожидался ON DELETE RESTRICT у %', label;
                END IF;
                PERFORM pg_temp.check_case(table_oid, default_row, label || ' ON DELETE RESTRICT',
                    p_constraint => label,
                    p_parent_default => defaults -> (constraint_info.confrelid::REGCLASS)::TEXT);
                PERFORM pg_temp.check_case(table_oid, default_row, label || ' ON DELETE RESTRICT',
                    '23503', label,
                    p_parent_default => defaults -> (constraint_info.confrelid::REGCLASS)::TEXT);
            END IF;
        END LOOP;
    END LOOP;

    -- Дополнительные ветви CHECK и частичного EXCLUDE.
    FOR extra IN SELECT * FROM (VALUES
        ('users', 'users_at_least_one_contact_check', 'пробелы',
            jsonb_build_object('phone', ' ', 'email', ' '),
            jsonb_build_object('phone', '+375291234567', 'email', NULL)),
        ('tariff_prices', 'tariff_prices_price_check', 'NaN',
            jsonb_build_object('price', 'NaN'), jsonb_build_object('price', 0)),
        ('bookings', 'bookings_total_price_check', 'NaN',
            jsonb_build_object('total_price', 'NaN'), jsonb_build_object('total_price', 0)),
        ('payments', 'payments_amount_check', 'NaN',
            jsonb_build_object('amount', 'NaN'), jsonb_build_object('amount', 0)),
        ('user_roles', 'user_roles_period_check', 'бесконечное начало',
            jsonb_build_object('valid_from', '-infinity'), '{}'::JSONB),
        ('tariff_prices', 'tariff_prices_period_check', 'бесконечное начало',
            jsonb_build_object('valid_from', '-infinity'), '{}'::JSONB),
        ('place_tariff_assignments', 'place_tariff_assignments_period_check', 'бесконечное начало',
            jsonb_build_object('starts_at', '-infinity'), '{}'::JSONB),
        ('section_tariff_assignments', 'section_tariff_assignments_period_check', 'бесконечное начало',
            jsonb_build_object('starts_at', '-infinity'), '{}'::JSONB),
        ('bookings', 'bookings_period_check', 'бесконечное начало',
            jsonb_build_object('starts_at', '-infinity'), '{}'::JSONB),
        ('bookings', 'bookings_period_check', 'бесконечное окончание',
            jsonb_build_object('ends_at', 'infinity'), '{}'::JSONB),
        ('bookings', 'bookings_attendance_check', 'уход раньше прихода',
            jsonb_build_object('arrived_at', next_end, 'departed_at', period_end),
            jsonb_build_object('arrived_at', period_end, 'departed_at', next_end)),
        ('bookings', 'bookings_attendance_check', 'бесконечный приход',
            jsonb_build_object('arrived_at', 'infinity'), '{}'::JSONB),
        ('bookings', 'bookings_attendance_check', 'бесконечный уход',
            jsonb_build_object('arrived_at', period_end, 'departed_at', 'infinity'),
            jsonb_build_object('arrived_at', period_end, 'departed_at', next_end)),
        ('bookings', 'bookings_no_overlap', 'отменённая бронь',
            jsonb_build_object('starts_at', period_start, 'ends_at', period_end, 'status', 'pending_payment'),
            jsonb_build_object('starts_at', period_start, 'ends_at', period_end, 'status', 'cancelled')),
        ('payments', 'payments_paid_at_check', 'неоплаченный платёж',
            jsonb_build_object('paid_at', CURRENT_TIMESTAMP), '{}'::JSONB),
        ('payments', 'payments_paid_at_check', 'оплата раньше создания',
            jsonb_build_object('status', 'succeeded', 'paid_at', CURRENT_TIMESTAMP - INTERVAL '1 second'),
            jsonb_build_object('status', 'succeeded', 'paid_at', CURRENT_TIMESTAMP))
    ) AS cases(table_name, constraint_name, description, bad_patch, good_patch)
    LOOP
        table_oid := format('public.%I', extra.table_name)::REGCLASS;
        default_row := defaults -> extra.table_name;
        label := extra.constraint_name || ': ' || extra.description;
        PERFORM pg_temp.check_case(table_oid, default_row || extra.good_patch, label);
        PERFORM pg_temp.check_case(table_oid, default_row || extra.bad_patch, label,
            CASE WHEN extra.constraint_name = 'bookings_no_overlap' THEN '23P01' ELSE '23514' END,
            extra.constraint_name);
    END LOOP;
END;
$$;

SELECT variant, COUNT(*) AS total,
    COUNT(*) FILTER (WHERE passed) AS passed,
    COUNT(*) FILTER (WHERE NOT passed) AS failed
FROM constraint_results GROUP BY variant ORDER BY variant;

SELECT test_name, variant, details FROM constraint_results WHERE NOT passed;

DO $$
BEGIN
    IF EXISTS (SELECT FROM constraint_results WHERE NOT passed) THEN
        RAISE EXCEPTION 'Есть непройденные тесты ограничений';
    END IF;
END;
$$;

ROLLBACK;
