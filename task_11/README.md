# Task 11 - SQL выборка (MySQL)

Выполнен вариант задания в сфере администрирования и разработки на БД `otus_3plwms`.

## 1) Запрос с INNER JOIN

Получить список активных пользователей и их доступов к клиентам.

```sql
SELECT
  u.id AS user_id,
  u.login,
  c.id AS client_id,
  c.name AS client_name,
  uc.role
FROM users u
INNER JOIN user_clients uc ON uc.user_id = u.id
INNER JOIN clients c ON c.id = uc.client_id
WHERE u.is_active = 1
ORDER BY u.id, c.id;
```

## 2) Запрос с LEFT JOIN

Вывести всех клиентов, включая тех, у кого пока нет товаров.

```sql
SELECT
  c.id AS client_id,
  c.name AS client_name,
  p.id AS product_id,
  p.sku,
  p.name AS product_name
FROM clients c
LEFT JOIN products p ON p.client_id = c.id
ORDER BY c.id, p.id;
```

## 3) Пять запросов с WHERE

1. `BETWEEN` - диагностика по диапазону id.

```sql
SELECT id, client_id, sku, name
FROM products
WHERE id BETWEEN 1 AND 10
ORDER BY id;
```

2. `LIKE` - поиск по SKU-префиксу.

```sql
SELECT id, client_id, sku, name
FROM products
WHERE sku LIKE 'SKU-ALFA-%'
ORDER BY id;
```

3. `IN` - фильтрация по единицам измерения.

```sql
SELECT id, sku, unit
FROM products
WHERE unit IN ('шт', 'короб')
ORDER BY id;
```

4. `IS NOT NULL` - товары с заполненным GTIN.

```sql
SELECT id, sku, gtin
FROM products
WHERE gtin IS NOT NULL
ORDER BY id;
```

5. Условие по JSON - товары с признаком `fragile=true`.

```sql
SELECT
  id,
  sku,
  name,
  JSON_EXTRACT(attributes_json, '$.fragile') AS fragile
FROM products
WHERE attributes_json IS NOT NULL
  AND JSON_EXTRACT(attributes_json, '$.fragile') = true
ORDER BY id;
```
