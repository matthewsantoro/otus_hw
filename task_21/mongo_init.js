use otus_mongo;

db.products.drop();
db.products.insertMany([
  {
    sku: "SKU-1001",
    name: "ALFA Термобокс 20л",
    category: "Тара",
    price: 5200,
    qty: 15,
    tags: ["cold", "medical"],
    manufacturer: "ALFA",
    updatedAt: new Date()
  },
  {
    sku: "SKU-1002",
    name: "BETA Контейнер 40л",
    category: "Тара",
    price: 7400,
    qty: 8,
    tags: ["cold", "food"],
    manufacturer: "BETA",
    updatedAt: new Date()
  },
  {
    sku: "SKU-1003",
    name: "Гелевый хладоэлемент",
    category: "Расходники",
    price: 350,
    qty: 120,
    tags: ["cold"],
    manufacturer: "ALFA",
    updatedAt: new Date()
  }
]);

db.products.createIndex({ sku: 1 }, { unique: true });
db.products.createIndex({ category: 1, price: -1 });
db.products.createIndex({ name: "text", tags: "text" });
