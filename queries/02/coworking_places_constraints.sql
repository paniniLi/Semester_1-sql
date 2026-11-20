-- Проверки ограничений таблицы coworking_places.
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
    INSERT INTO coworking_sections (name)
    VALUES (
        '__test_section_base'
    );

    -- 2. Общий позитивный тест: корректная вставка — ожидается успех.
    -- Проверяются ограничения:
    -- NOT NULL coworking_places.place_id
    -- NOT NULL coworking_places.name
    -- NOT NULL coworking_places.section_id
    -- NOT NULL coworking_places.status
    -- PRIMARY KEY coworking_places_pkey
    -- UNIQUE coworking_places_name_section_key
    -- FOREIGN KEY coworking_places_section_fk
    -- CHECK coworking_places_name_check
    -- CHECK coworking_places_status_check
    -- CHECK coworking_places_characteristics_check
    INSERT INTO coworking_places (name, section_id, status, characteristics)
    VALUES (
        '__test_place_base',
        (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
        'available',
        '{"equipment": ["monitor"]}'::JSONB
    );

    -- 3. Негативные тесты

    -- 3.1. NOT NULL coworking_places.place_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец place_id.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics, place_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_place_new',
            (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
            'available',
            '{"equipment": ["monitor"]}'::JSONB,
            NULL
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

    -- 3.2. NOT NULL coworking_places.name
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец name.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics)
        VALUES (
            NULL,
            (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
            'available',
            '{"equipment": ["monitor"]}'::JSONB
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

    -- 3.3. NOT NULL coworking_places.section_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец section_id.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics)
        VALUES (
            '__test_place_new',
            NULL,
            'available',
            '{"equipment": ["monitor"]}'::JSONB
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

    -- 3.4. NOT NULL coworking_places.status
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец status.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics)
        VALUES (
            '__test_place_new',
            (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
            NULL,
            '{"equipment": ["monitor"]}'::JSONB
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: status, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'status' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось status, получено %', actual_column;
        END IF;
    END;

    -- 3.5. PRIMARY KEY coworking_places_pkey
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение coworking_places_pkey.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics, place_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            '__test_place_new',
            (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
            'available',
            '{"equipment": ["monitor"]}'::JSONB,
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base')
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: coworking_places_pkey, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'coworking_places_pkey' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось coworking_places_pkey, получено %', actual_constraint;
        END IF;
    END;

    -- 3.6. UNIQUE coworking_places_name_section_key
    -- Негативный тест: повтор существующего уникального ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение coworking_places_name_section_key.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics)
        VALUES (
            '__test_place_base',
            (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
            'available',
            '{"equipment": ["monitor"]}'::JSONB
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: coworking_places_name_section_key, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'coworking_places_name_section_key' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось coworking_places_name_section_key, получено %', actual_constraint;
        END IF;
    END;

    -- 3.7. FOREIGN KEY coworking_places_section_fk
    -- Негативный тест: ссылка на отсутствующую строку coworking_sections.
    -- Ожидается ошибка SQLSTATE 23503, ограничение coworking_places_section_fk.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics)
        VALUES (
            '__test_place_new',
            (SELECT COALESCE(MAX(section_id), 0) + 1 FROM coworking_sections),
            'available',
            '{"equipment": ["monitor"]}'::JSONB
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: coworking_places_section_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'coworking_places_section_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось coworking_places_section_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.8. CHECK coworking_places_name_check
    -- Негативный тест: название состоит из пробелов.
    -- Ожидается ошибка SQLSTATE 23514, ограничение coworking_places_name_check.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics)
        VALUES (
            ' ',
            (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
            'available',
            '{"equipment": ["monitor"]}'::JSONB
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: coworking_places_name_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'coworking_places_name_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось coworking_places_name_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.9. CHECK coworking_places_status_check
    -- Негативный тест: неизвестный статус.
    -- Ожидается ошибка SQLSTATE 23514, ограничение coworking_places_status_check.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics)
        VALUES (
            '__test_place_new',
            (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
            'unknown',
            '{"equipment": ["monitor"]}'::JSONB
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: coworking_places_status_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'coworking_places_status_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось coworking_places_status_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.10. CHECK coworking_places_characteristics_check
    -- Негативный тест: JSON-массив вместо объекта.
    -- Ожидается ошибка SQLSTATE 23514, ограничение coworking_places_characteristics_check.
    BEGIN
        INSERT INTO coworking_places (name, section_id, status, characteristics)
        VALUES (
            '__test_place_new',
            (SELECT section_id FROM coworking_sections WHERE name = '__test_section_base'),
            'available',
            '[]'::JSONB
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: coworking_places_characteristics_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'coworking_places_characteristics_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось coworking_places_characteristics_check, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'coworking_places: пройдено 11 проверок (1 позитивная и 10 негативных).';
END;
$tests$;

-- 4. Чтение
SELECT * FROM coworking_places WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base');

-- 5. Откат тестовых данных
ROLLBACK;
