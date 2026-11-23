import { computed, watch } from 'vue';
import { storeToRefs } from 'pinia';
import type { RouteLocationRaw } from 'vue-router';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { childTenantRefsCacheKey } from 'src/modules/tenant/repositories/tenantRepository';
import { useModulePermissions } from 'src/modules/workspace/submodules/navigation/modulePermissions';
import { useDashboardBundleStore } from '../stores/dashboardBundleStore';
import { formatDashboardCount } from '../utils/formatDashboardMetric';
import { useAppDashboardRoutes } from './useAppDashboardRoutes';

export type TodayPlanWorkItem = {
  id: string;
  label: string;
  count: number;
  to: RouteLocationRaw;
  tone: 'warn' | 'info';
};

export type TodayPlanStep = {
  id: string;
  title: string;
  caption: string;
  count: number;
  to: RouteLocationRaw;
};

const MAX_WORK_ITEMS = 8;

const pushIfPositive = (
  rows: TodayPlanWorkItem[],
  item: Omit<TodayPlanWorkItem, 'count'> & { count: number },
) => {
  if (item.count <= 0) return;
  rows.push(item);
};

export const useTodayPlan = () => {
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();
  const bundleStore = useDashboardBundleStore();
  const { bundle, loading, lastRefreshedAt, hasData } = storeToRefs(bundleStore);
  const { tenantId } = storeToRefs(authStore);
  const { hasModuleAccess } = useModulePermissions();
  const routes = useAppDashboardRoutes();

  const isParent = computed(() => !tenantStore.selectedTenant?.parent_id);

  const canShowDelivery = computed(
    () => !isParent.value && hasModuleAccess('shop_order', 'view'),
  );
  const canShowShipment = computed(
    () => isParent.value && hasModuleAccess('global_stock', 'view'),
  );

  const shop = computed(() => bundle.value.shopOrder);
  const proc = computed(() => bundle.value.procurement);

  const workItems = computed<TodayPlanWorkItem[]>(() => {
    const rows: TodayPlanWorkItem[] = [];

    if (canShowDelivery.value && shop.value) {
      const s = shop.value;
      pushIfPositive(rows, {
        id: 'dropship-submitted',
        label: `${formatDashboardCount(s.dropshipSubmitted)} dropship orders waiting to pick`,
        count: s.dropshipSubmitted,
        to: routes.shopOrdersDropship(),
        tone: 'warn',
      });
      pushIfPositive(rows, {
        id: 'needs-quote',
        label: `${formatDashboardCount(s.needsQuoteCount)} orders need a quote`,
        count: s.needsQuoteCount,
        to: routes.shopOrders(),
        tone: 'warn',
      });
      pushIfPositive(rows, {
        id: 'ready-pickup',
        label: `${formatDashboardCount(s.readyForPickupCount)} orders ready for pickup or handoff`,
        count: s.readyForPickupCount,
        to: routes.shopOrders(),
        tone: 'warn',
      });
      pushIfPositive(rows, {
        id: 'dropship-processing',
        label: `${formatDashboardCount(s.dropshipProcessing)} dropship orders in processing`,
        count: s.dropshipProcessing,
        to: routes.shopOrdersDropship(),
        tone: 'info',
      });
      pushIfPositive(rows, {
        id: 'dropship-ready',
        label: `${formatDashboardCount(s.dropshipReady)} dropship orders ready to dispatch`,
        count: s.dropshipReady,
        to: routes.shopOrdersDropship(),
        tone: 'info',
      });
      pushIfPositive(rows, {
        id: 'processing',
        label: `${formatDashboardCount(s.processingCount)} orders in the pipeline`,
        count: s.processingCount,
        to: routes.shopOrders(),
        tone: 'info',
      });
    }

    if (canShowShipment.value && proc.value) {
      const p = proc.value;
      pushIfPositive(rows, {
        id: 'draft-shipments',
        label: `${formatDashboardCount(p.draftCount)} inbound batches under processing`,
        count: p.draftCount,
        to: routes.procurementShipmentList(),
        tone: 'warn',
      });
      pushIfPositive(rows, {
        id: 'in-transit',
        label: `${formatDashboardCount(p.inTransitCount)} inbound batches in transit`,
        count: p.inTransitCount,
        to: routes.procurementShipmentList(),
        tone: 'warn',
      });
    }

    return rows.slice(0, MAX_WORK_ITEMS);
  });

  const deliverySteps = computed<TodayPlanStep[]>(() => {
    if (!canShowDelivery.value) return [];
    const s = shop.value;
    if (!s) return [];

    return [
      {
        id: 'needs-quote',
        title: 'Quote or confirm',
        caption: 'Submitted, costing, or countered',
        count: s.needsQuoteCount,
        to: routes.shopOrders(),
      },
      {
        id: 'processing',
        title: 'Fulfill in warehouse',
        caption: 'Processing through packed',
        count: s.processingCount,
        to: routes.shopOrders(),
      },
      {
        id: 'ready-pickup',
        title: 'Ready for pickup or courier',
        caption: 'Hand off to customer or courier',
        count: s.readyForPickupCount,
        to: routes.shopOrders(),
      },
      {
        id: 'shipped',
        title: 'Out for delivery',
        caption: 'Shipped and in transit to buyer',
        count: s.shippedCount,
        to: routes.shopOrders(),
      },
      {
        id: 'dropship-submitted',
        title: 'Dropship — new',
        caption: 'Submitted, waiting for stock pick',
        count: s.dropshipSubmitted,
        to: routes.shopOrdersDropship(),
      },
      {
        id: 'dropship-processing',
        title: 'Dropship — processing',
        caption: 'Pick and pack for partner shops',
        count: s.dropshipProcessing,
        to: routes.shopOrdersDropship(),
      },
      {
        id: 'dropship-ready',
        title: 'Dropship — ready',
        caption: 'Ready for partner handoff',
        count: s.dropshipReady,
        to: routes.shopOrdersDropship(),
      },
    ];
  });

  const shipmentSteps = computed<TodayPlanStep[]>(() => {
    if (!canShowShipment.value) return [];
    const p = proc.value;
    if (!p) return [];

    return [
      {
        id: 'draft',
        title: 'Draft and receiving',
        caption: 'Open batches — add items and receive',
        count: p.draftCount,
        to: routes.procurementShipmentList(),
      },
      {
        id: 'in-transit',
        title: 'In transit',
        caption: 'Freight on the way to warehouse',
        count: p.inTransitCount,
        to: routes.procurementShipmentList(),
      },
      {
        id: 'received',
        title: 'Received',
        caption: 'Batches landed in stock',
        count: p.receivedCount,
        to: routes.procurementShipmentList(),
      },
    ];
  });

  const isClear = computed(
    () => workItems.value.length === 0 && !loading.value && hasData.value,
  );

  const openWorkCount = computed(() =>
    workItems.value.reduce((sum, item) => sum + item.count, 0),
  );

  const nextAction = computed(() => workItems.value[0] ?? null);

  const statusLabel = computed(() => {
    if (loading.value && !hasData.value) {
      return 'Updating';
    }
    if (hasData.value && openWorkCount.value <= 0) {
      return 'Clear';
    }
    if (openWorkCount.value > 0) {
      return `${openWorkCount.value} need you`;
    }
    return '—';
  });

  const refetch = async () => {
    const tid = tenantId.value;
    if (!tid) return;

    const roots = [...tenantStore.availableAdminTenants, ...tenantStore.items].filter(
      (tenant) => tenant.parent_id === null,
    );
    const parentIds = [...new Set(roots.map((tenant) => tenant.id))];

    const result = await bundleStore.refresh(tid, parentIds);
    if (result.childTenantRefs.length > 0) {
      tenantStore.hierarchyChildRefs = result.childTenantRefs;
      tenantStore.hierarchyChildRefsCacheKey = parentIds.length
        ? childTenantRefsCacheKey(parentIds)
        : '';
      tenantStore.persistWorkspaceState();
    }
  };

  watch(
    () => authStore.tenantId,
    (id) => {
      bundleStore.loadCached(id ?? null);
      if (id && !bundleStore.hasData) {
        void refetch();
      }
    },
    { immediate: true },
  );

  return {
    workItems,
    deliverySteps,
    shipmentSteps,
    canShowDelivery,
    canShowShipment,
    openWorkCount,
    nextAction,
    statusLabel,
    isLoading: loading,
    lastRefreshedAt,
    isClear,
    refetch,
  };
};