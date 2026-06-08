# Kebutuhan halaman Manajemen Stock

## Untuk masing-masing card

- Item Kritis
- Perlu Restock
- Stock Aman
- Coverage Rata-rata

## Prioritas Stock Tertinggi - Dalam bentuk horizontal bar chart

- sumbu y (kiri): nama produk
- sumbu y (kanan): ketahanan produk (dalam hari), contoh (0.2 hari, 1 hari)
- sumbu x: ketahanan produk (hari), hanya angka integer

## Ringkasan status stock - dalam bentuk donnut chart

- restock status: sesuaikan dengan enum StockStatus
- persentase masing-masing StockStatus

## Status dan prediksi stock - ditampilkan dalam bentuk tabel

- bahan baku: nama bahan baku
- sisa stok: stok saat ini
- prediksi butuh 7 hari: minimum stock untuk 7 hari
- coverage: ketahanan stok saat ini
- selisih: selisih kekurangan / kelebihan antara sisa stok dengan prediksi kebutuhan
- status: dari StockStatus
