import type { RouteRecordRaw } from 'vue-router';
import authRoutes from 'src/modules/auth/routes';
import dashboardRoutes from 'src/modules/dashboard/routes';
import tenantRoutes from 'src/modules/tenant/routes';
import featureCatalogRoutes from 'src/modules/featureCatalog/routes';
import costingFileRoutes from 'src/modules/costingFile/routes';
import membershipRoutes from 'src/modules/membership/routes';
import marketRoutes from 'src/modules/market/routes';
import productBasedCostingRoutes from 'src/modules/product_based_costing/routes';
import productRoutes from 'src/modules/products/routes';
import cartRoutes from 'src/modules/cart/routes';
import orderRoutes from 'src/modules/order/routes';
import storeRoutes from 'src/modules/store/routes';
import vendorRoutes from 'src/modules/vendor/routes';

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    redirect: '/platform/dashboard',
  },
  {
    path: '/app/home',
    redirect: '/app/dashboard',
  },
  {
    path: '/app/:tenantSlug/:after(app|tenants|costing|products|product-based-costing)/:rest(.*)*',
    redirect: (to) => {
      const tenantSlug =
        typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null
      const after =
        typeof to.params.after === 'string' ? to.params.after : null
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : ''

      return tenantSlug && after
        ? `/${tenantSlug}/app/${after}${rest ? `/${rest}` : ''}`
        : '/app/dashboard'
    },
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
  {
    path: '/shop/:tenantSlug/:rest(.*)*',
    redirect: (to) => {
      const tenantSlug =
        typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : ''

      return tenantSlug ? `/${tenantSlug}/shop/${rest}` : '/shop/dashboard'
    },
  },
  ...dashboardRoutes,
  ...tenantRoutes,
  ...authRoutes,
  ...featureCatalogRoutes,
  ...marketRoutes,
  ...productBasedCostingRoutes,
  ...productRoutes,
  ...cartRoutes,
  ...orderRoutes,
  ...storeRoutes,
  ...vendorRoutes,
  ...costingFileRoutes,
  ...membershipRoutes,

  // Always leave this as last one
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
];

export default routes;
