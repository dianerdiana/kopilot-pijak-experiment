export interface TrafficForecastResponse {
  request_id: string;
  model: string;
  cutoff_time: string;
  forecast_open_slots: number;
  history_open_hours_used: number;
  current_promo_context_source: string;
  future_promo_context_source: string;
  warnings: string[];
  predictions: TrafficPrediction[];
  peak_window: PeakWindow;
}

export interface TrafficPrediction {
  prediction_time: string;
  prediction_hour: number;
  forecast_open_slot: number;
  predicted_order_count: number;
  lower_bound: number;
  upper_bound: number;
  interval_width: number;
  prediction_interval_level_pct: number;
  interval_coverage_backtest_pct: number;
  traffic_level: string;
}

export interface PeakWindow {
  start_time: string;
  end_time: string;
  max_predicted_order_count: number;
}

export type Root = TrafficForecastResponse;
