import { computed } from 'vue';
import { useRoute } from 'vue-router';
import type { RouteLocationRaw } from 'vue-router';

type RouteQuery = Record<string, string>;

/**
 * App-scope route helpers for staff Home (`/:tenantSlug?/app/dashboard`).
 * Never use customer shop routes (`shop-*`, `/:slug/shop/*`) here.
 */
export const useAppDashboardRoutes = (tenantSlugOverride?: string) => {
  const route = useRoute();

  const tenantSlug = computed(
    () => tenantSlugOverride ?? ((route.params.tenantSlug as string) || ''),
  );

  const withSlug = (
    name: string,
    options?: { query?: RouteQuery; params?: Record<string, string | number> },
  ): RouteLocationRaw => ({
    name,
    params: {
      ...(tenantSlug.value ? { tenantSlug: tenantSlug.value } : {}),
      ...(options?.params ?? {}),
    },
    ...(options?.query ? { query: options.query } : {}),
  });

  return {
    tenantSlug,
    procurementStockList: () => withSlug('app-procurement-stock-list'),
    procurementShipmentList: () => withSlug('app-procurement-shipment-list'),
    procurementShipmentCreate: () => withSlug('app-procurement-shipment-list'),
    procurementShipmentDetails: (id: string | number) =>
      withSlug('app-procurement-shipment-details', { params: { id } }),
    shopOrders: (query?: RouteQuery) =>
      withSlug('app-shop-orders-page', query ? { query } : undefined),
    shopOrdersDropship: () =>
      withSlug('app-shop-orders-page', { query: { shopType: 'dropship' } }),
    globalInvoices: (query?: RouteQuery) =>
      withSlug('app-global-invoices-page', query ? { query } : undefined),
    globalInvoicesCreate: () => withSlug('app-global-invoices-create-wholesale'),
    reportsSalesSummary: () => withSlug('app-global-invoices-overview'),
    reportsCustomerDues: () =>
      withSlug('app-global-invoices-page', { query: { payment_status: 'unpaid' } }),
    stockValuation: () => withSlug('app-procurement-stock-list'),
    walletHome: () => withSlug('app-wallet-home-page'),
    tasks: () => withSlug('tasks-page'),
    capitalLedger: () => withSlug('app-capital-ledger-page'),
    capitalShipments: () => withSlug('app-capital-shipments-page'),
    afterSalesOverview: () => withSlug('app-after-sales-overview'),
    thriftCodReport: () => withSlug('thrift-cod-report'),
    thriftSales: () => withSlug('thrift-sales-page'),
  };
};
