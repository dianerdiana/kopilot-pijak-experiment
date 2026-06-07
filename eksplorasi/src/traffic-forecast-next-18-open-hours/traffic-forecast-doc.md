# Prediksi Traffic: Next 18 Open Hours

Dokumen ini menjelaskan:

- sumber data yang dipakai untuk request prediksi traffic
- cara mengambil context dari database
- mapping data dari database ke format request ML
- cara menyimpan hasil prediksi
- mapping hasil prediksi untuk frontend
- API-spec internal untuk proses prediksi traffic 18 jam operasional ke depan
- alur eksekusi terjadwal menggunakan cron-job
- dampak hasil prediksi traffic ke notifikasi jam padat

---

# 1. Tujuan

Tujuan proses ini adalah menghasilkan prediksi traffic atau jumlah order per jam untuk 18 jam operasional ke depan.

Hasil prediksi digunakan untuk:

- monitoring jam padat
- analitik traffic harian
- notifikasi peak hour
- perencanaan operasional
- visualisasi diagram batang traffic per jam

Hasil prediksi disimpan ke tabel `predictions` melalui model `Prediction` pada `schema.prisma` dengan tipe `TrafficForecast`.

---

# 2. Sumber Data Utama

## 2.1 Model yang Dipakai

- `Order`
- `DailyContext`
- `WeatherContext`
- `PromoCampaigns`
- `Prediction`

## 2.2 Inti Data yang Diambil

- histori traffic dari `Order`
- konteks kalender dari `DailyContext`
- konteks cuaca dari `WeatherContext` bila digunakan
- konteks promosi dari `PromoCampaigns`
- hasil prediksi sebelumnya dari `Prediction` bila diperlukan untuk evaluasi model

---

# 3. Alur Besar Proses

1. Cron-job berjalan sesuai jadwal.
2. Sistem menentukan `cutoff_time`.
3. Sistem mengambil histori order per jam dari periode sebelumnya.
4. Data historis dihitung dan diaggregasi per jam operasional.
5. Data dimapping ke format request ML.
6. Request dikirim ke API Traffic Forecast.
7. Response disimpan ke model `Prediction` dengan tipe `TrafficForecast`.
8. Ringkasan hasil dibuat untuk frontend.
9. Sistem memicu notifikasi jika ada jam padat yang melebihi ambang batas.

---

# 4. Cron-Job

## 4.1 Fungsi Cron-Job

- menjalankan prediksi traffic secara otomatis
- memastikan forecast selalu tersedia
- mengurangi proses manual
- menjaga konsistensi data prediksi harian

## 4.2 Contoh Jadwal

Contoh:

- setiap hari sebelum jam operasional berikutnya dimulai
- setiap hari setelah periode order saat ini dianggap final

Logika:

- `cutoff_time` = waktu terakhir data order yang dianggap valid
- cron berjalan setelah data jam itu dianggap final

## 4.3 Output Cron-Job

Cron-job menghasilkan:

- 1 request ke API ML Traffic Forecast
- 1 row baru pada `predictions`
- data siap pakai untuk dashboard traffic dan notifikasi

---

# 5. Request Body untuk ML

## 5.1 Bentuk Request

```json
{
  "request_id": "store_traffic_2026-06-07T18:00:00Z",
  "cutoff_time": "2026-06-07T18:00:00Z",
  "hourly_history": [],
  "current_context": {
    "has_active_promo": 0,
    "active_promo_count": 0,
    "active_promo_mean_discount": 0
  },
  "calendar_context": []
}
```

## 5.2 Definisi Field

- `request_id`
- `cutoff_time`
- `hourly_history`
- `current_context`
- `calendar_context`

Struktur data utama yang dikirim:

- `hourly_history` berisi histori traffic per jam dengan field `waktu_jam`, `order_count`, `kondisi_cuaca`, `periode_ramadan`, `jenis_event`, `apakah_libur`, `apakah_ramadan`, dan `apakah_periode_gajian`
- `current_context` berisi context saat cutoff dengan field `has_active_promo`, `active_promo_count`, dan `active_promo_mean_discount`
- `calendar_context` berisi context jam ke depan dengan field `waktu_jam`, `apakah_libur`, `apakah_ramadan`, `apakah_periode_gajian`, `has_active_promo`, `active_promo_count`, `active_promo_mean_discount`, dan `periode_ramadan`

---

# 6. Mapping Database ke Request ML

Bagian ini menjelaskan dari tabel mana saja, field apa saja yang diambil, dan bagaimana cara mengambilnya.

## 6.1 Mapping `hourly_history`

Sumber:

- `Order`
- `DailyContext`
- `WeatherContext`
- `PromoCampaigns`

Field Prisma yang dipakai:

- `Order.orderTime`
- `Order.orderId`
- `DailyContext.isHoliday`
- `DailyContext.isRamadhanPeriode`
- `DailyContext.isPaydayPeriode`
- `DailyContext.eventName`
- `WeatherContext.condition`
- `WeatherContext.ramadhanPeriode`
- `PromoCampaigns.status`
- `PromoCampaigns.startDate`
- `PromoCampaigns.endDate`
- `PromoCampaigns.discountValue`

Cara mengambil:

```ts
// Ambil order pada periode histori, lalu kelompokkan per jam operasional.
// Jam diambil dari Order.orderTime setelah dinormalisasi ke bucket jam.
hourlyHistory = groupByHour(
  ordersBetween(historyStart, cutoffTime),
)
```

Field yang diambil:

- `waktu_jam`
- `order_count`
- `kondisi_cuaca`
- `periode_ramadan`
- `jenis_event`
- `apakah_libur`
- `apakah_ramadan`
- `apakah_periode_gajian`

---

## 6.2 Mapping `current_context`

Sumber:

- `PromoCampaigns`
- `DailyContext`

Cara mengambil:

```ts
const activePromos = await prisma.promoCampaigns.findMany({
  where: {
    status: 'Active',
    startDate: { lte: cutoffDateOnly },
    endDate: { gte: cutoffDateOnly },
  },
});
```

Field:

- `has_active_promo`
- `active_promo_count`
- `active_promo_mean_discount`

---

## 6.3 Mapping `calendar_context`

Sumber:

- `DailyContext`
- `PromoCampaigns`
- `WeatherContext`

Cara mengambil:

Untuk setiap jam dalam rentang 18 jam operasional setelah `cutoff_time`:

- cek context hari pada `DailyContext`
- cek promo aktif pada jam atau tanggal terkait
- cek kondisi cuaca jika feature ini dipakai

Field:

- `waktu_jam`
- `apakah_libur`
- `apakah_ramadan`
- `apakah_periode_gajian`
- `has_active_promo`
- `active_promo_count`
- `active_promo_mean_discount`
- `periode_ramadan`

---

# 7. Context Retrieval dari Database

## 7.1 Current Context

Mengambil kondisi bisnis pada saat cutoff.

Sumber:

- `PromoCampaigns`
- `DailyContext`

Proses:

- cek promo aktif
- hitung jumlah promo aktif
- hitung rata-rata diskon
- cek hari libur
- cek periode gajian

---

## 7.2 Calendar Context

Mengambil konteks 18 jam ke depan.

Untuk setiap jam:

- cek holiday
- cek payday
- cek ramadhan
- cek promo aktif

---

## 7.3 Daily Context

Sumber:

- `DailyContext`

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

- agregasi kondisi cuaca per jam
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
Order.orderTime -> waktu_jam

Order.orderId -> order_count

DailyContext.isHoliday -> apakah_libur

DailyContext.isRamadhanPeriode -> apakah_ramadan

DailyContext.isPaydayPeriode -> apakah_periode_gajian

PromoCampaigns.discountValue -> active_promo_mean_discount

