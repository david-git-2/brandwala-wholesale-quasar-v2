import type { RouteRecordRaw } from 'vue-router'
import { createAccessGuard } from 'src/modules/auth/guards/accessGuard'
import type { ModuleKey } from 'src/modules/navigation/moduleRegistry'

const guard = (requiredModule: ModuleKey) =>
  createAccessGuard({
    loginRoute: 'admin-login-page',
    requiredScope: 'app',
    requireTenantContext: true,
    requiredModule,
  })

const procurementStockRoutes: RouteRecordRaw[] = [
  // Legacy Redirects
  {
    path: '/:tenantSlug?/app/global/shipment/:rest(.*)*',
    redirect: (to) => {
      const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : ''
      return tenantSlug
        ? `/${tenantSlug}/app/procurement/shipment${rest ? `/${rest}` : ''}`
        : `/app/procurement/shipment${rest ? `/${rest}` : ''}`
    },
  },
  {
    path: '/:tenantSlug?/app/global/stock/:rest(.*)*',
    redirect: (to) => {
      const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : ''
      return tenantSlug
        ? `/${tenantSlug}/app/procurement/stock${rest ? `/${rest}` : ''}`
        : `/app/procurement/stock${rest ? `/${rest}` : ''}`
    },
  },
  {
    path: '/:tenantSlug?/app/stock/:rest(.*)*',
    redirect: (to) => {
      const tenantSlug = typeof to.params.tenantSlug === 'string' ? to.params.tenantSlug : null
      const rest = Array.isArray(to.params.rest)
        ? to.params.rest.join('/')
        : typeof to.params.rest === 'string'
          ? to.params.rest
          : ''
      return tenantSlug
        ? `/${tenantSlug}/app/procurement/tenant-stock${rest ? `/${rest}` : ''}`
        : `/app/procurement/tenant-stock${rest ? `/${rest}` : ''}`
    },
  },

  // Active Routes
  {
    path: '/:tenantSlug?/app/procurement/shipment',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-shipment-list',
        component: () => import('../pages/InboundShipmentListPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id',
        name: 'app-procurement-shipment-details',
        component: () => import('../pages/InboundShipmentDetailsPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
      {
        path: ':id/add-catalog',
        name: 'app-procurement-shipment-add-catalog',
        component: () => import('../pages/ShipmentAddCatalogPage.vue'),
        beforeEnter: guard('global_shipment'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/procurement/stock',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-stock-list',
        component: () => import('../pages/WarehouseStockListPage.vue'),
        beforeEnter: guard('global_stock'),
      },
      {
        path: 'allocate',
        name: 'app-procurement-stock-allocate',
        component: () => import('../pages/AllocateStockPage.vue'),
        beforeEnter: guard('global_stock'),
      },
    ],
  },
  {
    path: '/:tenantSlug?/app/procurement/tenant-stock',
    component: () => import('layouts/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'app-procurement-tenant-stock-list',
        component: () => import('../pages/TenantStockListPage.vue'),
        beforeEnter: guard('procurement_stock'),
      },
    ],
  },
]

export default procurementStockRoutes
