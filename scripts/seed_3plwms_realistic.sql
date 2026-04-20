-- Seed realistic demo data for canonical 3PL WMS schema
-- Idempotent for dedicated seed clients: rerun refreshes their operational data.

BEGIN;

CREATE TEMP TABLE tmp_seed_clients (
  client_name text PRIMARY KEY,
  inn text NOT NULL,
  user_login text NOT NULL,
  client_code text NOT NULL
) ON COMMIT DROP;

INSERT INTO tmp_seed_clients (client_name, inn, user_login, client_code) VALUES
('ООО Альфа Логистик', '7701000001', 'seed_ops_alfa', 'ALFA'),
('ООО Бета Снабжение', '7701000002', 'seed_ops_beta', 'BETA'),
('ООО Гамма Фулфилмент', '7701000003', 'seed_ops_gamma', 'GAMM');

-- Clients and users
INSERT INTO core.clients (name, inn)
SELECT s.client_name, s.inn
FROM tmp_seed_clients s
WHERE NOT EXISTS (
  SELECT 1 FROM core.clients c WHERE c.name = s.client_name
);

INSERT INTO core.users (login, is_active)
SELECT s.user_login, true
FROM tmp_seed_clients s
ON CONFLICT (login) DO UPDATE SET is_active = EXCLUDED.is_active;

INSERT INTO core.user_clients (user_id, client_id, role)
SELECT u.id, c.id, 'operator'
FROM tmp_seed_clients s
JOIN core.users u ON u.login = s.user_login
JOIN core.clients c ON c.name = s.client_name
ON CONFLICT (user_id, client_id) DO UPDATE SET role = EXCLUDED.role;

CREATE TEMP TABLE tmp_seed_client_ids AS
SELECT c.id AS client_id, s.client_name, s.user_login, s.client_code
FROM tmp_seed_clients s
JOIN core.clients c ON c.name = s.client_name;

-- Refresh only seeded clients operational data.
DELETE FROM audit.events e
USING tmp_seed_client_ids t
WHERE e.client_id = t.client_id;

DELETE FROM ops.packages_history ph
USING tmp_seed_client_ids t
WHERE ph.client_id = t.client_id;

DELETE FROM ops.documents d
USING tmp_seed_client_ids t
WHERE d.client_id = t.client_id;

DELETE FROM ops.marking_codes mc
USING tmp_seed_client_ids t
WHERE mc.client_id = t.client_id;

DELETE FROM ops.packages p
USING tmp_seed_client_ids t
WHERE p.client_id = t.client_id;

DELETE FROM core.products p
USING tmp_seed_client_ids t
WHERE p.client_id = t.client_id;

-- Warehouses/zones/cells (shared)
CREATE TEMP TABLE tmp_seed_warehouses (
  warehouse_name text PRIMARY KEY,
  warehouse_address text NOT NULL
) ON COMMIT DROP;

INSERT INTO tmp_seed_warehouses VALUES
('СК Север', 'Московская обл., Химки, Транспортный проезд, 1'),
('СК Юг', 'Ростов-на-Дону, Логистическая ул., 7'),
('СК Центр', 'Казань, Промышленный тракт, 15');

INSERT INTO wh.warehouses (name, address)
SELECT w.warehouse_name, w.warehouse_address
FROM tmp_seed_warehouses w
WHERE NOT EXISTS (
  SELECT 1 FROM wh.warehouses x WHERE x.name = w.warehouse_name
);

WITH target_w AS (
  SELECT id, name FROM wh.warehouses
  WHERE name IN (SELECT warehouse_name FROM tmp_seed_warehouses)
), zones_seed AS (
  SELECT id AS warehouse_id, unnest(ARRAY['A','B','C','D']) AS zone_code
  FROM target_w
)
INSERT INTO wh.zones (warehouse_id, code, name)
SELECT zs.warehouse_id, zs.zone_code, 'Зона ' || zs.zone_code
FROM zones_seed zs
ON CONFLICT (warehouse_id, code) DO UPDATE SET name = EXCLUDED.name;

