-- Проверки ограничений таблицы coworking_sections.
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
    -- NOT NULL coworking_sections.section_id
    -- NOT NULL coworking_sections.name
    -- PRIMARY KEY coworking_sections_pkey
    -- UNIQUE coworking_sections_name_key
    -- CHECK coworking_sections_name_check
    INSERT INTO coworking_sections (name)
    VALUES (
        '__test_section_base'
    );

    -- 2. Негативные тесты

    -- 2.1. NOT NULL coworking_sections.section_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец section_id.
    BEGIN
        INSERT INTO coworking_sections (name, section_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_section_new',
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: section_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'section_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось section_id, получено %', actual_column;
        END IF;
    END;

    -- 2.2. NOT NULL coworking_sections.name
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец name.
    BEGIN
        INSERT INTO coworking_sections (name)
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

    -- 2.3. PRIMARY KEY coworking_sections_pkey
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение coworking_sections_pkey.
    BEGIN
        INSERT INTO coworking_sections (name, section_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_section_new',
            (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base')
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: coworking_sections_pkey, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'coworking_sections_pkey' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось coworking_sections_pkey, получено %', actual_constraint;
        END IF;
    END;

    -- 2.4. UNIQUE coworking_sections_name_key
    -- Негативный тест: повтор существующего уникального ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение coworking_sections_name_key.
    BEGIN
        INSERT INTO coworking_sections (name)
        VALUES (
            '__test_section_base'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: coworking_sections_name_key, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'coworking_sections_name_key' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось coworking_sections_name_key, получено %', actual_constraint;
        END IF;
    END;

    -- 2.5. CHECK coworking_sections_name_check
    -- Негативный тест: название состоит из пробелов.
    -- Ожидается ошибка SQLSTATE 23514, ограничение coworking_sections_name_check.
    BEGIN
        INSERT INTO coworking_sections (name)
        VALUES (
            ' '
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: coworking_sections_name_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'coworking_sections_name_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось coworking_sections_name_check, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'coworking_sections: пройдено 6 проверок (1 позитивная и 5 негативных).';
END;
$tests$;

-- 3. Чтение
SELECT * FROM coworking_sections WHERE section_id = (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base');

-- 4. Откат тестовых данных
ROLLBACK;
