-- Normalize 3PL WMS schema to canonical structure
-- Safe to run multiple times.

BEGIN;

CREATE SCHEMA IF NOT EXISTS ref;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS wh;
CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS audit;

-- Move legacy tables from public to canonical schemas when needed.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT *
    FROM (VALUES
      ('warehouses', 'wh'),
      ('zones', 'wh'),
      ('cells', 'wh'),
      ('clients', 'core'),
      ('users', 'core'),
      ('user_clients', 'core'),
      ('products', 'core'),
      ('package_types', 'ref'),
      ('marking_code_statuses', 'ref'),
      ('package_statuses', 'ref'),
      ('document_types', 'ref'),
      ('doc_types', 'ref'),
      ('document_statuses', 'ref'),
      ('event_types', 'ref'),
      ('marking_codes', 'ops'),
      ('packages', 'ops'),
      ('packages_history', 'ops'),
      ('documents', 'ops'),
      ('events', 'audit')
    ) AS t(table_name, target_schema)
  LOOP
    IF to_regclass(format('public.%I', r.table_name)) IS NOT NULL
       AND to_regclass(format('%I.%I', r.target_schema, r.table_name)) IS NULL THEN
      EXECUTE format('ALTER TABLE public.%I SET SCHEMA %I', r.table_name, r.target_schema);
    END IF;
  END LOOP;
END
$$;

-- Canonicalize doc_types naming.
DO $$
BEGIN
  IF to_regclass('ref.document_types') IS NOT NULL
     AND to_regclass('ref.doc_types') IS NULL THEN
    EXECUTE 'ALTER TABLE ref.document_types RENAME TO doc_types';
  END IF;
END
$$;

-- Canonicalize ops.documents column names.
DO $$
BEGIN
  IF to_regclass('ops.documents') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'ops'
        AND table_name = 'documents'
        AND column_name = 'document_type_id'
    ) AND NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'ops'
        AND table_name = 'documents'
        AND column_name = 'doc_type_id'
    ) THEN
      EXECUTE 'ALTER TABLE ops.documents RENAME COLUMN document_type_id TO doc_type_id';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'ops'
        AND table_name = 'documents'
        AND column_name = 'copmleted_ad'
    ) AND NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'ops'
        AND table_name = 'documents'
        AND column_name = 'completed_at'
    ) THEN
      EXECUTE 'ALTER TABLE ops.documents RENAME COLUMN copmleted_ad TO completed_at';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'ops'
        AND table_name = 'documents'
        AND column_name = 'completed_at'
    ) THEN
      EXECUTE 'ALTER TABLE ops.documents ADD COLUMN completed_at timestamp';
    END IF;
  END IF;
END
$$;

-- Ensure essential indexes.
CREATE INDEX IF NOT EXISTS idx_marking_codes_client_searchcode
  ON ops.marking_codes (client_id, searchcode);

CREATE INDEX IF NOT EXISTS idx_marking_codes_client_status
  ON ops.marking_codes (client_id, status_id);

CREATE INDEX IF NOT EXISTS idx_marking_codes_client_product
  ON ops.marking_codes (client_id, product_id);

CREATE INDEX IF NOT EXISTS idx_packages_client_searchcode
  ON ops.packages (client_id, searchcode);

CREATE INDEX IF NOT EXISTS idx_packages_client_type
  ON ops.packages (client_id, package_type_id);

CREATE INDEX IF NOT EXISTS idx_packages_client_status
  ON ops.packages (client_id, status_id);

CREATE INDEX IF NOT EXISTS idx_packages_history_parent_active
  ON ops.packages_history (client_id, parent_package_id)
  WHERE removed_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_packages_history_active_marking_code
  ON ops.packages_history (client_id, marking_code_id)
  WHERE removed_at IS NULL AND marking_code_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_packages_history_active_child_package
  ON ops.packages_history (client_id, child_package_id)
  WHERE removed_at IS NULL AND child_package_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_packages_history_parent_added_at
  ON ops.packages_history (client_id, added_at);

CREATE INDEX IF NOT EXISTS idx_documents_client_status
  ON ops.documents (client_id, status_id);

CREATE INDEX IF NOT EXISTS idx_documents_client_type
  ON ops.documents (client_id, doc_type_id);

CREATE INDEX IF NOT EXISTS idx_documents_client_created
  ON ops.documents (client_id, created_at);

CREATE INDEX IF NOT EXISTS idx_events_document_created
  ON audit.events (document_id, created_at);

CREATE INDEX IF NOT EXISTS idx_events_client_created
  ON audit.events (client_id, created_at);

CREATE INDEX IF NOT EXISTS idx_events_user_created
  ON audit.events (user_id, created_at);

CREATE INDEX IF NOT EXISTS idx_events_client_type_created
  ON audit.events (client_id, event_type_id, created_at);

-- Ensure business constraints for packages_history.
DO $$
BEGIN
  IF to_regclass('ops.packages_history') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'ck_packages_history_exactly_one_child'
        AND conrelid = 'ops.packages_history'::regclass
    ) THEN
      EXECUTE '
        ALTER TABLE ops.packages_history
        ADD CONSTRAINT ck_packages_history_exactly_one_child
        CHECK (
          (marking_code_id IS NOT NULL AND child_package_id IS NULL) OR
          (marking_code_id IS NULL AND child_package_id IS NOT NULL)
        )
      ';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'ck_packages_history_no_self_link'
        AND conrelid = 'ops.packages_history'::regclass
    ) THEN
      EXECUTE '
        ALTER TABLE ops.packages_history
        ADD CONSTRAINT ck_packages_history_no_self_link
        CHECK (child_package_id IS NULL OR child_package_id <> parent_package_id)
      ';
    END IF;
  END IF;
END
$$;

COMMIT;