WITH target_z AS (
  SELECT z.id, z.code
  FROM wh.zones z
  JOIN wh.warehouses w ON w.id = z.warehouse_id
  WHERE w.name IN (SELECT warehouse_name FROM tmp_seed_warehouses)
), cell_seed AS (
  SELECT z.id AS zone_id, z.code AS zone_code, gs AS n
  FROM target_z z
  CROSS JOIN generate_series(1, 30) AS gs
)
INSERT INTO wh.cells (zone_id, code)
SELECT cs.zone_id, format('%s-%03s', cs.zone_code, cs.n)
FROM cell_seed cs
ON CONFLICT (zone_id, code) DO NOTHING;

-- Products
WITH c AS (
  SELECT client_id, client_code FROM tmp_seed_client_ids
), prod_seed AS (
  SELECT
    c.client_id,
    c.client_code,
    gs,
    (ARRAY['pcs','box','set'])[1 + ((gs - 1) % 3)] AS unit_name
  FROM c
  CROSS JOIN generate_series(1, 120) AS gs
)
INSERT INTO core.products (client_id, sku, name, gtin, unit)
SELECT
  ps.client_id,
  format('SKU-%s-%04s', ps.client_code, ps.gs),
  format('%s товар %s', ps.client_code, ps.gs),
  (46000000000000 + (ps.client_id * 10000) + ps.gs)::text,
  ps.unit_name
FROM prod_seed ps
ON CONFLICT (client_id, sku) DO UPDATE
SET name = EXCLUDED.name,
    gtin = EXCLUDED.gtin,
    unit = EXCLUDED.unit;

CREATE TEMP TABLE tmp_cells AS
SELECT id AS cell_id, row_number() OVER (ORDER BY id) AS rn, count(*) OVER () AS cnt
FROM wh.cells;

CREATE TEMP TABLE tmp_products AS
SELECT
  p.client_id,
  p.id AS product_id,
  row_number() OVER (PARTITION BY p.client_id ORDER BY p.id) AS rn,
  count(*) OVER (PARTITION BY p.client_id) AS cnt
FROM core.products p
JOIN tmp_seed_client_ids t ON t.client_id = p.client_id;

-- Marking codes
WITH mc_status AS (
  SELECT
    max(id) FILTER (WHERE code = 'NEW') AS st_new,
    max(id) FILTER (WHERE code = 'IN_STOCK') AS st_in_stock,
    max(id) FILTER (WHERE code = 'RESERVED') AS st_reserved,
    max(id) FILTER (WHERE code = 'SHIPPED') AS st_shipped,
    max(id) FILTER (WHERE code = 'LOST') AS st_lost
  FROM ref.marking_code_statuses
), seed AS (
  SELECT t.client_id, t.client_code, gs
  FROM tmp_seed_client_ids t
  CROSS JOIN generate_series(1, 5000) AS gs
)
INSERT INTO ops.marking_codes (
  client_id,
  product_id,
  fullcode,
  searchcode,
  cell_id,
  status_id,
  created_at
)
SELECT
  s.client_id,
  p.product_id,
  format('MC-%s-%08s', s.client_code, s.gs),
  right(format('MC-%s-%08s', s.client_code, s.gs), 8),
  CASE WHEN s.gs % 23 = 0 THEN NULL ELSE c.cell_id END,
  CASE
    WHEN s.gs % 100 < 45 THEN ms.st_in_stock
    WHEN s.gs % 100 < 70 THEN ms.st_new
    WHEN s.gs % 100 < 85 THEN ms.st_reserved
    WHEN s.gs % 100 < 97 THEN ms.st_shipped
    ELSE ms.st_lost
  END,
  now() - ((s.gs % 180) || ' days')::interval - ((s.gs * 37 % 86400) || ' seconds')::interval
FROM seed s
JOIN tmp_products p
  ON p.client_id = s.client_id
 AND p.rn = ((s.gs - 1) % p.cnt) + 1
JOIN tmp_cells c
  ON c.rn = ((s.gs + s.client_id * 17) % c.cnt) + 1
CROSS JOIN mc_status ms;

