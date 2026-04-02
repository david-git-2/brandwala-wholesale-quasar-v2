import type { RouteRecordRaw } from 'vue-router';
import authRoutes from 'src/modules/auth/routes';
import dashboardRoutes from 'src/modules/dashboard/routes';
import tenantRoutes from 'src/modules/tenant/routes';
import featureCatalogRoutes from 'src/modules/featureCatalog/routes';

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
    path: '/shop/:tenantSlug?/home',
    redirect: (to) => ({
      name: 'customer-dashboard',
      params: {
        tenantSlug:
          typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : undefined,
      },
    }),
  },
  ...dashboardRoutes,
  ...tenantRoutes,
  ...authRoutes,
  ...featureCatalogRoutes,

  // Always leave this as last one
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
];

export default routes;
