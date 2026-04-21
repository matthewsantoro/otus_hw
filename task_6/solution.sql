ANALYZE ops.marking_codes;
ANALYZE core.products;
ANALYZE ops.packages_history;


EXPLAIN (ANALYZE, BUFFERS)
SELECT mc.id, mc.fullcode, mc.status_id, mc.created_at
FROM ops.marking_codes mc
WHERE mc.client_id = 1
  AND mc.status_id = 2
ORDER BY mc.created_at DESC
LIMIT 100;


EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id, p.client_id, p.sku, p.name
FROM core.products p
WHERE to_tsvector('russian', coalesce(p.name, '') || ' ' || coalesce(p.sku, ''))
      @@ to_tsquery('russian', 'alfa & товар & 112');


EXPLAIN (ANALYZE, BUFFERS)
SELECT ph.id, ph.parent_package_id, ph.marking_code_id, ph.added_at
FROM ops.packages_history ph
WHERE ph.client_id = 1
  AND ph.parent_package_id = 43
  AND ph.removed_at IS NULL
ORDER BY ph.added_at DESC
LIMIT 20;



-- 1) Индекс на несколько полей (composite)
CREATE INDEX idx_t6_mc_client_status_created_at
  ON ops.marking_codes (client_id, status_id, created_at DESC);

-- 2) Индекс для полнотекстового поиска (GIN + to_tsvector)
CREATE INDEX idx_t6_products_fts_ru
  ON core.products
  USING gin (to_tsvector('russian', coalesce(name, '') || ' ' || coalesce(sku, '')));

-- 3) Индекс на часть таблицы (partial index)
CREATE INDEX idx_t6_packages_history_active_parent_added
  ON ops.packages_history (client_id, parent_package_id, added_at DESC)
  WHERE removed_at IS NULL;


ANALYZE ops.marking_codes;
ANALYZE core.products;
ANALYZE ops.packages_history;



