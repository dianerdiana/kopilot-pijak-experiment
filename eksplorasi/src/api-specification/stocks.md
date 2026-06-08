# API Specification - Stocks

Dokumen ini menjelaskan API untuk halaman manajemen stock berdasarkan requirement di [`api-requirement/manajemen-stock.md`](../api-requirement/manajemen-stock.md), schema Prisma pada model `RawMaterial`, `Stock`, `DailyStockSnapshot`, `ProductIngredient`, `Product`, dan `Prediction`, serta output analitik demand forecast yang dipakai untuk menghitung kebutuhan stok 7 hari.

## 1. Ruang Lingkup

API ini mencakup:

- ringkasan kartu stock
- prioritas stock tertinggi
- ringkasan status stock
- tabel status dan prediksi stock
- perhitungan coverage stock berdasarkan kebutuhan 7 hari
- trigger internal untuk refresh perhitungan stock berdasarkan forecast terbaru

## 2. Asumsi

Beberapa hal di bawah ini diasumsikan agar spesifikasi bisa langsung dipakai:

- satuan utama stock disimpan pada model `RawMaterial.unit`
- kebutuhan stock dihitung dari forecast demand produk 7 hari
- kebutuhan bahan baku per produk diambil dari `ProductIngredient.quantityPerUnit`
- stock yang ditampilkan adalah stock bahan baku, bukan stock produk jadi
- `coverage` adalah ketahanan stock dalam hari berdasarkan kebutuhan harian rata-rata
- `prediksi butuh 7 hari` berarti minimum stock yang dibutuhkan untuk menutup forecast 7 hari
- `selisih` bernilai positif jika stock berlebih dan negatif jika stock kurang
- status stock mengikuti enum Prisma dan frontend menerima nilai `@map`-nya:
  - `StockStatus.Sufficient` -> `aman`
  - `StockStatus.Restock` -> `restock`
  - `StockStatus.Low` -> `alert`
  - `StockStatus.OutOfStock` -> `habis`
- status ringkasan dashboard menggunakan label bisnis:
  - `Item Kritis`
  - `Perlu Restock`
  - `Stock Aman`
- prioritas stock tertinggi ditampilkan berdasarkan kebutuhan / risiko tertinggi terhadap stock out
- daftar tabel mengikuti default pagination
- jika data forecast belum tersedia, backend boleh menggunakan estimasi berbasis histori terakhir atau mengembalikan state empty sesuai kebijakan implementasi

## 3. Base URL

Semua endpoint menggunakan prefix berikut:

```text
/api
```

## 4. Model Data

### 4.1 Stock Overview

Ringkasan utama halaman manajemen stock:

```json
{
  "criticalItems": 12,
  "restockItems": 28,
  "safeItems": 64,
  "averageCoverageDays": 3.8
}
```

### 4.2 Priority Stock Item

Item untuk horizontal bar chart prioritas stock tertinggi:

```json
{
  "materialId": "MAT-0001",
  "name": "Espresso Beans",
  "currentStock": 24,
  "coverageDays": 0.8,
  "requiredStock7d": 60,
  "priorityScore": 92
}
```

### 4.3 Stock Status Breakdown Item

Item untuk donut chart status stock:

```json
{
  "status": "aman",
  "label": "Stock Aman",
  "count": 64,
  "percentage": 61.5
}
```

### 4.4 Stock Table Item

Item untuk tabel status dan prediksi stock:

```json
{
  "materialId": "MAT-0001",
  "name": "Espresso Beans",
  "currentStock": 24,
  "requiredStock7d": 60,
  "coverageDays": 0.8,
  "difference": -36,
  "status": "alert"
}
```

### 4.5 Raw Material Detail

Representasi dasar bahan baku:

```json
{
  "id": "5a7d2f49-2f2f-4d50-9e9f-b2d3c8a8d111",
  "materialId": "MAT-0001",
  "name": "Espresso Beans",
  "unit": "gr",
  "pricePerUnit": 250,
  "supplier": "roastery_lokal",
  "unOpenedShelfLifeDays": 90,
  "openedShelfLifeDays": 30,
  "storageType": "kering",
  "reorderPoint": 20,
  "createdAt": "2026-06-08T10:00:00.000Z",
  "updatedAt": "2026-06-08T10:00:00.000Z"
}
```

## 5. Common Response Format

### 5.1 Success

```json
{
  "success": true,
  "message": "OK",
  "data": {}
}
```

### 5.2 Error

```json
{
  "success": false,
  "message": "Validation failed",
  "errorCode": "VALIDATION_ERROR",
  "errors": []
}
```

## 6. API - Manajemen Stock

### 6.1 Get Stock Dashboard Overview

`GET /api/stocks/overview`

