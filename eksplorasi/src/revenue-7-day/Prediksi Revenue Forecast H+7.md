# Prediksi Revenue: Revenue Forecast H+7

Dokumen ini menjelaskan:

- sumber data yang dipakai untuk request prediksi revenue
- cara mengambil context dari database
- mapping data dari database ke format request ML
- cara menyimpan hasil prediksi
- mapping hasil prediksi untuk frontend
- API-spec internal untuk proses prediksi revenue 7 hari
- alur eksekusi terjadwal menggunakan cron-job
- dampak upload data transaksi terhadap stock
- spesifikasi notifikasi `StockAlert` dan `Report`

---

# 1. Tujuan

Tujuan proses ini adalah menghasilkan prediksi revenue (omzet) untuk 7 hari ke depan berdasarkan histori transaksi, context bisnis, promosi, dan kalender operasional.

Hasil prediksi digunakan untuk:

- dashboard revenue
- monitoring performa bisnis
- analitik omzet
- evaluasi promo
- perencanaan operasional
- perbandingan forecast dan actual revenue

Hasil prediksi disimpan ke tabel `predictions` melalui model `Prediction` pada `schema.prisma` dengan tipe `RevenueForecast`.

---

# 2. Sumber Data Utama

## 2.1 Model yang Dipakai

- `TransactionDetail`
- `Order`
- `Product`
- `DailyContext`
- `WeatherContext`
- `PromoCampaigns`
- `Prediction`

## 2.2 Inti Data yang Diambil

- histori transaksi dari `TransactionDetail`
- histori pesanan dari `Order`
- data produk dari `Product`
- konteks kalender dari `DailyContext`
- konteks promosi dari `PromoCampaigns`
- konteks cuaca dari `WeatherContext` bila digunakan sebagai feature tambahan
- hasil prediksi sebelumnya dari `Prediction` bila diperlukan untuk evaluasi model

---

# 3. Alur Besar Proses

1. Cron-job berjalan sesuai jadwal.
2. Sistem menentukan `cutoff_date`.
3. Sistem mengambil histori transaksi 90 hari terakhir.
4. Revenue historis dihitung dan diaggregasi per hari.
5. Data dimapping ke format request ML.
6. Request dikirim ke API Revenue Forecast.
7. Response disimpan ke model `Prediction` (type `RevenueForecast`).
8. Ringkasan hasil dibuat untuk frontend.
9. Dashboard revenue menggunakan hasil prediksi terbaru.

---

# 4. Cron-Job

## 4.1 Fungsi Cron-Job

- menjalankan prediksi revenue otomatis
- memastikan forecast selalu tersedia
- mengurangi proses manual
- menjaga konsistensi data prediksi

## 4.2 Contoh Jadwal

Contoh:

- setiap hari pukul 23:00
- setelah jam operasional berakhir

Logika:

- `cutoff_date` = tanggal terakhir transaksi valid
- cron berjalan setelah transaksi hari tersebut dianggap final

## 4.3 Output Cron-Job

Cron-job menghasilkan:

- 1 request ke API ML Revenue Forecast
- 1 row baru pada `predictions`
- update dashboard revenue

---

# 5. Request Body untuk ML

## 5.1 Bentuk Request

```json
{
  "request_id": "store_revenue_2026-05-30",
  "cutoff_date": "2026-05-30",
  "forecast_days": 7,
  "daily_revenue_history": [],
  "calendar_context": []
}
```

## 5.2 Definisi Field

- `request_id`
- `cutoff_date`
- `forecast_days`
- `daily_revenue_history`
- `calendar_context`

Struktur data utama yang dikirim:

- `daily_revenue_history` berisi histori revenue harian dengan field `tanggal`, `revenue`, `order_count`, `items_sold`, dan `discount_total`
- `calendar_context` berisi context tanggal ke depan dengan field `tanggal`, `is_holiday`, `is_ramadhan_periode`, `is_payday_periode`, `has_active_promo`, `active_promo_count`, dan `active_promo_mean_discount`

---

# 6. Mapping Database ke Request ML

Bagian ini menjelaskan dari tabel mana saja, field apa saja yang diambil, dan bagaimana cara mengambilnya.

## 6.1 Mapping `daily_revenue_history`

Sumber:

- `TransactionDetail`
- `Order`

Field Prisma yang dipakai:

- `Order.orderTime`
- `Order.orderId`
- `TransactionDetail.totalPrice`
- `TransactionDetail.quantity`
- `TransactionDetail.discount`

