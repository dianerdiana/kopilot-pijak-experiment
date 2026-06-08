# API Specification - Products

Dokumen ini menjelaskan API untuk analitik produk berdasarkan requirement di [`api-requirement/produk.md`](../api-requirement/produk.md), schema Prisma pada model `Product` dan `Prediction`, serta format response dari model `DemandForecast`.

## 1. Ruang Lingkup

API ini mencakup:

- ringkasan analitik produk untuk dashboard
- data demand forecast per kategori
- ranking kategori berdasarkan demand dan potensi omzet
- insight produk untuk kartu ringkasan
- daftar 100 produk teratas berdasarkan confidence forecast
- trigger internal untuk generate demand forecast

## 2. Asumsi

Beberapa hal di bawah ini diasumsikan agar spesifikasi bisa langsung dipakai:

- sistem hanya menangani 1 store
- data analitik produk utama diambil dari hasil `Prediction` dengan tipe `DemandForecast`
- jika hasil forecast belum tersedia, backend boleh mengambil data fallback dari database operasional untuk nilai dasar seperti harga dan status produk
- response frontend memakai istilah yang mudah dibaca dan konsisten dengan kebutuhan UI, sementara data internal tetap mengikuti camelCase
- kategori produk mengikuti enum Prisma dan frontend menerima nilai `@map`-nya:
  - `Coffee` -> `kopi`
  - `NonCoffee` -> `non_kopi`
  - `Snack` -> `makanan_ringan`
- status produk pada tabel high-confidence product bersifat turunan, bukan field langsung di tabel `Product`
  - `Hot`
  - `Normal`
  - `Slow`
- potensi omzet dihitung dari `predictedQuantity * price`
- data `soldQuantity` diambil dari agregasi `TransactionDetail.quantity`
- daftar produk teratas yang ditampilkan di dashboard dibatasi sampai 100 item
- periode forecast default adalah 7 hari ke depan sesuai model yang sudah disiapkan

## 3. Base URL

Semua endpoint menggunakan prefix berikut:

```text
/api
```

## 4. Model Data

### 4.1 Product

Representasi dasar produk dari database:

```json
{
  "id": "9b9b8e71-3c30-4b7f-a7a9-3e3c4c1c6b11",
  "productId": "PRD-0001",
  "name": "Iced Hazelnut Macchiato Large",
  "category": "kopi",
  "variant": "dingin",
  "size": "large",
  "price": 35000,
  "isActive": true,
  "createdAt": "2026-06-08T10:00:00.000Z",
  "updatedAt": "2026-06-08T10:00:00.000Z"
}
```

### 4.2 Product Forecast Row

Representasi item pada daftar 100 produk teratas:

```json
{
  "productId": "PRD-0001",
  "name": "Iced Hazelnut Macchiato Large",
  "category": "kopi",
  "price": 35000,
  "lowerBoundDemandForecast": 60,
  "demandForecast": 74,
  "upperBoundDemandForecast": 88,
  "revenuePotential7d": 2590000,
  "soldQuantity": 145,
  "status": "Hot"
}
```

### 4.3 Product Analytics Summary

Ringkasan utama dashboard produk:

```json
{
  "totalActiveProducts": 48,
  "totalActiveCategories": 3,
  "forecastVolume": 2118,
  "totalForecastSku": 128,
  "revenuePotential": 79100000,
  "topProduct": {
    "productId": "PRD-0001",
    "name": "Iced Hazelnut Macchiato Large",
    "category": "kopi",
    "demandForecast": 74,
    "revenuePotential7d": 2590000
  }
}
```

### 4.4 Category Forecast Item

Item agregasi forecast per kategori:

```json
{
  "category": "kopi",
  "categoryLabel": "Coffee",
  "unitsSold": 2118,
  "revenuePotential7d": 79100000,
  "productCount": 18
}
```

### 4.5 Insight Item

Insight produk yang ditampilkan sebagai card:

