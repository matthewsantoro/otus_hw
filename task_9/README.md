# Task 9 - Внутренняя архитектура MySQL

Ниже пошаговый лог выполнения на сервере через Codex (профиль `ms`): команды и реальный вывод консоли.

## Шаг 1. Проверил Docker/Compose

```bash
command -v docker && docker --version 
```

```text
Docker version 26.1.3, build 26.1.3-0ubuntu1~20.04.1
```

## Шаг 2. Забрал стартовый репозиторий

```bash
rm -rf ~/otus-mysql-docker-task9 && git clone https://github.com/aeuge/otus-mysql-docker ~/otus-mysql-docker-task9 && cd ~/otus-mysql-docker-task9 && ls -la
```

```text
Cloning into '/home/ms/otus-mysql-docker-task9'...
total 28
drwxrwxr-x 4 ms ms 4096 Apr 22 22:59 .
drwxr-xr-x 6 ms ms 4096 Apr 22 22:59 ..
drwxrwxr-x 8 ms ms 4096 Apr 22 22:59 .git
-rw-rw-r-- 1 ms ms  416 Apr 22 22:59 README.md
drwxrwxr-x 2 ms ms 4096 Apr 22 22:59 custom.conf
-rw-rw-r-- 1 ms ms  339 Apr 22 22:59 docker-compose.yml
-rw-rw-r-- 1 ms ms   32 Apr 22 22:59 init.sql
```

## Шаг 3.  `init.sql` 


```sql
CREATE DATABASE IF NOT EXISTS otus_3plwms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE otus_3plwms;

CREATE TABLE IF NOT EXISTS clients (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  inn VARCHAR(12) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY ux_clients_inn (inn)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  login VARCHAR(100) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY ux_users_login (login)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS user_clients (
  user_id INT UNSIGNED NOT NULL,
  client_id INT UNSIGNED NOT NULL,
  role VARCHAR(50) NOT NULL,
  PRIMARY KEY (user_id, client_id),
  CONSTRAINT fk_user_clients_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_user_clients_client FOREIGN KEY (client_id) REFERENCES clients(id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  client_id INT UNSIGNED NOT NULL,
  sku VARCHAR(64) NOT NULL,
  name VARCHAR(255) NOT NULL,
  gtin VARCHAR(14),
  unit VARCHAR(16) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY ux_products_client_sku (client_id, sku),
  UNIQUE KEY ux_products_client_gtin (client_id, gtin),
  CONSTRAINT fk_products_client FOREIGN KEY (client_id) REFERENCES clients(id)
) ENGINE=InnoDB;

INSERT INTO clients (name, inn)
VALUES
  ('ООО Альфа Логистик', '7701000001'),
  ('ООО Бета Снабжение', '7701000002'),
  ('ООО Гамма Фулфилмент', '7701000003')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO users (login, is_active)
VALUES
  ('seed_ops_alfa', 1),
  ('seed_ops_beta', 1),
  ('seed_ops_gamma', 1)
ON DUPLICATE KEY UPDATE is_active = VALUES(is_active);

INSERT INTO user_clients (user_id, client_id, role)
SELECT u.id, c.id, 'operator'
FROM users u
JOIN clients c ON (
     (u.login = 'seed_ops_alfa'  AND c.inn = '7701000001')
  OR (u.login = 'seed_ops_beta'  AND c.inn = '7701000002')
  OR (u.login = 'seed_ops_gamma' AND c.inn = '7701000003')
)
ON DUPLICATE KEY UPDATE role = VALUES(role);

INSERT INTO products (client_id, sku, name, gtin, unit)
SELECT c.id, v.sku, v.name, v.gtin, v.unit
FROM clients c
JOIN (
  SELECT '7701000001' AS inn, 'SKU-ALFA-0001' AS sku, 'ALFA товар 1' AS name, '4600000010001' AS gtin, 'pcs' AS unit
  UNION ALL SELECT '7701000001', 'SKU-ALFA-0002', 'ALFA товар 2', '4600000010002', 'box'
  UNION ALL SELECT '7701000002', 'SKU-BETA-0001', 'BETA товар 1', '4600000020001', 'pcs'
  UNION ALL SELECT '7701000002', 'SKU-BETA-0002', 'BETA товар 2', '4600000020002', 'set'
  UNION ALL SELECT '7701000003', 'SKU-GAMM-0001', 'GAMM товар 1', '4600000030001', 'pcs'
  UNION ALL SELECT '7701000003', 'SKU-GAMM-0002', 'GAMM товар 2', '4600000030002', 'box'
) v ON v.inn = c.inn
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  gtin = VALUES(gtin),
  unit = VALUES(unit);

```CNF
[mysqld]
default-authentication-plugin=mysql_native_password
innodb_buffer_pool_size=256M
innodb_log_file_size=64M
max_connections=200
```


## Шаг 4. Запустил контейнер

```bash
cd ~/otus-mysql-docker-task9 &&  docker-compose up -d otusdb 
docker-compose ps
```

```text
Removing otus-mysql-docker-task9_otusdb_1 ... done
Removing network otus-mysql-docker-task9_default
Removing volume otus-mysql-docker-task9_data
Creating network "otus-mysql-docker-task9_default" with the default driver
Creating volume "otus-mysql-docker-task9_data" with default driver
Creating otus-mysql-docker-task9_otusdb_1 ... done
         Name                   Command           State           Ports
