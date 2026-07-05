import type { RouteRecordRaw } from 'vue-router'

const getTenantSlugPrefix = (params: Record<string, string | string[]>) => {
  const tenantSlug = typeof params.tenantSlug === 'string' ? params.tenantSlug : ''
  return tenantSlug ? `/${tenantSlug}` : ''
}

const accountingRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/accounting',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/finance/invoices`
    },
  },
  {
    path: '/:tenantSlug?/app/accounting/invoice',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/finance/invoices`
    },
  },
  {
    path: '/:tenantSlug?/app/accounting/customer-payments',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/finance/payments`
    },
  },
  {
    path: '/:tenantSlug?/app/accounting/customer-payments/:billingProfileId',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      const billingProfileId = typeof to.params.billingProfileId === 'string' ? to.params.billingProfileId : ''
      return `${prefix}/app/finance/payments/${billingProfileId}`
    },
  },
  {
    path: '/:tenantSlug?/app/accounting/shipment',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/finance/shipments`
    },
  },
  {
    path: '/:tenantSlug?/app/accounting/shipment/:id',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      const id = typeof to.params.id === 'string' ? to.params.id : ''
      return `${prefix}/app/finance/shipments/${id}`
    },
  },
  {
    path: '/:tenantSlug?/app/accounting/inventory-shipment',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/finance/shipments`
    },
  },
]

export default accountingRoutes
