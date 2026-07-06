import type { RouteRecordRaw } from 'vue-router'


const getTenantSlugPrefix = (params: Record<string, string | string[]>) => {
  const tenantSlug = typeof params.tenantSlug === 'string' ? params.tenantSlug : ''
  return tenantSlug ? `/${tenantSlug}` : ''
}

const globalRoutes: RouteRecordRaw[] = [
  {
    path: '/:tenantSlug?/app/global/invoices',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/sales/invoices`
    },
  },
  {
    path: '/:tenantSlug?/app/global/invoices/billing-profiles',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/sales/invoices/billing-profiles`
    },
  },
  {
    path: '/:tenantSlug?/app/global/invoices/recipient-profiles',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/sales/invoices/recipient-profiles`
    },
  },
  {
    path: '/:tenantSlug?/app/global/invoices/brands',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/sales/invoices`
    },
  },
  {
    path: '/:tenantSlug?/app/global/invoices/:id',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      const id = typeof to.params.id === 'string' ? to.params.id : ''
      return `${prefix}/app/sales/invoices/${id}`
    },
  },
  {
    path: '/:tenantSlug?/app/global/invoices/:id/preview',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      const id = typeof to.params.id === 'string' ? to.params.id : ''
      return `${prefix}/app/sales/invoices/${id}/preview`
    },
  },
  {
    path: '/:tenantSlug?/app/global/accounting/ledger',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/finance/invoices`
    },
  },
  {
    path: '/:tenantSlug?/app/global/accounting/shipments',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/finance/shipments`
    },
  },
  {
    path: '/:tenantSlug?/app/global/accounting/shipments/:id',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      const id = typeof to.params.id === 'string' ? to.params.id : ''
      return `${prefix}/app/finance/shipments/${id}`
    },
  },
  {
    path: '/:tenantSlug?/app/global/accounting/invoices',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/finance/invoices`
    },
  },
  {
    path: '/:tenantSlug?/app/global/investors',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/capital/profiles`
    },
  },
  {
    path: '/:tenantSlug?/app/global/investor-shipments',
    redirect: (to) => {
      const prefix = getTenantSlugPrefix(to.params)
      return `${prefix}/app/capital/shipments`
    },
  },
]

export default globalRoutes
