-- Проверки ограничений таблицы bookings.
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
    INSERT INTO users (login, full_name, phone, email)
    VALUES (
        '__test_user_base',
        'Тестовый пользователь',
        NULL,
        'test@example.org'
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

    -- 2. Общий позитивный тест: корректная вставка — ожидается успех.
    -- Проверяются ограничения:
    -- NOT NULL bookings.booking_id
    -- NOT NULL bookings.user_id
    -- NOT NULL bookings.place_id
    -- NOT NULL bookings.starts_at
    -- NOT NULL bookings.ends_at
    -- NOT NULL bookings.status
    -- NOT NULL bookings.total_price
    -- PRIMARY KEY bookings_pkey
    -- FOREIGN KEY bookings_user_fk
    -- FOREIGN KEY bookings_place_fk
    -- CHECK bookings_period_check
    -- CHECK bookings_status_check
    -- CHECK bookings_total_price_check
    -- CHECK bookings_attendance_check
    -- EXCLUDE bookings_no_overlap
    INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
    VALUES (
        (SELECT user_id FROM users WHERE login = '__test_user_base'),
        (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
        TIMESTAMPTZ '2035-05-01 10:00+03',
        TIMESTAMPTZ '2035-05-01 11:00+03',
        'confirmed',
        100.00,
        NULL,
        NULL
    );

    -- 3. Негативные тесты

    -- 3.1. NOT NULL bookings.booking_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец booking_id.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at, booking_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: booking_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'booking_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось booking_id, получено %', actual_column;
        END IF;
    END;

    -- 3.2. NOT NULL bookings.user_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец user_id.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            NULL,
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
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

    -- 3.3. NOT NULL bookings.place_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец place_id.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            NULL,
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
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

    -- 3.4. NOT NULL bookings.starts_at
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец starts_at.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            NULL,
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
            NULL
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

    -- 3.5. NOT NULL bookings.ends_at
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец ends_at.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            NULL,
            'pending_payment',
            100.00,
            NULL,
            NULL
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

    -- 3.6. NOT NULL bookings.status
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец status.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            NULL,
            100.00,
            NULL,
            NULL
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

    -- 3.7. NOT NULL bookings.total_price
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец total_price.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            NULL,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: total_price, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'total_price' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось total_price, получено %', actual_column;
        END IF;
    END;

    -- 3.8. PRIMARY KEY bookings_pkey
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение bookings_pkey.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at, booking_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
            NULL,
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03')
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: bookings_pkey, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_pkey' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_pkey, получено %', actual_constraint;
        END IF;
    END;

    -- 3.9. FOREIGN KEY bookings_user_fk
    -- Негативный тест: ссылка на отсутствующую строку users.
    -- Ожидается ошибка SQLSTATE 23503, ограничение bookings_user_fk.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT COALESCE(MAX(user_id), 0) + 1 FROM users),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: bookings_user_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_user_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_user_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.10. FOREIGN KEY bookings_place_fk
    -- Негативный тест: ссылка на отсутствующую строку coworking_places.
    -- Ожидается ошибка SQLSTATE 23503, ограничение bookings_place_fk.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT COALESCE(MAX(place_id), 0) + 1 FROM coworking_places),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: bookings_place_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_place_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_place_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.11. CHECK bookings_period_check
    -- Негативный тест: окончание равно началу.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_period_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            'pending_payment',
            100.00,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_period_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_period_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_period_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.12. CHECK bookings_status_check
    -- Негативный тест: неизвестный статус.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_status_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'unknown',
            100.00,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_status_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_status_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_status_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.13. CHECK bookings_total_price_check
    -- Негативный тест: отрицательная стоимость.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_total_price_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            -1.00,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_total_price_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_total_price_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_total_price_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.14. CHECK bookings_attendance_check
    -- Негативный тест: уход без зарегистрированного прихода.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_attendance_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
            TIMESTAMPTZ '2035-05-01 11:00+03'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_attendance_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_attendance_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_attendance_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.15. EXCLUDE bookings_no_overlap
    -- Негативный тест: период пересекается с исходной записью.
    -- Ожидается ошибка SQLSTATE 23P01, ограничение bookings_no_overlap.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03' + INTERVAL '30 minutes',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23P01: bookings_no_overlap, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23P01' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_no_overlap' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_no_overlap, получено %', actual_constraint;
        END IF;
    END;

    -- 3.16. bookings_total_price_check: NaN
    -- Негативный тест: NaN.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_total_price_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            'NaN'::NUMERIC,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_total_price_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_total_price_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_total_price_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.17. bookings_period_check: бесконечное окончание
    -- Негативный тест: бесконечное окончание.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_period_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            'infinity'::TIMESTAMPTZ,
            'pending_payment',
            100.00,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_period_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_period_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_period_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.18. bookings_period_check: бесконечное начало
    -- Негативный тест: бесконечное начало.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_period_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            '-infinity'::TIMESTAMPTZ,
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_period_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_period_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_period_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.19. bookings_attendance_check: уход раньше прихода
    -- Негативный тест: уход раньше прихода.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_attendance_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            TIMESTAMPTZ '2035-05-01 12:00+03',
            TIMESTAMPTZ '2035-05-01 11:00+03'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_attendance_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_attendance_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_attendance_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.20. bookings_attendance_check: бесконечный приход
    -- Негативный тест: бесконечный приход.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_attendance_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            'infinity'::TIMESTAMPTZ,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_attendance_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_attendance_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_attendance_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.21. bookings_attendance_check: бесконечный уход
    -- Негативный тест: бесконечный уход.
    -- Ожидается ошибка SQLSTATE 23514, ограничение bookings_attendance_check.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 11:00+03',
            TIMESTAMPTZ '2035-05-01 12:00+03',
            'pending_payment',
            100.00,
            TIMESTAMPTZ '2035-05-01 11:00+03',
            'infinity'::TIMESTAMPTZ
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: bookings_attendance_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_attendance_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_attendance_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.22. bookings_no_overlap: отменённая бронь может пересекаться
    -- Негативный тест: отменённая бронь может пересекаться.
    -- Ожидается ошибка SQLSTATE 23P01, ограничение bookings_no_overlap.
    BEGIN
        INSERT INTO bookings (user_id, place_id, starts_at, ends_at, status, total_price, arrived_at, departed_at)
        VALUES (
            (SELECT user_id FROM users WHERE login = '__test_user_base'),
            (SELECT place_id FROM coworking_places WHERE name = '__test_place_base'),
            TIMESTAMPTZ '2035-05-01 10:00+03',
            TIMESTAMPTZ '2035-05-01 11:00+03',
            'pending_payment',
            100.00,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23P01: bookings_no_overlap, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23P01' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'bookings_no_overlap' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось bookings_no_overlap, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'bookings: пройдено 23 проверок (1 позитивная и 22 негативных).';
END;
$tests$;

-- 4. Чтение
SELECT * FROM bookings WHERE booking_id = (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03');

-- 5. Откат тестовых данных
ROLLBACK;