Cara mengambil:

```ts
const revenueHistory = await prisma.transactionDetail.groupBy({
  by: ['orderId'],
  where: {
    order: {
      orderTime: {
        gte: ninetyDaysAgo,
        lte: cutoffDate,
      },
    },
  },
  _sum: {
    totalPrice: true,
    quantity: true,
    discount: true,
  },
});
```

Field yang diambil:

- `tanggal`
- `revenue`
- `order_count`
- `items_sold`
- `discount_total`

---

## 6.2 Mapping `calendar_context`

Sumber:

- DailyContext
- PromoCampaigns
- WeatherContext

Cara mengambil:

Untuk setiap tanggal dalam rentang `cutoff_date + 1` sampai `cutoff_date + 7`

for each date in [cutoff_date+1 ... cutoff_date+7]:
// Dari DailyContext
context = db.dailyContext.findUnique({ where: { date } })

// Dari PromoCampaigns
activePromos = db.promoCampaigns.findMany({
  where: {
    status: 'Active',
    startDate: { lte: date },
    endDate: { gte: date }
  }
})

// Hitung metric promo
promoCount = activePromos.length
meanDiscount = average(activePromos.map(p => p.discountValue))

// Opsional: dari WeatherContext
weather = db.weatherContext.findFirst({
  where: { dateTime: { gte: date, lt: date + 1 } }
})

Field:

- tanggal
- is_holiday
- is_ramadhan_periode
- is_payday_periode
- active_promo_count
- active_promo_mean_discount
- condition

## 6.3 Mapping `current_context`

Sumber:

- DailyContext
- PromoCampaigns

Cara mengambil:

// Pada tanggal cutoff_date
currentDate = cutoff_date

// Cek promo aktif
activePromos = db.promoCampaigns.findMany({
  where: {
    status: 'Active',
    startDate: { lte: currentDate },
    endDate: { gte: currentDate }
  }
})

// Cek daily context
dailyContext = db.dailyContext.findUnique({
  where: { date: currentDate }
})

Field:

- has_active_promo
- active_promo_count
- active_promo_mean_discount
- is_holiday
- is_payday_periode

---

# 7. Context Retrieval dari Database

## 7.1 Current Context

Mengambil kondisi bisnis pada saat cutoff.

Sumber:

- PromoCampaigns
- DailyContext

Proses:

- cek promo aktif
- hitung jumlah promo aktif
- hitung rata-rata diskon
- cek payday period
- cek hari libur

---

## 7.2 Calendar Context

Mengambil konteks 7 hari ke depan.

Untuk setiap tanggal:

- cek holiday
- cek payday
- cek ramadhan
- cek promo aktif

---

## 7.3 Daily Context

Sumber:

- DailyContext

Digunakan untuk:

- hari libur
- weekend
- periode ramadhan
- periode gajian
- event

---

## 7.4 Weather Context

Opsional.

Jika digunakan:

- agregasi kondisi cuaca harian
- digunakan sebagai feature tambahan model

---

# 8. Normalisasi Data Sebelum Dikirim ke ML

## 8.1 Tujuan Normalisasi

- konsistensi tipe data
- konsistensi format
- mempermudah kontrak API

## 8.2 Prinsip Mapping

Database:

```text
camelCase
```

ML:

```text
snake_case
```

---

## 8.3 Contoh Mapping

```ts
Order.orderTime -> tanggal

TransactionDetail.totalPrice -> revenue

TransactionDetail.quantity -> items_sold

TransactionDetail.discount -> discount_total

DailyContext.isHoliday -> is_holiday

DailyContext.isRamadhanPeriode -> is_ramadhan_periode

DailyContext.isPaydayPeriode -> is_payday_periode

PromoCampaigns.discountValue -> active_promo_mean_discount

WeatherContext.condition -> condition
```

---

# 9. Response ML

## 9.1 Bentuk Response

```json
{
  "request_id": "store_revenue_2026-05-30",
  "model": "XGBoost Revenue",
  "forecast_days": 7,
  "history_days_used": 90,
  "warnings": [],
  "predictions": [
    {
      "tanggal": "2026-06-01",
      "predicted_revenue": 2500000,
      "lower_bound": 2200000,
      "upper_bound": 2900000,
      "confidence_score": 0.92
    }
  ],
  "summary": {
    "total_forecast_revenue": 17500000,
    "average_daily_revenue": 2500000,
    "peak_revenue_date": "2026-06-03",
    "peak_revenue_value": 3200000
  }
}
```

