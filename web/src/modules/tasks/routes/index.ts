import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';

const tasksRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/tasks',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff', 'viewer'],
      requireTenantContext: true,
      requiredModule: 'tasks',
    }),
    children: [
      {
        path: '',
        name: 'tasks-page',
        component: () => import('../pages/TasksPage.vue'),
        meta: {
          title: 'Tasks',
          headerTitle: 'Task Management',
        },
      },
    ],
  },
];

export default tasksRoutes;
