import type {
  CustomerDashboardRecentOrder,
  OrderGlanceSegments,
} from '../types/customerDashboard';

/** UI-only placeholders until dashboard orders are wired to the API. */
export const MOCK_ORDER_GLANCE_SEGMENTS: OrderGlanceSegments = {
  needs_you: 2,
  in_progress: 5,
  delivered: 8,
  paid: 10,
  payment_needed: 2,
  total: 27,
};

export const MOCK_RECENT_ORDERS: CustomerDashboardRecentOrder[] = [
  {
    id: 1042,
    shop_id: 1,
    shop_name: 'Main Store',
    shop_slug: 'main',
    order_no: 'ORD-1042',
    status: 'priced',
    currency_symbol: '৳',
    created_at: '2026-09-08T10:30:00Z',
  },
  {
    id: 1038,
    shop_id: 1,
    shop_name: 'Main Store',
    shop_slug: 'main',
    order_no: 'ORD-1038',
    status: 'confirmed',
    currency_symbol: '৳',
    created_at: '2026-09-07T14:15:00Z',
  },
  {
    id: 1031,
    shop_id: 2,
    shop_name: 'Outlet Shop',
    shop_slug: 'outlet',
    order_no: 'ORD-1031',
    status: 'shipped',
    currency_symbol: '৳',
    created_at: '2026-09-06T09:00:00Z',
  },
  {
    id: 1024,
    shop_id: 1,
    shop_name: 'Main Store',
    shop_slug: 'main',
    order_no: 'ORD-1024',
    status: 'delivered',
    currency_symbol: '৳',
    created_at: '2026-09-04T16:45:00Z',
  },
  {
    id: 1019,
    shop_id: 2,
    shop_name: 'Outlet Shop',
    shop_slug: 'outlet',
    order_no: 'ORD-1019',
    status: 'payment_received',
    currency_symbol: '৳',
    created_at: '2026-09-02T11:20:00Z',
  },
];
