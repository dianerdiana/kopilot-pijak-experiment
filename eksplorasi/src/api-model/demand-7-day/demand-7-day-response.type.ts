export interface Demand7DayResponse {
  request_id: string;
  model: string;
  forecast_days: number;
  history_days_used: number;
  future_promo_context_source: string;
  warnings: any[];
  predictions: Prediction[];
}

export interface Prediction {
  rank: number;
  id_produk: string;
  nama_produk: string;
  kategori: string;
  history_days_used: number;
  current_promo_context_source: string;
  daily_forecast: DailyForecast[];
  predicted_quantity_7d: number;
  estimated_p90_quantity_7d: number;
  current_stock: number;
  incoming_stock: number;
  recommended_stock_minimum: number;
  suggested_restock_qty: number;
  risk_level: string;
  risk_score_pct: number;
}

export interface DailyForecast {
  prediction_date: string;
  horizon: number;
  predicted_units: number;
  lower_bound: number;
  upper_bound: number;
  prediction_interval_level_pct: number;
  interval_coverage_backtest_pct: number;
}
