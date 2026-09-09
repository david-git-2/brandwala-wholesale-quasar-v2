import { defineAsyncComponent } from 'vue';
import type { DashboardSlot } from 'src/modules/dashboard/types/dashboardSlot';

const AfterSalesInsights = defineAsyncComponent(() => import('./AfterSalesInsightsPanel.vue'));

/** Parent desk: policy owner, network-wide case queues, wholesale approvals. */
export const AFTER_SALES_DASHBOARD_SLOTS: readonly DashboardSlot[] = [
  {
    id: 'after_sales.ops.insights',
    scopes: ['app'],
    moduleKey: 'after_sales',
    action: 'view',
    parentGroupKey: 'after_sales',
    kind: 'section',
    title: 'After Sales Service',
    icon: 'ph ph-headset',
    order: 10,
    workspaceKinds: ['parent'],
    component: AfterSalesInsights,
  },
];
