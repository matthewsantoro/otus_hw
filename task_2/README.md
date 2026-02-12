# #2 Компоненты современной СУБД 
```
Домашнее задание
Описание/Пошаговая инструкция выполнения домашнего задания:
1. Проводим анализ возможных запросов\отчетов\поиска данных.
2. Предполагаем возможную кардинальность поля.
3. Создаем дополнительные индексы - простые или композитные.
4. На каждый индекс пишем краткое описание зачем он нужен (почему по этому полю\полям).
5. Думаем какие логические ограничения в БД нужно добавить - например какие поля должны быть уникальны, в какие нужно добавить условия, чтобы не нарушить бизнес логику. Пример - нельзя провести операцию по переводу средств на отрицательную сумму.
6. Создаем ограничения по выбранным полям.
```

## 1. Анализ возможных запросов\отчетов\поиска данных.

1. Где находится код по полному коду
```sql
  SELECT id, product_id, status_id, cell_id, created_at
  FROM marking_codes
  WHERE client_id = 
    AND fullcode = ''
```

2. Найти все коды  по продукрту
```sql
SELECT id, fullcode, status_id
FROM marking_codes
WHERE client_id = 
  AND product_id = 
```
3. Найти упаковку по коду 
```sql
SELECT p.id, p.cell_id, c.zone_id
FROM packages p
JOIN cells c ON c.id = p.cell_id
WHERE p.client_id = 
and p.fullcode = ''
```
4.  Список упаковок по статусу
```sql
SELECT id, fullcode, package_type_id
FROM packages
WHERE client_id = 
  AND status_id = 
```

5. Поиск текущего состава
```sql
SELECT marking_code_id, child_package_id, added_at
FROM packages_history
WHERE client_id = 
  AND parent_package_id = 
  AND removed_at IS NULL;
```

6. Лента событий по документу
```
SELECT *
FROM events
WHERE document_id = 
ORDER BY created_at;
``` 

7. Действия оператора
```
SELECT *
FROM events
WHERE user_id = 
  AND created_at >= 
  AND created_at < 
ORDER BY created_at DESC;
```

## 2. Оценка кардинальности поля

**Warwarehouses**
- id - высокая
- name - высокая
- addres - высокая


**Zones**
- id - высокая
- warehouse_id - низкая
- code - средняя
- name - средняя

**cells**
- id -  высокая
- zone_id - низкая
- code - средняя

**clients**
- id - высокая
- name - высокая
- inn - высокая

**users** 
- id -  высокая
- login -  высокая
- is_active -  низкая
- created_at - высокая

**user_clients**
- user_id - низкая
- client_id -  низкая
- role -  низкая

**package_types**
- id - высокая
- code - высокая
- name - высокая

**marking_code_statuses**
- id - высокая
- code - высокая
- name - высокая

**package_statuses**
- id - высокая
- code - высокая
- name - высокая

**document_types**
- id - высокая
- code - высокая
- name - высокая

**document_statuses**
- id - высокая
- code - высокая
- name - высокая

**event_types**
- id - высокая
- code - высокая
- name - высокая


**products**
- id -  высокая
- client_id -  низкая
- sku - высокая
- name - средняя
- gtin - средняя
- unit -  низкая


**marking_codes**
- id -  высокая
- client_id -  низкая
- product_id - низкая
- fullcode -  высокая
- searchcode - высокая
- cell_id - низкая
- status_id -  низкая
- created_at - высокая

**packages**
- id -  высокая
- client_id -  низкая
- package_type_id -  низкая
- fullcode -  высокая
- searchcode - высокая
- cell_id - средняя
- status_id -  низкая
- created_at - высокая


**packages_history**
- id -  высокая
- client_id -  низкая
- parent_package_id - низкая
- marking_code_id - высокая
- child_package_id - низкая
- added_at - высокая
- removed_at - средняя


**documents**
- id -  высокая
- client_id - низкая
- doc_type_id -  низкая
- status_id -  низкая
- created_by - средняя
- created_at - высокая
- copmleted_ad - высокая


**events**
- id -  высокая
- client_id -  низкая
- document_id - средняя
- event_type_id -  низкая
- user_id - низкая
- created_at -  высокая
- data -  высокая

