-- Проверки ограничений таблицы user_roles.
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
    INSERT INTO roles (name)
    VALUES (
        '__test_role_base'
    );

    INSERT INTO users (login, full_name, phone, email)
    VALUES (
        '__test_user_base',
        'Тестовый пользователь',
        NULL,
        'test@example.org'
    );


    INSERT INTO users (login, full_name, phone, email)
    VALUES (
        '__test_user_other',
        'Тестовый пользователь',
        NULL,
        'test@example.org'
    );

    -- 2. Общий позитивный тест: корректная вставка — ожидается успех.
    -- Проверяются ограничения:
    -- NOT NULL user_roles.user_role_id
    -- NOT NULL user_roles.role_id
    -- NOT NULL user_roles.user_id
    -- NOT NULL user_roles.assigned_by
    -- NOT NULL user_roles.valid_from
    -- NOT NULL user_roles.valid_to
    -- PRIMARY KEY user_roles_pk
    -- UNIQUE user_roles_role_user_key
    -- FOREIGN KEY user_roles_role_fk
    -- FOREIGN KEY user_roles_user_fk
    -- FOREIGN KEY user_roles_author_fk
    -- CHECK user_roles_period_check
    INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
    VALUES (
        (SELECT role_id FROM roles WHERE name = '__test_role_base'),
        (SELECT user_id FROM users WHERE login = '__test_user_base'),
        (SELECT user_id FROM users WHERE login = '__test_user_base'),
        TIMESTAMPTZ '2035-05-01 10:00+03',
        'infinity'
    );

    -- 3. Негативные тесты

    -- 3.1. NOT NULL user_roles.user_role_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец user_role_id.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to, user_role_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            'infinity',
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: user_role_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'user_role_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось user_role_id, получено %', actual_column;
        END IF;
    END;

    -- 3.2. NOT NULL user_roles.role_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец role_id.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            NULL,
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            'infinity'
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

    -- 3.3. NOT NULL user_roles.user_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец user_id.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            NULL,
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            'infinity'
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

    -- 3.4. NOT NULL user_roles.assigned_by
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец assigned_by.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            NULL,
            TIMESTAMPTZ '2035-05-01 10:00+03',
            'infinity'
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

    -- 3.5. NOT NULL user_roles.valid_from
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец valid_from.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            NULL,
            'infinity'
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

    -- 3.6. NOT NULL user_roles.valid_to
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец valid_to.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            NULL
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

    -- 3.7. PRIMARY KEY user_roles_pk
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение user_roles_pk.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to, user_role_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            'infinity',
            (SELECT user_role_id FROM user_roles WHERE role_id = (SELECT role_id FROM roles WHERE name = '__test_role_base') AND user_id = (SELECT user_id FROM users WHERE login = '__test_user_base'))
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: user_roles_pk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'user_roles_pk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось user_roles_pk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.8. UNIQUE user_roles_role_user_key
    -- Негативный тест: повтор существующего уникального ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение user_roles_role_user_key.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            'infinity'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: user_roles_role_user_key, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'user_roles_role_user_key' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось user_roles_role_user_key, получено %', actual_constraint;
        END IF;
    END;

    -- 3.9. FOREIGN KEY user_roles_role_fk
    -- Негативный тест: ссылка на отсутствующую строку roles.
    -- Ожидается ошибка SQLSTATE 23503, ограничение user_roles_role_fk.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT COALESCE(MAX(role_id), 0) + 1 FROM roles),
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            'infinity'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: user_roles_role_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'user_roles_role_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось user_roles_role_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.10. FOREIGN KEY user_roles_user_fk
    -- Негативный тест: ссылка на отсутствующую строку users.
    -- Ожидается ошибка SQLSTATE 23503, ограничение user_roles_user_fk.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT COALESCE(MAX(user_id), 0) + 1 FROM users),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            'infinity'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: user_roles_user_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'user_roles_user_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось user_roles_user_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.11. FOREIGN KEY user_roles_author_fk
    -- Негативный тест: ссылка на отсутствующую строку users.
    -- Ожидается ошибка SQLSTATE 23503, ограничение user_roles_author_fk.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            (SELECT COALESCE(MAX(user_id), 0) + 1 FROM users),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            'infinity'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: user_roles_author_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'user_roles_author_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось user_roles_author_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.12. CHECK user_roles_period_check
    -- Негативный тест: окончание равно началу.
    -- Ожидается ошибка SQLSTATE 23514, ограничение user_roles_period_check.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            TIMESTAMPTZ '2035-05-01 10:00+03'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: user_roles_period_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'user_roles_period_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось user_roles_period_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.13. user_roles_period_check: бесконечное начало
    -- Негативный тест: бесконечное начало.
    -- Ожидается ошибка SQLSTATE 23514, ограничение user_roles_period_check.
    BEGIN
        INSERT INTO user_roles (role_id, user_id, assigned_by, valid_from, valid_to)
        VALUES (
            (SELECT role_id FROM roles WHERE name = '__test_role_base'),
            (SELECT user_id FROM users WHERE login = '__test_user_other'),
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            '-infinity'::TIMESTAMPTZ,
            'infinity'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: user_roles_period_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'user_roles_period_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось user_roles_period_check, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'user_roles: пройдено 14 проверок (1 позитивная и 13 негативных).';
END;
$tests$;

-- 4. Чтение
SELECT * FROM user_roles WHERE user_role_id = (SELECT user_role_id FROM user_roles WHERE role_id = (SELECT role_id FROM roles WHERE name = '__test_role_base') AND user_id = (SELECT user_id FROM users WHERE login = '__test_user_base'));

-- 5. Откат тестовых данных
ROLLBACK;
