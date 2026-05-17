# Task 17 - Анализ и профилирование запроса (MySQL)



## 1) Сложная выборка

```sql
SELECT
  c.category_name,
  m.manufacturer_name,
  COUNT(DISTINCT o.order_id) AS orders_cnt,
  SUM(oi.line_amount) AS revenue,
  AVG(oi.line_amount) AS avg_line_amount
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN categories c ON c.category_id = p.category_id
JOIN manufacturers m ON m.manufacturer_id = p.manufacturer_id
WHERE o.created_at >= NOW() - INTERVAL 30 DAY
  AND o.status IN ('paid', 'shipped')
  AND o.customer_email IN (
    SELECT customer_email
    FROM orders
    GROUP BY customer_email
    HAVING COUNT(*) >= 2
  )
GROUP BY c.category_name, m.manufacturer_name
ORDER BY revenue DESC;
```

Пример результата:

```text
category_name  manufacturer_name  orders_cnt  revenue   avg_line_amount
Напитки        Polar Drinks       1           3000.00   3000.000000
Орехи          Acme Foods         2            900.00    450.000000
```

## 2) EXPLAIN в трех форматах

```sql
EXPLAIN FORMAT=TRADITIONAL
SELECT ...;

EXPLAIN FORMAT=JSON
SELECT ...;

EXPLAIN FORMAT=TREE
SELECT ...;
```

Ключевые наблюдения до оптимизации:
- по `orders` возможен полный проход (`ALL`)
- используются `temporary/filesort`
- есть подзапрос с `GROUP BY customer_email`

## 3) Замер до оптимизации

```sql
EXPLAIN ANALYZE
SELECT ...;
```

На тестовых данных до индексов:
- `Sort: revenue DESC` около `0.191 ms`
- чтение `orders` как `Table scan on o`

## 4) Оптимизация

Добавлены индексы:

```sql
CREATE INDEX idx_orders_created_status ON orders(created_at, status, customer_email);
CREATE INDEX idx_order_items_product_order ON order_items(product_id, order_id, line_amount);
```

## 5) Замер после оптимизации

```sql
EXPLAIN ANALYZE
SELECT ...;
```

На тестовых данных после индексов:
- `Sort: revenue DESC` около `0.135 ms`
- для `orders` используется `Covering index scan on o using idx_orders_created_status`

## 6) Вывод

После индексации план стал лучше для фильтрации по `orders`: вместо полного прохода используется покрывающий индекс, и время выполнения на тестовом наборе уменьшилось.

Полный SQL: `solution.sql`.
