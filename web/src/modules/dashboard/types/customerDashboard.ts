import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';
import type { ActiveCartItem } from 'src/modules/shop_order/repositories/shopCartRepository';
import type { ShopOrderStatus } from 'src/modules/shop_order/types';

export type CustomerDashboardCategory = {
  id: number;
  name: string;
  slug: string;
  icon: string | null;
};

export type CustomerDashboardRecentOrder = {
  id: number;
  shop_id: number;
  shop_name: string;
  shop_slug: string;
  order_no: string;
  status: ShopOrderStatus;
  currency_symbol: string | null;
  created_at: string;
};

export type OrderGlanceBuckets = {
  needs_you: number;
  in_progress: number;
  done: number;
  total: number;
};

export type OrderGlanceSegments = {
  needs_you: number;
  in_progress: number;
  delivered: number;
  paid: number;
  payment_needed: number;
  total: number;
};

export type CustomerDashboardSummary = {
  tenant_id: number | null;
  customer_group_id: number | null;
  shops: CustomerAccessibleShop[];
  categories: CustomerDashboardCategory[];
  order_glance: {
    buckets: OrderGlanceBuckets;
    segments: OrderGlanceSegments;
  };
  recent_orders: CustomerDashboardRecentOrder[];
  active_carts: ActiveCartItem[];
};
