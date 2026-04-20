# Индексы PostgreSQL (Task 6)

> Разработка проекта 3PL WMS

## Задание

Оптимизировать запросы в PostgreSQL с помощью индексов и подтвердить эффект через `EXPLAIN (ANALYZE, BUFFERS)`.

## Цель

1. Применить индексы на реальной БД проекта, а не на отдельном учебном примере.
2. Сравнить планы выполнения до и после индексации.
3. Зафиксировать результат в воспроизводимом виде (SQL + отчет).

## Контекст БД

Работа выполнялась на существующей модели из `task_1..task_5`:
- `ops.marking_codes`
- `ops.packages`
- `audit.events`
- связанные таблицы `core/ref/wh/ops/audit`

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

Контекст теста:
- `client_id = 1` (`ООО Альфа Логистик`)
- `marking_status_id = 2` (`IN_STOCK`)
- `package_status_id = 1` (`OPEN`)
- `document_id = 1`

1. `ops.marking_codes`
- До: `Bitmap Heap Scan + Sort`, `Execution Time: 1.204 ms`
- После: `Index Scan`, `Execution Time: 0.186 ms`
- Итог: ~`6.5x` быстрее

2. `ops.packages`
- До: `Bitmap Heap Scan + Sort`, `Execution Time: 0.321 ms`
- После: `Index Scan`, `Execution Time: 0.127 ms`
- Итог: ~`2.5x` быстрее

3. `audit.events`
- До: `Execution Time: 0.045 ms`
- После: `Execution Time: 0.049 ms`
- Итог: на текущем объеме строк по документу эффект нейтральный

## SQL Files

1. `solution.sql` - замеры до/после и создание индексов.
2. `../scripts/seed_3plwms_realistic.sql` - общий реалистичный seed для всех ДЗ.

## Вывод

Основной прирост получен на рабочих запросах к `ops.marking_codes` и `ops.packages`, где используются фильтры по клиенту/статусу и сортировка по времени. Структура и SQL полностью совместимы с общей схемой проекта.
