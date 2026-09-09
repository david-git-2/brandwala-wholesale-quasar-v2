import { defineAsyncComponent } from 'vue';
import type { DashboardSlot } from 'src/modules/dashboard/types/dashboardSlot';

const TasksInsights = defineAsyncComponent(() => import('./TasksInsightsPanel.vue'));

export const TASKS_DASHBOARD_SLOTS: readonly DashboardSlot[] = [
  {
    id: 'tasks.ops.insights',
    scopes: ['app'],
    moduleKey: 'tasks',
    action: 'view',
    parentGroupKey: 'tasks',
    kind: 'section',
    title: 'Operational Taskboard',
    icon: 'ph ph-clipboard-text',
    order: 10,
    component: TasksInsights,
  },
];
