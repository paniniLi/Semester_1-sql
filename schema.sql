BEGIN;

-- GiST-классы операторов для сравнения BIGINT через = в EXCLUDE.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE users (
    user_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    login TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,

    CONSTRAINT users_login_check CHECK (BTRIM(login) <> ''),
    CONSTRAINT users_full_name_check CHECK (BTRIM(full_name) <> ''),
    CONSTRAINT users_at_least_one_contact_check CHECK (
        NULLIF(BTRIM(phone), '') IS NOT NULL
        OR NULLIF(BTRIM(email), '') IS NOT NULL
    )
);

COMMENT ON TABLE users IS 'Пользователи коворкинга.';
COMMENT ON COLUMN users.user_id IS 'Уникальный идентификатор пользователя';
COMMENT ON COLUMN users.login IS 'Логин пользователя';
COMMENT ON COLUMN users.full_name IS 'ФИО пользователя';
COMMENT ON COLUMN users.phone IS 'Контактный телефон пользователя';
COMMENT ON COLUMN users.email IS 'Электронная почта пользователя';

COMMENT ON CONSTRAINT users_at_least_one_contact_check ON users IS 'Обязательно указание хотя бы одного способа связи: телефона или электронной почты. NULL, пустые строки и строки из одних пробелов не считаются заполненным контактом.';

CREATE TABLE roles (
    role_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,

    CONSTRAINT roles_name_check CHECK (BTRIM(name) <> '')
);

COMMENT ON TABLE roles IS 'Справочник ролей пользователей.';
COMMENT ON COLUMN roles.role_id IS 'Уникальный идентификатор роли';
COMMENT ON COLUMN roles.name IS 'Название роли';

CREATE TABLE user_roles (
    user_role_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL,
    role_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    assigned_by BIGINT NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ NOT NULL DEFAULT 'infinity'::TIMESTAMPTZ,

    CONSTRAINT user_roles_pk PRIMARY KEY (user_role_id),
    CONSTRAINT user_roles_role_user_key UNIQUE (role_id, user_id),

    CONSTRAINT user_roles_role_fk FOREIGN KEY (role_id)
        REFERENCES roles (role_id) ON DELETE RESTRICT,

    CONSTRAINT user_roles_user_fk FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT user_roles_author_fk FOREIGN KEY (assigned_by)
        REFERENCES users (user_id) ON DELETE RESTRICT,

    CONSTRAINT user_roles_period_check CHECK (isfinite(valid_from) AND valid_to > valid_from)
);

COMMENT ON TABLE user_roles IS 'Назначения ролей пользователям.';
COMMENT ON COLUMN user_roles.user_role_id IS 'Уникальный идентификатор назначения роли пользователю.';
COMMENT ON COLUMN user_roles.role_id IS 'Назначенная пользователю роль. Внешний ключ на roles.';
COMMENT ON COLUMN user_roles.user_id IS 'Получатель роли. Внешний ключ на users.';
COMMENT ON COLUMN user_roles.assigned_by IS 'Пользователь, присвоивший роль. Внешний ключ на users.';
COMMENT ON COLUMN user_roles.valid_from IS 'Начало периода действия роли (включительно).';
COMMENT ON COLUMN user_roles.valid_to IS 'Окончание периода действия роли (не включительно); по умолчанию infinity — бессрочно.';

COMMENT ON CONSTRAINT user_roles_role_user_key ON user_roles IS 'Альтернативный ключ: сочетание роли и её получателя уникально.';
COMMENT ON CONSTRAINT user_roles_role_fk ON user_roles IS 'ON DELETE RESTRICT: запрещено удаление роли, пока существуют её назначения пользователям, чтобы не потерять сведения о назначенных правах. Приложение должно проверить использование роли до её удаления.';
COMMENT ON CONSTRAINT user_roles_user_fk ON user_roles IS 'ON DELETE RESTRICT: запрещено удаление пользователя, пока существуют назначения ролей, в которых он указан получателем.';
COMMENT ON CONSTRAINT user_roles_author_fk ON user_roles IS 'ON DELETE RESTRICT: запрещено удаление пользователя, пока существуют назначения ролей, в которых он указан автором, чтобы сохранить сведения о том, кто назначил роль.';
COMMENT ON CONSTRAINT user_roles_period_check ON user_roles IS 'Начало периода действия роли должно быть конечным; окончание должно быть строго позже начала.';

