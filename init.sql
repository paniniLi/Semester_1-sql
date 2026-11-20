BEGIN;

-- Расширение позволяет сравнивать ID тарифа и секции в ограничениях EXCLUDE.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE tariff_plans (
    tariff_plan_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tariff_prices (
    tariff_price_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tariff_plan_id BIGINT NOT NULL,
    price NUMERIC(12, 2) NOT NULL,
    price_unit TEXT NOT NULL,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_to TIMESTAMPTZ NOT NULL DEFAULT 'infinity',
    -- Внешний ключ для автора цены следует добавить после создания таблицы пользователей.
    assigned_by BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- внешний ключ на tariff_plans с запретом физического удаления тарифного плана, пока на него ссылается запись из текущей таблицы
    CONSTRAINT tariff_prices_tariff_fk
        FOREIGN KEY (tariff_plan_id) REFERENCES tariff_plans (tariff_plan_id)
        ON DELETE RESTRICT,
    -- стоимость тарифного плана не может быть отрицательной
    CONSTRAINT tariff_prices_price_check
        CHECK (price >= 0),
    CONSTRAINT tariff_prices_period_check
        CHECK (valid_to > valid_from),
    -- Недопустимы пересечения периодов действия цен одного тарифа
    CONSTRAINT tariff_prices_no_overlap
        EXCLUDE USING gist (
            tariff_plan_id WITH =,
            tstzrange(valid_from, valid_to, '[)') WITH &&
        )
);

CREATE TABLE coworking_sections (
    section_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE section_tariff_assignments (
    assignment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tariff_plan_id BIGINT NOT NULL,
    section_id BIGINT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL DEFAULT 'infinity',
    assigned_by BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT section_tariff_assignments_tariff_fk
        FOREIGN KEY (tariff_plan_id) REFERENCES tariff_plans (tariff_plan_id)
        ON DELETE RESTRICT,
    CONSTRAINT section_tariff_assignments_section_fk
        FOREIGN KEY (section_id) REFERENCES coworking_sections (section_id)
        ON DELETE RESTRICT,
    CONSTRAINT section_tariff_assignments_period_check
        CHECK (ends_at > starts_at),
    -- Недопустимы пересечения периодов действия тарифных планов для одной секции
    CONSTRAINT section_tariff_assignments_no_overlap
        EXCLUDE USING gist (
            section_id WITH =,
            tstzrange(starts_at, ends_at, '[)') WITH &&
        )
);

COMMIT;
