-- Проверки ограничений таблицы users.
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
    -- NOT NULL users.user_id
    -- NOT NULL users.login
    -- NOT NULL users.full_name
    -- PRIMARY KEY users_pkey
    -- UNIQUE users_login_key
    -- CHECK users_login_check
    -- CHECK users_full_name_check
    -- CHECK users_at_least_one_contact_check
    INSERT INTO users (login, full_name, phone, email)
    VALUES (
        '__test_user_base',
        'Тестовый пользователь',
        NULL,
        'test@example.org'
    );

    -- 2. Негативные тесты

    -- 2.1. NOT NULL users.user_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец user_id.
    BEGIN
        INSERT INTO users (login, full_name, phone, email, user_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_user_new',
            'Тестовый пользователь',
            NULL,
            'test@example.org',
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: user_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'user_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось user_id, получено %', actual_column;
        END IF;
    END;

    -- 2.2. NOT NULL users.login
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец login.
    BEGIN
        INSERT INTO users (login, full_name, phone, email)
        VALUES (
            NULL,
            'Тестовый пользователь',
            NULL,
            'test@example.org'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: login, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'login' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось login, получено %', actual_column;
        END IF;
    END;

    -- 2.3. NOT NULL users.full_name
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец full_name.
    BEGIN
        INSERT INTO users (login, full_name, phone, email)
        VALUES (
            '__test_user_new',
            NULL,
            NULL,
            'test@example.org'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: full_name, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'full_name' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось full_name, получено %', actual_column;
        END IF;
    END;

    -- 2.4. PRIMARY KEY users_pkey
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение users_pkey.
    BEGIN
        INSERT INTO users (login, full_name, phone, email, user_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_user_new',
            'Тестовый пользователь',
            NULL,
            'test@example.org',
            (SELECT user_id FROM users WHERE login = '__test_user_base')
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: users_pkey, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'users_pkey' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось users_pkey, получено %', actual_constraint;
        END IF;
    END;

    -- 2.5. UNIQUE users_login_key
    -- Негативный тест: повтор существующего уникального ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение users_login_key.
    BEGIN
        INSERT INTO users (login, full_name, phone, email)
        VALUES (
            '__test_user_base',
            'Тестовый пользователь',
            NULL,
            'test@example.org'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: users_login_key, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'users_login_key' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось users_login_key, получено %', actual_constraint;
        END IF;
    END;

    -- 2.6. CHECK users_login_check
    -- Негативный тест: логин состоит из пробелов.
    -- Ожидается ошибка SQLSTATE 23514, ограничение users_login_check.
    BEGIN
        INSERT INTO users (login, full_name, phone, email)
        VALUES (
            ' ',
            'Тестовый пользователь',
            NULL,
            'test@example.org'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: users_login_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'users_login_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось users_login_check, получено %', actual_constraint;
        END IF;
    END;

    -- 2.7. CHECK users_full_name_check
    -- Негативный тест: ФИО состоит из пробелов.
    -- Ожидается ошибка SQLSTATE 23514, ограничение users_full_name_check.
    BEGIN
        INSERT INTO users (login, full_name, phone, email)
        VALUES (
            '__test_user_new',
            ' ',
            NULL,
            'test@example.org'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: users_full_name_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'users_full_name_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось users_full_name_check, получено %', actual_constraint;
        END IF;
    END;

    -- 2.8. CHECK users_at_least_one_contact_check
    -- Негативный тест: оба контакта отсутствуют.
    -- Ожидается ошибка SQLSTATE 23514, ограничение users_at_least_one_contact_check.
    BEGIN
        INSERT INTO users (login, full_name, phone, email)
        VALUES (
            '__test_user_new',
            'Тестовый пользователь',
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: users_at_least_one_contact_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'users_at_least_one_contact_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось users_at_least_one_contact_check, получено %', actual_constraint;
        END IF;
    END;

    -- 2.9. users_at_least_one_contact_check: контакты из пробелов
    -- Негативный тест: контакты из пробелов.
    -- Ожидается ошибка SQLSTATE 23514, ограничение users_at_least_one_contact_check.
    BEGIN
        INSERT INTO users (login, full_name, phone, email)
        VALUES (
            '__test_user_new',
            'Тестовый пользователь',
            ' ',
            ' '
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: users_at_least_one_contact_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'users_at_least_one_contact_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось users_at_least_one_contact_check, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'users: пройдено 10 проверок (1 позитивная и 9 негативных).';
END;
$tests$;

-- 3. Чтение
SELECT * FROM users WHERE user_id = (SELECT user_id FROM users WHERE login = '__test_user_base');

-- 4. Откат тестовых данных
ROLLBACK;
