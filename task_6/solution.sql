-- task_6 / indexes_postgresql
-- solution.sql
-- Запускать на существующей 3PL WMS модели

-- Параметры примера для текущего seed:
-- client_id = 1, marking status = 2 (IN_STOCK), package status = 1 (OPEN), document_id = 1

-- 1) Базовые замеры ДО task_6 индексов
DROP INDEX IF EXISTS ops.idx_mc_client_status_created_at;
DROP INDEX IF EXISTS ops.idx_packages_client_status_created_at;
DROP INDEX IF EXISTS audit.idx_events_document_created_at;

ANALYZE ops.marking_codes;
ANALYZE ops.packages;
ANALYZE audit.events;

EXPLAIN (ANALYZE, BUFFERS)
SELECT mc.id, mc.fullcode, mc.status_id, mc.created_at
FROM ops.marking_codes mc
WHERE mc.client_id = 1
  AND mc.status_id = 2
ORDER BY mc.created_at DESC
LIMIT 100;

EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id, p.fullcode, p.cell_id, p.created_at
FROM ops.packages p
WHERE p.client_id = 1
  AND p.status_id = 1
ORDER BY p.created_at DESC
LIMIT 100;

EXPLAIN (ANALYZE, BUFFERS)
SELECT e.id, e.document_id, e.event_type_id, e.user_id, e.created_at
FROM audit.events e
WHERE e.document_id = 1
ORDER BY e.created_at DESC
LIMIT 200;

-- 2) Индексы под реальные запросы проекта
CREATE INDEX IF NOT EXISTS idx_mc_client_status_created_at
  ON ops.marking_codes (client_id, status_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_packages_client_status_created_at
  ON ops.packages (client_id, status_id, created_at DESC)
  INCLUDE (cell_id, fullcode);

CREATE INDEX IF NOT EXISTS idx_events_document_created_at
  ON audit.events (document_id, created_at DESC);

ANALYZE ops.marking_codes;
ANALYZE ops.packages;
ANALYZE audit.events;

-- 3) Повторные замеры ПОСЛЕ индексов
EXPLAIN (ANALYZE, BUFFERS)
SELECT mc.id, mc.fullcode, mc.status_id, mc.created_at
FROM ops.marking_codes mc
WHERE mc.client_id = 1
  AND mc.status_id = 2
ORDER BY mc.created_at DESC
LIMIT 100;

EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id, p.fullcode, p.cell_id, p.created_at
FROM ops.packages p
WHERE p.client_id = 1
  AND p.status_id = 1
ORDER BY p.created_at DESC
LIMIT 100;

EXPLAIN (ANALYZE, BUFFERS)
SELECT e.id, e.document_id, e.event_type_id, e.user_id, e.created_at
FROM audit.events e
WHERE e.document_id = 1
ORDER BY e.created_at DESC
LIMIT 200;
