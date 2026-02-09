# #2 Компоненты современной СУБД 
## Анализ возможных запросов\отчетов\поиска данных.
1. Где находится паллета
```sql
SELECT id, client_id, package_type, fullcode, status, created_at
FROM packages
JOIN 
WHERE client_id = ''
  AND fullcode = ''
```