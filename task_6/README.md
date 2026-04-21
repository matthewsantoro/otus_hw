# Индексы PostgreSQL (Task 6)

## Задание (как в OTUS)

1. Создать индекс к таблице БД и показать EXPLAIN, где он используется.
2. Реализовать индекс для полнотекстового поиска.
3. Реализовать индекс на часть таблицы или индекс на поле с функцией.
4. Создать индекс на несколько полей.
5. Дать краткие комментарии к каждому индексу.
6. Описать, что делал и какие были проблемы.



## Индексы

1. `ops.idx_t6_mc_client_status_created_at`
```sql
CREATE INDEX idx_t6_mc_client_status_created_at
  ON ops.marking_codes (client_id, status_id, created_at DESC);
```
Комментарий: Ускоряет выборку кодов маркировки по клиенту и статусу с сортировкой по дате.

2. `core.idx_t6_products_fts_ru`
```sql
CREATE INDEX idx_t6_products_fts_ru
  ON core.products
  USING gin (to_tsvector('russian', coalesce(name, '') || ' ' || coalesce(sku, '')));
```
Комментарий: ускоряет полнотекстовый поиск по названию и SKU товара.

3. `ops.idx_t6_packages_history_active_parent_added`
```sql
CREATE INDEX idx_t6_packages_history_active_parent_added
  ON ops.packages_history (client_id, parent_package_id, added_at DESC)
  WHERE removed_at IS NULL;
```
Комментарий: ускоряет запросы по активным вложениям упаковки (removed_at IS NULL).

## Результаты EXPLAIN (текстом)

Тестовый контекст:
- client_id=1
- status_id=2 (IN_STOCK)
- parent_package_id=43

1. Составной индекс (`idx_t6_mc_client_status_created_at`)
- До: Bitmap Heap Scan + Sort, Execution Time: 1.190 ms
- После: Index Scan using idx_t6_mc_client_status_created_at, Execution Time: 0.111 ms
- Эффект: заметное ускорение выборки и сортировки.

2. Full-text индекс (`idx_t6_products_fts_ru`)
- До: Seq Scan on products, Execution Time: 2.785 ms
- После: Bitmap Index Scan on idx_t6_products_fts_ru + Bitmap Heap Scan, Execution Time: 0.032 ms
- Эффект: резкое ускорение полнотекстового поиска.

3. Partial индекс (`idx_t6_packages_history_active_parent_added`)
- До: Index Scan using idx_packages_history_parent_active + Sort, Execution Time: 0.034 ms
- После: Index Scan using idx_t6_packages_history_active_parent_added, Execution Time: 0.028 ms
- Эффект: план стал целевым под активные строки, время слегка улучшилось.


## Файлы

1. `solution.sql` - сценарий замеров и создания индексов.
2. `../scripts/seed_3plwms_realistic.sql` - данные.