CREATE TABLE tariff_plans (
    tariff_plan_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT tariff_plans_name_check CHECK (BTRIM(name) <> '')
);

COMMENT ON TABLE tariff_plans IS 'Справочник тарифных планов.';
COMMENT ON COLUMN tariff_plans.tariff_plan_id IS 'Уникальный идентификатор тарифа.';
COMMENT ON COLUMN tariff_plans.name IS 'Название тарифного плана.';
COMMENT ON COLUMN tariff_plans.created_at IS 'Дата и время создания тарифа; по умолчанию начало текущей транзакции.';

CREATE TABLE tariff_prices (
    tariff_price_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    tariff_plan_id BIGINT NOT NULL,
    price NUMERIC(12, 2) NOT NULL,
    price_unit TEXT NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ NOT NULL DEFAULT 'infinity'::TIMESTAMPTZ,
    assigned_by BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT tariff_prices_tariff_fk FOREIGN KEY (tariff_plan_id)
        REFERENCES tariff_plans (tariff_plan_id) ON DELETE RESTRICT,
    CONSTRAINT tariff_prices_author_fk FOREIGN KEY (assigned_by)
        REFERENCES users (user_id) ON DELETE RESTRICT,

    CONSTRAINT tariff_prices_price_check CHECK (price >= 0 AND price <> 'NaN'::NUMERIC),
    CONSTRAINT tariff_prices_unit_check CHECK (BTRIM(price_unit) <> ''),
    CONSTRAINT tariff_prices_period_check CHECK (isfinite(valid_from) AND valid_to > valid_from),
    CONSTRAINT tariff_prices_no_overlap EXCLUDE USING gist (
        tariff_plan_id WITH =,
        tstzrange(valid_from, valid_to, '[)') WITH &&
    )
);

COMMENT ON TABLE tariff_prices IS 'История цен тарифов.';
COMMENT ON COLUMN tariff_prices.tariff_price_id IS 'Уникальный идентификатор записи изменения цены тарифного плана.';
COMMENT ON COLUMN tariff_prices.tariff_plan_id IS 'Идентификатор тарифного плана. Внешний ключ на tariff_plans.';
COMMENT ON COLUMN tariff_prices.price IS 'Неотрицательная цена тарифного плана.';
COMMENT ON COLUMN tariff_prices.price_unit IS 'Единица измерения цены (hour, day, minute, etc.).';
COMMENT ON COLUMN tariff_prices.valid_from IS 'Начало периода действия цены (включительно).';
COMMENT ON COLUMN tariff_prices.valid_to IS 'Окончание периода действия цены (не включительно); infinity по умолчанию.';
COMMENT ON COLUMN tariff_prices.assigned_by IS 'Идентификатор пользователя, создавшего цену. Внешний ключ на users.';
COMMENT ON COLUMN tariff_prices.created_at IS 'Дата и время изменения цены; по умолчанию начало текущей транзакции.';

COMMENT ON CONSTRAINT tariff_prices_tariff_fk ON tariff_prices IS 'ON DELETE RESTRICT: запрещено удаление тарифного плана, пока существуют записи истории его цен.';
COMMENT ON CONSTRAINT tariff_prices_author_fk ON tariff_prices IS 'ON DELETE RESTRICT: запрещено удаление пользователя, пока существуют созданные им записи истории цен, чтобы сохранить сведения об авторе изменений.';
COMMENT ON CONSTRAINT tariff_prices_no_overlap ON tariff_prices IS 'Для одного тарифа запрещены пересекающиеся периоды цен [valid_from, valid_to).';

CREATE TABLE coworking_sections (
    section_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    name TEXT NOT NULL

    CONSTRAINT coworking_sections_name_check CHECK (BTRIM(name) <> '')
);

COMMENT ON TABLE coworking_sections IS 'Секции коворкинга.';
COMMENT ON COLUMN coworking_sections.section_id IS 'Уникальный идентификатор секции.';
COMMENT ON COLUMN coworking_sections.name IS 'Название секции коворкинга.';

CREATE TABLE coworking_places (
    place_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    section_id BIGINT NOT NULL,
    status TEXT NOT NULL DEFAULT 'available',
    characteristics JSONB,

    CONSTRAINT coworking_places_section_fk FOREIGN KEY (section_id)
        REFERENCES coworking_sections (section_id) ON DELETE RESTRICT,

    CONSTRAINT coworking_places_name_section_key UNIQUE (name, section_id),
    CONSTRAINT coworking_places_name_check CHECK (BTRIM(name) <> ''),
    CONSTRAINT coworking_places_status_check CHECK (status IN ('available', 'maintenance')),
    CONSTRAINT coworking_places_characteristics_check CHECK (
        characteristics IS NULL OR jsonb_typeof(characteristics) = 'object'
    )
);

