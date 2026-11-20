-- Проверки ограничений таблицы tariff_plans.
-- Запускать через psql с ON_ERROR_STOP=1.
-- Негативные тесты перехватывают исключения и проверяют SQLSTATE.
-- Данные откатываются в конце; значения identity-последовательностей не откатываются.
BEGIN;

DO $tests$
DECLARE
    actual_constraint TEXT;
    actual_column TEXT;
BEGIN
    -- 1. Общий позитивный тест: корректная вставка — ожидается успех.
    -- Проверяются ограничения:
    -- NOT NULL tariff_plans.tariff_plan_id
    -- NOT NULL tariff_plans.name
    -- NOT NULL tariff_plans.created_at
    -- PRIMARY KEY tariff_plans_pkey
    -- UNIQUE tariff_plans_name_key
    -- CHECK tariff_plans_name_check
    INSERT INTO tariff_plans (name, created_at)
    VALUES (
        '__test_tariff_base',
        CURRENT_TIMESTAMP
    );

    -- 2. Негативные тесты

    -- 2.1. NOT NULL tariff_plans.tariff_plan_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец tariff_plan_id.
    BEGIN
        INSERT INTO tariff_plans (name, created_at, tariff_plan_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_tariff_new',
            CURRENT_TIMESTAMP,
            NULL
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

    -- 2.2. NOT NULL tariff_plans.name
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец name.
    BEGIN
        INSERT INTO tariff_plans (name, created_at)
        VALUES (
            NULL,
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: name, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'name' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось name, получено %', actual_column;
        END IF;
    END;

    -- 2.3. NOT NULL tariff_plans.created_at
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец created_at.
    BEGIN
        INSERT INTO tariff_plans (name, created_at)
        VALUES (
            '__test_tariff_new',
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

    -- 2.4. PRIMARY KEY tariff_plans_pkey
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение tariff_plans_pkey.
    BEGIN
        INSERT INTO tariff_plans (name, created_at, tariff_plan_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_tariff_new',
            CURRENT_TIMESTAMP,
            (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base')
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: tariff_plans_pkey, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_plans_pkey' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_plans_pkey, получено %', actual_constraint;
        END IF;
    END;

    -- 2.5. UNIQUE tariff_plans_name_key
    -- Негативный тест: повтор существующего уникального ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение tariff_plans_name_key.
    BEGIN
        INSERT INTO tariff_plans (name, created_at)
        VALUES (
            '__test_tariff_base',
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: tariff_plans_name_key, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_plans_name_key' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_plans_name_key, получено %', actual_constraint;
        END IF;
    END;

    -- 2.6. CHECK tariff_plans_name_check
    -- Негативный тест: название состоит из пробелов.
    -- Ожидается ошибка SQLSTATE 23514, ограничение tariff_plans_name_check.
    BEGIN
        INSERT INTO tariff_plans (name, created_at)
        VALUES (
            ' ',
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: tariff_plans_name_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'tariff_plans_name_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось tariff_plans_name_check, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'tariff_plans: пройдено 7 проверок (1 позитивная и 6 негативных).';
END;
$tests$;

-- 3. Чтение
SELECT * FROM tariff_plans WHERE tariff_plan_id = (SELECT tariff_plan_id FROM tariff_plans WHERE name = '__test_tariff_base');

-- 4. Откат тестовых данных
ROLLBACK;
