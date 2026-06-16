import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'

const commerceAccountingRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/commerce-shop/accounting',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-commerce-accounting',
        component: () => import('../pages/CommerceAccountingPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin'],
          requiredModule: 'commerce_accounting',
        }),
      },
      {
        path: 'invoice',
        name: 'app-commerce-accounting-invoice-page',
        component: () => import('../pages/CommerceInvoiceAccountingPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin'],
          requiredModule: 'commerce_accounting',
        }),
      },
      {
        path: 'shipment',
        name: 'app-commerce-accounting-shipment-page',
        component: () => import('../pages/CommerceShipmentAccountingPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin'],
          requiredModule: 'commerce_accounting',
        }),
      },
      {
        path: 'shipment/:id',
        name: 'app-commerce-accounting-shipment-details-page',
        component: () => import('../pages/CommerceShipmentAccountingDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin'],
          requiredModule: 'commerce_accounting',
        }),
      },
      {
        path: 'inventory-shipment',
        name: 'app-commerce-accounting-inventory-shipment-page',
        component: () => import('../pages/CommerceInventoryShipmentAccountingPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          requireTenantContext: true,
          allowedRoles: ['admin'],
          requiredModule: 'commerce_accounting',
        }),
      },
    ],
  },
]

export default commerceAccountingRoutes
