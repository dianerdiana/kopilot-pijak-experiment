/*
  Warnings:

  - The values [KOPI,NON_KOPI,MAKANAN_RINGAN] on the enum `ProductCategory` will be removed. If these variants are still used in the database, this will fail.
  - The values [BESAR,REGULAR,SATUAN,500ML,1000ML] on the enum `ProductSize` will be removed. If these variants are still used in the database, this will fail.
  - The values [BOTOL,DINGIN,PANAS,MAKANAN] on the enum `ProductVariant` will be removed. If these variants are still used in the database, this will fail.
  - The values [AMAN,RESTOCK,ALERT,HABIS] on the enum `StockStatus` will be removed. If these variants are still used in the database, this will fail.
  - The values [BEKU,DINGIN,DINGIN_SETELAH_DIBUKA,SUHU_RUANG,KERING] on the enum `StorageType` will be removed. If these variants are still used in the database, this will fail.
  - The values [PASAR_TRADISIONAL,PEMASOK_ES,PEMASOK_UMUM,ROASTERY_LOKAL,TOKO_KEMASAN] on the enum `SupplierType` will be removed. If these variants are still used in the database, this will fail.
  - A unique constraint covering the columns `[id_user]` on the table `users` will be added. If there are existing duplicate values, this will fail.
  - Added the required column `id_user` to the `users` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('tunai', 'qris');

-- CreateEnum
CREATE TYPE "OrderType" AS ENUM ('makan_di_tempat', 'bawa_pulang', 'pengantaran');

-- CreateEnum
CREATE TYPE "SalesChannel" AS ENUM ('offline', 'online');

-- CreateEnum
CREATE TYPE "CustomerSegment" AS ENUM ('dosen_staff', 'mahasiswa', 'pekerja_sekitar', 'pelanggan_delivery', 'warga_sekitar');

-- CreateEnum
CREATE TYPE "DiscountType" AS ENUM ('acara', 'bundling', 'gajian', 'promo_pengantaran', 'tidak_ada');

-- AlterEnum
BEGIN;
CREATE TYPE "ProductCategory_new" AS ENUM ('kopi', 'non_kopi', 'makanan_ringan');
ALTER TABLE "products" ALTER COLUMN "category" TYPE "ProductCategory_new" USING ("category"::text::"ProductCategory_new");
ALTER TYPE "ProductCategory" RENAME TO "ProductCategory_old";
ALTER TYPE "ProductCategory_new" RENAME TO "ProductCategory";
DROP TYPE "public"."ProductCategory_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "ProductSize_new" AS ENUM ('besar', 'regular', 'satuan', '500ml', '1000ml');
ALTER TABLE "products" ALTER COLUMN "size" TYPE "ProductSize_new" USING ("size"::text::"ProductSize_new");
ALTER TYPE "ProductSize" RENAME TO "ProductSize_old";
ALTER TYPE "ProductSize_new" RENAME TO "ProductSize";
DROP TYPE "public"."ProductSize_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "ProductVariant_new" AS ENUM ('botol', 'dingin', 'panas', 'makanan');
ALTER TABLE "products" ALTER COLUMN "variant" TYPE "ProductVariant_new" USING ("variant"::text::"ProductVariant_new");
ALTER TYPE "ProductVariant" RENAME TO "ProductVariant_old";
ALTER TYPE "ProductVariant_new" RENAME TO "ProductVariant";
DROP TYPE "public"."ProductVariant_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "StockStatus_new" AS ENUM ('aman', 'restock', 'alert', 'habis');
ALTER TABLE "public"."stocks" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "stocks" ALTER COLUMN "status" TYPE "StockStatus_new" USING ("status"::text::"StockStatus_new");
ALTER TYPE "StockStatus" RENAME TO "StockStatus_old";
ALTER TYPE "StockStatus_new" RENAME TO "StockStatus";
DROP TYPE "public"."StockStatus_old";
ALTER TABLE "stocks" ALTER COLUMN "status" SET DEFAULT 'aman';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "StorageType_new" AS ENUM ('beku', 'dingin', 'dingin_setelah_dibuka', 'suhu_ruang', 'kering');
ALTER TABLE "raw_materials" ALTER COLUMN "jenis_penyimpanan" TYPE "StorageType_new" USING ("jenis_penyimpanan"::text::"StorageType_new");
ALTER TYPE "StorageType" RENAME TO "StorageType_old";
ALTER TYPE "StorageType_new" RENAME TO "StorageType";
DROP TYPE "public"."StorageType_old";
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "SupplierType_new" AS ENUM ('pasar_tradisional', 'pemasok_es', 'pemasok_umum', 'roastery_lokal', 'toko_kemasan');
ALTER TABLE "raw_materials" ALTER COLUMN "jenis_pemasok" TYPE "SupplierType_new" USING ("jenis_pemasok"::text::"SupplierType_new");
ALTER TYPE "SupplierType" RENAME TO "SupplierType_old";
ALTER TYPE "SupplierType_new" RENAME TO "SupplierType";
DROP TYPE "public"."SupplierType_old";
COMMIT;

-- AlterTable
ALTER TABLE "stocks" ALTER COLUMN "status" SET DEFAULT 'aman';

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "id_user" TEXT NOT NULL;

-- CreateTable
CREATE TABLE "orders" (
    "id" TEXT NOT NULL,
    "id_pesanan" TEXT NOT NULL,
    "waktu_pesanan" TIMESTAMP(3) NOT NULL,
    "metode_pembayaran" "PaymentMethod" NOT NULL,
    "jenis_pesanan" "OrderType" NOT NULL,
    "kanal_penjualan" "SalesChannel" NOT NULL,
    "segmen_pelanggan_estimasi" "CustomerSegment" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transaction_details" (
    "id" TEXT NOT NULL,
    "id_transaksi" TEXT NOT NULL,
    "id_pesanan" TEXT NOT NULL,
    "id_produk" TEXT NOT NULL,
    "jumlah" INTEGER NOT NULL,
    "harga_satuan" DECIMAL(10,2) NOT NULL,
    "jumlah_diskon" DECIMAL(10,2) NOT NULL,
    "diskon_diterapkan" BOOLEAN NOT NULL DEFAULT false,
    "jenis_diskon" "DiscountType" NOT NULL DEFAULT 'tidak_ada',
    "total_harga" DECIMAL(10,2) NOT NULL,
    "id_promo" TEXT NOT NULL DEFAULT 'tidak_ada',

    CONSTRAINT "transaction_details_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WeatherContext" (
    "waktu_jam" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "kondisi_cuaca" TEXT NOT NULL,
    "periode_ramadhan" BOOLEAN NOT NULL,

    CONSTRAINT "WeatherContext_pkey" PRIMARY KEY ("waktu_jam","kondisi_cuaca","periode_ramadhan")
);

-- CreateTable
CREATE TABLE "DailyContext" (
    "tanggal" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "apakah_libur" BOOLEAN NOT NULL,
    "apakah_akhir_pekan" BOOLEAN NOT NULL,
    "apakah_ramadhan" BOOLEAN NOT NULL,
    "apakah_periode_gajian" BOOLEAN NOT NULL,

    CONSTRAINT "DailyContext_pkey" PRIMARY KEY ("tanggal","apakah_libur","apakah_akhir_pekan","apakah_ramadhan","apakah_periode_gajian")
);

-- CreateIndex
CREATE UNIQUE INDEX "orders_id_pesanan_key" ON "orders"("id_pesanan");

-- CreateIndex
CREATE UNIQUE INDEX "transaction_details_id_transaksi_key" ON "transaction_details"("id_transaksi");

-- CreateIndex
CREATE UNIQUE INDEX "users_id_user_key" ON "users"("id_user");

-- AddForeignKey
ALTER TABLE "transaction_details" ADD CONSTRAINT "transaction_details_id_pesanan_fkey" FOREIGN KEY ("id_pesanan") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "transaction_details" ADD CONSTRAINT "transaction_details_id_produk_fkey" FOREIGN KEY ("id_produk") REFERENCES "products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
