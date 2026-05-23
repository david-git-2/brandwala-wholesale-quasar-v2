import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getAppRouteLocation,
  getShopLoginRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const commerceShopRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/commerce-shop',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'commerce_shop',
      validateAccess: ({ authStore, to }) => {
        const selectedTenantSlug = authStore.selectedTenant?.slug ?? null

        if (!selectedTenantSlug) {
          return true
        }

        const routeTenantSlug = getTenantSlugFromRoute(to)

        if (routeTenantSlug === selectedTenantSlug) {
          return true
        }

        return getAppRouteLocation(to, selectedTenantSlug)
      },
    }),
    children: [
      {
        path: '',
        redirect: { name: 'app-commerce-shop-manage-page' },
      },
      {
        path: 'manage-store',
        name: 'app-commerce-shop-manage-page',
        component: () => import('src/modules/store/pages/AdminManageStorePage.vue'),
      },
      {
        path: 'manage-access',
        name: 'app-commerce-shop-access-page',
        component: () => import('src/modules/store/pages/AdminManageAccessPage.vue'),
      },
      {
        path: 'store-products',
        name: 'app-commerce-shop-products-page',
        component: () => import('src/modules/commerce_shop/pages/AdminCommerceShopProductsPage.vue'),
      },
      {
        path: 'pricing',
        name: 'app-commerce-shop-pricing-page',
        component: () => import('src/modules/commerce_shop/pages/AdminCommerceShopPricingPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
          requireTenantContext: true,
          requiredModule: 'commerce_shop',
        }),
      },
      {
        path: 'orders',
        name: 'app-commerce-order-page',
        component: () => import('src/modules/order/pages/AdminOrderPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
          requireTenantContext: true,
          requiredModule: 'commerce_order',
        }),
      },
      {
        path: 'orders/:id',
        name: 'app-commerce-order-details-page',
        component: () => import('src/modules/order/pages/AdminOrderDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
          requireTenantContext: true,
          requiredModule: 'commerce_order',
        }),
      },
      {
        path: 'invoices',
        name: 'app-commerce-invoice-page',
        component: () => import('src/modules/invoice/pages/AdminInvoicePage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
          requireTenantContext: true,
          requiredModule: 'commerce_invoice',
        }),
      },
      {
        path: 'invoices/:invoiceId',
        name: 'app-commerce-invoice-details-page',
        component: () => import('src/modules/invoice/pages/AdminInvoiceDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
          requireTenantContext: true,
          requiredModule: 'commerce_invoice',
        }),
      },
      {
        path: 'invoices/billing-profiles',
        name: 'app-commerce-billing-profiles-page',
        component: () => import('src/modules/invoice/pages/AdminBillingProfilesPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['admin', 'staff'],
          requireTenantContext: true,
          requiredModule: 'commerce_invoice',
        }),
      },
    ],
  },
  {
    path: '/:tenantSlug?/shop/commerce-shop',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        name: 'shop-commerce-shop-page',
        component: () => import('src/modules/commerce_shop/pages/CustomerCommerceShopPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'commerce_shop',
        }),
      },
      {
        path: 'orders',
        name: 'shop-commerce-order-page',
        component: () => import('src/modules/order/pages/CustomerOrderPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'commerce_order',
        }),
      },
      {
        path: 'orders/:id',
        name: 'shop-commerce-order-details-page',
        component: () => import('src/modules/order/pages/CustomerOrderDetailsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'commerce_order',
        }),
      },
      {
        path: 'cart',
        name: 'shop-commerce-cart-page',
        component: () => import('src/modules/cart/pages/CustomerCartPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'commerce_cart',
        }),
      },
    ],
  },
]

export default commerceShopRoutes
