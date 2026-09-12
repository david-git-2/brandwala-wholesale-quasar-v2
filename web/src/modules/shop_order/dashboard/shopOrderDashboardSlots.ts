import { defineAsyncComponent } from 'vue';
import type { DashboardSlot } from 'src/modules/dashboard/types/dashboardSlot';

const ShopOrderCard = defineAsyncComponent(() => import('./ShopOrderCard.vue'));

export const SHOP_ORDER_DASHBOARD_SLOTS: readonly DashboardSlot[] = [
  {
    id: 'shop_order.ops.insights',
    scopes: ['app'],
    moduleKey: 'shop_order',
    action: 'view',
    parentGroupKey: 'shop_order',
    kind: 'section',
    title: 'Shop orders',
    icon: 'ph ph-storefront',
    order: 10,
    workspaceKinds: ['child'],
    component: ShopOrderCard,
  },
];