```json
{
  "type": "top_category",
  "title": "Kategori Terkuat",
  "message": "Coffee mendominasi demand dengan 2.118 unit dan potensi omzet Rp 79,1 jt dalam 7 hari ke depan."
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

## 6. API - Analitik Produk

### 6.1 Get Product Analytics Overview

`GET /api/products/analytics`

Mengambil data ringkasan untuk kartu dashboard produk, insight, dan agregasi kategori.

#### Query Params

- `forecastDays`
  - optional
  - default: `7`
  - nilai yang disarankan: `7`
- `includeInactive`
  - optional
  - default: `false`
  - jika `true`, produk nonaktif tetap ikut dihitung pada beberapa agregasi

#### Behavior

- mengambil data forecast terbaru dengan tipe `DemandForecast`
- jika ada lebih dari satu forecast, gunakan data terbaru berdasarkan `generatedAt`
- menghitung ringkasan berdasarkan response forecast dan data `Product`
- `totalActiveProducts` dihitung dari `Product.isActive = true`
- `totalActiveCategories` dihitung dari kategori unik produk aktif
- `forecastVolume` dihitung dari total `predicted_quantity_7d`
- `revenuePotential` dihitung dari total `predicted_quantity_7d * price`
- `topProduct` diambil dari produk dengan `predicted_quantity_7d` terbesar

#### Response 200

```json
{
  "success": true,
  "message": "Product analytics fetched successfully",
  "data": {
    "summary": {
      "totalActiveProducts": 48,
      "totalActiveCategories": 3,
      "forecastVolume": 2118,
      "totalForecastSku": 128,
      "revenuePotential": 79100000,
      "topProduct": {
        "productId": "PRD-0001",
        "name": "Iced Hazelnut Macchiato Large",
        "category": "kopi",
        "demandForecast": 74,
        "revenuePotential7d": 2590000
      }
    },
    "categoryForecast": [
      {
        "category": "kopi",
        "categoryLabel": "Coffee",
        "unitsSold": 2118,
        "revenuePotential7d": 79100000,
        "productCount": 18
      }
    ],
    "insights": [
      {
        "type": "top_category",
        "title": "Kategori Terkuat",
        "message": "Coffee mendominasi demand dengan 2.118 unit dan potensi omzet Rp 79,1 jt dalam 7 hari ke depan."
      }
    ]
  }
}
```

### 6.2 Get Demand Forecast by Category

`GET /api/products/demand-forecast`

Mengambil data forecast untuk ditampilkan sebagai bar chart demand forecast per kategori.

#### Query Params

- `forecastDays`
  - optional
  - default: `7`

#### Behavior

- mengambil forecast terbaru tipe `DemandForecast`
- mengelompokkan total demand per kategori
- kategori yang tidak memiliki produk aktif tetap boleh muncul jika dibutuhkan oleh UI, tetapi default-nya hanya kategori yang punya data

#### Response 200

```json
{
  "success": true,
  "message": "Demand forecast fetched successfully",
  "forecastDays": 7,
  "data": [
    {
      "category": "kopi",
      "categoryLabel": "Coffee",
      "unitsSold": 2118
    },
    {
      "category": "non_kopi",
      "categoryLabel": "Non Coffee",
      "unitsSold": 540
    }
  ]
}
```

### 6.3 Get Category Ranking

`GET /api/products/category-ranking`

Mengambil ranking kategori untuk ditampilkan sebagai progress bar.

#### Query Params

- `forecastDays`
  - optional
  - default: `7`

#### Behavior

- ranking dihitung dari `unitsSold` tertinggi ke terendah
- jika nilai sama, urutkan berdasarkan `revenuePotential7d` terbesar
- hasil juga menyertakan jumlah produk per kategori

#### Response 200

```json
{
  "success": true,
  "message": "Category ranking fetched successfully",
  "data": [
    {
      "rank": 1,
      "category": "kopi",
      "categoryLabel": "Coffee",
      "unitsSold": 2118,
      "revenuePotential7d": 79100000,
      "productCount": 18,
      "progressPct": 100
    }
  ]
}
```

### 6.4 Get Product Insights

`GET /api/products/insights`

Mengambil insight berbentuk card.

#### Query Params

- `forecastDays`
  - optional
  - default: `7`

#### Response 200

```json
{
  "success": true,
  "message": "Product insights fetched successfully",
  "data": [
    {
      "type": "top_category",
      "title": "Kategori Terkuat",
      "message": "Coffee mendominasi demand dengan 2.118 unit dan potensi omzet Rp 79,1 jt dalam 7 hari ke depan."
    },
    {
      "type": "top_product",
      "title": "Produk Unggulan",
      "message": "Iced Hazelnut Macchiato Large adalah produk dengan forecast tertinggi sebesar 74 unit, potensi omzet Rp 2.590.000."
    },
    {
      "type": "hot_product",
      "title": "Produk Hot",
      "message": "Terdapat 35 produk yang penjualannya jauh di atas rata-rata produk lainya. Pastikan stok bahan baku untuk menu-menu favorit ini selalu aman agar tidak kehilangan potensi transaksi."
    }
  ]
}
```

### 6.5 Get Top 100 High-Confidence Products

`GET /api/products/top-products`

Mengambil daftar 100 produk teratas berdasarkan confidence forecast.

#### Query Params

- `limit`
  - optional
  - default: `100`
  - maksimum: `100`
- `forecastDays`
  - optional
  - default: `7`
- `search`
  - optional
  - pencarian berdasarkan nama produk atau `productId`
- `category`
  - optional
  - filter berdasarkan kategori produk
- `status`
  - optional
  - filter berdasarkan status frontend:
    - `Hot`
    - `Normal`
    - `Slow`

#### Behavior

- menggunakan forecast terbaru tipe `DemandForecast`
- hasil diurutkan berdasarkan `rank` dari response model ML
- `status` diturunkan dari kombinasi demand forecast, sold quantity historis, dan threshold bisnis
- `soldQuantity` diambil dari agregasi `TransactionDetail.quantity`

#### Response 200

```json
{
  "success": true,
  "message": "Top products fetched successfully",
  "data": [
    {
      "productId": "PRD-0001",
      "name": "Iced Hazelnut Macchiato Large",
      "category": "kopi",
      "price": 35000,
      "lowerBoundDemandForecast": 60,
      "demandForecast": 74,
      "upperBoundDemandForecast": 88,
      "revenuePotential7d": 2590000,
      "soldQuantity": 145,
      "status": "Hot"
    }
  ],
  "pagination": {
    "limit": 100,
    "totalItems": 100
  }
}
```

### 6.6 Trigger Demand Forecast

`POST /api/products/demand-forecast/generate`

Endpoint internal untuk menjalankan proses generate forecast produk.

#### Request Body

```json
{
  "cutoffDate": "2026-06-07",
  "forecastDays": 7,
  "stockBufferPct": 0,
  "businessMinimum": 0
}
```

#### Validasi

- `cutoffDate`
  - wajib
  - format tanggal valid
- `forecastDays`
  - opsional
  - default `7`
  - disarankan hanya `7` untuk kebutuhan dashboard saat ini
- `stockBufferPct`
  - opsional
  - default `0`
- `businessMinimum`
  - opsional
  - default `0`

#### Behavior

- mengambil data produk dan histori transaksi
- membentuk payload request ke model ML `DemandForecast`
- menyimpan response ke tabel `Prediction`
- menormalisasi data untuk kebutuhan frontend
- jika forecast untuk `cutoffDate` yang sama sudah ada, backend boleh melakukan replacement atau menolak duplikasi sesuai kebijakan implementasi

#### Response 201

```json
{
  "success": true,
  "message": "Demand forecast generated successfully",
  "data": {
    "requestId": "store_demand_2026-06-07",
    "predictionId": "550e8400-e29b-41d4-a716-446655440000",
    "cutoffDate": "2026-06-07",
    "forecastDays": 7,
    "modelVersion": "XGBoost Original",
    "generatedAt": "2026-06-07T23:00:00.000Z",
    "summary": {
      "totalProducts": 128,
      "totalForecastVolume": 2118,
      "totalRevenuePotential": 79100000
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

### 7.2 Product-Specific Error Codes

- `DEMAND_FORECAST_NOT_FOUND`
- `DEMAND_FORECAST_FAILED`
- `PRODUCT_ANALYTICS_FAILED`

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

### 8.1 Get Product Analytics Overview

- `forecastDays` opsional, default `7`
- `includeInactive` opsional, default `false`

### 8.2 Get Demand Forecast by Category

- `forecastDays` opsional, default `7`

### 8.3 Get Category Ranking

- `forecastDays` opsional, default `7`

### 8.4 Get Product Insights

- `forecastDays` opsional, default `7`

### 8.5 Get Top 100 High-Confidence Products

- `limit` opsional, default `100`, maksimum `100`
- `forecastDays` opsional, default `7`
- `search` opsional
- `category` opsional
- `status` opsional, harus salah satu dari:
  - `Hot`
  - `Normal`
  - `Slow`

### 8.6 Trigger Demand Forecast

- `cutoffDate` wajib, format tanggal valid
- `forecastDays` opsional, default `7`
- `stockBufferPct` opsional
- `businessMinimum` opsional

## 9. Notes Implementasi

- response forecast mentah dari ML sebaiknya disimpan utuh pada `Prediction.responseData`
- ringkasan yang sering dipakai frontend sebaiknya dinormalisasi pada `Prediction.normalizedSummary`
- endpoint analytics sebaiknya membaca forecast terbaru agar dashboard selalu konsisten
- jika data forecast belum tersedia, backend dapat menampilkan state empty daripada error fatal, selama requirement UI tetap terpenuhi
- mapping kategori, status, dan satuan omzet harus konsisten antara service, response API, dan UI
