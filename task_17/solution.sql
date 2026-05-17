USE otus_task16;

EXPLAIN FORMAT=TRADITIONAL
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

EXPLAIN FORMAT=JSON
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

EXPLAIN FORMAT=TREE
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

EXPLAIN ANALYZE
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

DROP INDEX idx_orders_created_status ON orders;
DROP INDEX idx_order_items_product_order ON order_items;

CREATE INDEX idx_orders_created_status ON orders(created_at, status, customer_email);
CREATE INDEX idx_order_items_product_order ON order_items(product_id, order_id, line_amount);

EXPLAIN ANALYZE
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
