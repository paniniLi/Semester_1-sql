-- 1. Версия
SELECT version();

-- 2. Вставка корректных данных
INSERT INTO tariff_plans (name)
VALUES ('Демонстрационный тариф');

INSERT INTO coworking_sections (name)
VALUES ('Открытая рабочая зона');

-- 3. Чтение
SELECT * FROM tariff_plans;
SELECT * FROM coworking_sections;

-- 4. Негативный тест: ожидается ошибка
INSERT INTO tariff_prices (tariff_plan_id, price, price_unit, valid_from, assigned_by)
VALUES (
    (SELECT COALESCE(MAX(tariff_plan_id), 0) + 1 FROM tariff_plans),
    150.00,
    'hour',
    CURRENT_TIMESTAMP,
    1 -- ID пользователя, внёсшего цену; таблица пользователей пока не создана
);
