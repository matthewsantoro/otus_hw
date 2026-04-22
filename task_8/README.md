# Task 8 - Репликация PostgreSQL (физическая и логическая)

## Цель

Поднять стенд и настроить:

1. физическую репликацию `primary -> physical-replica`;
2. physical replication slot;
3. задержку применения WAL на standby в `5min`;
4. логическую репликацию `primary -> logical-subscriber`.

## Что использовал

1. `docker-compose.yml` - поднимает 3 контейнера: `postgres-primary`, `postgres-physical-replica`, `postgres-logical-subscriber`.
2. Команды PostgreSQL: `pg_isready`, `psql`, `pg_basebackup`.
3. Параметры репликации:
4. `primary_conninfo = 'host=postgres-primary port=5432 user=replicator password=replicator_pass application_name=physical_replica_1'`.
5. `primary_slot_name = 'otus_hw8_phys_slot'`.
6. `recovery_min_apply_delay = '5min'`.

## Шаг 1. Поднял стенд

```bash
cd results/otus_hw/task_8
docker compose up -d
docker compose ps
```

## Шаг 2. Физическая репликация

Сделал руками по шагам:

1. Дождался доступности `primary`:

```bash
docker exec -it postgres-physical-replica pg_isready -h postgres-primary -p 5432 -U postgres
```

2. На `primary` создал роль для репликации:

```sql 
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_pass'
```

3. На `primary` создал physical slot:

```bash
docker exec -i postgres-primary psql -U postgres -d postgres <<'SQL'
    SELECT 1 FROM pg_replication_slots WHERE slot_name = 'phys_slot'
  ) THEN
    PERFORM pg_create_physical_replication_slot('phys_slot');
  END IF;
END
$$;
SQL
```

4. На `standby` снял базовую копию с `primary`:

```bash
docker exec -it -e PGPASSWORD=replicator_pass postgres-physical-replica pg_basebackup \
  -h postgres-primary \
  -p 5432 \
  -U replicator \
  -D /var/lib/postgresql/data \
  -R \
  -S phys_slot \
  -X stream
```

5. На `standby` задал параметры подключения и задержки:

```conf
primary_conninfo = 'host=postgres-primary port=5432 user=replicator password=replicator_pass application_name=physical_replica_1'
primary_slot_name = 'phys_slot'
recovery_min_apply_delay = '5min'
```

Проверка на primary:

```sql
SELECT application_name, state, sync_state, pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS bytes_lag FROM pg_stat_replication;
SELECT slot_name, slot_type, active, restart_lsn FROM pg_replication_slots WHERE slot_name = 'otus_hw8_phys_slot'
```

## Шаг 3. Подготовил данные на primary для logical replication

Подключился к primary:

```bash
docker exec -it postgres-primary psql -U postgres -d postgres
```

Выполнил:

```sql
CREATE DATABASE otus_hw8;
\c otus_hw8

CREATE TABLE IF NOT EXISTS public.replication_demo (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_no TEXT NOT NULL UNIQUE,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.replication_demo (order_no, payload)
VALUES
  ('1', '{"client":"OPH","status":"new","items":3}'),
  ('2', '{"client":"ONTEX","status":"packing","items":1}'),
  ('3', '{"client":"ALFA","status":"shipped","items":5}')
ON CONFLICT (order_no) DO NOTHING;


CREATE PUBLICATION otus_hw8_publication FOR TABLE public.replication_demo;
 
$$;
```

## Шаг 4. Настроил logical subscriber

Подключился к `postgres-logical-subscriber`:

```bash
docker exec -it postgres-logical-subscriber psql -U postgres -d postgres
```

Выполнил:

```sql
CREATE DATABASE otus_hw8;
\c otus_hw8

CREATE TABLE IF NOT EXISTS public.replication_demo (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_no TEXT NOT NULL UNIQUE,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP SUBSCRIPTION IF EXISTS otus_hw8_subscription;

CREATE SUBSCRIPTION otus_hw8_subscription
CONNECTION 'host=postgres-primary port=5432 dbname=otus_hw8 user=postgres password=postgres'
PUBLICATION otus_hw8_publication
WITH (
  copy_data = true,
  create_slot = true,
  enabled = true
);

SELECT subname, received_lsn, latest_end_lsn,
       last_msg_send_time, last_msg_receipt_time
FROM pg_stat_subscription;
```

## Шаг 5. Проверил перенос новых данных

На primary добавил новые записи:

```sql
INSERT INTO public.replication_demo (order_no, payload)
VALUES
  ('5', '{"client":"DELTA","status":"new","items":2}'),
  ('6', '{"client":"OMEGA","status":"confirmed","items":4}');
```

На logical subscriber проверил, что данные пришли:

```sql
SELECT id, order_no, payload, created_at
FROM public.replication_demo
ORDER BY id;
```
