export interface Revenue7DayResponse {
  request_id: string;
  model: string;
  forecast_days: number;
  history_days_used: number;
  warnings: string[];
  predictions: RevenuePrediction[];
  summary: RevenueSummary;
}

export interface RevenuePrediction {
  tanggal: string;
  predicted_revenue: number;
  lower_bound: number;
  upper_bound: number;
  confidence_score: number;
}

export interface RevenueSummary {
  total_forecast_revenue: number;
  average_daily_revenue: number;
  peak_revenue_date: string;
  peak_revenue_value: number;
}
