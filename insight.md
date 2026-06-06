Berikut adalah rancangan struktur tabel dan *field* lengkap untuk database Anda. Desain ini menyatukan data master, manajemen stok, logika kedaluwarsa, serta menyertakan tabel transaksi penjualan (opsional namun krusial) agar alur perhitungan `stok_terpakai` harian bisa berjalan otomatis.

Saya menambahkan satu kolom penting pada tabel penerimaan, yaitu **`sisa_stok_batch`**, yang akan menjadi kunci utama sistem dalam menjalankan pemotongan stok berbasis **FIFO (First In First Out)**.

---

### 1. Kelompok Data Master (Master Data)

#### Tabel: `produk`

Menyimpan informasi utama mengenai produk jadi yang dijual.

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id` | INT | PK, Auto Increment | ID internal database |
| `kode_produk` | VARCHAR(50) | UNIQUE, INDEX | ID Bisnis (misal: PROD-001), di-*mapping* sebagai `id_produk` di tabel resep |
| `nama_produk` | VARCHAR(150) | NOT NULL | Nama menu/produk |
| `kategori` | VARCHAR(100) |  | Kategori (Coffee, Non-Coffee, Pastry, dll) |
| `varian` | VARCHAR(100) |  | Varian rasa/tipe |
| `ukuran` | VARCHAR(50) |  | Ukuran (Regular, Large, 250ml, dll) |
| `harga_dasar` | DECIMAL(15,2) | NOT NULL | Harga modal/HPP dasar produk |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Waktu data dibuat |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP ON UPDATE | Waktu data diubah |

#### Tabel: `bahan_baku`

Menyimpan profil dasar dari setiap bahan mentah.

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id` | INT | PK, Auto Increment | ID internal database |
| `kode_bahan` | VARCHAR(50) | UNIQUE, INDEX | ID Bisnis (misal: B001), di-*mapping* sebagai `id_bahan` |
| `nama_bahan` | VARCHAR(150) | NOT NULL | Nama bahan baku (Kopi Arabika, Susu UHT, dll) |
| `satuan` | VARCHAR(20) | NOT NULL | Satuan ukuran (gram, ml, pcs) |
| `biaya_per_satuan` | DECIMAL(15,2) |  | Harga beli rata-rata per satuan |
| `jenis_pemasok` | VARCHAR(100) |  | Kategori pemasok (Lokal, Distributor Utama, dll) |
| `umur_simpan_belum_dibuka_hari` | INT |  | Masa kedaluwarsa sejak datang (dalam hari) |
| `umur_simpan_setelah_dibuka_hari` | INT |  | Masa kedaluwarsa setelah segel dibuka (dalam hari) |
| `jenis_penyimpanan` | VARCHAR(100) |  | Kondisi simpan (Chiller, Suhu Ruang, Freezer) |
| `titik_pemesanan_ulang` | DECIMAL(12,3) |  | *Safety stock* / Batas minimum untuk re-order |

#### Tabel: `resep_produk`

Menghubungkan produk dengan bahan baku yang dibutuhkan (*Many-to-Many Relationship*).

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id` | INT | PK, Auto Increment | ID internal database |
| `id_produk` | VARCHAR(50) | FK (`produk.kode_produk`) | Kode produk terkait |
| `id_bahan` | VARCHAR(50) | FK (`bahan_baku.kode_bahan`) | Kode bahan baku yang digunakan |
| `jumlah_dibutuhkan` | DECIMAL(12,3) | NOT NULL | Jumlah bahan baku untuk 1 porsi produk |

---

### 2. Kelompok Manajemen Stok & Inventori

#### Tabel: `penerimaan_stok`

Mencatat setiap kali ada bahan baku masuk ke gudang beserta informasi *batch* dan kedaluwarsanya.

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id_penerimaan` | VARCHAR(50) | PK | ID Transaksi Penerimaan (misal: RCV000001) |
| `tanggal_penerimaan` | DATE | NOT NULL | Tanggal bahan diterima di gudang |
| `id_bahan` | VARCHAR(50) | FK (`bahan_baku.kode_bahan`) | Kode bahan baku yang diterima |
| `jumlah_diterima` | DECIMAL(12,3) | NOT NULL | Jumlah awal yang masuk (cth: 87417.074) |
| **`sisa_stok_batch`** | DECIMAL(12,3) | NOT NULL | **PENTING UNTUK FIFO:** Sisa riil *batch* ini yang bisa dipakai. Nilai berkurang saat terjual/expired |
| `biaya_per_satuan` | DECIMAL(15,2) | NOT NULL | Harga beli per satuan pada transaksi ini |
| `nama_pemasok` | VARCHAR(150) |  | Nama supplier/vendor |
| `id_batch` | VARCHAR(50) | INDEX | Kode produksi/lot dari supplier (misal: BAT000001) |
| `tanggal_dibuka` | DATE | NULLABLE | Diisi tanggal saat segel bahan pertama kali dibuka |
| `tanggal_expired_belum_dibuka` | DATE | NOT NULL | Tanggal expired standar |
| `tanggal_expired_setelah_dibuka` | DATE | NULLABLE | Hasil hitung: `tanggal_dibuka` + `umur_simpan_setelah_dibuka_hari` |
| `tanggal_expired_efektif` | DATE | NOT NULL | Tanggal terdekat antara belum/setelah dibuka. Menjadi acuan utama sistem |