COMMENT ON TABLE coworking_places IS 'Места коворкинга.';
COMMENT ON COLUMN coworking_places.place_id IS 'Уникальный идентификатор места.';
COMMENT ON COLUMN coworking_places.name IS 'Имя места коворкинга.';
COMMENT ON COLUMN coworking_places.section_id IS 'Идентификатор секции коворкинга. Внешний ключ на coworking_sections.';
COMMENT ON COLUMN coworking_places.status IS 'Статус места коворкинга: available — доступно (по умолчанию); maintenance — закрыто на обслуживание. Занятость по времени определяется бронированиями.';
COMMENT ON COLUMN coworking_places.characteristics IS 'Характеристики места и оборудования, например {"equipment": ["monitor", "docking_station"]}; SQL NULL означает отсутствие сведений.';

COMMENT ON CONSTRAINT coworking_places_name_section_key ON coworking_places IS 'Альтернативный ключ: название места уникально в пределах секции коворкинга.';
COMMENT ON CONSTRAINT coworking_places_section_fk ON coworking_places IS 'ON DELETE RESTRICT: запрещено удаление секции, пока существуют связанные с ней места коворкинга, чтобы сохранить сведения об их расположении.';

CREATE TABLE bookings (
    booking_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    place_id BIGINT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending_payment',
    total_price NUMERIC(12, 2) NOT NULL,
    arrived_at TIMESTAMPTZ,
    departed_at TIMESTAMPTZ,

    CONSTRAINT bookings_user_fk FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT bookings_place_fk FOREIGN KEY (place_id)
        REFERENCES coworking_places (place_id) ON DELETE RESTRICT,

    CONSTRAINT bookings_period_check CHECK (
        isfinite(starts_at) AND isfinite(ends_at) AND ends_at > starts_at
    ),
    CONSTRAINT bookings_status_check CHECK (
        status IN ('confirmed', 'pending_payment', 'cancelled')
    ),
    CONSTRAINT bookings_total_price_check CHECK (
        total_price >= 0 AND total_price <> 'NaN'::NUMERIC
    ),
    CONSTRAINT bookings_attendance_check CHECK (
        (arrived_at IS NULL OR isfinite(arrived_at))
        AND (departed_at IS NULL OR (
            arrived_at IS NOT NULL
            AND isfinite(departed_at)
            AND departed_at >= arrived_at
        ))
    ),
    CONSTRAINT bookings_no_overlap EXCLUDE USING gist (
        place_id WITH =,
        tstzrange(starts_at, ends_at, '[)') WITH &&
    ) WHERE (status IN ('confirmed', 'pending_payment'))
);

COMMENT ON TABLE bookings IS 'История бронирования мест.';
COMMENT ON COLUMN bookings.booking_id IS 'Уникальный идентификатор бронирования.';
COMMENT ON COLUMN bookings.user_id IS 'Идентификатор пользователя, создавшего бронирование. Внешний ключ на users.';
COMMENT ON COLUMN bookings.place_id IS 'Идентификатор забронированного места. Внешний ключ на coworking_places.';
COMMENT ON COLUMN bookings.starts_at IS 'Начало периода действия бронирования (включительно).';
COMMENT ON COLUMN bookings.ends_at IS 'Окончание периода действия бронирования (не включительно).';
COMMENT ON COLUMN bookings.status IS 'Статус бронирования: confirmed — действителен; pending_payment — в ожидании оплаты (по умолчанию); cancelled — отменён.';
COMMENT ON COLUMN bookings.total_price IS 'Итоговая стоимость бронирования, зафиксированная при создании брони; не пересчитывается при изменении тарифов.';
COMMENT ON COLUMN bookings.arrived_at IS 'Фактические дата и время прихода; NULL — приход не зарегистрирован.';
COMMENT ON COLUMN bookings.departed_at IS 'Фактические дата и время ухода; NULL — уход не зарегистрирован.';