-- Packages
WITH pkg_types AS (
  SELECT
    max(id) FILTER (WHERE code = 'BOX') AS pt_box,
    max(id) FILTER (WHERE code = 'PALLET') AS pt_pallet,
    max(id) FILTER (WHERE code = 'UNIT') AS pt_unit
  FROM ref.package_types
), pkg_status AS (
  SELECT
    max(id) FILTER (WHERE code = 'OPEN') AS st_open,
    max(id) FILTER (WHERE code = 'CLOSED') AS st_closed,
    max(id) FILTER (WHERE code = 'SEALED') AS st_sealed,
    max(id) FILTER (WHERE code = 'SHIPPED') AS st_shipped
  FROM ref.package_statuses
), seed AS (
  SELECT t.client_id, t.client_code, gs
  FROM tmp_seed_client_ids t
  CROSS JOIN generate_series(1, 1500) AS gs
)
INSERT INTO ops.packages (
  client_id,
  package_type_id,
  fullcode,
  searchcode,
  cell_id,
  status_id,
  created_at
)
SELECT
  s.client_id,
  CASE
    WHEN s.gs % 12 = 0 THEN pt.pt_pallet
    WHEN s.gs % 3 = 0 THEN pt.pt_box
    ELSE pt.pt_unit
  END,
  format('PKG-%s-%07s', s.client_code, s.gs),
  right(format('PKG-%s-%07s', s.client_code, s.gs), 8),
  c.cell_id,
  CASE
    WHEN s.gs % 100 < 40 THEN ps.st_open
    WHEN s.gs % 100 < 72 THEN ps.st_closed
    WHEN s.gs % 100 < 90 THEN ps.st_sealed
    ELSE ps.st_shipped
  END,
  now() - ((s.gs % 120) || ' days')::interval - ((s.gs * 11 % 86400) || ' seconds')::interval
FROM seed s
JOIN tmp_cells c
  ON c.rn = ((s.gs + s.client_id * 19) % c.cnt) + 1
CROSS JOIN pkg_types pt
CROSS JOIN pkg_status ps;

-- Packages history: link package -> marking code
WITH p AS (
  SELECT
    client_id,
    id AS package_id,
    row_number() OVER (PARTITION BY client_id ORDER BY id) AS rn
  FROM ops.packages
  WHERE client_id IN (SELECT client_id FROM tmp_seed_client_ids)
), m AS (
  SELECT
    client_id,
    id AS marking_code_id,
    row_number() OVER (PARTITION BY client_id ORDER BY id) AS rn
  FROM ops.marking_codes
  WHERE client_id IN (SELECT client_id FROM tmp_seed_client_ids)
)
INSERT INTO ops.packages_history (
  client_id,
  parent_package_id,
  marking_code_id,
  child_package_id,
  added_at,
  removed_at
)
SELECT
  p.client_id,
  p.package_id,
  m.marking_code_id,
  NULL,
  now() - ((p.rn % 90) || ' days')::interval,
  CASE WHEN p.rn % 11 = 0 THEN now() - ((p.rn % 15) || ' days')::interval ELSE NULL END
FROM p
JOIN m ON m.client_id = p.client_id AND m.rn = p.rn
WHERE p.rn <= 1000;

-- Packages history: nested package links
WITH p AS (
  SELECT
    client_id,
    id AS package_id,
    row_number() OVER (PARTITION BY client_id ORDER BY id) AS rn,
    lead(id) OVER (PARTITION BY client_id ORDER BY id) AS next_package_id
  FROM ops.packages
  WHERE client_id IN (SELECT client_id FROM tmp_seed_client_ids)
)
INSERT INTO ops.packages_history (
  client_id,
  parent_package_id,
  marking_code_id,
  child_package_id,
  added_at,
  removed_at
)
SELECT
  p.client_id,
  p.package_id,
  NULL,
  p.next_package_id,
  now() - ((p.rn % 60) || ' days')::interval,
  CASE WHEN p.rn % 8 = 0 THEN now() - ((p.rn % 10) || ' days')::interval ELSE NULL END
FROM p
WHERE p.next_package_id IS NOT NULL
  AND p.rn % 15 = 0;