#### Tabel: `snapshot_stok_harian`

Tempat penyimpanan rangkuman stok harian hasil kalkulasi otomatis sistem (*Cron Job*).

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `tanggal` | DATE | PK (Composite) | Tanggal pencatatan log (Y-M-D) |
| `id_bahan` | VARCHAR(50) | PK (Composite), FK | Kode bahan baku yang dicatat |
| `stok_awal` | DECIMAL(12,3) | NOT NULL | Sisa `stok_akhir` hari sebelumnya |
| `stok_masuk` | DECIMAL(12,3) | DEFAULT 0 | Total dari `jumlah_diterima` di tabel penerimaan hari ini |
| `stok_terpakai` | DECIMAL(12,3) | DEFAULT 0 | Total bahan yang terpakai untuk pesanan hari ini |
| `stok_terbuang` | DECIMAL(12,3) | DEFAULT 0 | Bahan yang rusak/hilang/otomatis dibuang karena *expired* |
| `stok_akhir` | DECIMAL(12,3) | NOT NULL | Rumus: `stok_awal` + `stok_masuk` - `stok_terpakai` - `stok_terbuang` |
| `flag_stok_habis` | TINYINT(1) | DEFAULT 0 | 1 jika `stok_akhir` = 0, berguna untuk alert cepat |
| `flag_hampir_expired` | TINYINT(1) | DEFAULT 0 | 1 jika ada *batch* aktif yang mendekati `tanggal_expired_efektif` |

---

### 3. Kelompok Transaksi Penjualan (Direkomendasikan)

*Tabel ini opsional, namun sistem Anda memerlukan data penjualan ini untuk memicu pemotongan resep harian secara otomatis ke dalam `stok_terpakai`.*

#### Tabel: `penjualan`

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id_penjualan` | VARCHAR(50) | PK | Nomor struk/invoice (misal: INV-20260606-001) |
| `tanggal_penjualan` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Waktu transaksi kasir |
| `total_harga` | DECIMAL(15,2) |  | Total bayar konsumen |

#### Tabel: `detail_penjualan`

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id` | INT | PK, Auto Increment | ID unik baris |
| `id_penjualan` | VARCHAR(50) | FK (`penjualan.id_penjualan`) | Menghubungkan ke struk utama |
| `id_produk` | VARCHAR(50) | FK (`produk.kode_produk`) | Kode menu yang dibeli |
| `jumlah_terjual` | INT | NOT NULL | Kuantitas menu yang dibeli (cth: 2 cup) |

---

### Tips Relasi untuk Developer:

1. **PK Composite pada Snapshot:** Tabel `snapshot_stok_harian` menggunakan *Composite Primary Key* gabungan dari `tanggal` dan `id_bahan`. Artinya, kombinasi data `2024-07-01` + `B001` tidak akan bisa terduplikasi.
2. **Skema Deserialisasi FIFO:** Saat ada transaksi masuk ke `detail_penjualan`, sistem aplikasi Anda harus melihat ke tabel `penerimaan_stok`, mengurutkan berdasarkan `tanggal_expired_efektif ASC` yang memiliki `sisa_stok_batch > 0`, lalu memotong angka pada `sisa_stok_batch` tersebut sebanding dengan perkalian `jumlah_terjual` $\times$ `jumlah_dibutuhkan`.