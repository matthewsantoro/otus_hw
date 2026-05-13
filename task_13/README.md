# Task 13 - Создаем отчетную выборку (MySQL)

ДЗ выполнено на **тестовой базе из `otus.md`** (`otus_rdbms_dml_aggregate`)

## 1) Инициализация тестовой БД и таблицы `products`

```sql
DROP DATABASE IF EXISTS otus_rdbms_dml_aggregate;
CREATE DATABASE otus_rdbms_dml_aggregate;
USE otus_rdbms_dml_aggregate;

DROP TABLE IF EXISTS products;
CREATE TABLE products (
    title VARCHAR(32) NOT NULL,
    category VARCHAR(32),
    price INT,
    rating INT,
    status VARCHAR(32) NOT NULL,
    PRIMARY KEY (title)
);

INSERT INTO products (title, category, price, rating, status) VALUES
    ('Агдам', 'Напитки', 150, 2, 'В наличии'),
    ('Килька', 'Консервы', 45, 4, 'Распродан'),
    ('Оливки', 'Консервы', 250, 5, 'Распродан'),
    ('Текила', 'Напитки', 3000, 5, 'В наличии'),
    ('Шмурдяк', 'Напитки', 120, 1, 'Распродан'),
    ('Арахис', 'Орехи', 250, 5, 'Распродан'),
    ('Фисташки', 'Орехи', 450, 5, 'В наличии');
```

## 2) Группировки с CASE, HAVING

Для каждой категории: min/max цена, количество предложений, количество "В наличии" и "Распродан".

```sql
SELECT
    category,
    COUNT(*) AS offers_total,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    SUM(CASE WHEN status = 'В наличии' THEN 1 ELSE 0 END) AS in_stock_count,
    SUM(CASE WHEN status = 'Распродан' THEN 1 ELSE 0 END) AS sold_out_count
FROM products
GROUP BY category
HAVING COUNT(*) >= 1
ORDER BY category;
```

## 3) Самый дорогой и самый дешевый товар в каждой категории

```sql
WITH ranked AS (
    SELECT
        title,
        category,
        price,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY price ASC, title ASC) AS rn_min,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY price DESC, title DESC) AS rn_max
    FROM products
)
SELECT
    category,
    title,
    price,
    CASE
        WHEN rn_min = 1 THEN 'cheapest'
        WHEN rn_max = 1 THEN 'most_expensive'
    END AS price_rank_type
FROM ranked
WHERE rn_min = 1 OR rn_max = 1
ORDER BY category, price_rank_type;
```

## 4) ROLLUP с количеством товаров по категориям + GROUPING()

```sql
SELECT
    IF(GROUPING(category), 'ИТОГО', category) AS category,
    COUNT(*) AS products_total
FROM products
GROUP BY category WITH ROLLUP;
```

