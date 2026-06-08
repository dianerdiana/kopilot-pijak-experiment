## Keputusan Strategi Inference untuk Seluruh Model

Berdasarkan karakter output, use case bisnis, dan siklus operasional kedai, ini strategi terbaik untuk **masing-masing** dari 4 model kamu.

---

## Model 03 — Revenue Forecast H+7

### Keputusan: **2x seminggu (Senin + Jumat)**

### Alasan

1. **Revenue itu metrik agregat — 1 angka per hari** — Berbeda dengan demand yang 21 produk × 7 hari, revenue forecast cuma menghasilkan 7 angka prediksi. Perubahannya dari hari ke hari tidak drastis karena pola mingguan kedai sangat konsisten.

2. **Keputusan berbasis revenue bersifat strategis, bukan taktis** — Kamu tidak ubah target omzet tiap hari. Kamu set di awal minggu, lalu cek ulang sebelum weekend. Dua momen ini (Senin = planning, Jumat = pre-weekend check) yang paling kritis.

3. **WMAPE 13.19% cukup stabil** — Bahkan forecast yang dibuat Senin untuk Jumat masih reasonable. Tidak perlu di-update tiap hari karena improvement-nya marginal.

### Flowchart

```mermaid
graph TD
    SEN["🌅 SENIN PAGI<br/>Revenue Forecast DIPANGGIL"]
    SEN --> SEN_A["Model generate:<br/>Prediksi omzet Senin-Minggu<br/>7 angka + interval ketidakpastian"]
    SEN_A --> SEN_B{"Total prediksi minggu ini<br/>vs target bulanan?"}
    SEN_B -->|On track| SEN_C["✅ Lanjut seperti biasa"]
    SEN_B -->|Di bawah target| SEN_D["⚠️ Pertimbangkan:<br/>Aktifkan promo / evaluasi menu"]

    SEN_C --> WEEKDAY["Selasa - Kamis<br/>🚫 Tidak perlu panggil model<br/>Fokus ke operasional harian"]
    SEN_D --> WEEKDAY

    WEEKDAY --> JUM["🌅 JUMAT PAGI<br/>Revenue Forecast DIPANGGIL ULANG"]
    JUM --> JUM_A["Model generate:<br/>Prediksi omzet Jumat-Minggu<br/>(sudah diupdate data Senin-Kamis)"]
    JUM_A --> JUM_B{"Forecast weekend<br/>naik atau turun dari Senin?"}
    JUM_B -->|Naik stabil| JUM_C["✅ Pastikan staf & stok cukup<br/>Tidak perlu promo"]
    JUM_B -->|Turun drastis| JUM_D["🚨 Aktifkan promo weekend<br/>Tambah staf shift ramai<br/>Push notification pelanggan"]

    style SEN fill:#4CAF50,color:white
    style JUM fill:#4CAF50,color:white
    style WEEKDAY fill:#9E9E9E,color:white
```

### Kapan Outputnya Dipakai

| Momen      | Output yang Dipakai     | Keputusan Bisnis                                                 |
| ---------- | ----------------------- | ---------------------------------------------------------------- |
| Senin pagi | Total prediksi 7 hari   | Set target mingguan, planning cashflow                           |
| Senin pagi | Prediksi per hari       | Kalau ada hari yang sangat rendah → timing promo                 |
| Jumat pagi | Prediksi Jumat-Minggu   | Final check: cukup stok? Perlu promo?                            |
| Jumat pagi | Interval ketidakpastian | Kalau interval lebar → ada ketidakpastian besar → siapkan plan B |

---

## Model 04 — Product Demand Forecast H+7

### Keputusan: **Setiap hari (7x seminggu) — WAJIB**

### Alasan

1. **Langsung menentukan berapa bahan baku yang dipesan** — Ini bukan angka yang cuma "dilihat", ini angka yang langsung dieksekusi jadi pesanan ke supplier. Pesanan salah = stockout atau waste.

2. **Bahan baku cepat basi butuh keputusan harian** — Susu (3-5 hari), Croissant (1-2 hari). Tidak bisa pesan 7 hari sekali.

3. **21 produk × 7 hari = 147 prediksi yang bisa berubah** — Setiap hari ada data baru masuk, demand per produk lebih volatile daripada total revenue. WMAPE 21.34% artinya perlu update terus supaya akurasinya terjaga.

