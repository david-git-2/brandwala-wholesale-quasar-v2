import { defineAsyncComponent } from 'vue';
import type { DashboardSlot } from 'src/modules/dashboard/types/dashboardSlot';

const InvestorCapitalInsights = defineAsyncComponent(
  () => import('./InvestorCapitalInsightsPanel.vue'),
);

export const INVESTOR_CAPITAL_DASHBOARD_SLOTS: readonly DashboardSlot[] = [
  {
    id: 'investor_capital.ops.insights',
    scopes: ['app'],
    moduleKey: 'investor_capital_ledger',
    action: 'view',
    parentGroupKey: 'investor_capital',
    kind: 'section',
    title: 'Capital Pool Pulse',
    icon: 'ph ph-piggy-bank',
    order: 10,
    component: InvestorCapitalInsights,
  },
];