COMMENT ON CONSTRAINT bookings_user_fk ON bookings IS 'ON DELETE RESTRICT: запрещено удаление пользователя, пока существуют его бронирования, чтобы сохранить историю бронирований клиента.';
COMMENT ON CONSTRAINT bookings_place_fk ON bookings IS 'ON DELETE RESTRICT: запрещено удаление места коворкинга, пока существуют его бронирования, чтобы сохранить сведения о забронированных местах.';
COMMENT ON CONSTRAINT bookings_no_overlap ON bookings IS 'Для одного места запрещены пересечения [starts_at, ends_at) среди confirmed и pending_payment; отменённые брони исключены.';

CREATE TABLE place_tariff_assignments (
    assignment_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    tariff_plan_id BIGINT NOT NULL,
    place_id BIGINT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL DEFAULT 'infinity'::TIMESTAMPTZ,
    assigned_by BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT place_tariff_assignments_tariff_fk FOREIGN KEY (tariff_plan_id)
        REFERENCES tariff_plans (tariff_plan_id) ON DELETE RESTRICT,
    CONSTRAINT place_tariff_assignments_place_fk FOREIGN KEY (place_id)
        REFERENCES coworking_places (place_id) ON DELETE RESTRICT,
    CONSTRAINT place_tariff_assignments_author_fk FOREIGN KEY (assigned_by)
        REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT place_tariff_assignments_period_check CHECK (
        isfinite(starts_at) AND ends_at > starts_at
    ),
    CONSTRAINT place_tariff_assignments_no_overlap EXCLUDE USING gist (
        place_id WITH =,
        tstzrange(starts_at, ends_at, '[)') WITH &&
    )
);

COMMENT ON TABLE place_tariff_assignments IS 'Назначения тарифных планов местам коворкинга.';
COMMENT ON COLUMN place_tariff_assignments.assignment_id IS 'Уникальный идентификатор назначения тарифного плана месту.';
COMMENT ON COLUMN place_tariff_assignments.tariff_plan_id IS 'Идентификатор назначенного тарифного плана. Внешний ключ на tariff_plans.';
COMMENT ON COLUMN place_tariff_assignments.place_id IS 'Идентификатор места, которому назначен тарифный план. Внешний ключ на coworking_places.';
COMMENT ON COLUMN place_tariff_assignments.starts_at IS 'Начало периода действия тарифного плана на месте (включительно).';
COMMENT ON COLUMN place_tariff_assignments.ends_at IS 'Окончание периода действия тарифного плана на месте (не включительно); infinity по умолчанию.';
COMMENT ON COLUMN place_tariff_assignments.assigned_by IS 'Идентификатор пользователя, назначившего тарифный план месту. Внешний ключ на users.';
COMMENT ON COLUMN place_tariff_assignments.created_at IS 'Дата и время создания назначения; по умолчанию начало текущей транзакции.';

COMMENT ON CONSTRAINT place_tariff_assignments_tariff_fk ON place_tariff_assignments IS 'ON DELETE RESTRICT: запрещено удаление тарифного плана, пока существуют его назначения местам коворкинга.';
COMMENT ON CONSTRAINT place_tariff_assignments_place_fk ON place_tariff_assignments IS 'ON DELETE RESTRICT: запрещено удаление места коворкинга, пока существуют назначения тарифных планов этому месту.';
COMMENT ON CONSTRAINT place_tariff_assignments_author_fk ON place_tariff_assignments IS 'ON DELETE RESTRICT: запрещено удаление пользователя, пока существуют созданные им назначения тарифных планов местам, чтобы сохранить сведения об авторе назначений.';
COMMENT ON CONSTRAINT place_tariff_assignments_no_overlap ON place_tariff_assignments IS 'Для одного места запрещены пересекающиеся назначения любых тарифов; соседние интервалы разрешены.';

CREATE TABLE section_tariff_assignments (
    assignment_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    tariff_plan_id BIGINT NOT NULL,
    section_id BIGINT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL DEFAULT 'infinity'::TIMESTAMPTZ,
    assigned_by BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT section_tariff_assignments_tariff_fk FOREIGN KEY (tariff_plan_id)
        REFERENCES tariff_plans (tariff_plan_id) ON DELETE RESTRICT,
    CONSTRAINT section_tariff_assignments_section_fk FOREIGN KEY (section_id)
        REFERENCES coworking_sections (section_id) ON DELETE RESTRICT,
    CONSTRAINT section_tariff_assignments_author_fk FOREIGN KEY (assigned_by)
        REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT section_tariff_assignments_period_check CHECK (
        isfinite(starts_at) AND ends_at > starts_at
    ),
    CONSTRAINT section_tariff_assignments_no_overlap EXCLUDE USING gist (
        section_id WITH =,
        tstzrange(starts_at, ends_at, '[)') WITH &&
    )
);

