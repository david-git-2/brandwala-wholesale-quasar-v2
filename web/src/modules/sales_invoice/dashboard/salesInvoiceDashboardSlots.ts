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
  {
    id: 'sales_invoice.shortcuts.list',
    scopes: ['app'],
    moduleKey: 'global_invoice',
    action: 'view',
    parentGroupKey: 'sales_invoice',
    kind: 'shortcut',
    title: 'Invoices Ledger',
    caption: 'Desk & wholesale invoices',
    icon: 'ph ph-receipt',
    order: 20,
    routeName: 'app-global-invoices-page',
  },
  {
    id: 'sales_invoice.shortcuts.create',
    scopes: ['app'],
    moduleKey: 'global_invoice',
    action: 'create',
    parentGroupKey: 'sales_invoice',
    kind: 'shortcut',
    title: 'Create Invoice',
    caption: 'Issue wholesale invoice',
    icon: 'ph ph-plus-circle',
    order: 30,
    routeName: 'app-global-invoices-create-wholesale',
  },
];
