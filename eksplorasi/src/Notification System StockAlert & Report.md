# Notification System: StockAlert & Report

Dokumen ini menjelaskan:

- jenis notifikasi sistem
- sumber data notifikasi
- trigger notifikasi
- format pesan
- penyimpanan notifikasi
- penyajian notifikasi ke frontend
- API-spec internal
- alur pengiriman notifikasi

---

# 1. Tujuan

Tujuan sistem notifikasi adalah memberikan informasi ketika terjadi perubahan data transaksi yang mempengaruhi stok dan operasional bisnis.

Jenis notifikasi:

- StockAlert
- Report

---

# 2. Sumber Data Utama

## 2.1 Model yang Dipakai

- Stock
- RawMaterial
- Order
- TransactionDetail
- DailyStockSnapshot

## 2.2 Data yang Diambil

- status stok
- jumlah stok
- transaksi terbaru
- revenue transaksi
- histori snapshot

---

# 3. Alur Besar Proses

1. Upload transaksi.
2. Update Stock.
3. Cek Status Stock.
4. Generate Notification.
5. Insert Notification.
6. Frontend Fetch Notification.

---

# 4. Trigger Notification

## 4.1 Trigger StockAlert

- stok rendah
- stok habis
- stok perlu restock

## 4.2 Trigger Report

- upload transaksi berhasil
- upload transaksi gagal

## 4.3 Output

- pesan notifikasi
- timestamp
- kategori notifikasi

---

# 5. Struktur Notification

## 5.1 Bentuk Payload

```json
{
  "type": "StockAlert",
  "title": "Low Stock",
  "message": "Stok Susu UHT tersisa 5 liter",
  "priority": "HIGH",
  "channel": "IN_APP",
  "status": "ACTIVE",
  "payload": {
    "materialId": "MAT001",
    "currentQuantity": 5
  },
  "createdAt": "2026-06-01T10:00:00Z"
}
```

---

## 5.2 Field

- type
- title
- message
- createdAt

---

# 6. Mapping Database ke Notification

## 6.1 Mapping StockAlert

Sumber:

- Stock
- RawMaterial

---

## 6.2 Mapping Report

Sumber:

- Order
- TransactionDetail

---

## 6.3 Mapping Quantity

Field:

```text
Stock.currentQuantity
```

---

## 6.4 Mapping Material

Field:

```text
RawMaterial.name
```

---

# 7. Context Retrieval

## 7.1 Stock Context

Mengambil stok terbaru.

---

## 7.2 Transaction Context

Mengambil transaksi yang baru diproses.

---

## 7.3 Snapshot Context

Mengambil perubahan stok.

---

## 7.4 Material Context

Mengambil nama bahan baku.

---

# 8. Normalisasi Data

## 8.1 Tujuan

- format pesan konsisten
- payload konsisten

## 8.2 Mapping

```text
camelCase -> camelCase
```

---

## 8.3 Contoh

```ts
currentQuantity
-> currentQuantity
```

---

# 9. Tipe Notifikasi

## 9.1 StockAlert

Kategori:

- Low
- Restock
- OutOfStock

---

## 9.2 Report

Kategori:

- Upload Success
- Upload Failed

---

# 10. Penyimpanan Notifikasi

## 10.1 Tujuan

- histori notifikasi
- audit sistem

## 10.2 Data yang Disimpan

- type
- title
- message
- createdAt

## 10.3 Catatan

Notifikasi disimpan ke tabel Notification dan status baca user dicatat melalui NotificationRead.

---

# 11. Trigger Logic

## 11.1 Low Stock

```ts
currentQuantity <= minimumQuantity;
```

Pesan:

```text
[StockAlert]

Stok hampir habis.
Segera lakukan restock.
```

---

## 11.2 Out Of Stock

```ts
currentQuantity <= 0;
```

Pesan:

```text
[StockAlert]

Stok habis.
Penjualan dapat terganggu.
```

---

## 11.3 Upload Success

Pesan:

```text
[Report]

Upload transaksi berhasil diproses.
```

---

## 11.4 Upload Failed

Pesan:

```text
[Report]

Upload transaksi gagal diproses.
```

---

# 12. Mapping untuk Frontend

## 12.1 Notification List

Field:

- title
- message
- createdAt

---

## 12.2 Badge Counter

Field:

- unreadCount

---

## 12.3 Notification Detail

Field:

- type
- title
- message

---

# 13. API-Spec Internal

## 13.1 Endpoint

```http
GET /api/notifications
```

---

## 13.2 Response

```json
{
  "notifications": []
}
```

---

## 13.3 Read Notification

```http
PATCH /api/notifications/:id/read
```

---

## 13.4 Error Response

```json
{
  "success": false
}
```

---

## 13.5 Behavior

- generate notification
- save notification
- push ke frontend

---

# 14. Ringkasan Mapping Teknis

## 14.1 Database ke Notification

- Stock -> StockAlert
- TransactionDetail -> Report

## 14.2 Notification ke Frontend

- notification list
- badge
- alert panel

## 14.3 Frontend Display

- popup
- notification center
- dashboard alert

---

# 15. Catatan Implementasi

- notifikasi dibuat setelah transaksi selesai diproses
- notifikasi tidak boleh mengganggu transaksi utama
- gunakan async job jika volume transaksi tinggi
- payload notifikasi harus ringan dan mudah dirender