Mengambil ringkasan utama untuk dashboard manajemen stock.

#### Query Params

- `forecastDays`
  - optional
  - default: `7`
- `includeInactiveProducts`
  - optional
  - default: `false`

#### Behavior

- menghitung `Item Kritis` dari stock dengan status `habis` atau coverage sangat rendah
- menghitung `Perlu Restock` dari stock dengan status `restock` atau `alert`
- menghitung `Stock Aman` dari stock dengan status `aman`
- menghitung `averageCoverageDays` dari seluruh bahan baku yang aktif

#### Response 200

```json
{
  "success": true,
  "message": "Stock overview fetched successfully",
  "data": {
    "criticalItems": 12,
    "restockItems": 28,
    "safeItems": 64,
    "averageCoverageDays": 3.8
  }
}
```

### 6.2 Get Priority Stock

`GET /api/stocks/priority`

Mengambil prioritas stock tertinggi untuk bar chart horizontal.

#### Query Params

- `forecastDays`
  - optional
  - default: `7`
- `limit`
  - optional
  - default: `10`
- `sortBy`
  - optional
  - default: `priorityScore`
  - pilihan:
    - `priorityScore`
    - `coverageDays`
    - `requiredStock7d`

#### Behavior

- prioritas dihitung berdasarkan kebutuhan stock 7 hari terhadap stock tersedia
- item dengan coverage paling rendah memiliki prioritas lebih tinggi
- apabila diperlukan, nama produk terkait bisa dipakai untuk konteks visualisasi, tetapi sumber utama tetap bahan baku

#### Response 200

```json
{
  "success": true,
  "message": "Priority stock fetched successfully",
  "data": {
    "forecastDays": 7,
    "items": [
      {
        "materialId": "MAT-0001",
        "name": "Espresso Beans",
        "currentStock": 24,
        "coverageDays": 0.8,
        "requiredStock7d": 60,
        "priorityScore": 92
      }
    ]
  }
}
```

### 6.3 Get Stock Status Breakdown

`GET /api/stocks/status-breakdown`

Mengambil ringkasan status stock untuk donut chart.

#### Query Params

- `forecastDays`
  - optional
  - default: `7`

#### Behavior

- menghitung jumlah bahan baku per `StockStatus`
- persentase dihitung dari total seluruh bahan baku yang masuk scope
- status mengikuti enum Prisma yang sudah di-map ke label frontend

#### Response 200

```json
{
  "success": true,
  "message": "Stock status breakdown fetched successfully",
  "data": {
    "items": [
      {
        "status": "aman",
        "label": "Stock Aman",
        "count": 64,
        "percentage": 61.5
      },
      {
        "status": "restock",
        "label": "Perlu Restock",
        "count": 28,
        "percentage": 26.9
      },
      {
        "status": "alert",
        "label": "Item Kritis",
        "count": 10,
        "percentage": 9.6
      },
      {
        "status": "habis",
        "label": "Item Kritis",
        "count": 2,
        "percentage": 1.9
      }
    ]
  }
}
```

### 6.4 Get Stock Status Table

`GET /api/stocks/table`

Mengambil tabel status dan prediksi stock bahan baku.

#### Query Params

- `page`
  - optional
  - default: `1`
- `limit`
  - optional
  - default: `10`
- `search`
  - optional
  - pencarian berdasarkan nama bahan baku atau `materialId`
- `status`
  - optional
  - filter berdasarkan status stock:
    - `aman`
    - `restock`
    - `alert`
    - `habis`
- `forecastDays`
  - optional
  - default: `7`

#### Behavior

- `currentStock` diambil dari `Stock.currentQuantity`
- `requiredStock7d` dihitung dari forecast demand 7 hari dan resep produk
- `coverageDays` dihitung dari `currentStock / kebutuhan harian rata-rata`
- `difference` dihitung dari `currentStock - requiredStock7d`
- status diturunkan dari coverage dan perbandingan stock terhadap kebutuhan

#### Response 200

```json
{
  "success": true,
  "message": "Stock table fetched successfully",
  "data": {
    "items": [
      {
        "materialId": "MAT-0001",
        "name": "Espresso Beans",
        "currentStock": 24,
        "requiredStock7d": 60,
        "coverageDays": 0.8,
        "difference": -36,
        "status": "alert"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "totalItems": 1,
      "totalPages": 1
    }
  }
}
```

### 6.5 Get Stock Detail by Material ID

`GET /api/stocks/:materialId`

Mengambil detail stock satu bahan baku.

#### Path Params

- `materialId`
  - wajib
  - kode bisnis bahan baku, bukan UUID internal

#### Behavior