COMMENT ON TABLE section_tariff_assignments IS 'Назначения тарифных планов секциям коворкинга.';
COMMENT ON COLUMN section_tariff_assignments.assignment_id IS 'Уникальный идентификатор назначения тарифного плана секции.';
COMMENT ON COLUMN section_tariff_assignments.tariff_plan_id IS 'Идентификатор назначенного тарифного плана. Внешний ключ на tariff_plans.';
COMMENT ON COLUMN section_tariff_assignments.section_id IS 'Идентификатор секции, которой назначен тарифный план. Внешний ключ на coworking_sections.';
COMMENT ON COLUMN section_tariff_assignments.starts_at IS 'Начало периода действия тарифного плана на секции (включительно).';
COMMENT ON COLUMN section_tariff_assignments.ends_at IS 'Окончание периода действия тарифного плана на секции (не включительно); infinity по умолчанию.';
COMMENT ON COLUMN section_tariff_assignments.assigned_by IS 'Идентификатор пользователя, назначившего тарифный план секции. Внешний ключ на users.';
COMMENT ON COLUMN section_tariff_assignments.created_at IS 'Дата и время создания назначения; по умолчанию начало текущей транзакции.';

COMMENT ON CONSTRAINT section_tariff_assignments_tariff_fk ON section_tariff_assignments IS 'ON DELETE RESTRICT: запрещено удаление тарифного плана, пока существуют его назначения секциям коворкинга.';
COMMENT ON CONSTRAINT section_tariff_assignments_section_fk ON section_tariff_assignments IS 'ON DELETE RESTRICT: запрещено удаление секции, пока существуют назначения тарифных планов этой секции.';
COMMENT ON CONSTRAINT section_tariff_assignments_author_fk ON section_tariff_assignments IS 'ON DELETE RESTRICT: запрещено удаление пользователя, пока существуют созданные им назначения тарифных планов секциям, чтобы сохранить сведения об авторе назначений.';
COMMENT ON CONSTRAINT section_tariff_assignments_no_overlap ON section_tariff_assignments IS 'Для одной секции запрещены пересекающиеся назначения любых тарифов; собственный тариф места может действовать одновременно.';

CREATE TABLE payments (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL PRIMARY KEY,
    booking_id BIGINT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMPTZ,

    CONSTRAINT payments_booking_fk FOREIGN KEY (booking_id)
        REFERENCES bookings (booking_id) ON DELETE RESTRICT,
    CONSTRAINT payments_amount_check CHECK (
        amount >= 0 AND amount <> 'NaN'::NUMERIC
    ),
    CONSTRAINT payments_status_check CHECK (
        status IN ('pending', 'succeeded', 'failed')
    ),
    CONSTRAINT payments_paid_at_check CHECK (
        (status = 'succeeded' AND paid_at IS NOT NULL
            AND isfinite(paid_at) AND paid_at >= created_at)
        OR (status IN ('pending', 'failed') AND paid_at IS NULL)
    )
    -- booking_id намеренно не UNIQUE: допустимы несколько попыток оплаты.
);

COMMENT ON TABLE payments IS 'Попытки оплаты бронирований.';
COMMENT ON COLUMN payments.payment_id IS 'Уникальный идентификатор попытки платежа.';
COMMENT ON COLUMN payments.booking_id IS 'Идентификатор оплачиваемого бронирования. Внешний ключ на bookings.';
COMMENT ON COLUMN payments.amount IS 'Неотрицательная сумма платежа.';
COMMENT ON COLUMN payments.status IS 'Статус платежа: pending — ожидается (по умолчанию); succeeded — успешно оплачен; failed — неуспешная попытка.';
COMMENT ON COLUMN payments.created_at IS 'Дата и время создания попытки платежа; по умолчанию начало текущей транзакции.';
COMMENT ON COLUMN payments.paid_at IS 'Дата и время успешной оплаты; NULL — оплата не выполнена.';

COMMENT ON CONSTRAINT payments_booking_fk ON payments IS 'ON DELETE RESTRICT: запрещено удаление бронирования, пока существуют связанные с ним платежи, чтобы сохранить платёжную историю.';

COMMIT;
