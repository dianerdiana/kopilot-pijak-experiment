# Prediksi Demand: Demand Forecast Products H+7

Dokumen ini menjelaskan:

- sumber data yang dipakai untuk request prediksi ML
- cara mengambil context dari database
- mapping data dari database ke format request ML
- cara menyimpan hasil prediksi
- mapping hasil prediksi untuk frontend
- api-spec internal untuk proses prediksi 7 hari
- alur eksekusi terjadwal menggunakan cron-job

---

## 1. Tujuan

Tujuan proses ini adalah menghasilkan prediksi demand produk untuk 7 hari ke depan, lalu memakai hasilnya untuk:

- analitik produk
- rekomendasi stok
- status stok bahan baku
- tampilan tabel produk di frontend

Hasil prediksi disimpan ke tabel `predictions` melalui model `Prediction` pada `schema.prisma`.

---

## 2. Sumber Data Utama

### 2.1 Model yang dipakai

- `Product`
- `TransactionDetail`
- `Order`
- `Stock`
- `StockReceipts`
- `RawMaterial`
- `ProductIngredient`
- `DailyContext`
- `WeatherContext`
- `PromoCampaigns`
- `Prediction`

### 2.2 Inti data yang diambil

- produk aktif dari `Product`
- histori penjualan dari `TransactionDetail` dan `Order`
- stok saat ini dari `Stock`
- stok bahan baku masuk dari `StockReceipts`
- konteks harian dari `DailyContext`
- konteks promosi dari `PromoCampaigns`
- konteks cuaca dari `WeatherContext` bila dipakai sebagai fitur tambahan internal

---

## 3. Alur Besar Proses

1. Cron-job berjalan sesuai jadwal.
2. Sistem menentukan `cutoff_date`.
3. Sistem mengambil data dari database untuk 90 hari histori dan 7 hari context ke depan.
4. Data mentah dimapping ke format request ML.
5. Request dikirim ke API machine learning.
6. Response dari ML disimpan ke model `Prediction`.
7. Response yang dibutuhkan dihitung ulang atau dinormalisasi untuk frontend.
8. Hasil turunan dipakai untuk update `Stock` dan penyajian frontend.

---

## 4. Cron-Job

Request prediksi ini dijalankan secara terjadwal menggunakan cron-job.

### 4.1 Fungsi cron-job

- menjalankan prediksi secara otomatis
- memastikan hasil prediksi selalu tersedia untuk frontend
- mengurangi proses manual
- menjaga konsistensi data prediksi harian

### 4.2 Contoh jadwal

Jadwal dapat disesuaikan, misalnya:

- setiap hari setelah jam operasional selesai
- setiap malam pukul 23:00

Contoh logika:

- `cutoff_date` = tanggal terakhir data transaksi yang dianggap valid
- cron-job berjalan setelah transaksi hari itu dianggap final

### 4.3 Output cron-job

Cron-job akan menghasilkan:

- 1 request ke API ML
- 1 row baru pada `predictions`
- update pada `stocks` jika ada perubahan hasil rekomendasi

---

## 5. Request Body untuk ML

### 5.1 Bentuk request

```json
{
  "request_id": "store_demand_2026-05-30",
  "cutoff_date": "2026-05-30",
  "stock_buffer_pct": 0,
  "business_minimum": 0,
  "products": [],
  "calendar_context": []
}
```

### 5.2 Definisi field

- `request_id`: id unik untuk request, format disarankan `<nama_toko>_demand_<tanggal>`
- `cutoff_date`: tanggal terakhir data yang boleh dipakai
- `stock_buffer_pct`: buffer stok tambahan
- `business_minimum`: batas minimum bisnis untuk rekomendasi stok
- `products`: daftar produk yang diprediksi
- `calendar_context`: context harian untuk 7 hari ke depan

---

## 6. Mapping Database ke Request ML

Bagian ini menjelaskan bagaimana data dari database diambil lalu dibentuk menjadi payload yang sesuai dengan API ML.

---

### 6.1 Mapping Product

Sumber utama:

- `Product`
- `ProductIngredient`
- `Stock`
- `RawMaterial`

Mapping ke request ML:

- `id_produk` -> `Product.productId`
- `nama_produk` -> `Product.name`
- `kategori` -> label kategori dari `Product.category`
- `varian` -> `Product.variant`
- `ukuran` -> `Product.size`
- `harga_dasar` -> `Product.price`
- `current_stock` -> hasil perhitungan dari bahan baku
- `incoming_stock` -> total stok bahan baku yang masuk pada rentang `cutoff_date + 1` sampai `cutoff_date + 7`

