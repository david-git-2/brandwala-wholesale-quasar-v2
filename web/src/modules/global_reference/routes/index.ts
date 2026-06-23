import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const platformGuard = createAccessGuard({
  loginRoute: 'superadmin-login-page',
  requiredScope: 'platform',
  allowedRoles: ['superadmin'],
})

const appGuard = (requiredModule:
  | 'global_reference_currency'
  | 'global_reference_market'
  | 'global_reference_payment_method'
  | 'global_reference_unit_of_measure') =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    allowedRoles: ['admin', 'staff'],
    requireTenantContext: true,
    requiredModule,
  })

const globalReferenceRoutes: RouteRecordRaw[] = [
  {
    path: '/platform/markets',
    redirect: '/platform/reference/markets',
  },
  {
    path: '/platform/reference',
    component: () => import('layouts/PlatformLayout.vue'),
    beforeEnter: platformGuard,
    children: [
      {
        path: '',
        name: 'platform-reference-hub',
        component: () => import('../pages/ReferenceHubPage.vue'),
      },
      {
        path: 'markets',
        name: 'platform-reference-markets',
        component: () => import('../pages/MarketsReferencePage.vue'),
      },
      {
        path: 'currencies',
        name: 'platform-reference-currencies',
        component: () => import('../pages/CurrenciesPage.vue'),
      },
      {
        path: 'payment-methods',
        name: 'platform-reference-payment-methods',
        component: () => import('../pages/PaymentMethodsPage.vue'),
      },
      {
        path: 'units',
        name: 'platform-reference-units',
        component: () => import('../pages/UnitsOfMeasurePage.vue'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/thrift/currencies',
    redirect: (to) => {
      const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null
      return tenantSlug ? `/${tenantSlug}/app/reference/currencies` : '/app/reference/currencies'
    },
  },
  {
    path: '/:tenantSlug?/app/reference/currencies',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: appGuard('global_reference_currency'),
    children: [
      {
        path: '',
        name: 'app-reference-currencies',
        component: () => import('../pages/AppCurrenciesPage.vue'),
        meta: { title: 'Currencies', headerTitle: 'Currencies' },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/reference/markets',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: appGuard('global_reference_market'),
    children: [
      {
        path: '',
        name: 'app-reference-markets',
        component: () => import('../pages/AppMarketsPage.vue'),
        meta: { title: 'Markets', headerTitle: 'Markets' },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/reference/payment-methods',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: appGuard('global_reference_payment_method'),
    children: [
      {
        path: '',
        name: 'app-reference-payment-methods',
        component: () => import('../pages/AppPaymentMethodsPage.vue'),
        meta: { title: 'Payment Methods', headerTitle: 'Payment Methods' },
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/reference/units',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: appGuard('global_reference_unit_of_measure'),
    children: [
      {
        path: '',
        name: 'app-reference-units',
        component: () => import('../pages/AppUnitsPage.vue'),
        meta: { title: 'Units of Measure', headerTitle: 'Units of Measure' },
      },
    ],
  },
]

export default globalReferenceRoutes
