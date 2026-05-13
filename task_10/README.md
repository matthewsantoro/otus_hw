# Task 10 - Типы данных в MySQL

## Что изменил в типах данных и почему

1. clients.inn: VARCHAR(12) -> CHAR(10) 

Причина: для юрлиц используется фиксированная длина ИНН (10 символов), **CHAR** лучше отражает доменную модель.

```sql
ALTER TABLE clients
  MODIFY COLUMN inn CHAR(10) NOT NULL;
```


2. users.login: VARCHAR(100) -> VARCHAR(64)

Причина: 100 символов избыточно для логина

```sql
ALTER TABLE users
  MODIFY COLUMN login VARCHAR(64) NOT NULL;
```


3. products.unit: VARCHAR(16) -> ENUM('ШТ', 'Короб', 'Набор', 'кг', 'л', 'уп.')

Причина: единицы измерения должны храниться из заранее определенного перечня.
```sql
ALTER TABLE products
  MODIFY COLUMN unit ENUM('ШТ', 'Короб', 'Набор', 'кг', 'л', 'уп.') NOT NULL;
```

4. products.name: VARCHAR(255) -> VARCHAR(200)

Причина: 255 допустимо, но в текущем проекте не требуется; снижена избыточность.

```sql
ALTER TABLE products
  MODIFY COLUMN name VARCHAR(200) NOT NULL;
```

## Добавление JSON в структуру

Дополнительные атрибуты для товаров, которые есть не укаждого продукта
- `products.attributes_json JSON NULL`

```sql
ALTER TABLE products
  ADD COLUMN attributes_json JSON NULL 
```


```sql
INSERT INTO products (client_id, sku, name, gtin, unit, attributes_json)
VALUES (
  (SELECT id FROM clients WHERE inn = '7701000001' LIMIT 1),
  'SKU-0001',
  'ALFA термобокс 20л',
  '4600000010999',
  'шт',
  JSON_OBJECT(
    'color', 'Синий',
    'volume_l', 20,
    'temperature_mode', JSON_OBJECT('min_c', -5, 'max_c', 8),
    'fragile', true,
    'tags', JSON_ARRAY('медицина', 'важно')
  )
)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  gtin = VALUES(gtin),
  unit = VALUES(unit),
  attributes_json = VALUES(attributes_json);
```

