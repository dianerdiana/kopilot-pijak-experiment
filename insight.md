Berikut adalah rancangan struktur tabel dan *field* lengkap untuk database Anda. Desain ini menyatukan data master, manajemen stok, logika kedaluwarsa, serta menyertakan tabel transaksi penjualan (opsional namun krusial) agar alur perhitungan `stok_terpakai` harian bisa berjalan otomatis.

Saya menambahkan satu kolom penting pada tabel penerimaan, yaitu **`sisa_stok_batch`**, yang akan menjadi kunci utama sistem dalam menjalankan pemotongan stok berbasis **FIFO (First In First Out)**.

---

### 1. Kelompok Data Master (Master Data)

#### Tabel: `produk`

Menyimpan informasi utama mengenai produk jadi yang dijual.

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id` | INT | PK, Auto Increment | ID internal database |
| `id_produk` | VARCHAR(50) | UNIQUE, INDEX | ID produk P001-P021. |
| `nama_produk` | VARCHAR(150) | NOT NULL | Nama menu. |
| `kategori` | ENUM('kopi', 'makanan_ringan', 'non_kopi') |  | Kategori: kopi, non_kopi, makanan_ringan. |
| `varian` | ENUM('botolan', 'dingin', 'makanan', 'panas') |  | Varian: panas, dingin, botolan, makanan. |
| `ukuran` | ENUM('1000ml', '500ml', 'large', 'regular', 'satuan') |  | Ukuran menu. |
| `harga_dasar` | DECIMAL(15,2) | NOT NULL | Harga dasar produk dalam rupiah. |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Waktu data dibuat |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP ON UPDATE | Waktu data diubah |

#### Tabel: `bahan_baku`

Menyimpan profil dasar dari setiap bahan mentah.

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id` | INT | PK, Auto Increment | ID internal database |
| `id_bahan` | VARCHAR(50) | UNIQUE, INDEX | ID bahan B001 dst. |
| `nama_bahan` | VARCHAR(150) | NOT NULL | Nama bahan atau packaging. |
| `satuan` | ENUM('gram', 'ml', 'pcs') | NOT NULL | Satuan: gram, ml, pcs. |
| `biaya_per_satuan` | DECIMAL(15,2) |  | Harga bahan per satuan dalam rupiah. |
| `jenis_pemasok` | ENUM('pasar_tradisional', 'pemasok_es', 'pemasok_umum', 'roastery_lokal', 'toko_kemasan') |  | Kategori pemasok: roastery_lokal, pemasok_umum, pasar_tradisional, toko_kemasan, pemasok_es, produksi_sendiri. |
| `umur_simpan_belum_dibuka_hari` | INT |  | Umur simpan batch sebelum dibuka. |
| `umur_simpan_setelah_dibuka_hari` | INT |  | Umur simpan setelah dibuka. |
| `jenis_penyimpanan` | ENUM('beku', 'dingin', 'dingin_setelah_dibuka', 'kering', 'suhu_ruang') |  | Cara simpan bahan. |
| `titik_pemesanan_ulang` | DECIMAL(12,3) |  | Batas minimum stok untuk restock alert. |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Waktu data dibuat |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP ON UPDATE | Waktu data diubah |

#### Tabel: `resep_produk`

