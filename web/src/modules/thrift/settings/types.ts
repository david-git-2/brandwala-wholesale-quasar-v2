export interface ThriftSettings {
  tenant_id: number;
  default_origin_unit_price: number;
  hand_tag_unit_cost?: number | null;
  hand_tag_unit_currency_id?: number | null;
  sticker_unit_cost?: number | null;
  sticker_unit_currency_id?: number | null;
  created_at: string;
  updated_at: string;
}

export interface ThriftSettingsInput {
  defaultOriginUnitPrice: number;
  handTagUnitCost?: number | null;
  handTagUnitCurrencyId?: number | null;
  stickerUnitCost?: number | null;
  stickerUnitCurrencyId?: number | null;
}