--------------------------------------------------------------------------------
otus-mysql-docker-       docker-entrypoint.sh     Up      0.0.0.0:3309->3306/tcp
task9_otusdb_1           --ini ...                        ,:::3309->3306/tcp,
                                                          33060/tcp
```


## Шаг 5. Установил и запустил sysbench (*)

```bash
sudo -n apt-get install -y sysbench
```


```bash
sysbench --version
```

```text
sysbench 1.0.18
```



prepare
```bash
sysbench /usr/share/sysbench/oltp_read_write.lua --mysql-host=127.0.0.1 --mysql-port=3309 --mysql-user=root --mysql-password=12345 --mysql-db=otus_3plwms --tables=2 --table-size=10000 prepare
```

```text
sysbench 1.0.18 (using system LuaJIT 2.1.0-beta3)

Creating table 'sbtest1'...
Inserting 10000 records into 'sbtest1'
Creating a secondary index on 'sbtest1'...
Creating table 'sbtest2'...
Inserting 10000 records into 'sbtest2'
Creating a secondary index on 'sbtest2'...
```

run
```bash
sysbench /usr/share/sysbench/oltp_read_write.lua --mysql-host=127.0.0.1 --mysql-port=3309 --mysql-user=root --mysql-password=12345 --mysql-db=otus_3plwms --tables=2 --table-size=10000 --threads=4 --time=30 --report-interval=10 run
```

```text
sysbench 1.0.18 (using system LuaJIT 2.1.0-beta3)

[ 10s ] thds: 4 tps: 153.38 qps: 3086.08 (r/w/o: 2163.17/614.94/307.97) lat (ms,95%): 33.12 err/s: 0.80 reconn/s: 0.00
[ 20s ] thds: 4 tps: 152.90 qps: 3064.25 (r/w/o: 2145.43/612.61/306.20) lat (ms,95%): 31.94 err/s: 0.40 reconn/s: 0.00
[ 30s ] thds: 4 tps: 149.40 qps: 2995.70 (r/w/o: 2098.30/598.20/299.20) lat (ms,95%): 32.53 err/s: 0.40 reconn/s: 0.00
SQL statistics:
    queries performed:
        read:                            64078
        write:                           18274
        other:                           9138
        total:                           91490
    transactions:                        4561   (151.94 per sec.)
    queries:                             91490  (3047.75 per sec.)
    ignored errors:                      16     (0.53 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          30.0182s
    total number of events:              4561

Latency (ms):
         min:                                   11.40
         avg:                                   26.32
         max:                                  143.80
         95th percentile:                       32.53
         sum:                               120033.93
```

cleanup
```bash
sysbench /usr/share/sysbench/oltp_read_write.lua --mysql-host=127.0.0.1 --mysql-port=3309 --mysql-user=root --mysql-password=12345 --mysql-db=otus_3plwms --tables=2 cleanup
```

```text
sysbench 1.0.18 (using system LuaJIT 2.1.0-beta3)

Dropping table 'sbtest1'...
Dropping table 'sbtest2'...
```
