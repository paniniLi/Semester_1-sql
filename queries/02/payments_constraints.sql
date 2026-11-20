-- Проверки ограничений таблицы payments.
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

    -- 2. Общий позитивный тест: корректная вставка — ожидается успех.
    -- Проверяются ограничения:
    -- NOT NULL payments.payment_id
    -- NOT NULL payments.booking_id
    -- NOT NULL payments.amount
    -- NOT NULL payments.status
    -- NOT NULL payments.created_at
    -- PRIMARY KEY payments_pkey
    -- FOREIGN KEY payments_booking_fk
    -- CHECK payments_amount_check
    -- CHECK payments_status_check
    -- CHECK payments_paid_at_check
    INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
    VALUES (
        (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
        100.00,
        'pending',
        CURRENT_TIMESTAMP,
        NULL
    );

    -- 3. Негативные тесты

    -- 3.1. NOT NULL payments.payment_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец payment_id.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at, payment_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            100.00,
            'pending',
            CURRENT_TIMESTAMP,
            NULL,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: payment_id, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'payment_id' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось payment_id, получено %', actual_column;
        END IF;
    END;

    -- 3.2. NOT NULL payments.booking_id
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец booking_id.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            NULL,
            100.00,
            'pending',
            CURRENT_TIMESTAMP,
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

    -- 3.3. NOT NULL payments.amount
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец amount.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            NULL,
            'pending',
            CURRENT_TIMESTAMP,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23502: amount, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23502' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_column IS DISTINCT FROM 'amount' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось amount, получено %', actual_column;
        END IF;
    END;

    -- 3.4. NOT NULL payments.status
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец status.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            100.00,
            NULL,
            CURRENT_TIMESTAMP,
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

    -- 3.5. NOT NULL payments.created_at
    -- Негативный тест: NULL в обязательном столбце.
    -- Ожидается ошибка SQLSTATE 23502, столбец created_at.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            100.00,
            'pending',
            NULL,
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

    -- 3.6. PRIMARY KEY payments_pkey
    -- Негативный тест: повтор существующего первичного ключа.
    -- Ожидается ошибка SQLSTATE 23505, ограничение payments_pkey.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at, payment_id)
        OVERRIDING SYSTEM VALUE
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            100.00,
            'pending',
            CURRENT_TIMESTAMP,
            NULL,
            (SELECT payment_id FROM payments WHERE booking_id = (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'))
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23505: payments_pkey, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23505' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'payments_pkey' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось payments_pkey, получено %', actual_constraint;
        END IF;
    END;

    -- 3.7. FOREIGN KEY payments_booking_fk
    -- Негативный тест: ссылка на отсутствующую строку bookings.
    -- Ожидается ошибка SQLSTATE 23503, ограничение payments_booking_fk.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            (SELECT COALESCE(MAX(booking_id), 0) + 1 FROM bookings),
            100.00,
            'pending',
            CURRENT_TIMESTAMP,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23503: payments_booking_fk, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23503' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'payments_booking_fk' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось payments_booking_fk, получено %', actual_constraint;
        END IF;
    END;

    -- 3.8. CHECK payments_amount_check
    -- Негативный тест: отрицательная сумма.
    -- Ожидается ошибка SQLSTATE 23514, ограничение payments_amount_check.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            -1.00,
            'pending',
            CURRENT_TIMESTAMP,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: payments_amount_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'payments_amount_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось payments_amount_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.9. CHECK payments_status_check
    -- Негативный тест: неизвестный статус.
    -- Ожидается ошибка SQLSTATE 23514, ограничение payments_status_check.
    -- Вложенный блок откатит временное удаление пересекающейся проверки.
    BEGIN
        ALTER TABLE payments DROP CONSTRAINT payments_paid_at_check;
        BEGIN
            INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
            VALUES (
                (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
                100.00,
                'unknown',
                CURRENT_TIMESTAMP,
                NULL
            );
            RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: payments_status_check, но вставка прошла';
        EXCEPTION WHEN OTHERS THEN
            IF SQLSTATE <> '23514' THEN
                RAISE;
            END IF;
            GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
            IF actual_constraint IS DISTINCT FROM 'payments_status_check' THEN
                RAISE EXCEPTION 'Неверный источник ошибки: ожидалось payments_status_check, получено %', actual_constraint;
            END IF;
        END;
        RAISE SQLSTATE 'ZX001';
    EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;
    END;

    -- 3.10. CHECK payments_paid_at_check
    -- Негативный тест: успешная оплата без даты оплаты.
    -- Ожидается ошибка SQLSTATE 23514, ограничение payments_paid_at_check.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            100.00,
            'succeeded',
            CURRENT_TIMESTAMP,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: payments_paid_at_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'payments_paid_at_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось payments_paid_at_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.11. payments_amount_check: NaN
    -- Негативный тест: NaN.
    -- Ожидается ошибка SQLSTATE 23514, ограничение payments_amount_check.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            'NaN'::NUMERIC,
            'pending',
            CURRENT_TIMESTAMP,
            NULL
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: payments_amount_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'payments_amount_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось payments_amount_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.12. payments_paid_at_check: дата оплаты у ожидающего платежа
    -- Негативный тест: дата оплаты у ожидающего платежа.
    -- Ожидается ошибка SQLSTATE 23514, ограничение payments_paid_at_check.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            100.00,
            'pending',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: payments_paid_at_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'payments_paid_at_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось payments_paid_at_check, получено %', actual_constraint;
        END IF;
    END;

    -- 3.13. payments_paid_at_check: оплата раньше создания
    -- Негативный тест: оплата раньше создания.
    -- Ожидается ошибка SQLSTATE 23514, ограничение payments_paid_at_check.
    BEGIN
        INSERT INTO payments (booking_id, amount, status, created_at, paid_at)
        VALUES (
            (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'),
            100.00,
            'succeeded',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP - INTERVAL '1 second'
        );
        RAISE EXCEPTION 'Ожидалась ошибка SQLSTATE 23514: payments_paid_at_check, но вставка прошла';
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> '23514' THEN
            RAISE;
        END IF;
        GET STACKED DIAGNOSTICS actual_constraint = CONSTRAINT_NAME, actual_column = COLUMN_NAME;
        IF actual_constraint IS DISTINCT FROM 'payments_paid_at_check' THEN
            RAISE EXCEPTION 'Неверный источник ошибки: ожидалось payments_paid_at_check, получено %', actual_constraint;
        END IF;
    END;

    RAISE NOTICE 'payments: пройдено 14 проверок (1 позитивная и 13 негативных).';
END;
$tests$;

-- 4. Чтение
SELECT * FROM payments WHERE payment_id = (SELECT payment_id FROM payments WHERE booking_id = (SELECT booking_id FROM bookings WHERE place_id = (SELECT place_id FROM coworking_places WHERE name = '__test_place_base') AND starts_at = TIMESTAMPTZ '2035-05-01 10:00+03'));

-- 5. Откат тестовых данных
ROLLBACK;
