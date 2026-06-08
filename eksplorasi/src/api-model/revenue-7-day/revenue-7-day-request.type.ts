export interface Revenue7DayRequest {
  request_id: string;
  cutoff_date: string;
  forecast_days: number;
  daily_revenue_history: DailyRevenueHistory[];
  calendar_context: CalendarContext[];
}

export interface DailyRevenueHistory {
  tanggal: string;
  revenue: number;
  order_count: number;
  items_sold: number;
  discount_total: number;
}

export interface CalendarContext {
  tanggal: string;
  is_holiday: number;
  is_ramadhan_periode: number;
  is_payday_periode: number;
  has_active_promo: number;
  active_promo_count: number;
  active_promo_mean_discount: number;
  condition?: string;
}
