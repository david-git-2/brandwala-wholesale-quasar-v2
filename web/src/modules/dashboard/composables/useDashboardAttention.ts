import { computed } from 'vue';
import { storeToRefs } from 'pinia';
import type { RouteLocationRaw } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useDashboardBundleStore } from '../stores/dashboardBundleStore';
import {
  formatDashboardCount,
  formatDashboardMoney,
} from '../utils/formatDashboardMetric';
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
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();
  const bundleStore = useDashboardBundleStore();
  const { bundle } = storeToRefs(bundleStore);
  const { hasModuleAccess } = useModulePermissions();
  const { tenantId } = storeToRefs(authStore);
  const routes = useAppDashboardRoutes();

  const isParent = computed(() => !tenantStore.selectedTenant?.parent_id);

  const canStock = computed(() => isParent.value && hasModuleAccess('global_stock', 'view'));
  const canShopOrder = computed(() => !isParent.value && hasModuleAccess('shop_order', 'view'));
  const canInvestor = computed(() => isParent.value && hasModuleAccess('investor_capital_ledger', 'view'));

  const items = computed<DashboardAttentionItem[]>(() => {
    const rows: DashboardAttentionItem[] = [];
    const shop = bundle.value.shopOrder;
    const proc = bundle.value.procurement;
    const investor = bundle.value.investorCapital;

    if (canShopOrder.value) {
      const pickup = shop?.readyForPickupCount ?? 0;
      if (pickup > 0) {
        rows.push({
          id: 'ready-pickup',
          label: `${formatDashboardCount(pickup)} orders ready for pickup`,
          value: formatDashboardCount(pickup),
          to: routes.shopOrders(),
          tone: 'warn',
        });
      }

      const dropshipSubmitted = shop?.dropshipSubmitted ?? 0;
      if (dropshipSubmitted > 0) {
        rows.push({
          id: 'dropship-submitted',
          label: `${formatDashboardCount(dropshipSubmitted)} dropship orders submitted`,
          value: formatDashboardCount(dropshipSubmitted),
          to: routes.shopOrdersDropship(),
          tone: 'warn',
        });
      }
    }

    if (canStock.value) {
      const inTransit = proc?.inTransitCount ?? 0;
      if (inTransit > 0) {
        rows.push({
          id: 'in-transit',
          label: `${formatDashboardCount(inTransit)} batches in transit`,
          value: formatDashboardCount(inTransit),
          to: routes.procurementShipmentList(),
          tone: 'warn',
        });
      }

      const draft = proc?.draftCount ?? 0;
      if (draft > 0) {
        rows.push({
          id: 'draft-shipments',
          label: `${formatDashboardCount(draft)} batches under processing`,
          value: formatDashboardCount(draft),
          to: routes.procurementShipmentList(),
          tone: 'warn',
        });
      }
    }

    if (canInvestor.value) {
      const due = investor?.dueToInvestors ?? 0;
      if (due > 0) {
        rows.push({
          id: 'due-investors',
          label: `${formatDashboardMoney(due)} due to investors`,
          value: formatDashboardMoney(due),
          to: routes.capitalLedger(),
          tone: 'warn',
        });
      }
    }

    return rows.slice(0, MAX_ITEMS);
  });

  return { items };
};
