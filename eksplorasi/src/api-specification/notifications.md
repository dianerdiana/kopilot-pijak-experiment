# API Specification - Notifications

Dokumen ini menjelaskan API untuk halaman notifikasi berdasarkan requirement di [`api-requirement/notifikasi.md`](../api-requirement/notifikasi.md), schema Prisma pada model `Notification`, `NotificationRead`, dan `User`, serta pola dokumentasi yang sudah dipakai pada modul lain.

## 1. Ruang Lingkup

API ini mencakup:

- ringkasan notifikasi pada card dashboard
- daftar notifikasi dengan pagination dan filter
- detail notifikasi
- penandaan notifikasi sebagai sudah dibaca
- penandaan semua notifikasi sebagai sudah dibaca

## 2. Asumsi

Beberapa hal di bawah ini diasumsikan agar spesifikasi bisa langsung dipakai:

- notifikasi disimpan pada model `Notification`
- status lifecycle notifikasi mengikuti enum Prisma `NotificationStatus`
  - `Active` -> `aktif`
  - `Expired` -> `kedaluwarsa`
  - `Resolved` -> `selesai`
  - `Archived` -> `diarsipkan`
- status baca tidak disimpan pada `Notification`, tetapi diturunkan dari relasi `NotificationRead`
- jika sebuah notifikasi belum memiliki record di `NotificationRead` untuk user terkait, maka status bacanya dianggap `belum_dibaca`
- halaman notifikasi memakai periode cek default 7 hari
- filter UI yang diminta pada requirement dipetakan ke query filter yang sederhana:
  - `all`
  - `unread`
  - `peak_hour`
  - `stock`
  - `revenue`
- notifikasi aktif pada card dihitung dari notifikasi dengan `status = aktif`
- notifikasi belum dibaca dihitung dari notifikasi aktif yang belum ada record read untuk user bersangkutan
- tabel notifikasi ditampilkan sebagai card dengan pagination
- `payload` pada model `Notification` tetap disimpan utuh, tetapi tidak wajib selalu dikembalikan ke frontend ringkas

## 3. Base URL

Semua endpoint menggunakan prefix berikut:

```text
/api
```

## 4. Model Data

### 4.1 Notification

Representasi notifikasi yang dikembalikan ke client:

```json
{
  "id": "7d27e5b0-5c97-4c0c-a7cf-0f6a9f4f71a2",
  "type": "peringatan_jam_sibuk",
  "title": "Jam sibuk terdeteksi",
  "message": "Terdapat 3 jam padat pada forecast traffic 18 jam ke depan.",
  "status": "aktif",
  "readStatus": "belum_dibaca",
  "createdAt": "2026-06-08T10:00:00.000Z",
  "updatedAt": "2026-06-08T10:00:00.000Z",
  "validUntil": "2026-06-09T10:00:00.000Z"
}
```

### 4.2 Notification Overview

Ringkasan utama halaman notifikasi:

```json
{
  "activeNotifications": 18,
  "unreadNotifications": 7,
  "checkPeriodDays": 7
}
```

### 4.3 Notification Card Item

Item untuk daftar notifikasi:

