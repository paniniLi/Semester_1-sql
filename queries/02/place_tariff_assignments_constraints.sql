-- Проверки ограничений таблицы place_tariff_assignments.
-- Запускать через psql с ON_ERROR_STOP=1.
-- Негативные тесты перехватывают исключения и проверяют SQLSTATE.
-- Данные откатываются в конце; значения identity-последовательностей не откатываются.
BEGIN;

DO $tests$
DECLARE
    actual_constraint TEXT;
    actual_column TEXT;
BEGIN
    -- 1. Исходные данные для связанных таблиц
    INSERT INTO tariff_plans (name, created_at)
    VALUES (
        '__test_tariff_base',
        CURRENT_TIMESTAMP
    );

    INSERT INTO coworking_sections (name)
    VALUES (
        '__test_section_base'
    );

    INSERT INTO coworking_places (name, section_id, status, characteristics)
    VALUES (
        '__test_place_base',
        (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
        'available',
        '{"equipment": ["monitor"]}'::JSONB
    );

    INSERT INTO users (login, full_name, phone, email)
    VALUES (
        '__test_user_base',
        'Тестовый пользователь',
        NULL,
        'test@example.org'
    );

    -- 2. Общий позитивный тест: корректная вставка — ожидается успех.
    -- Проверяются ограничения:
    -- NOT NULL place_tariff_assignments.assignment_id
    -- NOT NULL place_tariff_assignments.tariff_plan_id
    -- NOT NULL place_tariff_assignments.place_id
    -- NOT NULL place_tariff_assignments.starts_at
    -- NOT NULL place_tariff_assignments.ends_at
    -- NOT NULL place_tariff_assignments.assigned_by
    -- NOT NULL place_tariff_assignments.created_at
    -- PRIMARY KEY place_tariff_assignments_pkey
    -- FOREIGN KEY place_tariff_assignments_tariff_fk
    -- FOREIGN KEY place_tariff_assignments_place_fk
    -- FOREIGN KEY place_tariff_assignments_author_fk
    -- CHECK place_tariff_assignments_period_check
    -- EXCLUDE place_tariff_assignments_no_overlap
    INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
    VALUES (
        (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
        (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
        TIMESTAMPTZ '2035-05-01 10:00+03',
        TIMESTAMPTZ '2035-05-01 11:00+03',
        (SELECT user_id FROM users WHERE login = '__test_user_base'),
        CURRENT_TIMESTAMP
    );

    -- 3. Негативные тесты

    -- 3.1. NOT NULL place_tariff_assignments.assignment_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец assignment_id.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at, assignment_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: assignment_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'assignment_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось assignment_id, получено %', actual_column;
        END IF;
    END;

    -- 3.2. NOT NULL place_tariff_assignments.tariff_plan_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец tariff_plan_id.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            NULL,
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: tariff_plan_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'tariff_plan_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_plan_id, получено %', actual_column;
        END IF;
    END;

    -- 3.3. NOT NULL place_tariff_assignments.place_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец place_id.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            NULL,
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: place_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'place_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось place_id, получено %', actual_column;
        END IF;
    END;

    -- 3.4. NOT NULL place_tariff_assignments.starts_at
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец starts_at.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            NULL,
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: starts_at, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'starts_at' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось starts_at, получено %', actual_column;
        END IF;
    END;

    -- 3.5. NOT NULL place_tariff_assignments.ends_at
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец ends_at.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            NULL,
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: ends_at, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'ends_at' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось ends_at, получено %', actual_column;
        END IF;
    END;

    -- 3.6. NOT NULL place_tariff_assignments.assigned_by
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец assigned_by.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            NULL,
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: assigned_by, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'assigned_by' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось assigned_by, получено %', actual_column;
        END IF;
    END;

    -- 3.7. NOT NULL place_tariff_assignments.created_at
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец created_at.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: created_at, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'created_at' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось created_at, получено %', actual_column;
        END IF;
    END;

    -- 3.8. PRIMARY KEY place_tariff_assignments_pkey
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение place_tariff_assignments_pkey.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at, assignment_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP,
            (SELECT assignment_id FROM place_tariff_assignments WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03')
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: place_tariff_assignments_pkey, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'place_tariff_assignments_pkey' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось place_tariff_assignments_pkey, получено %', actual_constraint;
        END IF;
    END;

    -- 3.9. FOREIGN KEY place_tariff_assignments_tariff_fk
    -- Негативный тест: ссылка на отсутствующую строку tariff_plans.
    -- Ожидается ошибка SQLSTATE 23503, ограничение place_tariff_assignments_tariff_fk.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT COALESCE(MAX(tariff_plan_id), 0) + 1 FROM tariff_plans),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: place_tariff_assignments_tariff_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'place_tariff_assignments_tariff_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось place_tariff_assignments_tariff_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.10. FOREIGN KEY place_tariff_assignments_place_fk
    -- Негативный тест: ссылка на отсутствующую строку coworking_places.
    -- Ожидается ошибка SQLSTATE 23503, ограничение place_tariff_assignments_place_fk.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT COALESCE(MAX(place_id), 0) + 1 FROM coworking_places),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: place_tariff_assignments_place_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'place_tariff_assignments_place_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось place_tariff_assignments_place_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.11. FOREIGN KEY place_tariff_assignments_author_fk
    -- Негативный тест: ссылка на отсутствующую строку users.
    -- Ожидается ошибка SQLSTATE 23503, ограничение place_tariff_assignments_author_fk.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT COALESCE(MAX(user_id), 0) + 1 FROM users),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: place_tariff_assignments_author_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'place_tariff_assignments_author_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось place_tariff_assignments_author_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.12. CHECK place_tariff_assignments_period_check
    -- Негативный тест: окончание равно началу.
    -- Ожидается ошибка SQLSTATE 23514, ограничение place_tariff_assignments_period_check.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: place_tariff_assignments_period_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'place_tariff_assignments_period_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось place_tariff_assignments_period_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.13. EXCLUDE place_tariff_assignments_no_overlap
    -- Негативный тест: период пересекается с исходной записью.
    -- Ожидается ошибка SQLSTATE 23P01, ограничение place_tariff_assignments_no_overlap.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03' + INTERVAL '30 minutes',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23P01: place_tariff_assignments_no_overlap, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23P01' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'place_tariff_assignments_no_overlap' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось place_tariff_assignments_no_overlap, получено %', actual_constraint;
        END IF;
    END;

    -- 3.14. place_tariff_assignments_period_check: бесконечное начало
    -- Негативный тест: бесконечное начало.
    -- Ожидается ошибка SQLSTATE 23514, ограничение place_tariff_assignments_period_check.
    BEGIN
        INSERT INTO place_tariff_assignments (tariff_plan_id, place_id, starts_at, ends_at, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            '-infinity'::TIMESTAMPTZ,
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: place_tariff_assignments_period_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'place_tariff_assignments_period_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось place_tariff_assignments_period_check, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'place_tariff_assignments: пройдено 15 проверок (1 позитивная и 14 негативных).';
END;
$tests$;

-- 4. Чтение
SELECT * FROM place_tariff_assignments WHERE assignment_id = (SELECT assignment_id FROM place_tariff_assignments WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03');

-- 5. Откат тестовых данных
ROLLBACK;
