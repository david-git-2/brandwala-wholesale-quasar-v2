import type { ActiveCartItem } from 'src/modules/shop_order/repositories/shopCartRepository';
import type { CustomerAccessibleShop } from 'src/modules/shop_order/repositories/shopOrderRepository';
import { orderGlanceBucket } from '../utils/customerDashboardStatus';

export type ShopPortalStat = {
  pendingOrders: number;
  cartItems: number;
};

export const buildShopPortalStats = (
  shops: CustomerAccessibleShop[],
  activeCarts: ActiveCartItem[],
  orders: Array<{ shop_id: number; status: string }>,
): Record<number, ShopPortalStat> => {
  const stats: Record<number, ShopPortalStat> = {};

  for (const shop of shops) {
    stats[shop.id] = { pendingOrders: 0, cartItems: 0 };
  }

  for (const cart of activeCarts) {
    const shopId = Number(cart.shop_id);
    if (!stats[shopId]) {
      stats[shopId] = { pendingOrders: 0, cartItems: 0 };
    }
    stats[shopId].cartItems += Number(cart.item_count ?? 0);
  }

  for (const order of orders) {
    const bucket = orderGlanceBucket(order.status);
    if (!bucket || bucket === 'done') continue;
    const shopId = Number(order.shop_id);
    if (!stats[shopId]) {
      stats[shopId] = { pendingOrders: 0, cartItems: 0 };
    }
    stats[shopId].pendingOrders += 1;
  }

  return stats;
};
