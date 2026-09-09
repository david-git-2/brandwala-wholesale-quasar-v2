import { defineAsyncComponent } from 'vue';
import type { DashboardSlot } from 'src/modules/dashboard/types/dashboardSlot';

const WalletTreasuryInsights = defineAsyncComponent(
  () => import('./WalletTreasuryInsightsPanel.vue'),
);

export const WALLET_DASHBOARD_SLOTS: readonly DashboardSlot[] = [
  {
    id: 'wallet.ops.insights',
    scopes: ['app'],
    moduleKey: 'universal_wallet',
    action: 'view',
    parentGroupKey: 'universal_wallet',
    kind: 'section',
    title: 'Treasury & Liquidity',
    icon: 'ph ph-wallet',
    order: 10,
    component: WalletTreasuryInsights,
  },
];
