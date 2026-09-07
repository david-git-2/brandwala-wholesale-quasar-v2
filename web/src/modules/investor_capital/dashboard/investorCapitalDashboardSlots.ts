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
  {
    id: 'investor_capital.shortcuts.ledger',
    scopes: ['app'],
    moduleKey: 'investor_capital_ledger',
    action: 'view',
    parentGroupKey: 'investor_capital',
    kind: 'shortcut',
    title: 'Capital Ledger',
    caption: 'Transactions & records',
    icon: 'ph ph-arrows-left-right',
    order: 20,
    routeName: 'app-capital-ledger-page',
  },
  {
    id: 'investor_capital.shortcuts.profiles',
    scopes: ['app'],
    moduleKey: 'investor_profiles',
    action: 'view',
    parentGroupKey: 'investor_capital',
    kind: 'shortcut',
    title: 'Profiles',
    caption: 'Manage investor accounts',
    icon: 'ph ph-users-three',
    order: 30,
    routeName: 'app-capital-profiles-page',
  },
];