4. **Outputnya sudah berupa action layer** — Model ini tidak cuma prediksi, tapi juga menghasilkan `recommended_stock_minimum` dan `demand_ingredient_requirements`. Artinya outputnya langsung bisa dieksekusi jadi pesanan.

### ⚠️ PENTING: Cara Baca Output-nya

**JANGAN** pesan bahan baku untuk 7 hari sekaligus berdasarkan satu forecast. Gunakan strategi **rolling window**:

| Horizon         | Peran       | Tindakan                                                                                  |
| --------------- | ----------- | ----------------------------------------------------------------------------------------- |
| **H+1**         | ✅ EKSEKUSI | Pesan bahan cepat basi (susu, roti) untuk **hari ini**                                    |
| **H+2**         | ✅ SIAP     | Pesan bahan yang butuh prep 1 hari (roti dari bakery)                                     |
| **H+3 s/d H+7** | 👁️ PANTAU   | Early signal — kalau naik tajam, komunikasi awal ke supplier. **TAPI jangan pesan dulu.** |

### Flowchart

```mermaid
graph TD
    PAGI["🌅 SETIAP PAGI (05:00)<br/>Demand Forecast DIPANGGIL"]
    PAGI --> GEN["Model generate:<br/>21 produk × 7 hari prediksi<br/>+ recommended stock minimum<br/>+ kebutuhan bahan baku"]

    GEN --> H1["📦 H+1 = HARI INI<br/>Eksekusi pesanan"]
    H1 --> H1A["Pesan susu segar<br/>Pesan bahan cepat basi<br/>Siapkan stok harian"]

    GEN --> H2["📋 H+2 = BESOK<br/>Siapkan pesanan"]
    H2 --> H2A["Pesan roti dari bakery<br/>Prep bahan yang butuh<br/>perendaman/fermentasi"]

    GEN --> H3["👁️ H+3 s/d H+7<br/>Early signal only"]
    H3 --> H3A{"Ada spike demand<br/>di H+5 s/d H+7?"}
    H3A -->|Ya| H3B["📞 Komunikasi awal<br/>ke supplier: 'Besok/besoknya<br/>butuh tambahan'"]
    H3A -->|Tidak| H3C["Tidak perlu tindakan<br/>Tunggu forecast besok"]

    H1A --> CHECK{"Hari apa hari ini?"}
    CHECK -->|Senin-Kamis| NORMAL["Operasi normal<br/>Besok pagi panggil ulang"]
    CHECK -->|Jumat| JUMAT["⭐ HARI KRITIS<br/>H+1=Sabtu, H+2=Minggu<br/>PANGGIL BESAR!<br/>Pesan susu & roti untuk weekend"]
    CHECK -->|Sabtu| SABTU["Monitor aktual vs prediksi<br/>Kalau demand melebihi forecast<br/>→ pesan darurat untuk Minggu"]

    style PAGI fill:#4CAF50,color:white
    style JUMAT fill:#FF5722,color:white
    style H3 fill:#FFF9C4
```

### Output yang Dipakai Per Hari

| File Output                                      | Kapan Dipakai | Untuk Apa                                |
| ------------------------------------------------ | ------------- | ---------------------------------------- |
| `demand_next_7_days.csv`                         | Setiap pagi   | Cek H+1 untuk pesanan hari ini           |
| `demand_ingredient_requirements_next_7_days.csv` | Setiap pagi   | Konversi demand → kebutuhan bahan baku   |
| `demand_top_products_next_7_days.csv`            | Jumat pagi    | Fokus stok untuk top products di weekend |

---

## Model 05 — Hourly Traffic Forecast H+18

### Keputusan: **Setiap awal hari operasional (1x/hari) + Optional mid-day refresh**

### Alasan

1. **Horizon cuma 18 jam (1 hari operasional)** — Artinya setiap pagi kamu butuh prediksi baru karena prediksi kemarin sudah expired. Tidak bisa di-skip.

2. **Penggunaan utama: staffing & shift planning** — Kamu butuh tahu jam berapa puncaknya hari ini buat ngatur barista. Ini keputusan yang harus diambil **sebelum buka**.

