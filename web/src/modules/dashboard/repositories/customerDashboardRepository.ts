import { supabase } from 'src/boot/supabase';
import type { ActiveCartItem } from 'src/modules/shop_order/repositories/shopCartRepository';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';
import type {
  CustomerDashboardCategory,
  CustomerDashboardRecentOrder,
  CustomerDashboardSummary,
  OrderGlanceBuckets,
  OrderGlanceSegments,
} from '../types/customerDashboard';

const emptyBuckets = (): OrderGlanceBuckets => ({
  needs_you: 0,
  in_progress: 0,
  done: 0,
  total: 0,
});

const emptySegments = (): OrderGlanceSegments => ({
  needs_you: 0,
  in_progress: 0,
  delivered: 0,
  paid: 0,
  payment_needed: 0,
  total: 0,
});

const parseSummary = (raw: unknown, tenantId: number): CustomerDashboardSummary => {
  const data = (raw ?? {}) as Record<string, unknown>;
  const orderGlance = (data.order_glance ?? {}) as Record<string, unknown>;

  return {
    tenant_id: (data.tenant_id as number | null) ?? tenantId,
    customer_group_id: (data.customer_group_id as number | null) ?? null,
    shops: (data.shops as CustomerAccessibleShop[] | null) ?? [],
    categories: (data.categories as CustomerDashboardCategory[] | null) ?? [],
    order_glance: {
      buckets: { ...emptyBuckets(), ...((orderGlance.buckets as OrderGlanceBuckets | null) ?? {}) },
      segments: { ...emptySegments(), ...((orderGlance.segments as OrderGlanceSegments | null) ?? {}) },
    },
    recent_orders: (data.recent_orders as CustomerDashboardRecentOrder[] | null) ?? [],
    active_carts: ((data.active_carts as ActiveCartItem[] | null) ?? []).map((row) => ({
      ...row,
      cart_id: Number(row.cart_id),
      shop_id: Number(row.shop_id),
      item_count: Number(row.item_count),
      cart_total: row.cart_total == null ? null : Number(row.cart_total),
    })),
  };
};

const getCustomerDashboardSummary = async (tenantId: number): Promise<CustomerDashboardSummary> => {
  const { data, error } = await supabase.rpc('get_customer_dashboard_summary', {
    p_tenant_id: tenantId,
  });

  if (error) throw error;
  return parseSummary(data, tenantId);
};

export const customerDashboardRepository = {
  getCustomerDashboardSummary,
};
