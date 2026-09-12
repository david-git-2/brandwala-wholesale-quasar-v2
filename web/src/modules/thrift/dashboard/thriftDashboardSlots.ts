import { defineAsyncComponent } from 'vue';

import type { DashboardSlot } from 'src/modules/dashboard/types/dashboardSlot';

const ThriftDashboardActions = defineAsyncComponent(
  () => import('./ThriftDashboardActions.vue'),
);
const ThriftInsightsPanel = defineAsyncComponent(() => import('./ThriftInsightsPanel.vue'));

/** Thrift ops home: action bar and shop glance card. */
export const THRIFT_DASHBOARD_SLOTS: readonly DashboardSlot[] = [
  {
    id: 'thrift.ops.actions',
    scopes: ['app'],
    moduleKey: 'thrift_sales',
    action: 'view',
    parentGroupKey: 'thrift',
    kind: 'section',
    title: 'Actions',
    icon: 'ph ph-lightning',
    order: 5,
    component: ThriftDashboardActions,
  },
  {
    id: 'thrift.ops.insights',
    scopes: ['app'],
    moduleKey: 'thrift_reports',
    action: 'view',
    parentGroupKey: 'thrift',
    kind: 'section',
    title: 'Shop glance',
    icon: 'ph ph-chart-pie-slice',
    order: 10,
    component: ThriftInsightsPanel,
  },
];