WeatherContext.condition -> kondisi_cuaca
```

---

# 9. Response ML

## 9.1 Bentuk Response

```json
{
  "request_id": "store_traffic_2026-06-07T18:00:00Z",
  "model": "XGBoost Traffic",
  "cutoff_time": "2026-06-07T18:00:00Z",
  "forecast_open_slots": 18,
  "history_open_hours_used": 90,
  "current_promo_context_source": "current_active_promo_lookup",
  "future_promo_context_source": "calendar_context_lookup",
  "warnings": [],
  "predictions": [
    {
      "prediction_time": "2026-06-08T11:00:00Z",
      "prediction_hour": 11,
      "forecast_open_slot": 1,
      "predicted_order_count": 45,
      "lower_bound": 38,
      "upper_bound": 53,
      "interval_width": 15,
      "prediction_interval_level_pct": 90,
      "interval_coverage_backtest_pct": 87.5,
      "traffic_level": "Heavy"
    }
  ],
  "peak_window": {
    "start_time": "2026-06-08T11:00:00Z",
    "end_time": "2026-06-08T13:00:00Z",
    "max_predicted_order_count": 45
  }
}
```

## 9.2 Field Dalam Predictions

- `prediction_time`
- `prediction_hour`
- `forecast_open_slot`
- `predicted_order_count`
- `lower_bound`
- `upper_bound`
- `interval_width`
- `prediction_interval_level_pct`
- `interval_coverage_backtest_pct`
- `traffic_level`

Contoh:

```json
{
  "prediction_time": "2026-06-08T11:00:00Z",
  "prediction_hour": 11,
  "forecast_open_slot": 1,
  "predicted_order_count": 45,
  "lower_bound": 38,
  "upper_bound": 53,
  "interval_width": 15,
  "prediction_interval_level_pct": 90,
  "interval_coverage_backtest_pct": 87.5,
  "traffic_level": "Heavy"
}
```

---

# 10. Penyimpanan Hasil Prediksi

Hasil prediksi disimpan ke model `Prediction`.

## 10.1 Mapping ke Model Prediction

- `type` = `TrafficForecast`
- `cutoffDate`
- `cutoffHour`
- `forecastDays`
- `modelVersion`
- `responseData`
- `normalizedSummary`
- `generatedAt`

---

## 10.2 Contoh `normalizedSummary`

```json
{
  "forecastOpenSlots": 18,
  "peakWindow": {
    "startTime": "2026-06-08T11:00:00Z",
    "endTime": "2026-06-08T13:00:00Z",
    "maxPredictedOrderCount": 45
  },
  "trafficBuckets": [
    {
      "hour": 6,
      "forecastTotalTransaction": 20,
      "trafficPercentage": 11.1,
      "trafficLevel": "Low"
    }
  ]
}
```

---

## 10.3 Tujuan Normalized Summary

- query cepat frontend
- dashboard analytics
- mengurangi parsing JSON besar

---

# 11. Dampak Hasil Prediksi Traffic

## 11.1 Tabel yang Dipakai

- `Prediction`

## 11.2 Data yang Dihasilkan

- total forecast traffic
- peak window
- traffic level
- confidence interval

## 11.3 Catatan

Traffic forecast tidak mengubah transaksi maupun stok.

Traffic forecast dipakai untuk analitik dan notifikasi jam padat.

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

- `prediction_time` -> `predictionTime`
- `prediction_hour` -> `predictionHour`
- `forecast_open_slot` -> `forecastOpenSlot`
- `predicted_order_count` -> `predictedOrderCount`
- `lower_bound` -> `lowerBound`
- `upper_bound` -> `upperBound`
- `interval_width` -> `intervalWidth`
- `prediction_interval_level_pct` -> `predictionIntervalLevelPct`
- `interval_coverage_backtest_pct` -> `intervalCoverageBacktestPct`
- `traffic_level` -> `trafficLevel`

---

## 12.3 Traffic Analytics

Field:

- `forecastOpenSlots`
- `peakWindow`
- `maxPredictedOrderCount`
- `trafficLevel`
- `trafficPercentage`

---

## 12.4 Traffic Bar Chart

Field:

- `hour`
- `forecastTotalTransaction`
- `trafficPercentage`
- `trafficLevel`

Contoh data frontend:

```json
[
  {
    "hour": 6,
    "forecastTotalTransaction": 20,
    "trafficPercentage": 11.1,
    "trafficLevel": "Low"
  }
]
```

---

# 13. Notifikasi Jam Padat

## 13.1 Trigger Notifikasi

Notifikasi dibuat ketika jumlah jam padat dalam forecast lebih dari atau sama dengan 3 jam.

## 13.2 Logika Dasar

- tentukan slot dengan `trafficLevel = Heavy`
- hitung jumlah slot `Heavy`
- jika jumlahnya `>= 3`, buat notifikasi `PeakHourAlert`

## 13.3 Contoh Pesan

- `Terdapat 3 jam padat pada forecast traffic 18 jam ke depan`

---

# 14. API-Spec Internal

## 14.1 Trigger Endpoint

```http
POST /api/traffic-forecast/forecast
```

Endpoint dapat dipanggil oleh:

- cron-job
- scheduler
- admin trigger

---

## 14.2 Request Body

```json
{
  "cutoff_time": "2026-06-07T18:00:00Z"
}
```

---

## 14.3 Response Body

```json
{
  "success": true,
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
```

---

## 14.4 Error Response

```json
{
  "success": false,
  "message": "Failed to generate traffic forecast",
  "errorCode": "TRAFFIC_FORECAST_FAILED",
  "details": "Insufficient historical data (need at least 30 hours)"
}
```

---

## 14.5 Behavior Endpoint

- mengambil data histori order per jam
- membentuk payload ML
- mengirim request ke API ML
- menyimpan hasil ke Prediction
- mengembalikan ringkasan hasil

---

# 15. Ringkasan Mapping Teknis

## 15.1 Database ke ML

- `Order` -> histori traffic per jam
- `DailyContext` -> konteks kalender
- `PromoCampaigns` -> konteks promo
- `WeatherContext` -> konteks cuaca jika dipakai

## 15.2 ML ke Database

- response mentah -> `Prediction.responseData`
- ringkasan -> `Prediction.normalizedSummary`

## 15.3 Database ke Frontend

- data Prisma tetap camelCase
- hasil ML dimapping ke camelCase
- frontend menerima data siap render

---

# 16. Catatan Implementasi

- service traffic forecast sebaiknya dipisah dari revenue dan demand forecast
- response ML disimpan utuh untuk audit
- `normalizedSummary` digunakan untuk query cepat frontend
- seluruh mapping harus konsisten antara backend, ML, dan frontend
- jika ada field baru pada model ML cukup memperbarui mapper tanpa mengubah struktur utama