## 3 и 4. Индексы

**marking_codes**

UNIQUE (client_id, fullcode) - поиск КМ по полному коду, защита от дублей 

CREATE INDEX idx_marking_codes_client_searchcode
  ON marking_codes (client_id, searchcode); - поиск по простому коду

CREATE INDEX idx_marking_codes_client_status
  ON marking_codes (client_id, status_id); - отчеты по статусам

CREATE INDEX idx_marking_codes_client_product - отчеты по продукту
  ON marking_codes (client_id, product_id); 

**packages**

UNIQUE (client_id, fullcode) - поиск упоковки по полному коду, защита от дублей 

СREATE INDEX idx_packages_client_searchcode
    ON packages (client_id, searchcode); - поиск по сокращенной упаковки


CREATE INDEX idx_packages_client_type
    ON packages (client_id, package_type_id); - все паллеты клиента / все короба клиента. Хоть и кардинальность низкая у типа, обязательная свзяка клиентов увеличивает ее. 

CREATE INDEX idx_packages_client_status
    ON packages (client_id, status_id); - для отчета по статусам. Хоть и кардинальность низкая у статуса, обязательная свзяка клиентов увеличивает ее.  


**packages_history**

CREATE INDEX idx_packages_history_parent_active
    ON packages_history (client_id, parent_package_id)
    WHERE removed_at IS NULL; - что сейчас внутри упаковки

CREATE UNIQUE INDEX ux_packages_history_active_marking_code
    ON packages_history (client_id, marking_code_id)
    WHERE removed_at IS NULL AND marking_code_id IS NOT NULL; - поиск по айди КМ и проверки уникальности

CREATE UNIQUE INDEX ux_packages_history_active_child_package
    ON packages_history (client_id, child_package_id)
    WHERE removed_at IS NULL AND child_package_id IS NOT NULL; - поиск по айди упаковки и уникальности вложения

  CREATE INDEX idx_packages_history_added_at(client_id, added_at) - отчет сборки за период времени
    
**events**

CREATE INDEX idx_events_document_created
  ON events (document_id, created_at); - аудит документов

CREATE INDEX idx_events_client_created
  ON events (client_id, created_at); - история за переиод

CREATE INDEX idx_events_user_created
  ON events (user_id, created_at); - активность пользователя за период времени

CREATE INDEX idx_events_client_type_created
  ON events (client_id, event_type_id, created_at); - отчет по статусам по переиодам

  **documents**

CREATE INDEX idx_documents_client_status
  ON documents (client_id, status_id); -поиск статусам у клиента

CREATE INDEX idx_documents_client_type
  ON documents (client_id, documen_type_id); -отчет по типам операции

CREATE INDEX idx_documents_client_created
  ON documents (client_id, created_at); - список документов клиента за период/по времени

  **products**

CREATE UNIQUE INDEX ux_products_client_sku
  ON products (client_id, sku) - поиск по SKU 

CREATE UNIQUE INDEX ux_products_client_gtin
  ON products (client_id, gtin) - поиск по GTIN

## 5 и 6 Ограничения
1. Нельзя в истории чтобы одна запись  ссылалась и на код и на упаковку

 ```sql CHECK (
    (marking_code_id IS NOT NULL AND child_package_id IS NULL) OR
    (marking_code_id IS NULL AND child_package_id IS NOT NULL)  );
  ```
2. Запрет самовложений

```sql
CHECK (child_package_id IS NULL OR child_package_id <> parent_package_id);
```

3. Нельзя чтобы время завершения документа было меньше, чем время создания
```sql
CHECK (copmleted_ad IS NULL OR copmleted_ad >= created_at);
```

4. один код не может быть в двух упаковках одновременно
```sql
CREATE UNIQUE INDEX IF NOT EXISTS ux_ph_active_marking_code
  ON packages_history (client_id, marking_code_id)
  WHERE removed_at IS NULL AND marking_code_id IS NOT NULL;
```

5. один короб не может быть в двух упаковках(палете или еще одном коробе) одновременно
```sql
CREATE UNIQUE INDEX IF NOT EXISTS ux_ph_active_child_package
  ON packages_history (client_id, child_package_id)
  WHERE removed_at IS NULL AND child_package_id IS NOT NULL;
```


