# DML в MySQL (агрегация)

## Тестовый стенд

### Запуск в Docker

```sh
docker run \
  --name otus-mysql-8.4 \
  -e MYSQL_ROOT_PASSWORD=123456 \
  -e LANG=C.UTF-8 \
  -d \
  mysql:8.4.4
```

```sh
docker exec -it otus-mysql-8.4 mysql -u root -p123456
```

### Инициализация

```mysql
DROP DATABASE IF EXISTS otus_rdbms_dml_aggregate;
CREATE DATABASE otus_rdbms_dml_aggregate;
USE otus_rdbms_dml_aggregate;
```

### Таблицы

Клиенты

```
+-------------+---------------+
| customer_id | email         |
+-------------+---------------+
|           1 | vasya@mail.ru |
|           2 | lena@mail.ru  |
|           3 | sonya@mail.ru |
+-------------+---------------+
```

```mysql
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id SERIAL,
    email VARCHAR(255) NOT NULL,
    PRIMARY KEY (customer_id)
);
```

```mysql
INSERT INTO customers
    (email)
VALUES
    ('vasya@mail.ru'),
    ('lena@mail.ru'),
    ('sonya@mail.ru');
```

```mysql
SELECT * FROM customers;
```

Заказы

```
+----------+-------------+---------+
| order_id | customer_id | total   |
+----------+-------------+---------+
|        1 |           1 |  450.00 |
|        2 |           1 |  220.00 |
|        3 |           2 | 1500.00 |
|        4 |           2 |  450.00 |
|        5 |           2 |  220.00 |
+----------+-------------+---------+
```

```mysql
DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    order_id SERIAL,
    customer_id BIGINT UNSIGNED NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id),
    CONSTRAINT fk__orders__customers
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
);
```

```mysql
INSERT INTO orders
    (customer_id, total)
VALUES
    (1, 450),
    (1, 220),
    (2, 1500),
    (2, 450),
    (2, 220);
```

```mysql
SELECT * FROM orders;
```

Товары (не связаны с предыдущими таблицами)

```
+------------------+------------------+-------+--------+----------------+
| title            | category         | price | rating | status         |
+------------------+------------------+-------+--------+----------------+
| Агдам            | Напитки          |   150 |      2 | В наличии      |
| Арахис           | Орехи            |   250 |      5 | Распродан      |
| Килька           | Консервы         |    45 |      4 | Распродан      |
| Оливки           | Консервы         |   250 |      5 | Распродан      |
| Текила           | Напитки          |  3000 |      5 | В наличии      |
| Фисташки         | Орехи            |   450 |      5 | В наличии      |
| Шмурдяк          | Напитки          |   120 |      1 | Распродан      |
+------------------+------------------+-------+--------+----------------+
```

```mysql
DROP TABLE IF EXISTS products;

CREATE TABLE products (
    title VARCHAR(32) NOT NULL,
    category VARCHAR(32),
    price INT,
    rating INT,
    status VARCHAR(32) NOT NULL,
    PRIMARY KEY (title)
);
```

```mysql
INSERT INTO products
    (title, category, price, rating, status)
VALUES
    ('Агдам', 'Напитки', 150, 2, 'В наличии'),
    ('Килька', 'Консервы', 45, 4, 'Распродан'),
    ('Оливки', 'Консервы', 250, 5, 'Распродан'),
    ('Текила', 'Напитки', 3000, 5, 'В наличии'),
    ('Шмурдяк', 'Напитки', 120, 1, 'Распродан'),
    ('Арахис', 'Орехи', 250, 5, 'Распродан'),
    ('Фисташки', 'Орехи', 450, 5, 'В наличии');
```

```mysql
SELECT * FROM products;
```

## JOIN

### Вопросы на засыпку

```mysql
SELECT *
    FROM customers c
    JOIN orders o;
```

```mysql
SELECT *
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id;
```

```mysql
SELECT *
    FROM customers c
    JOIN orders o
        ON c.customer_id = c.customer_id;
```

```mysql
SELECT *
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.order_id;
```

### Декартово произведение

```mysql
SELECT *
    FROM customers c
    JOIN orders o
    ORDER BY c.customer_id, o.order_id;
```

### ON — аналог WHERE для JOIN

```mysql
SELECT *
    FROM customers c
    JOIN orders o
    WHERE c.customer_id = o.customer_id
    ORDER BY c.customer_id, o.order_id;
```

```mysql
SELECT *
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    ORDER BY c.customer_id, o.order_id;
```

### Типичные опечатки

```mysql
SELECT *
    FROM customers c
    JOIN orders o
        ON c.customer_id = c.customer_id
    ORDER BY c.customer_id, o.order_id;
```

```mysql
SELECT *
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.order_id
    ORDER BY c.customer_id, o.order_id;
```

### LEFT JOIN

```mysql
SELECT *
    FROM customers c
    LEFT JOIN orders o
        ON c.customer_id = o.customer_id
    ORDER BY c.customer_id, o.order_id;
```

```mysql
SELECT *
    FROM customers c
    LEFT JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_id IS NULL
    ORDER BY c.customer_id, o.order_id;
```

### Проверка знаний

.
.
.

```mysql
SELECT
    c.email,
    SUM(o.total) AS total
    FROM customers c
    LEFT JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.email;
```

```mysql
SELECT
    c.email,
    COALESCE(SUM(o.total), 0) AS total
    FROM customers c
    LEFT JOIN orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.email;
```

