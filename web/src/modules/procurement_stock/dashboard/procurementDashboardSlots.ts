import { defineAsyncComponent } from 'vue';
import type { DashboardSlot } from 'src/modules/dashboard/types/dashboardSlot';

const ProcurementStockCard = defineAsyncComponent(
  () => import('./ProcurementStockCard.vue'),
);

export const PROCUREMENT_DASHBOARD_SLOTS: readonly DashboardSlot[] = [
  {
    id: 'procurement.ops.insights',
    scopes: ['app'],
    moduleKey: 'global_stock',
    action: 'view',
    parentGroupKey: 'global_stock',
    kind: 'section',
    title: 'Stock & procurement',
    icon: 'ph ph-package',
    order: 10,
    workspaceKinds: ['parent'],
    component: ProcurementStockCard,
  },
];
