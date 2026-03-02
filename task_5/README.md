# DML: вставка, обновление, удаление, выборка данных в PostgreSQL 

```
1. Напишите запрос по своей базе с регулярным выражением, добавьте пояснение, что вы хотите найти.
2. Напишите запрос по своей базе с использованием LEFT JOIN и INNER JOIN, как порядок соединений в FROM влияет на результат? Почему?
3. Напишите запрос на добавление данных с выводом информации о добавленных строках.
4. Напишите запрос с обновлением данные используя UPDATE FROM.
5. Напишите запрос для удаления данных с оператором DELETE используя join с другой таблицей с помощью using.
```

## Запрос с регулярным выражение
`Поиск кода маркировки у которого номер состоит из 14 цифр`
```sql
SELECT id, fullcode, created_at
FROM ops.marking_codes
WHERE client_id = :client_id
  AND fullcode ~ '\m[0-9]{14}\M';
```

## LEFT JOIN и INNER JOIN
`Все упоковки укоторых есть есть cell `
```sql
SELECT p.id, p.fullcode, c.code AS cell_code
FROM ops.packages p
INNER JOIN wh.cells c ON c.id = p.cell_id
WHERE p.client_id = :client_id;
```

`Все коды маркировки и (если есть) ячейку`

```sql
SELECT mc.id, mc.fullcode, c.code AS cell_code
FROM ops.marking_codes mc
LEFT JOIN wh.cells c ON c.id = mc.cell_id
WHERE mc.client_id = :client_id;
```

Для LEFT JOIN порядок влияет, потому что сохраняет строки только из левой таблицы

## INSERT c возвратом данных
```sql

INSERT INTO core.clients (name, inn)
VALUES ('ООО IDR', '789999999')
RETURNING id, name, inn;
```

## UPDATE FROM
`обновляем все упаковки подтяшивая статусы их таблицы статусов упаковок`

```sql
UPDATE ops.packages p
SET status_id = s.id
FROM ref.package_statuses s
WHERE p.client_id = :client_id
  AND s.code = 'CLOSED'
  AND p.status_id = (SELECT id FROM ref.package_statuses WHERE code = 'OPEN')
RETURNING p.id, p.fullcode, p.status_id;
```
## DELETE используя join с другой таблицей с помощью using**
`удаляем события аудита старше 90 дней только для документов в статусе CANCELLED`
```sql
DELETE FROM audit.events e
USING ops.documents d, ref.document_statuses ds
WHERE e.document_id = d.id
  AND d.status_id = ds.id
  AND ds.code = 'CANCELLED'
  AND e.created_at < now() - interval '90 days'
RETURNING e.id, e.document_id, e.created_at;
```

## COPY
`COPY из CSV файла в таблицу`

```sql
COPY core.products (client_id, sku, name, gtin, unit)
FROM '/tmp/products.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ';');
```