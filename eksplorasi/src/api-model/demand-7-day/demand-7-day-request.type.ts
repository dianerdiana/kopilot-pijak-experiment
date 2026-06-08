export interface Demand7DayRequest {
  request_id: string;
  cutoff_date: string;
  stock_buffer_pct: number;
  business_minimum: number;
  products: Product[];
  calendar_context: CalendarContext[];
}

export interface Product {
  id_produk: string;
  nama_produk: string;
  kategori: string;
  varian: string;
  ukuran: string;
  harga_dasar: number;
  current_stock: number;
  incoming_stock: number;
  current_context?: CurrentContext;
  daily_history?: DailyHistory[];
}

export interface CurrentContext {
  has_active_promo: number;
  active_promo_count: number;
  active_promo_mean_discount: number;
  product_has_active_promo: number;
  product_active_promo_count: number;
  product_active_promo_mean_discount: number;
}

export interface DailyHistory {
  tanggal: string;
  units_sold: number;
  product_revenue: number;
  product_order_count: number;
  product_discount_total: number;
  apakah_ramadan: number;
}

export interface CalendarContext {
  tanggal: string;
  id_produk: any;
  apakah_libur: number;
  apakah_ramadan: number;
  apakah_periode_gajian: number;
  has_active_promo: number;
  active_promo_count: number;
  active_promo_mean_discount: number;
  product_has_active_promo: number;
  product_active_promo_count: number;
  product_active_promo_mean_discount: number;
}
