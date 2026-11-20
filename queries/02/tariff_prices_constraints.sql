-- Проверки ограничений таблицы tariff_prices.
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

    INSERT INTO users (login, full_name, phone, email)
    VALUES (
        '__test_user_base',
        'Тестовый пользователь',
        NULL,
        'test@example.org'
    );

    -- 2. Общий позитивный тест: корректная вставка — ожидается успех.
    -- Проверяются ограничения:
    -- NOT NULL tariff_prices.tariff_price_id
    -- NOT NULL tariff_prices.tariff_plan_id
    -- NOT NULL tariff_prices.price
    -- NOT NULL tariff_prices.price_unit
    -- NOT NULL tariff_prices.valid_from
    -- NOT NULL tariff_prices.valid_to
    -- NOT NULL tariff_prices.assigned_by
    -- NOT NULL tariff_prices.created_at
    -- PRIMARY KEY tariff_prices_pkey
    -- FOREIGN KEY tariff_prices_tariff_fk
    -- FOREIGN KEY tariff_prices_author_fk
    -- CHECK tariff_prices_price_check
    -- CHECK tariff_prices_unit_check
    -- CHECK tariff_prices_period_check
    -- EXCLUDE tariff_prices_no_overlap
    INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
    VALUES (
        (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
        100.00,
        'hour',
        TIMESTAMPTZ '2035-05-01 10:00+03',
        TIMESTAMPTZ '2035-05-01 11:00+03',
        (SELECT user_id FROM users WHERE login = '__test_user_base'),
        CURRENT_TIMESTAMP
    );

    -- 3. Негативные тесты

    -- 3.1. NOT NULL tariff_prices.tariff_price_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец tariff_price_id.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at, tariff_price_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: tariff_price_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'tariff_price_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_price_id, получено %', actual_column;
        END IF;
    END;

    -- 3.2. NOT NULL tariff_prices.tariff_plan_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец tariff_plan_id.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            NULL,
            100.00,
            'hour',
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

    -- 3.3. NOT NULL tariff_prices.price
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец price.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            NULL,
            'hour',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: price, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'price' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось price, получено %', actual_column;
        END IF;
    END;

    -- 3.4. NOT NULL tariff_prices.price_unit
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец price_unit.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            NULL,
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: price_unit, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'price_unit' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось price_unit, получено %', actual_column;
        END IF;
    END;

    -- 3.5. NOT NULL tariff_prices.valid_from
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец valid_from.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
            NULL,
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: valid_from, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'valid_from' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось valid_from, получено %', actual_column;
        END IF;
    END;

    -- 3.6. NOT NULL tariff_prices.valid_to
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец valid_to.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            NULL,
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: valid_to, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'valid_to' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось valid_to, получено %', actual_column;
        END IF;
    END;

    -- 3.7. NOT NULL tariff_prices.assigned_by
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец assigned_by.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
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

    -- 3.8. NOT NULL tariff_prices.created_at
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец created_at.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
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

    -- 3.9. PRIMARY KEY tariff_prices_pkey
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение tariff_prices_pkey.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at, tariff_price_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP,
            (SELECT tariff_price_id FROM tariff_prices WHERE tariff_plan_id = (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base') AND valid_from = TIMESTAMPTZ '2035-05-01 10:00+03')
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: tariff_prices_pkey, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_prices_pkey' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_prices_pkey, получено %', actual_constraint;
        END IF;
    END;

    -- 3.10. FOREIGN KEY tariff_prices_tariff_fk
    -- Негативный тест: ссылка на отсутствующую строку tariff_plans.
    -- Ожидается ошибка SQLSTATE 23503, ограничение tariff_prices_tariff_fk.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT COALESCE(MAX(tariff_plan_id), 0) + 1 FROM tariff_plans),
            100.00,
            'hour',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: tariff_prices_tariff_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_prices_tariff_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_prices_tariff_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.11. FOREIGN KEY tariff_prices_author_fk
    -- Негативный тест: ссылка на отсутствующую строку users.
    -- Ожидается ошибка SQLSTATE 23503, ограничение tariff_prices_author_fk.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT COALESCE(MAX(user_id), 0) + 1 FROM users),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: tariff_prices_author_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_prices_author_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_prices_author_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.12. CHECK tariff_prices_price_check
    -- Негативный тест: отрицательная цена.
    -- Ожидается ошибка SQLSTATE 23514, ограничение tariff_prices_price_check.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            -1.00,
            'hour',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: tariff_prices_price_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_prices_price_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_prices_price_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.13. CHECK tariff_prices_unit_check
    -- Негативный тест: единица измерения состоит из пробелов.
    -- Ожидается ошибка SQLSTATE 23514, ограничение tariff_prices_unit_check.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            ' ',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: tariff_prices_unit_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_prices_unit_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_prices_unit_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.14. CHECK tariff_prices_period_check
    -- Негативный тест: окончание равно началу.
    -- Ожидается ошибка SQLSTATE 23514, ограничение tariff_prices_period_check.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: tariff_prices_period_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_prices_period_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_prices_period_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.15. EXCLUDE tariff_prices_no_overlap
    -- Негативный тест: период пересекается с исходной записью.
    -- Ожидается ошибка SQLSTATE 23P01, ограничение tariff_prices_no_overlap.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
            TIMESTAMPTZ '2035-05-01 10:00+03' + INTERVAL '30 minutes',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23P01: tariff_prices_no_overlap, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23P01' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_prices_no_overlap' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_prices_no_overlap, получено %', actual_constraint;
        END IF;
    END;

    -- 3.16. tariff_prices_price_check: NaN
    -- Негативный тест: NaN.
    -- Ожидается ошибка SQLSTATE 23514, ограничение tariff_prices_price_check.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            'NaN'::NUMERIC,
            'hour',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: tariff_prices_price_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_prices_price_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_prices_price_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.17. tariff_prices_period_check: бесконечное начало
    -- Негативный тест: бесконечное начало.
    -- Ожидается ошибка SQLSTATE 23514, ограничение tariff_prices_period_check.
    BEGIN
        INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, valid_to, assigned_by, created_at)
        VALUES (
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base'),
            100.00,
            'hour',
            '-infinity'::TIMESTAMPTZ,
            TIMESTAMPTZ '2035-05-01 12:00+03',
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: tariff_prices_period_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_prices_period_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_prices_period_check, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'tariff_prices: пройдено 18 проверок (1 позитивная и 17 негативных).';
END;
$tests$;

-- 4. Чтение
SELECT * FROM tariff_prices WHERE tariff_price_id = (SELECT tariff_price_id FROM tariff_prices WHERE tariff_plan_id = (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base') AND valid_from = TIMESTAMPTZ '2035-05-01 10:00+03');

-- 5. Откат тестовых данных
ROLLBACK;
