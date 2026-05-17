# Task 16 - Хранимые процедуры и триггеры в MySQL

## 1) Пользователи и права

```sql
CREATE USER 'client'@'%' IDENTIFIED BY 'client123';
CREATE USER 'manager'@'%' IDENTIFIED BY 'manager123';

GRANT EXECUTE ON PROCEDURE otus_task16.get_products TO 'client'@'%';
GRANT EXECUTE ON PROCEDURE otus_task16.get_orders TO 'manager'@'%';
FLUSH PRIVILEGES;
```

## 2) Процедура `get_products` (базовый вариант)

Поддерживает:
- фильтр по категории
- фильтр по цене
- фильтр по производителю
- сортировку (`price` или `title`)
- пагинацию (`page`, `page_size`)

```sql
CALL get_products('Орехи', 100, 1000, NULL, 'price', 1, 20);
```

## 3) Процедура `get_orders`                    

Поддерживает:
- период: hour, day, week
- уровни группировки: product, category, manufacturer

```sql

DELIMITER $$

DROP PROCEDURE IF EXISTS get_products $$
CREATE PROCEDURE get_products(
  IN p_category_name VARCHAR(100),
  IN p_min_price DECIMAL(10,2),
  IN p_max_price DECIMAL(10,2),
  IN p_manufacturer_name VARCHAR(100),
  IN p_sort_field VARCHAR(10),
  IN p_page INT,
  IN p_page_size INT
)
BEGIN
  IF p_page IS NULL OR p_page < 1 THEN
    SET p_page = 1;
  END IF;

  IF p_page_size IS NULL OR p_page_size < 1 THEN
    SET p_page_size = 20;
  END IF;

  SELECT
    p.product_id,
    p.title,
    c.category_name,
    m.manufacturer_name,
    p.price,
    p.rating,
    p.status,
    p.attributes_json
  FROM products p
  JOIN categories c ON c.category_id = p.category_id
  JOIN manufacturers m ON m.manufacturer_id = p.manufacturer_id
  WHERE (p_category_name IS NULL OR c.category_name = p_category_name)
    AND (p_manufacturer_name IS NULL OR m.manufacturer_name = p_manufacturer_name)
    AND (p_min_price IS NULL OR p.price >= p_min_price)
    AND (p_max_price IS NULL OR p.price <= p_max_price)
  ORDER BY
    IF(p_sort_field = 'price', p.price, NULL),
    IF(p_sort_field = 'title', p.title, NULL),
    p.product_id
  LIMIT p_page_size OFFSET (p_page - 1) * p_page_size;
END $$

DROP PROCEDURE IF EXISTS get_orders $$
CREATE PROCEDURE get_orders(
  IN p_period VARCHAR(10),     
  IN p_group_level VARCHAR(20) 
)
BEGIN
  IF p_period NOT IN ('hour', 'day', 'week') THEN
    SET p_period = 'day';
  END IF;

  IF p_group_level NOT IN ('product', 'category', 'manufacturer') THEN
    SET p_group_level = 'product';
  END IF;

  SELECT
    CASE
      WHEN p_period = 'hour' THEN DATE_FORMAT(o.created_at, '%Y-%m-%d %H:00:00')
      WHEN p_period = 'day' THEN DATE_FORMAT(o.created_at, '%Y-%m-%d')
      WHEN p_period = 'week' THEN DATE_FORMAT(o.created_at, '%x-%v')
    END AS period_key,
    CASE
      WHEN p_group_level = 'product' THEN p.title
      WHEN p_group_level = 'category' THEN c.category_name
      WHEN p_group_level = 'manufacturer' THEN m.manufacturer_name
    END AS group_key,
    SUM(oi.qty) AS total_qty,
    SUM(oi.line_amount) AS total_sales
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  JOIN products p ON p.product_id = oi.product_id
  JOIN categories c ON c.category_id = p.category_id
  JOIN manufacturers m ON m.manufacturer_id = p.manufacturer_id
  GROUP BY period_key, group_key
  ORDER BY period_key DESC, total_sales DESC;
END $$

DELIMITER ;

CALL get_orders('day', 'category');
CALL get_orders('week', 'manufacturer');
```



