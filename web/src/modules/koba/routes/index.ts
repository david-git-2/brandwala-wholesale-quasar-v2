import type { RouteRecordRaw } from 'vue-router'

import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import {
  getAppRouteLocation,
  getShopLoginRouteLocation,
  getTenantSlugFromRoute,
} from 'src/modules/tenant/utils/tenantRouteContext'

const kobaRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/koba',
    component: () => import('layouts/AppLayout.vue'),
    beforeEnter: createAccessGuard({
      loginRoute: 'admin-login-page',
      requiredScope: 'app',
      allowedRoles: ['admin', 'staff'],
      requireTenantContext: true,
      requiredModule: 'koba_retail',
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
        redirect: { name: 'app-koba-retail-page' },
      },
      {
        path: 'retail',
        name: 'app-koba-retail-page',
        component: () => import('src/modules/koba/retail/pages/KobaRetailProductsPage.vue'),
      },
      {
        path: 'retail/cart',
        name: 'app-koba-retail-cart-page',
        component: () => import('src/modules/koba/retail/pages/KobaCartPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: 'admin-login-page',
          requiredScope: 'app',
          allowedRoles: ['staff'],
          requireTenantContext: true,
          requiredModule: 'koba_retail',
        }),
      },
      {
        path: 'retail/orders',
        name: 'app-koba-retail-orders-page',
        component: () => import('src/modules/koba/retail/pages/KobaOrdersPage.vue'),
      },
      {
        path: 'retail/orders/:id',
        name: 'app-koba-retail-order-detail-page',
        component: () => import('src/modules/koba/retail/pages/KobaOrderDetailPage.vue'),
      },
      {
        path: 'retail/settings',
        name: 'app-koba-retail-settings-page',
        component: () => import('src/modules/koba/retail/pages/KobaRetailSettingsPage.vue'),
      },
      {
        path: 'retail/customers',
        name: 'app-koba-retail-customers-page',
        component: () => import('src/modules/koba/retail/pages/KobaRetailCustomersPage.vue'),
      },
      {
        path: 'retail/customers/:phone',
        name: 'app-koba-retail-customer-profile-page',
        component: () => import('src/modules/koba/retail/pages/KobaRetailCustomerProfilePage.vue'),
        props: true,
      },
    ],
  },
  {
    path: '/:tenantSlug?/shop/koba',
    component: () => import('layouts/ShopLayout.vue'),
    children: [
      {
        path: '',
        redirect: { name: 'shop-koba-retail-page' },
      },
      {
        path: 'retail',
        name: 'shop-koba-retail-page',
        component: () => import('src/modules/koba/retail/pages/KobaRetailProductsPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'koba_retail',
        }),
      },
      {
        path: 'retail/cart',
        name: 'shop-koba-retail-cart-page',
        component: () => import('src/modules/koba/retail/pages/KobaCartPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'koba_retail',
        }),
      },
      {
        path: 'retail/orders',
        name: 'shop-koba-retail-orders-page',
        component: () => import('src/modules/koba/retail/pages/KobaOrdersPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'koba_retail',
        }),
      },
      {
        path: 'retail/orders/:id',
        name: 'shop-koba-retail-order-detail-page',
        component: () => import('src/modules/koba/retail/pages/KobaOrderDetailPage.vue'),
        beforeEnter: createAccessGuard({
          loginRoute: (to) =>
            getShopLoginRouteLocation(to, {
              redirect: to.fullPath,
            }),
          requiredScope: 'shop',
          requireTenantContext: true,
          allowedRoles: ['customer_admin', 'customer_negotiator', 'customer_staff'],
          requiredModule: 'koba_retail',
        }),
      },
    ],
  },
]

export default kobaRoutes