### 6.2 Cara menghitung `current_stock`

`current_stock` tidak diambil langsung dari `Product`, tetapi dihitung dari bahan baku yang dipakai oleh produk.

Langkahnya:

1. ambil semua `ProductIngredient` untuk produk tersebut
2. ambil `Stock.currentQuantity` untuk setiap `stockId`
3. ambil `quantityPerUnit` dari tiap bahan baku
4. hitung kapasitas produk yang dapat dibuat oleh tiap bahan baku
5. ambil nilai paling kecil dari semua hasil perhitungan

Rumus umum:

```ts
capacityPerIngredient = currentQuantity / quantityPerUnit
current_stock = min(capacityPerIngredient untuk semua bahan)
```

### 6.3 Cara menghitung `incoming_stock`

`incoming_stock` diambil dari `StockReceipts`.

Aturan:

- hanya hitung penerimaan stok yang jatuh pada rentang `cutoff_date + 1` sampai `cutoff_date + 7`
- agregasi dilakukan per bahan baku
- lalu diproyeksikan ke produk yang menggunakan bahan tersebut

Kalau bahan baku masuk pada periode itu, maka stok yang akan masuk bisa ikut menambah kapasitas produksi produk.

### 6.4 Mapping `daily_history`

`daily_history` dibentuk dari transaksi historis 90 hari sebelum `cutoff_date`.

Sumber data:

- `TransactionDetail`
- `Order`

Field request:

- `tanggal` -> tanggal transaksi
- `units_sold` -> jumlah produk terjual
- `product_revenue` -> total omzet produk pada hari itu
- `product_order_count` -> jumlah transaksi item produk pada hari itu
- `product_discount_total` -> total diskon produk pada hari itu
- `apakah_ramadan` -> context dari `DailyContext`

### 6.5 Mapping `current_context`

`current_context` adalah context saat ini yang dipakai untuk setiap produk.

Sumber data yang relevan:

- `PromoCampaigns`
- `DailyContext`
- `WeatherContext` jika dipakai sebagai feature internal tambahan

Field request:

- `has_active_promo`
- `active_promo_count`
- `active_promo_mean_discount`
- `product_has_active_promo`
- `product_active_promo_count`
- `product_active_promo_mean_discount`

### 6.6 Mapping `calendar_context`

`calendar_context` diambil untuk 7 hari setelah `cutoff_date`.

Sumber data:

- `DailyContext`
- `PromoCampaigns`
- `WeatherContext` jika dipakai

Field request:

- `tanggal`
- `id_produk`
- `apakah_libur`
- `apakah_ramadan`
- `apakah_periode_gajian`
- `has_active_promo`
- `active_promo_count`
- `active_promo_mean_discount`
- `product_has_active_promo`
- `product_active_promo_count`
- `product_active_promo_mean_discount`

---

## 7. Context Retrieval dari Database

Bagian ini menjelaskan detail pengambilan context.

---

### 7.1 Current Context

`current_context` dipakai sebagai kondisi saat cutoff terjadi.

Untuk membentuknya:

- cek promo aktif pada tanggal `cutoff_date`
- cek apakah produk termasuk target promo aktif
- hitung jumlah promo aktif
- hitung rata-rata diskon aktif
- jika ada promo spesifik produk, hitung metric produk juga

Contoh sumber:

- `PromoCampaigns.status = Active`
- `PromoCampaigns.startDate <= cutoff_date <= PromoCampaigns.endDate`
- `PromoCampaigns.idProducts` atau `PromoCampaigns.categoryTarget`

### 7.2 Calendar Context

`calendar_context` dipakai sebagai fitur masa depan untuk 7 hari ke depan.

Untuk setiap tanggal pada interval:

- cek `DailyContext.isHoliday`
- cek `DailyContext.isRamadhanPeriode`
- cek `DailyContext.isPaydayPeriode`
- cek promo yang aktif pada tanggal tersebut
- cek promo yang khusus untuk produk tersebut

### 7.3 Daily Context

`DailyContext` dipakai sebagai sumber:

- hari libur
- periode Ramadhan
- periode gajian
- event harian

Jika data tersebut belum ada per tanggal, sistem bisa:

- menggunakan fallback default
- atau mengisi berdasarkan rule internal

### 7.4 Weather Context

`WeatherContext` bersifat opsional bila dipakai sebagai fitur internal.

Jika digunakan:

- ambil kondisi cuaca pada waktu tertentu
- agregasikan ke tanggal yang dibutuhkan
- gunakan sebagai fitur tambahan pada konteks historis atau konteks prediksi