Menghubungkan produk dengan bahan baku yang dibutuhkan (*Many-to-Many Relationship*).

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id` | INT | PK, Auto Increment | ID internal database |
| `id_produk` | VARCHAR(50) | FK (`produk.id_produk`) | Produk yang membutuhkan bahan. |
| `id_bahan` | VARCHAR(50) | FK (`bahan_baku.id_bahan`) | Bahan yang digunakan. |
| `jumlah_dibutuhkan` | DECIMAL(12,3) | NOT NULL | Jumlah bahan untuk 1 unit produk, mengikuti satuan bahan. |

---

### 2. Kelompok Manajemen Stok & Inventori

#### Tabel: `penerimaan_stok`

Mencatat setiap kali ada bahan baku masuk ke gudang beserta informasi *batch* dan kedaluwarsanya.

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id` | INT | PK, Auto Increment | ID internal database |
| `id_penerimaan` | VARCHAR(50) | UNIQUE, INDEX | ID penerimaan stok. |
| `tanggal_penerimaan` | DATE | NOT NULL | Tanggal bahan masuk. |
| `id_bahan` | VARCHAR(50) | FK (`bahan_baku.id_bahan`) | Bahan yang diterima. |
| `jumlah_diterima` | DECIMAL(12,3) | NOT NULL | Jumlah diterima sesuai satuan bahan. |
| **`sisa_stok_batch`** | DECIMAL(12,3) | NOT NULL | **PENTING UNTUK FIFO:** Sisa riil *batch* ini yang bisa dipakai. Nilai berkurang saat terjual/expired |
| `biaya_per_satuan` | DECIMAL(15,2) | NOT NULL | Biaya batch per satuan. |
| `nama_pemasok` | ENUM('Grosir Bahan Tamalanrea', 'Pasar Daya Makassar', 'Roastery Lokal Makassar', 'Supplier Es Batu Makassar', 'Toko Kemasan Perintis') |  | Nama pemasok sintetis. |
| `id_batch` | VARCHAR(50) | INDEX | ID batch stok. |
| `tanggal_dibuka` | DATE | NULLABLE | Tanggal batch dibuka; kosong jika belum dibuka. |
| `tanggal_expired_belum_dibuka` | DATE | NOT NULL | Expired jika belum dibuka. |
| `tanggal_expired_setelah_dibuka` | DATE | NULLABLE | Expired setelah dibuka. |
| `tanggal_expired_efektif` | DATE | NOT NULL | Tanggal expired final yang dipakai. |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Waktu data dibuat |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP ON UPDATE | Waktu data diubah |

#### Tabel: `snapshot_stok_harian`

Tempat penyimpanan rangkuman stok harian hasil kalkulasi otomatis sistem (*Cron Job*).

| Nama Field | Tipe Data | Atribut | Keterangan |
| --- | --- | --- | --- |
| `id` | INT | PK, Auto Increment | ID internal database |
| `tanggal` | DATE | NOT NULL, INDEX | Tanggal snapshot. |
| `id_bahan` | VARCHAR(50) | FK (`bahan_baku.id_bahan`) | Bahan yang diukur. |
| `stok_awal` | DECIMAL(12,3) | NOT NULL | Stok awal hari. |
| `stok_masuk` | DECIMAL(12,3) | DEFAULT 0 | Stok masuk hari itu. |
| `stok_terpakai` | DECIMAL(12,3) | DEFAULT 0 | Stok dipakai dari transaksi x resep. |
| `stok_terbuang` | DECIMAL(12,3) | DEFAULT 0 | Stok waste/expired/spoilage sintetis. |
| `stok_akhir` | DECIMAL(12,3) | NOT NULL | Stok akhir hari. |
| `flag_stok_habis` | TINYINT(1) | DEFAULT 0 | 1 jika stok akhir di bawah/mendekati titik pemesanan ulang. |
| `flag_hampir_expired` | TINYINT(1) | DEFAULT 0 | 1 jika ada risiko mendekati expired. |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Waktu data dibuat |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP ON UPDATE | Waktu data diubah |

---


### Tips Relasi untuk Developer:

1. **Unique Constraint pada Snapshot:** Tabel `snapshot_stok_harian` menggunakan `id` sebagai *Primary Key* tunggal, namun memiliki *Composite Unique Key/Constraint* gabungan dari `tanggal` dan `id_bahan`. Artinya, kombinasi data `2024-07-01` + `B001` tidak akan bisa terduplikasi.
2. **Skema Deserialisasi FIFO:** Saat ada transaksi masuk ke `detail_penjualan`, sistem aplikasi Anda harus melihat ke tabel `penerimaan_stok`, mengurutkan berdasarkan `tanggal_expired_efektif ASC` yang memiliki `sisa_stok_batch > 0`, lalu memotong angka pada `sisa_stok_batch` tersebut sebanding dengan perkalian `jumlah_terjual` $\times$ `jumlah_dibutuhkan`.