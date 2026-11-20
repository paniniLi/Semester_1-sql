-- Проверки ограничений таблицы roles.
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
    -- NOT NULL roles.role_id
    -- NOT NULL roles.name
    -- PRIMARY KEY roles_pkey
    -- UNIQUE roles_name_key
    -- CHECK roles_name_check
    INSERT INTO roles (name)
    VALUES (
        '__test_role_base'
    );

    -- 2. Негативные тесты

    -- 2.1. NOT NULL roles.role_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец role_id.
    BEGIN
        INSERT INTO roles (name, role_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_role_new',
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: role_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'role_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось role_id, получено %', actual_column;
        END IF;
    END;

    -- 2.2. NOT NULL roles.name
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец name.
    BEGIN
        INSERT INTO roles (name)
        VALUES (
            NULL
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

    -- 2.3. PRIMARY KEY roles_pkey
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение roles_pkey.
    BEGIN
        INSERT INTO roles (name, role_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_role_new',
            (SELECT role_id FROM roles WHERE name = '__test_role_base')
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: roles_pkey, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'roles_pkey' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось roles_pkey, получено %', actual_constraint;
        END IF;
    END;

    -- 2.4. UNIQUE roles_name_key
    -- Негативный тест: повтор существующего уникального ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение roles_name_key.
    BEGIN
        INSERT INTO roles (name)
        VALUES (
            '__test_role_base'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: roles_name_key, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'roles_name_key' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось roles_name_key, получено %', actual_constraint;
        END IF;
    END;

    -- 2.5. CHECK roles_name_check
    -- Негативный тест: название состоит из пробелов.
    -- Ожидается ошибка SQLSTATE 23514, ограничение roles_name_check.
    BEGIN
        INSERT INTO roles (name)
        VALUES (
            ' '
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: roles_name_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'roles_name_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось roles_name_check, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'roles: пройдено 6 проверок (1 позитивная и 5 негативных).';
END;
$tests$;

-- 3. Чтение
SELECT * FROM roles WHERE role_id = (SELECT role_id FROM roles WHERE name = '__test_role_base');

-- 4. Откат тестовых данных
ROLLBACK;
