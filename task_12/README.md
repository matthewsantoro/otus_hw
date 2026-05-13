# Task 12 - Транзакции, MVCC, ACID в MySQL

Сценарий:  
приемка товара на склад. Одной операцией меняем остаток и пишем движение.

## 1) Таблицы для остатков и движений

```sql
CREATE TABLE IF NOT EXISTS stock_balances (
  product_id INT UNSIGNED NOT NULL,
  qty INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (product_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS stock_movements (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id INT UNSIGNED NOT NULL,
  movement_type ENUM('receipt','ship','adjustment') NOT NULL,
  delta_qty INT NOT NULL,
  movement_note VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB;
```

## 2) Транзакционная процедура приемки

```sql
CREATE PROCEDURE sp_receive_stock (
  IN p_product_id INT UNSIGNED,
  IN p_delta_qty INT,
  IN p_note VARCHAR(255)
)
BEGIN
  START TRANSACTION;

  UPDATE stock_balances
  SET qty = qty + p_delta_qty
  WHERE product_id = p_product_id;

  INSERT INTO stock_movements (product_id, movement_type, delta_qty, movement_note)
  VALUES (p_product_id, 'receipt', p_delta_qty, p_note);

  COMMIT;
END;
```

## 3) Загрузка CSV через LOAD DATA

```sql
LOAD DATA LOCAL INFILE '/home/ms/projects/otus/otus_hw/task_12/stock_receipts.csv'
INTO TABLE stock_receipts_stage
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(client_inn, sku, delta_qty);
```

## 4) Применение загрузки

```sql
CALL sp_apply_receipts_from_stage();
```

## 5) mysqlimport
```bash
mysqlimport --local --ignore-lines=1 --fields-terminated-by=, --fields-enclosed-by='"' --columns='client_inn,sku,delta_qty'-u root -p otus_3plwms  /home/ms/projects/otus/otus_hw/task_12/stock_receipts.csv
```
