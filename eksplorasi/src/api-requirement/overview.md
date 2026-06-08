# Data yang dibutuhkan oleh halaman overview

## Untuk masing-masing card:

- Forecast revenue: naik / turun berapa persen
- Restock priority: (2 raw material teratas yang perlu restock)
- Peak hour time: <startTime> - <endTime>
- Favorite menu: 2 menu yang paling banyak dibeli dari aktual history transaksi

- Actual revenue: (revenue kemarin dibandingkan dengan revenue 7 hari sebelumnya, misal kemarin hari senin dibandingkan dengan hari senin di minggu sebelumnya) perlu keterangannya juga berapa persen naik atau turunnya
- Forecast revenue: (forecast 7 hari)
- Average transaction: (datanya sama seperti revenue, tapi ini dalam bentuk rata-rata) perlu keterangannya juga berapa persen naik atau turunnya
- Tomorrow peak hour: <startTime> - <endTime>
- Critical stock: total item yang perlu segera restock

## revenue actual vs forecast - dalam bentuk diagram garis dengan 3 garis: actual revenue, forecast revenue, upper bound, lower bound

- Actual revenue
- Forecast revenue
- Upper bound (batas atas dari forecast)
- Lower bound (batas bawah dari forecast)

## Untuk Top Demand Produk - horizontal diagram bar - ini data aktual dari transaksi

- Product name (nama produk)
- Quantity sold (jumlah unit terjual)

## Prioritas Restock dari Forecast - dalam bentuk tabel

- Inventory (nama dari raw material)
- Minimum Qty (minimal stock untuk kebutuhan 7 hari)
- Current Stock (stock saat ini)

## Traffic Forecast per-jam - diagram bar dalam bentuk waktu

- Prediction Hour (jam prediksi)
- Prediction Order Count
- Traffic Level (sesuaikan dengan enum (low, normal, high))
