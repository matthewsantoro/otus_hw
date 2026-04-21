# Task 7 - Агрегация, CTE и LAG (PostgreSQL)

## Что требуется по заданию

1. Создать таблицу `statistic`.
2. Заполнить её данными из условия.
3. Сделать агрегирующий запрос по годам с сортировкой.
4. Повторить тот же результат через `CTE`.
5. Вывести очки за текущий и предыдущий год для каждого игрока через `LAG`.

## Что реализовано

Все пункты выполнены в `solution.sql`:

1. DDL + INSERT (таблица и данные).
2. `GROUP BY year_game` + `ORDER BY year_game`.
3. Эквивалентный запрос через `WITH yearly_totals AS (...)`.
4. Оконная функция `LAG(points)` с `PARTITION BY player_name`.

## Теория (структуры CTE и LAG)

### Общая структура CTE

```sql
WITH cte_name AS (
  SELECT ...
)
SELECT ...
FROM cte_name;
```

### Общая структура LAG

```sql
LAG(expression [, offset [, default_value]])
OVER (
  [PARTITION BY column_list]
  [ORDER BY sort_expression]
)
```

### Как применено в этом ДЗ

```sql
WITH yearly_totals AS (
  SELECT year_game, SUM(points) AS total_points
  FROM public.statistic
  GROUP BY year_game
)
SELECT year_game, total_points
FROM yearly_totals
ORDER BY year_game;
```

```sql
SELECT
  player_name,
  year_game,
  points AS current_year_points,
  LAG(points) OVER (
    PARTITION BY player_name
    ORDER BY year_game
  ) AS previous_year_points
FROM public.statistic
ORDER BY player_name, year_game;
```

`ORDER BY` внутри окна `LAG` обязателен для корректной логики "предыдущего года". Без него ошибка не возникнет, но результат будет недетерминированным.

## Ожидаемый итог агрегации по годам

| year_game | total_points |
|---|---:|
| 2018 | 92.00 |
| 2019 | 98.00 |
| 2020 | 110.00 |

## Как запустить

В psql:

```sql
\i results/otus_hw/task_7/solution.sql
```

Скрипт сначала пересоздает таблицу `public.statistic`, затем выполняет три итоговых SELECT.
