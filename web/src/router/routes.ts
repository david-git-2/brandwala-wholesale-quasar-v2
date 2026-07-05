import type { RouteRecordRaw } from 'vue-router';
import authRoutes from 'src/modules/auth/routes';
import dashboardRoutes from 'src/modules/dashboard/routes';
import tenantRoutes from 'src/modules/tenant/routes';
import featureCatalogRoutes from 'src/modules/featureCatalog/routes';
import costingFileRoutes from 'src/modules/costingFile/routes';
import membershipRoutes from 'src/modules/membership/routes';
import globalReferenceRoutes from 'src/modules/global_reference/routes';
import productBasedCostingRoutes from 'src/modules/product_based_costing/routes';
import productRoutes from 'src/modules/products/routes';
import cartRoutes from 'src/modules/cart/routes';
import orderRoutes from 'src/modules/order/routes';
import storeRoutes from 'src/modules/store/routes';
import vendorRoutes from 'src/modules/vendor/routes';
import shipmentRoutes from 'src/modules/shipment/routes';
import inventoryRoutes from 'src/modules/inventory/routes';
import invoiceRoutes from 'src/modules/invoice/routes';
import accountingRoutes from 'src/modules/accounting/routes';
import investorRoutes from 'src/modules/investor/routes';
import commerceShopRoutes from 'src/modules/commerce_shop/routes';
import commerceOrderRoutes from 'src/modules/commerce_order/routes';
import commerceInvoiceRoutes from 'src/modules/commerce_invoice/routes';
import commerceAccountingRoutes from 'src/modules/commerce_accounting/routes';
import commerceCartRoutes from 'src/modules/commerce_cart/routes';
import documentationRoutes from 'src/modules/documentation/routes';
import kobaRoutes from 'src/modules/koba/routes';
import tasksRoutes from 'src/modules/tasks/routes';
import thriftRoutes from 'src/modules/thrift/routes';
import investorPortalRoutes from 'src/modules/investor_portal/routes';
import globalRoutes from 'src/modules/global/routes';
import procurementStockRoutes from 'src/modules/procurement_stock/routes';
import salesInvoiceRoutes from 'src/modules/sales_invoice/routes';
import reportingTreasuryRoutes from 'src/modules/reporting_treasury/routes';



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
  ...globalReferenceRoutes,
  ...productBasedCostingRoutes,
  ...productRoutes,
  ...cartRoutes,
  ...orderRoutes,
  ...shipmentRoutes,
  ...inventoryRoutes,
  ...accountingRoutes,
  ...investorRoutes,
  ...commerceShopRoutes,
  ...commerceOrderRoutes,
  ...commerceInvoiceRoutes,
  ...commerceAccountingRoutes,
  ...commerceCartRoutes,
  ...invoiceRoutes,
  ...storeRoutes,
  ...vendorRoutes,
  ...costingFileRoutes,
  ...membershipRoutes,
  ...documentationRoutes,
  ...kobaRoutes,
  ...tasksRoutes,
  ...thriftRoutes,
  ...investorPortalRoutes,
  ...globalRoutes,
  ...procurementStockRoutes,
  ...salesInvoiceRoutes,
  ...reportingTreasuryRoutes,


  // Always leave this as last one
  {
    path: '/:catchAll(.*)*',
    component: () => import('pages/ErrorNotFound.vue'),
  },
];

export default routes;
