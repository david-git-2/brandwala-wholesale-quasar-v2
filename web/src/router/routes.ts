import type { RouteRecordRaw } from 'vue-router';
import authRoutes from 'src/modules/workspace/submodules/auth/routes';
import dashboardRoutes from 'src/modules/workspace/submodules/dashboard/routes';
import tenantRoutes from 'src/modules/tenant/routes';
import featureCatalogRoutes from 'src/modules/tenant/submodules/feature_catalog/routes';
import costingFileRoutes from 'src/modules/preorder_costing_file/routes';
import membershipRoutes from 'src/modules/tenant/submodules/membership/routes';
import globalReferenceRoutes from 'src/modules/tenant/submodules/global_reference/routes';
import productBasedCostingRoutes from 'src/modules/shop_order/submodules/product_based_costing/routes';
import productRoutes from 'src/modules/shop_order/submodules/products/routes';
import vendorRoutes from 'src/modules/people/submodules/vendor/routes';
import kobaRoutes from 'src/modules/koba/routes';
import notificationRoutes from 'src/modules/workspace/submodules/notifications/routes';
import thriftRoutes from 'src/modules/thrift/routes';
import investorPortalRoutes from 'src/modules/people/submodules/investor_portal/routes';
import globalRoutes from 'src/modules/procurement_stock/submodules/global_stock/routes';
import procurementStockRoutes from 'src/modules/procurement_stock/routes';
import reportingTreasuryRoutes from 'src/modules/finance/submodules/reporting_treasury/routes';
import billsPaysRoutes from 'src/modules/finance/submodules/bills_pays/routes';
import investorCapitalAdminRoutes from 'src/modules/people/submodules/investor_capital/routes/adminRoutes';
import shopOrderRoutes from 'src/modules/shop_order/routes';
import accessControlRoutes from 'src/modules/tenant/submodules/access_control/routes';
import customerRoutes from 'src/modules/people/submodules/customer/routes';
import peopleRoutes from 'src/modules/people/routes';
import proxyPurchaseRoutes from 'src/modules/proxy_purchase/routes';
import landingRoutes from 'src/modules/workspace/submodules/landing/routes';
import helpRoutes from 'src/modules/docs/submodules/help/routes';
import docsRoutes from 'src/modules/docs/routes';
import operatingManualRoutes from 'src/modules/docs/submodules/operating_manual/routes';
const devRoutes: RouteRecordRaw[] = [
  {
    path: '/dev/designsystem',
    component: () => import('layouts/ExternalLayout.vue'),
    children: [
      {
        path: '',
        name: 'dev-design-system',
        component: () => import('pages/DesignSystemPage.vue'),
        meta: {
          title: 'Design System',
        },
      },
    ],
  },
  {
    path: '/dev/document',
    name: 'dev-documentation-codex',
    component: () => import('pages/DevDocumentPage.vue'),
    meta: {
      title: 'Documentation Codex',
      public: true,
    },
  },
  {
    path: '/dev/documents',
    redirect: '/dev/document',
  },
  {
    path: '/dev/doc',
    redirect: '/dev/document',
  },
];

const legacySlugRedirects: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug/app/:rest(.*)*',
    redirect: (to) => {
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : '';
      const suffix = rest ? `/${rest}` : '';
      const query =
        to.query && Object.keys(to.query).length
          ? `?${new URLSearchParams(to.query as Record<string, string>).toString()}`
          : '';
      return `/app${suffix}${query}`;
    },
  },
  {
    path: '/:tenantSlug/investor/:rest(.*)*',
    redirect: (to) => {
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : '';
      const suffix = rest ? `/${rest}` : '';
      const query =
        to.query && Object.keys(to.query).length
          ? `?${new URLSearchParams(to.query as Record<string, string>).toString()}`
          : '';
      return `/investor${suffix}${query}`;
    },
  },
  {
    path: '/:tenantSlug/investor',
    redirect: '/investor',
  },
  {
    path: '/:tenantSlug/shop/:rest(.*)*',
    redirect: (to) => {
      const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : '';
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : '';
      const suffix = rest ? `/${rest}` : '';
      const query =
        to.query && Object.keys(to.query).length
          ? `?${new URLSearchParams(to.query as Record<string, string>).toString()}`
          : '';
      return tenantSlug ? `/shop/${tenantSlug}${suffix}${query}` : `/shop${suffix}${query}`;
    },
  },
  {
    path: '/app/:tenantSlug/:after(app|tenants|costing|products|product-based-costing)/:rest(.*)*',
    redirect: (to) => {
      const after = typeof to.params.after === 'string' ? to.params.after : null;
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : '';
      return after ? `/app/${after}${rest ? `/${rest}` : ''}` : '/app/dashboard';
    },
  },
];

const routes: RouteRecordRaw[] = [
  ...landingRoutes,
  ...helpRoutes,
  ...docsRoutes,
  ...operatingManualRoutes,
  ...legacySlugRedirects,
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
  ...featureCatalogRoutes,
  ...globalReferenceRoutes,
  ...productBasedCostingRoutes,
  ...productRoutes,
  ...vendorRoutes,
  ...costingFileRoutes,
  ...membershipRoutes,
  ...kobaRoutes,
  ...notificationRoutes,
  ...thriftRoutes,
  ...investorPortalRoutes,
  ...procurementStockRoutes,
  ...shopOrderRoutes,
  ...globalRoutes,
  ...billsPaysRoutes,
  ...reportingTreasuryRoutes,
  ...investorCapitalAdminRoutes,
  ...accessControlRoutes,
  ...customerRoutes,
  ...peopleRoutes,
  ...proxyPurchaseRoutes,

  ...(import.meta.env.DEV ? devRoutes : []),

  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
];

export default routes;