import type { RouteRecordRaw } from 'vue-router';
import authRoutes from 'src/modules/auth/routes';
import dashboardRoutes from 'src/modules/dashboard/routes';
import tenantRoutes from 'src/modules/tenant/routes';
import moduleRoutes from 'src/modules/modules/routes';

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/app/dashboard',
  },
  {
    path: '/app/home',
    redirect: '/app/dashboard',
  },
  {
    path: '/platform/home',
    redirect: '/platform/dashboard',
  },
  {
    path: '/shop/home',
    redirect: '/shop/dashboard',
  },
  ...dashboardRoutes,
  ...tenantRoutes,
  ...authRoutes,
  ...moduleRoutes,

  // Always leave this as last one
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
];

export default routes;