-- Documents
WITH doc_types AS (
  SELECT
    max(id) FILTER (WHERE code = 'RECEIPT') AS dt_receipt,
    max(id) FILTER (WHERE code = 'SHIPMENT') AS dt_shipment,
    max(id) FILTER (WHERE code = 'MOVE') AS dt_move,
    max(id) FILTER (WHERE code = 'INVENTORY') AS dt_inventory
  FROM ref.doc_types
), doc_status AS (
  SELECT
    max(id) FILTER (WHERE code = 'DRAFT') AS st_draft,
    max(id) FILTER (WHERE code = 'POSTED') AS st_posted,
    max(id) FILTER (WHERE code = 'CANCELLED') AS st_cancelled
  FROM ref.document_statuses
), users_map AS (
  SELECT t.client_id, u.id AS user_id
  FROM tmp_seed_client_ids t
  JOIN core.users u ON u.login = t.user_login
), seed AS (
  SELECT t.client_id, gs
  FROM tmp_seed_client_ids t
  CROSS JOIN generate_series(1, 600) AS gs
)
INSERT INTO ops.documents (
  client_id,
  doc_type_id,
  status_id,
  created_by,
  created_at,
  completed_at
)
SELECT
  s.client_id,
  CASE
    WHEN s.gs % 4 = 0 THEN dt.dt_receipt
    WHEN s.gs % 4 = 1 THEN dt.dt_shipment
    WHEN s.gs % 4 = 2 THEN dt.dt_move
    ELSE dt.dt_inventory
  END,
  CASE
    WHEN s.gs % 10 < 6 THEN ds.st_posted
    WHEN s.gs % 10 < 8 THEN ds.st_draft
    ELSE ds.st_cancelled
  END,
  um.user_id,
  now() - ((s.gs % 120) || ' days')::interval - ((s.gs * 13 % 86400) || ' seconds')::interval,
  CASE
    WHEN s.gs % 10 < 6 OR s.gs % 10 >= 8
      THEN now() - ((s.gs % 110) || ' days')::interval
    ELSE NULL
  END
FROM seed s
JOIN users_map um ON um.client_id = s.client_id
CROSS JOIN doc_types dt
CROSS JOIN doc_status ds;

-- Events
WITH event_types AS (
  SELECT
    max(id) FILTER (WHERE code = 'PACKAGE_CREATED') AS ev_package_created,
    max(id) FILTER (WHERE code = 'MOVE') AS ev_move,
    max(id) FILTER (WHERE code = 'STATUS_CHANGE') AS ev_status_change,
    max(id) FILTER (WHERE code = 'DOC_POSTED') AS ev_doc_posted
  FROM ref.event_types
), docs AS (
  SELECT d.id, d.client_id, d.status_id, d.created_by, d.created_at
  FROM ops.documents d
  WHERE d.client_id IN (SELECT client_id FROM tmp_seed_client_ids)
), ds AS (
  SELECT id, code FROM ref.document_statuses
)
INSERT INTO audit.events (
  client_id,
  document_id,
  event_type_id,
  user_id,
  created_at,
  data
)
SELECT
  d.client_id,
  d.id,
  CASE n.step_no
    WHEN 1 THEN et.ev_package_created
    WHEN 2 THEN et.ev_move
    ELSE CASE WHEN ds.code = 'POSTED' THEN et.ev_doc_posted ELSE et.ev_status_change END
  END,
  d.created_by,
  d.created_at + (n.step_no || ' minutes')::interval,
  jsonb_build_object(
    'source', 'seed_3plwms_realistic',
    'step', n.step_no,
    'document_status', ds.code
  )
FROM docs d
JOIN ds ON ds.id = d.status_id
CROSS JOIN event_types et
CROSS JOIN (VALUES (1), (2), (3)) AS n(step_no);

ANALYZE core.clients;
ANALYZE core.users;
ANALYZE core.products;
ANALYZE ops.marking_codes;
ANALYZE ops.packages;
ANALYZE ops.packages_history;
ANALYZE ops.documents;
ANALYZE audit.events;

COMMIT;
