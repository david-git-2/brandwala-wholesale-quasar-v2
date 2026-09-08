import type { RouteRecordRaw } from 'vue-router';
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard';
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry';

const guard = (requiredModule: ModuleKey) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    requiredModule,
  });

const afterSalesRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/after-sales',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: guard('after_sales'),
    children: [
      {
        path: '',
        name: 'app-after-sales-overview',
        component: () => import('../pages/AfterSalesOverviewPage.vue'),
        meta: { title: 'Returns Hub', headerTitle: 'Returns Hub' },
      },
      {
        path: 'cases',
        name: 'app-after-sales-cases',
        component: () => import('../pages/AfterSalesCaseListPage.vue'),
        meta: { title: 'All cases', headerTitle: 'All cases' },
      },
      {
        path: 'wholesale',
        name: 'app-after-sales-wholesale',
        component: () => import('../pages/AfterSalesCaseListPage.vue'),
        props: {
          channelPreset: 'wholesale',
          pageTitle: 'Wholesale returns',
          pageCaption: 'B2B return-for-credit queue.',
        },
        meta: { title: 'Wholesale returns', headerTitle: 'Wholesale returns' },
      },
      {
        path: 'dropship',
        name: 'app-after-sales-dropship',
        component: () => import('../pages/AfterSalesCaseListPage.vue'),
        props: {
          channelPreset: 'dropship',
          pageTitle: 'Dropship complaints',
          pageCaption: 'Off-system recipient reports.',
        },
        meta: { title: 'Dropship complaints', headerTitle: 'Dropship complaints' },
      },
      {
        path: 'dropship/intake',
        name: 'app-after-sales-dropship-intake',
        component: () => import('../pages/DropshipIntakePage.vue'),
        meta: { title: 'Log dropship complaint', headerTitle: 'Log dropship complaint' },
      },
      {
        path: 'policy',
        name: 'app-after-sales-policy-list',
        component: () => import('../pages/AfterSalesPolicyListPage.vue'),
        meta: { title: 'Return policies', headerTitle: 'Return policies' },
      },
      {
        path: 'policy/new',
        name: 'app-after-sales-policy-new',
        component: () => import('../pages/AfterSalesPolicyPage.vue'),
        props: { createMode: true },
        meta: { title: 'Create return policy', headerTitle: 'Create return policy' },
      },
      {
        path: 'policy/:policyId',
        name: 'app-after-sales-policy-detail',
        component: () => import('../pages/AfterSalesPolicyPage.vue'),
        props: (route) => ({ policyId: route.params.policyId }),
        meta: { title: 'Return policy', headerTitle: 'Return policy' },
      },
      {
        path: ':id',
        name: 'app-after-sales-case-detail',
        component: () => import('../pages/AfterSalesCaseDetailPage.vue'),
        meta: { title: 'Case detail', headerTitle: 'Case detail' },
      },
    ],
  },
];

export default afterSalesRoutes;
