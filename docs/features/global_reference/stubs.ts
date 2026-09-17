/**
 * Global Reference, Koba Vertical & Central Trash — TypeScript Stubs & Mock Data
 */

export interface GlobalCurrency {
  code: string;
  name: string;
  symbol: string;
  exchange_rate_bdt: number;
  is_default: boolean;
  is_active: boolean;
  updated_at: string;
}

export interface GlobalMarket {
  id: number;
  code: string;
  name: string;
  region: string | null;
  currency_code: string;
  is_active: boolean;
}

export interface GlobalPaymentMethod {
  id: number;
  code: string;
  name: string;
  scope: 'all' | 'pos' | 'online' | 'wholesale';
  category: 'cash' | 'mfs' | 'bank' | 'card' | 'credit';
  is_active: boolean;
}

export interface GlobalUnitOfMeasure {
  id: number;
  code: string;
  name: string;
  unit_type: 'quantity' | 'weight' | 'volume' | 'length';
  symbol: string;
  is_active: boolean;
}

export interface KobaProduct {
  id: number;
  tenant_id: number;
  external_id: string;
  title: string;
  brand: string | null;
  list_price_gbp: number;
  base_price_bdt: number;
  media_urls: string[];
  attributes: Record<string, unknown>;
  is_active: boolean;
  created_at: string;
}

export type KobaOrderStatus =
  | 'pending'
  | 'confirmed'
  | 'processing'
  | 'shipped'
  | 'delivered'
  | 'cancelled';

export interface KobaOrder {
  id: number;
  tenant_id: number;
  order_number: string;
  customer_phone: string;
  customer_name: string;
  shipping_address: string;
  shipping_district: string | null;
  shipping_thana: string | null;
  total_amount_bdt: number;
  total_commission_bdt: number;
  company_profit_bdt: number;
  agent_profit_bdt: number;
  status: KobaOrderStatus;
  created_at: string;
}

export interface KobaRetailSettings {
  id: number;
  tenant_id: number;
  extra_profit_user_pct: number;
  extra_profit_company_pct: number;
  cod_charge_pct: number;
  packing_fee_flat: number;
  invoice_fee_flat: number;
  gateway_fee_flat: number;
  delivery_rates: Record<string, number>;
}

export interface TrashEntry {
  id: string;
  tenant_id: number;
  entity_type: string;
  entity_id: string;
  label: string;
  module_key: string | null;
  deleted_at: string;
  deleted_by: string | null;
  payload: Record<string, unknown>;
}

export const mockCurrencies: GlobalCurrency[] = [
  {
    code: 'GBP',
    name: 'British Pound',
    symbol: '£',
    exchange_rate_bdt: 162.5,
    is_default: false,
    is_active: true,
    updated_at: '2026-09-17T12:00:00Z',
  },
  {
    code: 'USD',
    name: 'US Dollar',
    symbol: '$',
    exchange_rate_bdt: 121.0,
    is_default: false,
    is_active: true,
    updated_at: '2026-09-17T12:00:00Z',
  },
  {
    code: 'BDT',
    name: 'Bangladeshi Taka',
    symbol: '৳',
    exchange_rate_bdt: 1.0,
    is_default: true,
    is_active: true,
    updated_at: '2026-09-17T12:00:00Z',
  },
];

export const mockTrashEntries: TrashEntry[] = [
  {
    id: '123e4567-e89b-12d3-a456-426614174000',
    tenant_id: 1,
    entity_type: 'vendor',
    entity_id: '45',
    label: 'Apex Footwear Ltd',
    module_key: 'procurement_stock',
    deleted_at: '2026-09-16T14:20:00Z',
    deleted_by: 'admin@brandwala.com',
    payload: { name: 'Apex Footwear Ltd', phone: '+8801700000000' },
  },
  {
    id: '123e4567-e89b-12d3-a456-426614174001',
    tenant_id: 1,
    entity_type: 'product',
    entity_id: '108',
    label: 'Vintage Denim Jacket (Size L)',
    module_key: 'thrift',
    deleted_at: '2026-09-17T09:15:00Z',
    deleted_by: 'staff@brandwala.com',
    payload: { sku: 'TH-DNM-001', price: 1850 },
  },
];