```json
{
  "id": "7d27e5b0-5c97-4c0c-a7cf-0f6a9f4f71a2",
  "time": "2026-06-08T10:00:00.000Z",
  "title": "Stok mendekati habis",
  "message": "Espresso Beans hanya cukup untuk 0,8 hari.",
  "type": "peringatan_stok",
  "status": "aktif",
  "readStatus": "belum_dibaca"
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

## 6. API - Notifications

### 6.1 Get Notification Overview

`GET /api/notifications/overview`

Mengambil ringkasan card notifikasi.

#### Query Params

- `days`
  - optional
  - default: `7`

#### Behavior

- menghitung notifikasi aktif dalam periode cek
- menghitung notifikasi yang belum dibaca untuk user yang sedang login
- periode cek dipakai untuk membatasi data ringkasan pada dashboard

#### Response 200

```json
{
  "success": true,
  "message": "Notification overview fetched successfully",
  "data": {
    "activeNotifications": 18,
    "unreadNotifications": 7,
    "checkPeriodDays": 7
  }
}
```

### 6.2 Get Notification List

`GET /api/notifications`

Mengambil daftar notifikasi dalam bentuk card dengan pagination.

#### Query Params

- `page`
  - optional
  - default: `1`
- `limit`
  - optional
  - default: `10`
- `days`
  - optional
  - default: `7`
- `filter`
  - optional
  - default: `all`
  - pilihan:
    - `all`
    - `unread`
    - `peak_hour`
    - `stock`
    - `revenue`
- `status`
  - optional
  - filter berdasarkan lifecycle status notifikasi:
    - `aktif`
    - `kedaluwarsa`
    - `selesai`
    - `diarsipkan`

#### Behavior

- `filter=unread` hanya menampilkan notifikasi yang belum dibaca
- `filter=peak_hour` hanya menampilkan `NotificationType.PeakHourAlert`
- `filter=stock` hanya menampilkan `NotificationType.StockAlert`
- `filter=revenue` hanya menampilkan `NotificationType.Report`
- data diurutkan dari yang terbaru
- status baca diturunkan dari `NotificationRead`

#### Response 200

```json
{
  "success": true,
  "message": "Notification list fetched successfully",
  "data": [
    {
      "id": "7d27e5b0-5c97-4c0c-a7cf-0f6a9f4f71a2",
      "time": "2026-06-08T10:00:00.000Z",
      "title": "Stok mendekati habis",
      "message": "Espresso Beans hanya cukup untuk 0,8 hari.",
      "type": "peringatan_stok",
      "status": "aktif",
      "readStatus": "belum_dibaca"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "totalItems": 1,
    "totalPages": 1
  }
}
```

### 6.3 Get Notification Detail

`GET /api/notifications/:id`

Mengambil detail satu notifikasi.

#### Path Params

- `id`
  - UUID notification

#### Response 200

```json
{
  "success": true,
  "message": "Notification detail fetched successfully",
  "data": {
    "id": "7d27e5b0-5c97-4c0c-a7cf-0f6a9f4f71a2",
    "type": "peringatan_stok",
    "title": "Stok mendekati habis",
    "message": "Espresso Beans hanya cukup untuk 0,8 hari.",
    "status": "aktif",
    "readStatus": "belum_dibaca",
    "createdAt": "2026-06-08T10:00:00.000Z",
    "updatedAt": "2026-06-08T10:00:00.000Z",
    "validUntil": "2026-06-09T10:00:00.000Z",
    "payload": {
      "materialId": "MAT-0001",
      "coverageDays": 0.8
    }
  }
}
```

### 6.4 Mark Notification As Read

`POST /api/notifications/:id/read`

Menandai satu notifikasi sebagai sudah dibaca untuk user yang sedang login.

#### Path Params

- `id`
  - UUID notification

#### Behavior

- membuat record pada `NotificationRead` jika belum ada
- jika record sudah ada, request tetap dianggap sukses
- read time disimpan pada `readAt`

#### Response 200

```json
{
  "success": true,
  "message": "Notification marked as read",
  "data": {
    "id": "7d27e5b0-5c97-4c0c-a7cf-0f6a9f4f71a2",
    "readStatus": "dibaca",
    "readAt": "2026-06-08T10:05:00.000Z"
  }
}
```

### 6.5 Mark All Notifications As Read

`POST /api/notifications/read-all`

Menandai semua notifikasi aktif yang belum dibaca sebagai sudah dibaca untuk user yang sedang login.

#### Query Params

- `days`
  - optional
  - default: `7`

#### Behavior

- hanya memproses notifikasi dalam scope periode cek
- notifikasi yang sudah dibaca tidak diubah
- endpoint ini cocok untuk aksi bulk pada halaman notifikasi

#### Response 200

```json
{
  "success": true,
  "message": "All notifications marked as read",
  "data": {
    "updatedCount": 7
  }
}
```

### 6.6 Archive Notification

`POST /api/notifications/:id/archive`

Mengarsipkan notifikasi agar tidak muncul di tampilan default.

#### Path Params

- `id`
  - UUID notification

#### Behavior

- status lifecycle notifikasi diubah menjadi `diarsipkan`
- notifikasi tetap tersimpan untuk audit

#### Response 200

```json
{
  "success": true,
  "message": "Notification archived successfully",
  "data": {
    "id": "7d27e5b0-5c97-4c0c-a7cf-0f6a9f4f71a2",
    "status": "diarsipkan"
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

### 7.2 Notification-Specific Error Codes

- `NOTIFICATION_NOT_FOUND`
- `NOTIFICATION_READ_FAILED`
- `NOTIFICATION_ARCHIVE_FAILED`
- `NOTIFICATION_LIST_FAILED`

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

### 8.1 Get Notification Overview

- `days` opsional, default `7`

### 8.2 Get Notification List

- `page` opsional, default `1`
- `limit` opsional, default `10`
- `days` opsional, default `7`
- `filter` opsional, default `all`
- `status` opsional, harus salah satu:
  - `aktif`
  - `kedaluwarsa`
  - `selesai`
  - `diarsipkan`

### 8.3 Get Notification Detail

- `id` wajib

### 8.4 Mark Notification As Read

- `id` wajib

### 8.5 Mark All Notifications As Read

- `days` opsional, default `7`

### 8.6 Archive Notification

- `id` wajib

## 9. Notes Implementasi

- status baca sebaiknya dihitung per user, bukan global
- `NotificationStatus` digunakan untuk lifecycle notifikasi, sedangkan `readStatus` dipakai untuk kebutuhan UI
- daftar notifikasi perlu diurutkan dari yang paling baru agar kartu terbaru muncul di atas
- `payload` berguna untuk konteks tambahan, tetapi frontend tidak wajib selalu menampilkannya
- jika nanti ada kebutuhan broadcast notification atau scheduling, struktur ini tetap bisa diperluas tanpa mengubah kontrak utama halaman notifikasi
