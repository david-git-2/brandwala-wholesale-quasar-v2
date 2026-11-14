import { computed } from 'vue';
import { storeToRefs } from 'pinia';
import type { RouteLocationRaw } from 'vue-router';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useDashboardBundleStore } from '../stores/dashboardBundleStore';
import { formatDashboardCount } from '../utils/formatDashboardMetric';
import { useAppDashboardRoutes } from './useAppDashboardRoutes';

export type DashboardAttentionItem = {
  id: string;
  label: string;
  value: string;
  to: RouteLocationRaw;
  tone: 'warn';
};

const MAX_ITEMS = 8;

export const useDashboardAttention = () => {
  const tenantStore = useTenantStore();
  const bundleStore = useDashboardBundleStore();
  const { bundle } = storeToRefs(bundleStore);
  const { hasModuleAccess } = useModulePermissions();
  const routes = useAppDashboardRoutes();

  const isParent = computed(() => !tenantStore.selectedTenant?.parent_id);

  const canStock = computed(() => isParent.value && hasModuleAccess('global_stock', 'view'));
  const canShopOrder = computed(() => !isParent.value && hasModuleAccess('shop_order', 'view'));

  const items = computed<DashboardAttentionItem[]>(() => {
    const rows: DashboardAttentionItem[] = [];
    const shop = bundle.value.shopOrder;
    const proc = bundle.value.procurement;

    if (canShopOrder.value && shop) {
      const dropshipSubmitted = shop.dropshipSubmitted ?? 0;
      if (dropshipSubmitted > 0) {
        rows.push({
          id: 'dropship-submitted',
          label: `${formatDashboardCount(dropshipSubmitted)} dropship orders submitted`,
          value: formatDashboardCount(dropshipSubmitted),
          to: routes.shopOrdersDropship(),
          tone: 'warn',
        });
      }

      const needsQuote = shop.needsQuoteCount ?? 0;
      if (needsQuote > 0) {
        rows.push({
          id: 'needs-quote',
          label: `${formatDashboardCount(needsQuote)} orders need a quote`,
          value: formatDashboardCount(needsQuote),
          to: routes.shopOrders(),
          tone: 'warn',
        });
      }

      const pickup = shop.readyForPickupCount ?? 0;
      if (pickup > 0) {
        rows.push({
          id: 'ready-pickup',
          label: `${formatDashboardCount(pickup)} orders ready for pickup`,
          value: formatDashboardCount(pickup),
          to: routes.shopOrders(),
          tone: 'warn',
        });
      }

      const dropshipProcessing = shop.dropshipProcessing ?? 0;
      if (dropshipProcessing > 0) {
        rows.push({
          id: 'dropship-processing',
          label: `${formatDashboardCount(dropshipProcessing)} dropship orders in processing`,
          value: formatDashboardCount(dropshipProcessing),
          to: routes.shopOrdersDropship(),
          tone: 'warn',
        });
      }

      const dropshipReady = shop.dropshipReady ?? 0;
      if (dropshipReady > 0) {
        rows.push({
          id: 'dropship-ready',
          label: `${formatDashboardCount(dropshipReady)} dropship orders ready`,
          value: formatDashboardCount(dropshipReady),
          to: routes.shopOrdersDropship(),
          tone: 'warn',
        });
      }

      const processing = shop.processingCount ?? 0;
      if (processing > 0) {
        rows.push({
          id: 'processing',
          label: `${formatDashboardCount(processing)} orders in the pipeline`,
          value: formatDashboardCount(processing),
          to: routes.shopOrders(),
          tone: 'warn',
        });
      }
    }

    if (canStock.value && proc) {
      const draft = proc.draftCount ?? 0;
      if (draft > 0) {
        rows.push({
          id: 'draft-shipments',
          label: `${formatDashboardCount(draft)} batches under processing`,
          value: formatDashboardCount(draft),
          to: routes.procurementShipmentList(),
          tone: 'warn',
        });
      }

      const inTransit = proc.inTransitCount ?? 0;
      if (inTransit > 0) {
        rows.push({
          id: 'in-transit',
          label: `${formatDashboardCount(inTransit)} batches in transit`,
          value: formatDashboardCount(inTransit),
          to: routes.procurementShipmentList(),
          tone: 'warn',
        });
      }
    }

    return rows.slice(0, MAX_ITEMS);
  });

  return { items };
};
