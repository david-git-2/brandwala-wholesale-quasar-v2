import { defineAsyncComponent } from 'vue';
import type { DashboardSlot } from 'src/modules/dashboard/types/dashboardSlot';

const WholesaleInvoiceInsights = defineAsyncComponent(
  () => import('./WholesaleInvoiceInsightsPanel.vue'),
);

export const SALES_INVOICE_DASHBOARD_SLOTS: readonly DashboardSlot[] = [
  {
    id: 'sales_invoice.ops.insights',
    scopes: ['app'],
    moduleKey: 'global_invoice',
    action: 'view',
    parentGroupKey: 'sales_invoice',
    kind: 'section',
    title: 'Invoice Pulse',
    icon: 'ph ph-receipt',
    order: 10,
    component: WholesaleInvoiceInsights,
  },
];
