# Индексы PostgreSQL (Task 6)

> Разработка проекта 3PL WMS

## Задание

Оптимизировать запросы в PostgreSQL с помощью индексов и подтвердить эффект через `EXPLAIN (ANALYZE, BUFFERS)`.

## Цель

1. Применить индексы на реальной БД проекта, а не на отдельном учебном примере.
2. Сравнить планы выполнения до и после индексации.
3. Зафиксировать результат в воспроизводимом виде (SQL + отчет).


## Выполнено

1. Подготовлен датасет в реальной схеме проекта.
2. Сняты базовые замеры по целевым запросам.
3. Добавлены индексы:
   - `idx_mc_client_status_created_at`
   - `idx_packages_client_status_created_at`
   - `idx_events_document_created_at`
4. Повторно сняты замеры и сравнены планы.

## Индексы и комментарии

1. `ops.idx_mc_client_status_created_at (client_id, status_id, created_at DESC)`
Назначение: быстрый отбор кодов маркировки по клиенту/статусу с сортировкой по дате.

2. `ops.idx_packages_client_status_created_at (client_id, status_id, created_at DESC) INCLUDE (cell_id, fullcode)`
Назначение: ускорение выборки упаковок по клиенту/статусу и выдача последних записей.

3. `audit.idx_events_document_created_at (document_id, created_at DESC)`
Назначение: ускорение ленты событий по документу.

## Результаты EXPLAIN (ANALYZE, BUFFERS)

Тестовые данные:
- client_id = 1 ("ООО Альфа Логистик")
- marking_status_id = 2 ("IN_STOCK")
- package_status_id = 1 ("OPEN")
- document_id = 1`

1. `ops.marking_codes`
- До: Bitmap Heap Scan + Sort, Execution Time: 1.204 ms
- После: Index Scan, Execution Time: 0.186 ms
- Итог: 6.5x быстрее

2. `ops.packages`
- До: Bitmap Heap Scan + Sort, Execution Time: 0.321 ms
- После: Index Scan, Execution Time: 0.127 ms
- Итог: 2.5x быстрее

3. `audit.events`
- До: Execution Time: 0.045 ms
- После: Execution Time: 0.049 ms
- Итог: на текущем объеме строк по документу эффект нет, мало данных. 

## SQL

`solution.sql` - замеры до/после и создание индексов.