## GROUP BY

### Вопросы на засыпку

```mysql
SELECT
    customer_id,
    order_id,
    SUM(total)
    FROM orders
    GROUP BY customer_id;
```

### Как работает GROUP BY

```mysql
SELECT *
    FROM products
    ORDER BY category;
```

```mysql
SELECT
    category,
    COUNT(*) AS count
    FROM products
    GROUP BY category;
```

```mysql
SELECT
    category,
    status,
    COUNT(*) AS count
    FROM products
    GROUP BY category, status;
```

### Независимые вычисления

```mysql
SELECT
    category,
    MIN(price) AS min_price,
    MAX(price) AS max_price
    FROM products
    GROUP BY category;
```

### Зависимые столбцы

```mysql
SELECT
    category,
    title,
    MAX(price) AS max_price,
    MIN(price) AS max_price
    FROM products
    GROUP BY category;
```

Исключение: GROUP BY по первичному ключу

```mysql
SELECT
    category,
    title,
    MAX(price) AS max_price,
    MIN(price) AS max_price
    FROM products
    GROUP BY title;
```

### Особенности GROUP BY в MySQL

```mysql
SET @current_sql_mode = @@session.sql_mode;
SET SESSION sql_mode = '';
```

```mysql
SELECT
    category,
    title,
    MAX(price) AS max_price,
    MIN(price) AS max_price
    FROM products
    GROUP BY category;
```

```mysql
SET SESSION sql_mode = @current_sql_mode;
```

```mysql
SELECT
    category,
    ANY_VALUE(title) AS title,
    MAX(price) AS max_price,
    MIN(price) AS max_price
    FROM products
    GROUP BY category;
```

### Задача: Хорошие категории

```mysql
SELECT * FROM products;
```

```mysql
SELECT DISTINCT category
    FROM products
    WHERE rating >= 4;
```

```mysql
SELECT DISTINCT category
    FROM products
    WHERE category NOT IN (
        SELECT DISTINCT category
        FROM products
        WHERE rating < 4
    );
```

```mysql
SELECT
    category,
    MIN(rating) AS min_rating
    FROM products
    GROUP BY category;
```

```mysql
SELECT
    category,
    MIN(rating) AS min_rating
    FROM products
    WHERE min_rating >= 4
    GROUP BY category;
```

### WHERE VS HAVING

```mysql
SELECT
    category,
    MIN(rating) AS min_rating
    FROM products
    GROUP BY category
    HAVING min_rating >= 4;
```

```mysql
SELECT
    category
    FROM products
    GROUP BY category
    HAVING MIN(rating) >= 4;
```

## Продвинутые приёмы

### Задача: Товары в наличии

```mysql
SELECT
    category,
    COUNT(*) AS total
    FROM products
    WHERE status = 'В наличии'
    GROUP BY category;
```

```mysql
SELECT
    category,
    CASE WHEN status = 'В наличии'
        THEN 1
        ELSE 0
        END
    AS in_stock
    FROM products;
```

```mysql
SELECT
    category,
    SUM( CASE WHEN status = 'В наличии'
         THEN 1
         ELSE 0
         END ) AS sum_in_stock
    FROM products
    GROUP BY category;
```

### Задача: Максимальная цена в категории

```mysql
SELECT
    title,
    category,
    price,
    MAX(price) OVER (PARTITION BY category)
        AS max_price_in_category
    FROM products;
```

Задание: напишите запрос, который вернёт название товара, категорию и общее кол-во товаров в этой категории:

```
+------------------+------------------+-------------------+
| title            | category         | count_in_category |
+------------------+------------------+-------------------+
| Килька           | Консервы         |                 2 |
| Оливки           | Консервы         |                 2 |
| Агдам            | Напитки          |                 3 |
| Текила           | Напитки          |                 3 |
| Шмурдяк          | Напитки          |                 3 |
| Арахис           | Орехи            |                 2 |
| Фисташки         | Орехи            |                 2 |
+------------------+------------------+-------------------+
```

.
.
.

```mysql
SELECT
    title,
    category,
    COUNT(*) OVER (PARTITION BY category)
        AS count_in_category
    FROM products;
```

Как пронумеровать все строки в каждой группе:

```mysql
SELECT
    RANK() OVER (PARTITION BY category ORDER BY title)
        AS position,
    title,
    category,
    price
    FROM products;
```

### Задача: Общая цена всех товаров

```mysql
SELECT
    category,
    SUM(price) AS total
    FROM products
    GROUP BY category
    WITH ROLLUP;
```

```mysql
SELECT
    category,
    status,
    SUM(price) AS total
    FROM products
    GROUP BY category, status
    WITH ROLLUP;
```

```mysql
INSERT INTO products
    (title, category, price, rating, status)
VALUES
    ('Непонятная фигня 1', NULL, 400, NULL, 'В наличии'),
    ('Непонятная фигня 2', NULL, 1000, NULL, 'В наличии');
```

```mysql
SELECT * FROM products;
```

```mysql
SELECT
    category,
    SUM(price) AS total
    FROM products
    GROUP BY category
    WITH ROLLUP;
```

```mysql
SELECT
    IF(GROUPING(category), 'ИТОГО', category)
        AS category,
    SUM(price) AS total
    FROM products
    GROUP BY category
    WITH ROLLUP;
```

## Ссылка на опрос

```
https://otus.ru/polls/112797/
```