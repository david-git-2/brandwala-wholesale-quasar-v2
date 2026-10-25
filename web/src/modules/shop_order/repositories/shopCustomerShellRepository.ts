import { supabase } from 'src/boot/supabase';
import type { ShopLoginGroupRow } from 'src/modules/auth/utils/shopCustomerGroupSession';
import type { CustomerAccessibleShop } from './shopOrderRepository';
import type { ActiveCartItem } from './shopCartRepository';

export type ShopCustomerShellBundle = {
  active_carts: ActiveCartItem[];
  customer_shops: CustomerAccessibleShop[];
  login_groups: ShopLoginGroupRow[];
};

const normalizeLoginGroups = (rows: unknown): ShopLoginGroupRow[] => {
  const list = Array.isArray(rows) ? rows : [];
  return list.filter(
    (row): row is ShopLoginGroupRow =>
      Boolean(
        row &&
          typeof row === 'object' &&
          typeof (row as ShopLoginGroupRow).member_id === 'number' &&
          typeof (row as ShopLoginGroupRow).customer_group_id === 'number' &&
          (row as ShopLoginGroupRow).has_match !== false,
      ),
  );
};

const normalizeActiveCarts = (rows: unknown): ActiveCartItem[] => {
  const list = Array.isArray(rows) ? rows : [];
  return list.map((row: Record<string, unknown>) => ({
    cart_id: Number(row.cart_id),
    shop_id: Number(row.shop_id),
    shop_name: String(row.shop_name ?? ''),
    shop_slug: String(row.shop_slug ?? ''),
    shop_logo_url: (row.shop_logo_url as string | null) ?? null,
    shop_type: row.shop_type as ActiveCartItem['shop_type'],
    can_see_buy_price: Boolean(row.can_see_buy_price),
    can_see_sell_price: Boolean(row.can_see_sell_price),
    currency_id: row.currency_id != null ? Number(row.currency_id) : null,
    currency_code: (row.currency_code as string | null) ?? null,
    currency_symbol: (row.currency_symbol as string | null) ?? null,
    item_count: Number(row.item_count ?? 0),
    cart_total: row.cart_total != null ? Number(row.cart_total) : null,
    updated_at: String(row.updated_at ?? ''),
  }));
};

export const shopCustomerShellRepository = {
  async getBundle(tenantId: number): Promise<ShopCustomerShellBundle> {
    const { data, error } = await supabase.rpc('get_shop_customer_shell_bundle', {
      p_tenant_id: tenantId,
    });

    if (error) {
      throw error;
    }

    const payload = (data ?? {}) as Record<string, unknown>;
    return {
      active_carts: normalizeActiveCarts(payload.active_carts),
      customer_shops: (payload.customer_shops as CustomerAccessibleShop[] | null) ?? [],
      login_groups: normalizeLoginGroups(payload.login_groups),
    };
  },
};
