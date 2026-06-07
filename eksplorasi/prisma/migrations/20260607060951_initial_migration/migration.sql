-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('SUPER_ADMIN', 'MANAGER');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'INACTIVE');

-- CreateEnum
CREATE TYPE "StockUnit" AS ENUM ('ml', 'gr', 'pcs');

-- CreateEnum
CREATE TYPE "PredictionType" AS ENUM ('REVENUE_FORECAST', 'TRAFFIC_FORECAST', 'DEMAND_FORECAST', 'DEMAND_RECOMMENDATION');

-- CreateEnum
CREATE TYPE "ProductCategory" AS ENUM ('KOPI', 'NON_KOPI', 'MAKANAN_RINGAN');

-- CreateEnum
CREATE TYPE "ProductVariant" AS ENUM ('BOTOL', 'DINGIN', 'PANAS', 'MAKANAN');

-- CreateEnum
CREATE TYPE "ProductSize" AS ENUM ('BESAR', 'REGULAR', 'SATUAN', '500ML', '1000ML');

-- CreateEnum
CREATE TYPE "SupplierType" AS ENUM ('PASAR_TRADISIONAL', 'PEMASOK_ES', 'PEMASOK_UMUM', 'ROASTERY_LOKAL', 'TOKO_KEMASAN');

-- CreateEnum
CREATE TYPE "StorageType" AS ENUM ('BEKU', 'DINGIN', 'DINGIN_SETELAH_DIBUKA', 'SUHU_RUANG', 'KERING');

-- CreateEnum
CREATE TYPE "StockStatus" AS ENUM ('AMAN', 'RESTOCK', 'ALERT', 'HABIS');

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "status" "UserStatus" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "products" (
    "id" TEXT NOT NULL,
    "product_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "variant" "ProductVariant" NOT NULL,
    "category" "ProductCategory" NOT NULL,
    "size" "ProductSize" NOT NULL,
    "price" DECIMAL(10,2) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_ingredients" (
    "id" TEXT NOT NULL,
    "product_id" TEXT NOT NULL,
    "stock_id" TEXT NOT NULL,
    "quantity_per_unit" DECIMAL(10,3) NOT NULL,

    CONSTRAINT "product_ingredients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "raw_materials" (
    "id" TEXT NOT NULL,
    "id_bahan" TEXT NOT NULL,
    "nama_bahan" TEXT NOT NULL,
    "satuan" "StockUnit" NOT NULL,
    "biaya_per_satuan" DECIMAL(10,2) NOT NULL,
    "jenis_pemasok" "SupplierType" NOT NULL,
    "umur_simpan_belum_dibuka_hari" INTEGER NOT NULL,
    "umur_simpan_sudah_dibuka_hari" INTEGER NOT NULL,
    "jenis_penyimpanan" "StorageType" NOT NULL,
    "reorder_point" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "raw_materials_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stocks" (
    "id" TEXT NOT NULL,
    "materialId" TEXT NOT NULL,
    "current_quantity" INTEGER NOT NULL,
    "minimum_quantity" INTEGER NOT NULL,
    "ketahanan_hari" INTEGER NOT NULL,
    "status" "StockStatus" NOT NULL DEFAULT 'AMAN',
    "last_updated" TIMESTAMP(3) NOT NULL,
    "rawMaterialId" TEXT,

    CONSTRAINT "stocks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_receipts" (
    "id" TEXT NOT NULL,
    "id_penerimaan" TEXT NOT NULL,
    "id_bahan" TEXT NOT NULL,
    "jumlah_diterima" INTEGER NOT NULL,
    "biaya_per_satuan" DECIMAL(10,2) NOT NULL,
    "tanggal_penerimaan" DATE NOT NULL,
    "nama_pemasok" TEXT NOT NULL,
    "id_batch" TEXT NOT NULL,
    "sisa_stock_batch" INTEGER NOT NULL,
    "tanggal_dibuka" DATE,
    "tanggal_expired_belum_dibuka" DATE,
    "tanggal_expired_setelah_dibuka" DATE,
    "tanggal_expired_efektif" DATE,

    CONSTRAINT "stock_receipts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "daily_stock_snapshots" (
    "id" TEXT NOT NULL,
    "stock_id" TEXT NOT NULL,
    "stock_awal" INTEGER NOT NULL,
    "stock_masuk" INTEGER NOT NULL,
    "stock_terpakai" INTEGER NOT NULL,
    "stock_terbuang" INTEGER NOT NULL,
    "stock_akhir" INTEGER NOT NULL,
    "flag_stok_habis" BOOLEAN NOT NULL,
    "flag_hampir_expired" BOOLEAN NOT NULL,
    "tanggal_snapshot" DATE NOT NULL,

    CONSTRAINT "daily_stock_snapshots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "predictions" (
    "id" TEXT NOT NULL,
    "store_id" TEXT NOT NULL,
    "type" "PredictionType" NOT NULL,
    "cutoff_date" DATE NOT NULL,
    "cutoff_hour" INTEGER,
    "model_version" TEXT NOT NULL,
    "response_data" JSONB NOT NULL,
    "normalized_summary" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "predictions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "products_product_id_key" ON "products"("product_id");

-- CreateIndex
CREATE INDEX "products_product_id_idx" ON "products"("product_id");

-- CreateIndex
CREATE UNIQUE INDEX "products_variant_category_size_key" ON "products"("variant", "category", "size");

-- CreateIndex
CREATE UNIQUE INDEX "product_ingredients_product_id_stock_id_key" ON "product_ingredients"("product_id", "stock_id");

-- CreateIndex
CREATE UNIQUE INDEX "raw_materials_id_bahan_key" ON "raw_materials"("id_bahan");

-- CreateIndex
CREATE UNIQUE INDEX "raw_materials_nama_bahan_key" ON "raw_materials"("nama_bahan");

-- CreateIndex
CREATE UNIQUE INDEX "stock_receipts_id_penerimaan_key" ON "stock_receipts"("id_penerimaan");

-- CreateIndex
CREATE UNIQUE INDEX "predictions_store_id_type_cutoff_date_cutoff_hour_key" ON "predictions"("store_id", "type", "cutoff_date", "cutoff_hour");

-- AddForeignKey
ALTER TABLE "product_ingredients" ADD CONSTRAINT "product_ingredients_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_ingredients" ADD CONSTRAINT "product_ingredients_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "stocks"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stocks" ADD CONSTRAINT "stocks_rawMaterialId_fkey" FOREIGN KEY ("rawMaterialId") REFERENCES "raw_materials"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "daily_stock_snapshots" ADD CONSTRAINT "daily_stock_snapshots_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "stocks"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
