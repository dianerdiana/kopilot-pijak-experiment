# API Specification - Sales

Dokumen ini menjelaskan API untuk halaman penjualan / analitik penjualan berdasarkan requirement di [`api-requirement/penjualan.md`](../api-requirement/penjualan.md), schema Prisma pada model `Order`, `TransactionDetail`, `Product`, dan `Prediction`, serta format response dari model `RevenueForecast` dan `TrafficForecast`.

## 1. Ruang Lingkup

API ini mencakup:

- ringkasan card penjualan
- tren pendapatan 30 hari terakhir
- produk terlaris
- traffic hour
- kontribusi kategori
- riwayat transaksi
- trigger internal untuk generate revenue forecast dan traffic forecast

## 2. Asumsi

Beberapa hal di bawah ini diasumsikan agar spesifikasi bisa langsung dipakai:

- semua metrik utama sales dihitung dari data transaksi aktual pada `Order` dan `TransactionDetail`
- data forecast dipakai sebagai pelengkap untuk dashboard, bukan sebagai sumber utama transaksi aktual
- omzet 30 hari memakai perbandingan terhadap 30 hari sebelumnya
- periode default untuk dashboard adalah 30 hari
- traffic hour pada halaman sales memakai hasil forecast traffic 18 open hours ke depan, dengan fallback ke data aktual bila dibutuhkan
- kategori produk mengikuti enum Prisma dan frontend menerima nilai `@map`-nya:
  - `Coffee` -> `kopi`
  - `NonCoffee` -> `non_kopi`
  - `Snack` -> `makanan_ringan`
- status traffic mengikuti nilai turunan yang sesuai kebutuhan UI:
  - `Low`
  - `Normal`
  - `High`
- format produk pada riwayat transaksi mengikuti pola `"<qty>x <nama_produk>"`
- `totalTransactions` dihitung dari jumlah `Order`
- `totalItemsSold` dihitung dari total `TransactionDetail.quantity`
- `averagePurchase` dihitung dari total omzet dibagi total transaksi

## 3. Base URL

Semua endpoint menggunakan prefix berikut:

```text
/api
```

## 4. Model Data

### 4.1 Sales Overview

Ringkasan utama dashboard penjualan:

```json
{
  "currentPeriodRevenue": 125000000,
  "previousPeriodRevenue": 98000000,
  "revenueChangePct": 27.55,
  "totalTransactions": 4120,
  "totalItemsSold": 8650,
  "averagePurchase": 30388,
  "topSellingProduct": {
    "productId": "PRD-0001",
    "name": "Iced Hazelnut Macchiato Large",
    "totalSold": 245
  }
}
```

### 4.2 Revenue Trend Item

Item untuk grafik tren pendapatan 30 hari:

```json
{
  "date": "2026-06-01",
  "revenue": 2500000,
  "orderCount": 120,
  "itemsSold": 260
}
```

### 4.3 Top Selling Product Item

Item untuk diagram batang produk terlaris:

```json
{
  "productId": "PRD-0001",
  "name": "Iced Hazelnut Macchiato Large",
  "totalSold": 245,
  "revenue": 8575000
}
```

### 4.4 Traffic Hour Item

Item untuk traffic hour:

```json
{
  "predictionTime": "2026-06-08T11:00:00Z",
  "predictionHour": 11,
  "forecastOpenSlot": 1,
  "predictedOrderCount": 45,
  "lowerBound": 38,
  "upperBound": 53,
  "trafficLevel": "High"
}
```

### 4.5 Category Contribution Item

Item untuk donut chart kontribusi kategori:

```json
{
  "category": "kopi",
  "categoryLabel": "Coffee",
  "revenue": 62000000,
  "percentage": 49.6
}
```

### 4.6 Transaction History Item

Item untuk tabel riwayat transaksi:

