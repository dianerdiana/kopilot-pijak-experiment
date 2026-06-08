# Kebutuhan halaman notifikasi

## untuk masing-masing card

- notifikasi aktif
- notifikasi belum dibaca
- periode cek (hari)

## Daftar notifikasi - Ini dalam bentuk card untuk masing-masing notifikasi, dengan pagination di bawah. Dan ada filter untuk pilih; semua, belum dibaca, jam sibuk (NotificationType.PeakHourAlert), stock (NotificationType.StockAlert), dan revenue (NotificationType.Report)

- id
- waktu
- judul
- isi notifikasi
- tipe notifikasi (sesuaikan dengan enum NotificationType)
- status baca (sesuaikan dengan enum NotificationStatus)