- mengembalikan detail bahan baku
- mengembalikan stock aktual dan kebutuhan forecast
- mengembalikan status stock dan coverage

#### Response 200

```json
{
  "success": true,
  "message": "Stock detail fetched successfully",
  "data": {
    "material": {
      "id": "5a7d2f49-2f2f-4d50-9e9f-b2d3c8a8d111",
      "materialId": "MAT-0001",
      "name": "Espresso Beans",
      "unit": "gr",
      "pricePerUnit": 250,
      "supplier": "roastery_lokal",
      "unOpenedShelfLifeDays": 90,
      "openedShelfLifeDays": 30,
      "storageType": "kering",
      "reorderPoint": 20,
      "createdAt": "2026-06-08T10:00:00.000Z",
      "updatedAt": "2026-06-08T10:00:00.000Z"
    },
    "stock": {
      "currentStock": 24,
      "minimumQuantity": 20,
      "resilienceDays": 0.8,
      "status": "alert",
      "lastUpdated": "2026-06-08T10:00:00.000Z"
    },
    "forecast": {
      "forecastDays": 7,
      "requiredStock7d": 60,
      "difference": -36
    }
  }
}
```

### 6.6 Refresh Stock Forecast Summary

`POST /api/stocks/refresh-summary`

Endpoint internal untuk memperbarui ringkasan stock berdasarkan forecast demand terbaru.

#### Request Body

```json
{
  "forecastDays": 7
}
```

#### Behavior

- mengambil forecast demand terbaru dari `Prediction`
- menghitung kebutuhan stock 7 hari per bahan baku
- memperbarui ringkasan yang dipakai dashboard
- jika diperlukan, `Stock.minimumQuantity`, `Stock.resilienceDays`, dan `Stock.status` bisa disinkronkan oleh service internal

#### Response 201

```json
{
  "success": true,
  "message": "Stock summary refreshed successfully",
  "data": {
    "forecastDays": 7,
    "generatedAt": "2026-06-08T10:00:00.000Z",
    "summary": {
      "criticalItems": 12,
      "restockItems": 28,
      "safeItems": 64,
      "averageCoverageDays": 3.8
    }
  }
}
```

## 7. Error Codes

### 7.1 Common Error Codes

- `VALIDATION_ERROR`
- `UNAUTHORIZED`
- `FORBIDDEN`
- `NOT_FOUND`
- `CONFLICT`
- `INTERNAL_SERVER_ERROR`

### 7.2 Stock-Specific Error Codes

- `STOCK_ANALYTICS_FAILED`
- `STOCK_FORECAST_NOT_FOUND`
- `STOCK_FORECAST_FAILED`
- `RAW_MATERIAL_NOT_FOUND`

### 7.3 Recommended HTTP Status Codes

- `200 OK`
- `201 Created`
- `400 Bad Request`
- `401 Unauthorized`
- `403 Forbidden`
- `404 Not Found`
- `409 Conflict`
- `500 Internal Server Error`

## 8. Validation Rules Summary

### 8.1 Get Stock Dashboard Overview

- `forecastDays` opsional, default `7`
- `includeInactiveProducts` opsional, default `false`

### 8.2 Get Priority Stock

- `forecastDays` opsional, default `7`
- `limit` opsional, default `10`
- `sortBy` opsional, harus salah satu:
  - `priorityScore`
  - `coverageDays`
  - `requiredStock7d`

### 8.3 Get Stock Status Breakdown

- `forecastDays` opsional, default `7`

### 8.4 Get Stock Status Table

- `page` opsional, default `1`
- `limit` opsional, default `10`
- `search` opsional
- `status` opsional, harus salah satu:
  - `aman`
  - `restock`
  - `alert`
  - `habis`
- `forecastDays` opsional, default `7`

### 8.5 Get Stock Detail by Material ID

- `materialId` wajib

### 8.6 Refresh Stock Forecast Summary

- `forecastDays` opsional, default `7`

## 9. Notes Implementasi

- perhitungan kebutuhan stock sebaiknya berbasis forecast demand terbaru agar dashboard tetap relevan
- `coverageDays` lebih tepat disimpan sebagai angka desimal, lalu frontend bisa membulatkan sesuai kebutuhan tampilan
- jika stock aktual sudah habis, `difference` bernilai negatif dan status sebaiknya `habis`
- tabel stock lebih baik menggunakan data ringkasan ter-normalisasi supaya frontend tidak perlu menghitung ulang resep produk
- jika frontend membutuhkan performa lebih ringan, endpoint overview boleh dijadikan sumber utama untuk kartu, sementara endpoint table dipanggil terpisah
- status `StockStatus` tetap menjadi sumber kebenaran utama untuk klasifikasi, sedangkan label kartu adalah turunan bisnis
