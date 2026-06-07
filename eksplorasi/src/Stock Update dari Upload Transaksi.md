# Stock Update dari Upload Transaksi

Dokumen ini menjelaskan:

- sumber data yang dipakai saat upload transaksi
- proses pengurangan stok akibat transaksi
- cara menghitung kebutuhan bahan baku
- update status stok
- penyimpanan histori stok
- mapping ke frontend
- API-spec internal upload transaksi
- alur proses update stok

---

# 1. Tujuan

Tujuan proses ini adalah memastikan stok bahan baku selalu mencerminkan kondisi aktual setelah transaksi penjualan diproses.

Proses ini digunakan untuk:

- menjaga akurasi stok
- menghitung penggunaan bahan baku
- menentukan status stok
- menghasilkan histori pergerakan stok
- memicu notifikasi stok

---

# 2. Sumber Data Utama

## 2.1 Model yang Dipakai

- Order
- TransactionDetail
- Product
- ProductIngredient
- Stock
- RawMaterial
- DailyStockSnapshot

## 2.2 Inti Data yang Diambil

- transaksi penjualan dari TransactionDetail
- data pesanan dari Order
- resep produk dari ProductIngredient
- stok bahan baku dari Stock
- informasi bahan baku dari RawMaterial

---

# 3. Alur Besar Proses

1. User upload data transaksi.
2. Sistem melakukan validasi data.
3. Data Order dibuat.
4. Data TransactionDetail dibuat.
5. Sistem mengambil resep produk.
6. Sistem menghitung bahan baku yang digunakan.
7. Sistem mengurangi stok.
8. Sistem memperbarui status stok.
9. Sistem membuat DailyStockSnapshot.
10. Sistem memicu notifikasi.

---

# 4. Trigger Proses

## 4.1 Trigger Utama

Proses berjalan ketika:

- upload transaksi berhasil
- transaksi baru dibuat manual
- sinkronisasi transaksi POS selesai

## 4.2 Tujuan Trigger

- update stok otomatis
- menjaga konsistensi inventori
- menghasilkan histori penggunaan bahan

## 4.3 Output

- update Stock
- insert DailyStockSnapshot
- trigger Notification

---

# 5. Request Upload Transaksi

## 5.1 Bentuk Request

```json
{
  "orderId": "ORD001",
  "items": [
    {
      "productId": "PRD001",
      "quantity": 2
    }
  ]
}
```

## 5.2 Field Utama

- orderId
- productId
- quantity

---

# 6. Mapping Database ke Perhitungan Stok

## 6.1 Mapping Produk

Sumber:

- Product
- ProductIngredient

Field:

- productId
- stockId
- quantityPerUnit

---

## 6.2 Cara Menghitung Penggunaan Bahan

Rumus:

```text
usedStock = quantityPerUnit * quantitySold
```

Contoh:

```text
Espresso = 20 gr
Terjual = 3

Penggunaan = 60 gr
```

---

## 6.3 Mapping Stock

Sumber:

- Stock

Field:

- currentQuantity
- minimumQuantity
- status

---

## 6.4 Cara Mengurangi Stock

Rumus:

```text
newQuantity =
currentQuantity - usedStock
```

---

## 6.5 Mapping Raw Material

Sumber:

- RawMaterial

Field:

- materialId
- reorderPoint

Digunakan untuk menentukan status stok.

---

# 7. Context Retrieval dari Database

## 7.1 Product Context

Mengambil seluruh ProductIngredient berdasarkan productId.

---

## 7.2 Stock Context

Mengambil stok aktif dari Stock.

---

## 7.3 Material Context

Mengambil informasi reorder point dari RawMaterial.

---

## 7.4 Snapshot Context

Mengambil snapshot terakhir jika diperlukan.

---

# 8. Normalisasi Data

## 8.1 Tujuan

- konsistensi data
- validasi quantity
- validasi relasi produk

## 8.2 Prinsip Mapping

Database:

```text
camelCase
```

Frontend:

```text
camelCase
```

---

## 8.3 Contoh Mapping

```ts
ProductIngredient.quantityPerUnit
-> quantityPerUnit

Stock.currentQuantity
-> currentQuantity
```

---

# 9. Hasil Perhitungan

## 9.1 Output

- usedStock
- remainingStock
- stockStatus

---

## 9.2 Contoh

```json
{
  "materialId": "MAT001",
  "usedStock": 50,
  "remainingStock": 120
}
```

---

# 10. Penyimpanan Hasil

## 10.1 Update Stock

Field:

- currentQuantity
- status
- lastUpdated

---

## 10.2 Insert DailyStockSnapshot

Field:

- beginningStock
- usedStock
- endingStock
- snapshotDate

---

## 10.3 Tujuan Snapshot

- histori stok
- analitik penggunaan bahan
- audit

---

# 11. Update Status Stock

## 11.1 Field yang Dipakai

- currentQuantity
- minimumQuantity

---

## 11.2 Mapping Status

- Sufficient
- Restock
- Low
- OutOfStock

---

## 11.3 Logika

```ts
if (currentQuantity <= 0) status = OutOfStock;
else if (currentQuantity <= minimumQuantity) status = Low;
else if (currentQuantity <= reorderPoint) status = Restock;
else status = Sufficient;
```

---

# 12. Mapping untuk Frontend

## 12.1 Stock Dashboard

Field:

- currentQuantity
- status
- resilienceDays

---

## 12.2 Material Table

Field:

- materialName
- stock
- status

---

## 12.3 Snapshot Chart

Field:

- stockAwal
- stockTerpakai
- stockAkhir

---

# 13. API-Spec Internal

## 13.1 Endpoint

```http
POST /api/transactions/upload
```

---

## 13.2 Request

```json
{
  "fileId": "transaction.csv"
}
```

---

## 13.3 Response

```json
{
  "success": true,
  "updatedStocks": 12,
  "processedTransactions": 250
}
```

---

## 13.4 Error Response

```json
{
  "success": false,
  "errorCode": "TRANSACTION_PROCESS_FAILED"
}
```

---

## 13.5 Behavior

- insert Order
- insert TransactionDetail
- productIngredient
- RawMaterial
- update Stock
- insert Snapshot
- trigger Notification

---

# 14. Ringkasan Mapping Teknis

## 14.1 Database ke Process

- TransactionDetail -> quantity sold
- ProductIngredient -> recipe
- Stock -> stock source

## 14.2 Process ke Database

- update Stock
- insert DailyStockSnapshot

## 14.3 Database ke Frontend

- stock dashboard
- stock analytics
- inventory monitoring

---

# 15. Catatan Implementasi

- update stok harus dalam database transaction
- rollback jika salah satu proses gagal
- snapshot dibuat setelah update stok berhasil
- notifikasi dipicu setelah commit berhasil