3. **Tidak perlu lebih sering dari 1x/hari** — Karena cuaca dan promo biasanya tidak berubah di tengah hari. Tapi kalau ada event mendadak (misal hujan deras), bisa di-refresh siang.

4. **Berbeda dari model H+7** — Traffic model ini tidak ada overlap antar hari. Setiap forecast hanya berlaku untuk 1 hari. Jadi jelas **harus dipanggil tiap pagi**.

### Flowchart

```mermaid
graph TD
    PAGI["🌅 SETIAP PAGI (05:00)<br/>Traffic Forecast DIPANGGIL"]
    PAGI --> GEN["Model generate:<br/>18 slot jam (06:00-23:00)<br/>Prediksi order per jam<br/>+ peak window<br/>+ traffic level<br/>+ staffing signal"]

    GEN --> PEAK["🕐 Identifikasi Peak Window<br/>Jam berapa paling ramai?"]
    PEAK --> PEAK_A{"Peak di jam berapa?"}
    PEAK_A -->|"Pagi 08:00-09:00"| MORNING["Staffing pagi:<br/>Barista utama shift pagi<br/>Siapkan stok breakfast combo"]
    PEAK_A -->|"Sore 16:00-19:00"| AFTERNOON["Staffing sore:<br/>Tambah barista shift sore<br/>Siapkan stok menu populer"]
    PEAK_A -->|"Double peak"| BOTH["Double shift:<br/>Barista pagi DAN sore<br/>Ini hari ramai!"]

    GEN --> LEVEL["📊 Traffic Level"]
    LEVEL -->|Low| LOW["Normal staffing<br/>1 barista + 1 kasir"]
    LEVEL -->|Medium| MED["Standby 1 barista tambahan<br/>Siap kalau naik"]
    LEVEL -->|High| HIGH["Full team on deck<br/>2 barista + 1 kasir<br/>Antisipasi antrean"]

    BOTH --> MID["☀️ SIANG HARI (Optional)"]
    MED --> MID
    MID --> MID_A{"Ada perubahan<br/>cuaca / event mendadak?"}
    MID_A -->|Ya| MID_B["🔄 Refresh forecast<br/>Update staffing sore"]
    MID_A -->|Tidak| MID_C["Tetap pakai<br/>forecast pagi"]

    style PAGI fill:#4CAF50,color:white
    style HIGH fill:#FF5722,color:white
    style MID fill:#FFF9C4
```

### Output yang Dipakai

| Output                          | Keputusan Bisnis                                        |
| ------------------------------- | ------------------------------------------------------- |
| Prediksi per jam                | Jumlah barista per shift                                |
| Peak window (jam teramai)       | Waktu istirahat staf diatur di luar peak                |
| Traffic level (low/medium/high) | Siapkan take-away cup, stok additional                  |
| Staffing signal                 | Direct decision: perlu panggil staf tambahan atau tidak |

---

## Model 06 — Product Association

### Keputusan: **1x per bulan (batch refresh)**

### Alasan

1. **Ini BUKAN model forecasting** — Tidak ada prediksi masa depan. Ini lookup table berbasis aturan asosiasi (rule-based). Cukup dibangun ulang secara periodik.

2. **Pola belanja pelanggan berubah lambat** — Hubungan "Roti Bakar Coklat + Cafe Latte Hot" tidak berubah dari minggu ke minggu. Butuh bulanan agar ada cukup data baru yang bisa menggeser pola.

3. **Dipakai di checkout/rekomendasi — real-time tapi datanya statis** — Backend cuma baca CSV lookup, tidak perlu panggil model setiap kali. Artinya biaya computasinya nyaris nol di runtime.

4. **Dari kodemu sendiri** — Metadata association merekomendasikan: `"recommended_production_refresh": "weekly or monthly batch refresh"`.

### Kapan perlu refresh lebih cepat?

| Trigger                      | Aksi                                                       |
| ---------------------------- | ---------------------------------------------------------- |
| Menu baru ditambahkan        | Refresh association (karena produk baru belum punya rule)  |
| Menu dihapus/dinonaktifkan   | Refresh association (hapus rule yang refer ke produk mati) |
| Promo bundling besar selesai | Refresh setelah 2 minggu data baru masuk                   |
| Tidak ada perubahan menu     | Refresh rutin tiap bulan                                   |