---

## 8. Normalisasi Data Sebelum Dikirim ke ML

Data dari database tidak dikirim mentah. Semuanya harus dimapping ke format yang sesuai dengan schema request ML.

### 8.1 Tujuan normalisasi

- menyamakan nama field
- memastikan tipe data konsisten
- mengurangi noise dari struktur database internal
- membuat payload lebih sesuai dengan kontrak API ML

### 8.2 Prinsip mapping

- database memakai camelCase sesuai Prisma
- request ML memakai snake_case
- semua data perlu ditransformasi sebelum dikirim

### 8.3 Contoh mapping

```ts
// Prisma
Product.productId -> request.id_produk
Product.name -> request.nama_produk
Product.category -> request.kategori
Stock.currentQuantity -> request.current_stock
Prediction.modelVersion -> response.model
```

---

## 9. Response ML

Response dari ML dikembalikan seperti bentuk berikut:

```json
{
  "request_id": "postman-demand-revisi-20260530",
  "model": "XGBoost Original",
  "forecast_days": 7,
  "history_days_used": 90,
  "future_promo_context_source": "no_planned_context_fallback",
  "warnings": [],
  "predictions": []
}
```

### 9.1 Field utama response

- `request_id`: identitas request
- `model`: nama model yang digunakan
- `forecast_days`: jumlah hari forecast
- `history_days_used`: jumlah hari histori yang dipakai
- `future_promo_context_source`: sumber context promo untuk periode depan
- `warnings`: daftar warning jika ada
- `predictions`: hasil prediksi per produk

### 9.2 Field dalam `predictions`

- `rank`
- `id_produk`
- `nama_produk`
- `kategori`
- `history_days_used`
- `current_promo_context_source`
- `daily_forecast`
- `predicted_quantity_7d`
- `estimated_p90_quantity_7d`
- `current_stock`
- `incoming_stock`
- `recommended_stock_minimum`
- `suggested_restock_qty`
- `risk_level`
- `risk_score_pct`

---

## 10. Penyimpanan Hasil Prediksi

Hasil prediksi disimpan ke model `Prediction` atau tabel `predictions`.

### 10.1 Mapping ke model Prediction

- `id`: primary key
- `type`: `DEMAND_FORECAST`
- `cutoffDate`: dari `cutoff_date` request
- `forecastDays`: dari `forecast_days`
- `modelVersion`: dari field `model` response ML
- `responseData`: seluruh response ML dalam bentuk JSON
- `normalizedSummary`: ringkasan hasil prediksi yang diproses ulang untuk kebutuhan query
- `generatedAt`: waktu hasil prediksi dibuat

### 10.2 Catatan model

- `storeId` dihapus karena sistem hanya untuk 1 store
- `createdAt` diganti menjadi `generatedAt`
- `forecastDays` ditambahkan untuk menyimpan `forecast_days`

### 10.3 Contoh tujuan `normalizedSummary`

`normalizedSummary` bisa berisi data ringkas seperti:

- total produk diprediksi
- total demand forecast
- total potensi omzet
- produk dengan risk tertinggi
- kategori breakdown

Contoh ini berguna agar frontend tidak perlu selalu memproses seluruh JSON response mentah.

---

## 11. Update Stok

Setelah hasil prediksi diterima, sistem dapat melakukan update ke model `Stock`.

### 11.1 Field `Stock` yang dipakai

- `currentQuantity`
- `minimumQuantity`
- `resilienceDays`
- `status`
- `lastUpdated`

### 11.2 Mapping status

Gunakan enum `StockStatus`:

- `Sufficient` untuk kondisi aman
- `Restock` untuk kondisi perlu pengisian ulang
- `Low` untuk kondisi alert
- `OutOfStock` untuk stok habis

### 11.3 Logika perubahan

- `minimumQuantity` dapat diisi dari `recommended_stock_minimum`
- `resilienceDays` dapat dihitung dari kapasitas stok terhadap forecast harian
- `status` ditentukan dari ketahanan stok terhadap demand 7 hari
- `lastUpdated` diisi saat update dilakukan

---

## 12. Mapping untuk Frontend

Data untuk frontend tidak diambil langsung dari response mentah ML. Data terlebih dahulu dimapping ke format yang sesuai dengan schema dan kebutuhan UI.

### 12.1 Prinsip mapping ke frontend

- data backend dan Prisma memakai camelCase
- data response ML memakai snake_case
- frontend menerima data camelCase agar konsisten dengan schema dan codebase

### 12.2 Mapping response ML ke frontend

Contoh mapping:

