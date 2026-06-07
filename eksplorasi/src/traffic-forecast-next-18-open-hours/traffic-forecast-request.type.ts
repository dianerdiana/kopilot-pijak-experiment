export interface Root {
  request_id: string;
  cutoff_time: string;
  hourly_history: HourlyHistory[];
  current_context: CurrentContext;
  calendar_context: CalendarContext[];
}

export interface HourlyHistory {
  waktu_jam: string;
  order_count: number;
  kondisi_cuaca: string;
  periode_ramadan: string;
  jenis_event: string;
  apakah_libur: number;
  apakah_ramadan: number;
  apakah_periode_gajian: number;
}

export interface CurrentContext {
  has_active_promo: number;
  active_promo_count: number;
  active_promo_mean_discount: number;
}

export interface CalendarContext {
  waktu_jam: string;
  apakah_libur: number;
  apakah_ramadan: number;
  apakah_periode_gajian: number;
  has_active_promo: number;
  active_promo_count: number;
  active_promo_mean_discount: number;
  periode_ramadan: string;
}