### Flowchart

```mermaid
graph TD
    MONTHLY["📅 AWAL BULAN<br/>Association Analysis DIPANGGIL<br/>(Batch refresh)"]
    MONTHLY --> REBUILD["Rebuild association rules:<br/>4 active rules<br/>51 fallback recommendations<br/>Promo bundle candidates"]
    REBUILD --> DEPLOY["Deploy ke backend API<br/>CSV lookup table di-update"]
    DEPLOY --> DAILY["Harian: Backend baca lookup table<br/>tanpa panggil model lagi"]

    DAILY --> CHECK{"Ada perubahan menu<br/>atau promo besar?"}
    CHECK -->|Tidak| NEXT["Tunggu refresh bulan depan"]
    CHECK -->|Ya - Menu baru| EMERGENCY["🚨 Refresh darurat<br/>Karena produk baru<br/>belum punya rekomendasi"]
    CHECK -->|Ya - Menu dihapus| EMERGENCY2["🚨 Refresh darurat<br/>Hapus rule yang refer<br/>ke produk mati"]

    style MONTHLY fill:#2196F3,color:white
    style DAILY fill:#9E9E9E,color:white
    style EMERGENCY fill:#FF5722,color:white
    style EMERGENCY2 fill:#FF5722,color:white
```

### Output yang Dipakai

| File Output                      | Kapan Dipakai               | Untuk Apa                                                         |
| -------------------------------- | --------------------------- | ----------------------------------------------------------------- |
| `cross_sell_recommendations.csv` | Real-time di checkout       | "Beli Roti Bakar Coklat? Tambah Cafe Latte Hot diskon 15%"        |
| `fallback_recommendations.csv`   | Real-time di product detail | Produk tanpa rule → rekomendasikan produk populer lintas kategori |
| `promo_bundle_candidates.csv`    | Saat planning promo bulanan | "Bundle Sarapan: Roti Bakar + Kopi, bundling Tea-Time, dll"       |

---

## Ringkasan: Semua Model dalam Satu Minggu

```mermaid
graph LR
    subgraph "SENIN"
        S1["📊 Revenue Forecast ✅"]
        S2["📦 Demand Forecast ✅"]
        S3["🚦 Traffic Forecast ✅"]
    end

    subgraph "SELASA - KAMIS"
        SK1["📊 Revenue — 🚫 skip"]
        SK2["📦 Demand Forecast ✅"]
        SK3["🚦 Traffic Forecast ✅"]
    end

    subgraph "JUMAT ⭐"
        J1["📊 Revenue Forecast ✅"]
        J2["📦 Demand Forecast ✅<br/>PESANAN BESAR WEEKEND"]
        J3["🚦 Traffic Forecast ✅"]
    end

    subgraph "SABTU - MINGGU"
        WE1["📊 Revenue — 🚫 skip"]
        WE2["📦 Demand Forecast ✅"]
        WE3["🚦 Traffic Forecast ✅"]
    end

    subgraph "AWAL BULAN"
        M1["🔗 Association Refresh ✅<br/>(Batch rebuild)"]
    end
```

### Tabel Keputusan Final

| Model                 | Frekuensi     | Hari Wajib   | Biaya/bulan   | Alasan Utama                                     |
| --------------------- | ------------- | ------------ | ------------- | ------------------------------------------------ |
| **03 - Revenue H+7**  | **2x/minggu** | Senin, Jumat | ~8 inference  | Keputusan strategis, tidak berubah tiap hari     |
| **04 - Demand H+7**   | **7x/minggu** | Setiap hari  | ~30 inference | Langsung menentukan pesanan bahan baku           |
| **05 - Traffic H+18** | **7x/minggu** | Setiap hari  | ~30 inference | Staffing harian, expired setiap 18 jam           |
| **06 - Association**  | **1x/bulan**  | Awal bulan   | 1 batch       | Lookup table statis, pola belanja berubah lambat |

### Total pemanggilan model per bulan: ~69 inference + 1 batch refresh

Ini sangat efisien. Model XGBoost yang kamu pakai bisa inferensi dalam hitungan detik per panggilan, jadi total beban komputasi per bulan kurang dari **5 menit**.