- `id_produk` -> `productId`
- `nama_produk` -> `name`
- `kategori` -> `category`
- `predicted_quantity_7d` -> `predictedQuantity7d`
- `estimated_p90_quantity_7d` -> `estimatedP90Quantity7d`
- `recommended_stock_minimum` -> `recommendedStockMinimum`
- `suggested_restock_qty` -> `suggestedRestockQty`
- `risk_level` -> `riskLevel`
- `risk_score_pct` -> `riskScorePct`

### 12.3 Analitik Produk

Field yang dipakai:

- `totalProdukAktif` -> jumlah `Product` dengan `isActive = true`
- `volumeForecast` -> jumlah semua `predictedQuantity7d`
- `potensiOmzet` -> jumlah `predictedQuantity7d * price`
- `produkTerlaris` -> produk dengan `predictedQuantity7d` paling besar
- `kategoriBreakdown` -> agregasi berdasarkan `Product.category`

### 12.4 Kategori Breakdown

Kategori harus mengikuti mapping Prisma:

- `kopi`
- `non_kopi`
- `makanan_ringan`

Bentuk data frontend:

```ts
[
  {
    category: 'kopi',
    revenuePotential: 0,
    totalDemand: 0,
    productCount: 0,
  },
];
```

### 12.5 Tabel Produk

Field tabel yang dipakai frontend:

- `name`
- `category`
- `price`
- `demandForecast`
- `potensiOmzet`
- `terjual`
- `status`

### 12.6 Field `terjual`

`terjual` tidak berasal dari response ML.

Sumbernya:

- `TransactionDetail.quantity`

Lalu diaggregasi per produk dan per periode yang dibutuhkan.

### 12.7 Status frontend

Status frontend:

- `"Hot"`
- `"Normal"`
- `"Slow"`

Default:

- `"Normal"`

Contoh logika:

```ts
if (dailyAvg > hotThreshold) {
  status = 'Hot';
} else if (dailyAvg < slowThreshold) {
  status = 'Slow';
}
```

---

## 13. API-Spec Internal

Spesifikasi ini menjelaskan endpoint internal yang memicu proses prediksi.

### 13.1 Trigger Endpoint

`POST /api/demand-7-day/forecast`

Endpoint ini dapat dipanggil oleh:

- cron-job
- manual admin trigger
- job scheduler internal

### 13.2 Request Body

```json
{
  "cutoffDate": "2026-05-30",
  "stockBufferPct": 0,
  "businessMinimum": 0
}
```

### 13.3 Response Body

```json
{
  "success": true,
  "requestId": "store_demand_2026-05-30",
  "predictionId": "uuid",
  "cutoffDate": "2026-05-30",
  "forecastDays": 7,
  "modelVersion": "XGBoost Original",
  "generatedAt": "2026-05-30T23:00:00.000Z",
  "summary": {
    "totalProducts": 20,
    "totalForecast": 180,
    "totalRevenuePotential": 4500000
  }
}
```

### 13.4 Error Response

Contoh error:

```json
{
  "success": false,
  "message": "Failed to generate demand forecast",
  "errorCode": "DEMAND_FORECAST_FAILED"
}
```

### 13.5 Behavior Endpoint

- mengambil data dari database
- membentuk payload request ML
- mengirim request ke API ML
- menyimpan response ke `Prediction`
- mengembalikan ringkasan hasil

---

## 14. Ringkasan Mapping Teknis

### 14.1 Database ke ML

- `Product` -> payload produk
- `TransactionDetail` + `Order` -> histori penjualan
- `Stock` -> stok aktif
- `StockReceipts` -> incoming stock
- `DailyContext` -> konteks kalender
- `PromoCampaigns` -> konteks promo
- `WeatherContext` -> konteks cuaca jika dipakai

### 14.2 ML ke Database

- response mentah -> `Prediction.responseData`
- ringkasan terstruktur -> `Prediction.normalizedSummary`
- rekomendasi stok -> `Stock`

### 14.3 Database ke Frontend

- data Prisma tetap dalam camelCase
- hasil prediksi yang awalnya snake_case dimapping ke camelCase
- frontend menerima data final yang sudah siap render

---

## 15. Catatan Implementasi

- request ML sebaiknya dibuat oleh service khusus agar mapping lebih rapi
- response ML sebaiknya disimpan utuh untuk audit dan debugging
- `normalizedSummary` sebaiknya dipakai untuk query cepat frontend
- semua mapping perlu konsisten antara database, service, dan frontend
- jika field baru ditambahkan ke response ML, cukup update mapper tanpa mengubah struktur inti
