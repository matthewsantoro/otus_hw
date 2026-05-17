# Task 21 - MongoDB

## Что сделано

1. Поднял MongoDB в Docker.
2. Заполнил тестовыми данными.
3. Выполнил выборки и обновления.
4. Добавил индексы и пример проверки плана запроса.

## Запуск

```bash
docker run -d --name otus-mongo -p 27017:27017 mongo:7
mongosh "mongodb://localhost:27017" < results/otus_hw/task_21/mongo_init.js
```

## Примеры запросов на выборку

```javascript
use otus_mongo;


 db.products.find(
   { category: "Тара" },
   { _id: 0, sku: 1, name: 1, price: 1 }
 ).sort({ price: -1 });


 db.products.find(
   { $text: { $search: "medical" } },
   { _id: 0, sku: 1, name: 1, score: { $meta: "textScore" } }
 ).sort({ score: { $meta: "textScore" } });
```

## Примеры обновлений

```javascript

 db.products.updateOne(
   { sku: "SKU-1001" },
   { $inc: { qty: -2 }, $set: { updatedAt: new Date() } }
 );

 db.products.updateMany(
   { category: "Тара" },
   { $set: { warehouseZone: "A1", updatedAt: new Date() } }
 );
```

## Индексы и производительность

```javascript
db.products.getIndexes();
db.products.find({ category: "Тара" }).sort({ price: -1 }).explain("executionStats");
```



