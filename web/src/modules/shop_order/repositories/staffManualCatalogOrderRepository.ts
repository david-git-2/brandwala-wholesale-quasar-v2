import { supabase } from 'src/boot/supabase';
import { shopOrderRepository } from './shopOrderRepository';

export type StaffCatalogOrderCreateMode = 'standard' | 'old_order';

export interface StaffCatalogOrderLineInput {
  product_id: number;
  quantity: number;
  sell_price_amount?: number;
  cost_price_amount?: number;
}

export interface StaffCatalogOrderRatesInput {
  conversion_rate: number;
  cargo_rate: number;
  profit_rate: number;
  first_offer_rate?: number;
  final_offer_rate?: number;
  profit_basis: 'purchase' | 'total_cost';
}

export interface StaffCatalogOrderSubmitResult {
  order_id: number;
  order_no: string;
  status: string;
  billing_profile_warning?: boolean;
}

const resolveVendorCatalogShopForCreate = async (opts: {
  tenantId: number;
  parentTenantId?: number | null;
  customerGroupId: number;
  selectedShopId?: number | null;
  knownVendorCatalogShopIds?: number[];
}): Promise<number> => {
  if (opts.selectedShopId != null && opts.selectedShopId > 0) {
    return opts.selectedShopId;
  }

  const linkedIds = new Set<number>();
  const { data: accessRows, error: accessError } = await supabase
    .from('shop_customer_group_access')
    .select('shop_id')
    .eq('customer_group_id', opts.customerGroupId)
    .eq('status', true);
  if (accessError) throw accessError;
  for (const row of accessRows ?? []) {
    if (row.shop_id != null) linkedIds.add(row.shop_id);
  }

  const pickVendorCatalogFromIds = async (ids: number[]): Promise<number | null> => {
    if (ids.length === 0) return null;
    const { data: shopRows, error } = await supabase
      .from('shops')
      .select('id')
      .in('id', ids)
      .eq('shop_type', 'vendor_catalog')
      .eq('is_active', true)
      .is('deleted_at', null)
      .order('id', { ascending: true })
      .limit(1);
    if (error) throw error;
    return shopRows?.[0]?.id ?? null;
  };

  const fromGroup = await pickVendorCatalogFromIds([...linkedIds]);
  if (fromGroup != null) return fromGroup;

  const known = [...(opts.knownVendorCatalogShopIds ?? [])].sort((a, b) => a - b);
  if (known.length > 0) {
    const fromKnown = await pickVendorCatalogFromIds(known);
    if (fromKnown != null) return fromKnown;
  }

  const shops = await shopOrderRepository.listShops(opts.tenantId, {
    parentTenantId: opts.parentTenantId ?? null,
    active: true,
  });
  const tenantCatalogIds = shops
    .filter((s) => s.shop_type === 'vendor_catalog')
    .map((s) => s.id)
    .sort((a, b) => a - b);
  if (tenantCatalogIds.length > 0) return tenantCatalogIds[0]!;

  throw new Error(
    'No vendor catalog shop is linked to this customer group. Link a shop in customer access settings, or pick a shop (optional) before creating the order.',
  );
};

const createOrder = async (
  shopId: number,
  customerGroupId: number,
  items: StaffCatalogOrderLineInput[],
  payload: {
    recordedAt: string;
    hiddenFromCustomer?: boolean;
    createMode?: StaffCatalogOrderCreateMode;
    initialStatus?: string;
    rates?: StaffCatalogOrderRatesInput;
  },
): Promise<StaffCatalogOrderSubmitResult> => {
  const mode = payload.createMode ?? 'standard';
  const ratesPayload =
    mode === 'old_order' && payload.rates
      ? (() => {
          const profitPct = payload.rates.profit_rate;
          return {
            conversion_rate: payload.rates.conversion_rate,
            cargo_rate: payload.rates.cargo_rate,
            profit_rate: profitPct,
            first_offer_rate: profitPct,
            final_offer_rate: profitPct,
            profit_basis: payload.rates.profit_basis,
          };
        })()
      : null;

  const { data, error } = await supabase.rpc('staff_create_vendor_catalog_order', {
    p_shop_id: shopId,
    p_customer_group_id: customerGroupId,
    p_items: items,
    p_order_name: null,
    p_profile_id: null,
    p_recorded_at: payload.recordedAt,
    p_hidden_from_customer: payload.hiddenFromCustomer ?? true,
    p_create_mode: mode,
    p_initial_status: mode === 'old_order' ? (payload.initialStatus ?? 'procuring') : null,
    p_rates: ratesPayload,
  });
  if (error) throw error;
  return data as StaffCatalogOrderSubmitResult;
};

export const staffManualCatalogOrderRepository = {
  createOrder,
  resolveVendorCatalogShopForCreate,
};