```json
{
  "orderId": "ORD-0001",
  "orderTime": "2026-06-08T10:15:00.000Z",
  "productsText": "2x Iced Hazelnut Macchiato Large, 1x Chocolate Croissant",
  "items": [
    {
      "productId": "PRD-0001",
      "name": "Iced Hazelnut Macchiato Large",
      "quantity": 2
    }
  ],
  "totalPrice": 105000
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

## 6. API - Analitik Penjualan

### 6.1 Get Sales Dashboard Overview

`GET /api/sales/overview`

Mengambil ringkasan utama untuk dashboard penjualan.

#### Query Params

- `days`
  - optional
  - default: `30`
  - nilai yang disarankan: `30`

#### Behavior

- menghitung omzet 30 hari terakhir
- membandingkan omzet 30 hari terakhir dengan 30 hari sebelumnya
- menghitung total transaksi dan total item terjual
- menghitung average purchase
- menyertakan produk terlaris pada periode tersebut

#### Response 200

```json
{
  "success": true,
  "message": "Sales overview fetched successfully",
  "data": {
    "currentPeriodRevenue": 125000000,
    "previousPeriodRevenue": 98000000,
    "revenueChangePct": 27.55,
    "totalTransactions": 4120,
    "totalItemsSold": 8650,
    "averagePurchase": 30388,
    "topSellingProduct": {
      "productId": "PRD-0001",
      "name": "Iced Hazelnut Macchiato Large",
      "totalSold": 245
    }
  }
}
```

### 6.2 Get Revenue Trend

`GET /api/sales/revenue-trend`

Mengambil data tren pendapatan harian untuk 30 hari terakhir.

#### Query Params

- `days`
  - optional
  - default: `30`

#### Behavior

- data dibentuk dari agregasi `TransactionDetail.totalPrice` per hari
- grafik frontend dapat menampilkan sumbu x sebagai tanggal dan sumbu y sebagai omzet
- titik revenue tertinggi boleh di-highlight oleh frontend

#### Response 200

```json
{
  "success": true,
  "message": "Revenue trend fetched successfully",
  "data": {
    "days": 30,
    "items": [
      {
        "date": "2026-06-01",
        "revenue": 2500000,
        "orderCount": 120,
        "itemsSold": 260
      }
    ]
  }
}
```

### 6.3 Get Top Selling Products

`GET /api/sales/top-products`

Mengambil daftar produk terlaris untuk diagram batang.

#### Query Params

- `days`
  - optional
  - default: `30`
- `limit`
  - optional
  - default: `10`
  - nilai yang disarankan: `10`
- `sortBy`
  - optional
  - default: `totalSold`
  - pilihan:
    - `totalSold`
    - `revenue`

#### Behavior

- produk diurutkan berdasarkan jumlah terjual atau omzet
- data dihitung dari agregasi `TransactionDetail.quantity`
- jika `sortBy = revenue`, pengurutan memakai total omzet produk pada periode tersebut

#### Response 200

```json
{
  "success": true,
  "message": "Top selling products fetched successfully",
  "data": {
    "days": 30,
    "items": [
      {
        "productId": "PRD-0001",
        "name": "Iced Hazelnut Macchiato Large",
        "totalSold": 245,
        "revenue": 8575000
      }
    ]
  }
}
```

### 6.4 Get Traffic Hour

`GET /api/sales/traffic-hour`

Mengambil data traffic hour untuk kebutuhan chart jam sibuk.

#### Query Params

- `source`
  - optional
  - default: `forecast`
  - pilihan:
    - `forecast`
    - `actual`
- `forecastOpenSlots`
  - optional
  - default: `18`

#### Behavior

- jika `source = forecast`, gunakan forecast dari `Prediction` dengan tipe `TrafficForecast`
- jika `source = actual`, gunakan agregasi order aktual per jam
- jika hasil forecast tersedia, response bisa menyertakan `peakWindow`
- data digunakan untuk visualisasi jam sibuk dan penanda puncak traffic

#### Response 200

```json
{
  "success": true,
  "message": "Traffic hour fetched successfully",
  "data": {
    "source": "forecast",
    "forecastOpenSlots": 18,
    "peakWindow": {
      "startTime": "2026-06-08T11:00:00Z",
      "endTime": "2026-06-08T13:00:00Z",
      "maxPredictedOrderCount": 45
    },
    "items": [
      {
        "predictionTime": "2026-06-08T11:00:00Z",
        "predictionHour": 11,
        "forecastOpenSlot": 1,
        "predictedOrderCount": 45,
        "lowerBound": 38,
        "upperBound": 53,
        "trafficLevel": "High"
      }
    ]
  }
}
```

### 6.5 Get Category Contribution

`GET /api/sales/category-contribution`

Mengambil kontribusi penjualan per kategori untuk donut chart.

#### Query Params

- `days`
  - optional
  - default: `30`

#### Behavior

- menghitung total omzet per kategori produk
- menghitung persentase kontribusi berdasarkan total omzet periode yang dipilih
- kategori mengikuti mapping enum Prisma

#### Response 200

```json
{
  "success": true,
  "message": "Category contribution fetched successfully",
  "data": {
    "items": [
      {
        "category": "kopi",
        "categoryLabel": "Coffee",
        "revenue": 62000000,
        "percentage": 49.6
      },
      {
        "category": "non_kopi",
        "categoryLabel": "Non Coffee",
        "revenue": 35000000,
        "percentage": 28
      }
    ]
  }
}
```

### 6.6 Get Transaction History

`GET /api/sales/transactions`

Mengambil riwayat transaksi untuk tabel.

#### Query Params

- `page`
  - optional
  - default: `1`
- `limit`
  - optional
  - default: `10`
- `search`
  - optional
  - pencarian berdasarkan `orderId`
- `startDate`
  - optional
  - filter tanggal awal
- `endDate`
  - optional
  - filter tanggal akhir

#### Behavior

- menampilkan order beserta ringkasan produk dalam format `"<qty>x <nama_produk>"`
- satu baris mewakili satu order
- `items` boleh dipakai frontend jika ingin render detail produk tanpa parsing string

#### Response 200

```json
{
  "success": true,
  "message": "Transaction history fetched successfully",
  "data": {
    "items": [
      {
        "orderId": "ORD-0001",
        "orderTime": "2026-06-08T10:15:00.000Z",
        "productsText": "2x Iced Hazelnut Macchiato Large, 1x Chocolate Croissant",
        "items": [
          {
            "productId": "PRD-0001",
            "name": "Iced Hazelnut Macchiato Large",
            "quantity": 2
          }
        ],
        "totalPrice": 105000
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

### 6.7 Trigger Revenue Forecast

`POST /api/revenue-forecast/forecast`

Endpoint internal untuk menjalankan proses generate revenue forecast 7 hari.

#### Request Body

```json
{
  "cutoffDate": "2026-06-07",
  "forecastDays": 7
}
```

#### Response 201

```json
{
  "success": true,
  "message": "Revenue forecast generated successfully",
  "data": {
    "requestId": "store_revenue_2026-06-07",
    "predictionId": "550e8400-e29b-41d4-a716-446655440000",
    "cutoffDate": "2026-06-07",
    "forecastDays": 7,
    "modelVersion": "XGBoost Revenue",
    "generatedAt": "2026-06-07T23:00:00.000Z",
    "summary": {
      "totalForecastRevenue": 17500000,
      "averageDailyRevenue": 2500000,
      "peakRevenueDate": "2026-06-10",
      "peakRevenueValue": 3200000
    }
  }
}
```

### 6.8 Trigger Traffic Forecast

`POST /api/traffic-forecast/forecast`

Endpoint internal untuk menjalankan proses generate traffic forecast 18 open hours.

#### Request Body

```json
{
  "cutoffTime": "2026-06-07T18:00:00Z"
}
```

#### Response 201

```json
{
  "success": true,
  "message": "Traffic forecast generated successfully",
  "data": {
    "requestId": "store_traffic_2026-06-07T18:00:00Z",
    "predictionId": "550e8400-e29b-41d4-a716-446655440000",
    "cutoffTime": "2026-06-07T18:00:00Z",
    "forecastOpenSlots": 18,
    "modelVersion": "XGBoost Traffic",
    "generatedAt": "2026-06-07T18:05:00.000Z",
    "peakWindow": {
      "startTime": "2026-06-08T11:00:00Z",
      "endTime": "2026-06-08T13:00:00Z",
      "maxPredictedOrderCount": 45
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

### 7.2 Sales-Specific Error Codes

- `REVENUE_FORECAST_NOT_FOUND`
- `REVENUE_FORECAST_FAILED`
- `TRAFFIC_FORECAST_NOT_FOUND`
- `TRAFFIC_FORECAST_FAILED`
- `SALES_ANALYTICS_FAILED`

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

### 8.1 Get Sales Dashboard Overview

- `days` opsional, default `30`

### 8.2 Get Revenue Trend

- `days` opsional, default `30`

### 8.3 Get Top Selling Products

- `days` opsional, default `30`
- `limit` opsional, default `10`
- `sortBy` opsional, harus salah satu:
  - `totalSold`
  - `revenue`

### 8.4 Get Traffic Hour

- `source` opsional, default `forecast`
- `forecastOpenSlots` opsional, default `18`

### 8.5 Get Category Contribution

- `days` opsional, default `30`

### 8.6 Get Transaction History

- `page` opsional, default `1`
- `limit` opsional, default `10`
- `search` opsional
- `startDate` opsional
- `endDate` opsional

### 8.7 Trigger Revenue Forecast

- `cutoffDate` wajib, format tanggal valid
- `forecastDays` opsional, default `7`

### 8.8 Trigger Traffic Forecast

- `cutoffTime` wajib, format datetime valid

## 9. Notes Implementasi

- omzet dan total item terjual sebaiknya dihitung dari transaksi yang sudah final
- jika frontend membutuhkan dashboard yang lebih ringan, endpoint `overview` boleh menggabungkan ringkasan utama tanpa memaksa fetch ke endpoint lain
- `productsText` pada riwayat transaksi disarankan tetap dikirim walaupun frontend juga menerima `items`
- traffic hour pada halaman sales bisa memakai forecast untuk view operasional, sedangkan mode actual berguna jika dibutuhkan perbandingan historis
- hasil forecast mentah sebaiknya tetap disimpan utuh pada `Prediction.responseData`
- `normalizedSummary` sebaiknya dipakai untuk query cepat dan response dashboard