---

## 9.2 Field Dalam Predictions

- tanggal
- predicted_revenue
- lower_bound
- upper_bound
- confidence_score

Contoh:

```json
{
  "tanggal": "2026-06-01",
  "predicted_revenue": 2500000,
  "lower_bound": 2200000,
  "upper_bound": 2900000,
  "confidence_score": 0.92
}
```

---

# 10. Penyimpanan Hasil Prediksi

Hasil prediksi disimpan ke model `Prediction`.

## 10.1 Mapping ke Model Prediction

- type = `RevenueForecast`
- cutoffDate
- forecastDays
- modelVersion
- responseData
- normalizedSummary
- generatedAt

---

## 10.2 Contoh `normalizedSummary`

```json
{
  "totalForecastRevenue": 17500000,
  "averageDailyRevenue": 2500000,
  "highestForecastRevenue": 3200000,
  "lowestForecastRevenue": 1800000,
  "peakRevenueDate": "2026-06-03",
  "dailyBreakdown": [
    { "date": "2026-06-01", "revenue": 2500000 },
    { "date": "2026-06-02", "revenue": 2700000 },
    { "date": "2026-06-03", "revenue": 3200000 }
  ]
}
```

---

## 10.3 Tujuan Normalized Summary

- query cepat frontend
- dashboard analytics
- mengurangi parsing JSON besar

---

# 11. Dampak Hasil Prediksi Revenue

## 11.1 Tabel yang Dipakai

- Prediction

## 11.2 Data yang Dihasilkan

- total forecast revenue
- average forecast revenue
- trend revenue
- confidence score

## 11.3 Catatan

Revenue forecast tidak mengubah transaksi maupun stok.

Revenue forecast hanya digunakan untuk analitik.

---

# 12. Mapping untuk Frontend

## 12.1 Prinsip Mapping

Backend:

```text
snake_case
```

Frontend:

```text
camelCase
```

---

## 12.2 Mapping Response ML ke Frontend

- predicted_revenue -> predictedRevenue
- lower_bound -> lowerBound
- upper_bound -> upperBound
- confidence_score -> confidenceScore
- total_forecast_revenue -> totalForecastRevenue
- average_daily_revenue -> averageDailyRevenue
- peak_revenue_date -> peakRevenueDate

---

## 12.3 Revenue Analytics

Field:

- totalForecastRevenue
- averageDailyRevenue
- revenueGrowth
- bestDay
- worstDay
- confidenceScore

---

## 12.4 Revenue Trend Chart

Field:

- date
- predictedRevenue
- lowerBound
- upperBound

---

## 12.5 Revenue Dashboard

Field:

- revenueForecast
- revenueTarget
- revenueAchievement
- confidenceScore

---

# 13. API-Spec Internal

## 13.1 Trigger Endpoint

```http
POST /api/revenue-forecast/forecast
```

Endpoint dapat dipanggil oleh:

- cron-job
- scheduler
- admin trigger

---

## 13.2 Request Body

```json
{
  "cutoffDate": "2026-06-07",
  "forecastDays": 7
}
```

---

## 13.3 Response Body

```json
{
  "success": true,
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
```

---

## 13.4 Error Response

```json
{
  "success": false,
  "message": "Failed to generate revenue forecast",
  "errorCode": "REVENUE_FORECAST_FAILED",
  "details": "Insufficient historical data (need at least 30 days)"
}
```

---

## 13.5 Behavior Endpoint

- mengambil data histori transaksi
- membentuk payload ML
- mengirim request ke API ML
- menyimpan hasil ke Prediction
- mengembalikan ringkasan hasil

---

# 14. Ringkasan Mapping Teknis

## 14.1 Database ke ML

- TransactionDetail -> revenue history
- Order -> order metrics
- DailyContext -> calendar context
- PromoCampaigns -> promo context
- WeatherContext -> weather context

---

## 14.2 ML ke Database

- response mentah -> Prediction.responseData
- ringkasan -> Prediction.normalizedSummary

---

## 14.3 Database ke Frontend

- data Prisma tetap camelCase
- hasil ML dimapping ke camelCase
- frontend menerima data siap render

---

# 15. Catatan Implementasi

- service revenue forecast sebaiknya dipisah dari demand forecast
- response ML disimpan utuh untuk audit
- normalizedSummary digunakan untuk query cepat
- seluruh mapping harus konsisten antara backend, ML, dan frontend
- jika ada field baru pada model ML cukup memperbarui mapper tanpa mengubah struktur utama
