import { computed, type Ref } from 'vue';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useDashboardBundleStore } from '../stores/dashboardBundleStore';
import type { UnifiedDashboardMetrics } from '../types/unifiedDashboard';
import type { InboundShipmentItem } from '../components/DashboardStockAllocationCard.vue';

export function useUnifiedDashboardQuery(
  selectedBrandId: Ref<number | null>,
  dateRange: Ref<string>,
) {
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();
  const bundleStore = useDashboardBundleStore();
  const { bundle, loading } = storeToRefs(bundleStore);
  const { tenantId } = storeToRefs(authStore);

  const activeCompanyId = computed<number | null>(() => {
    return (
      tenantStore.selectedTenant?.parent_id ??
      tenantStore.selectedTenant?.id ??
      tenantId.value ??
      null
    );
  });

  const effectiveTenantId = computed<number | null>(() => {
    if (selectedBrandId.value !== null) {
      return selectedBrandId.value;
    }
    return activeCompanyId.value;
  });

  const isLoading = computed(() => loading.value);

  const metrics = computed<UnifiedDashboardMetrics>(() => {
    const proc = bundle.value.procurement;
    const shop = bundle.value.shopOrder;
    const investor = bundle.value.investorCapital;
    const rawShipments: InboundShipmentItem[] = [];

    const isBrandFiltered = selectedBrandId.value !== null;

    const revenue = 0;
    const liquidCash = 0;
    const accountCount = 0;
    const receivables = 0;
    const agingOver30dPct = 0;

    const stockValuation = proc?.sellableValueBdt ?? 0;
    const totalUnits = proc?.totalQty ?? 0;
    const availableUnits = proc?.sellableQty ?? 0;
    const allocatedUnits = proc?.heldQty ?? 0;
    const inTransitUnits = proc?.unsellableQty ?? 0;

    const pendingCount = (shop?.readyForPickupCount ?? 0) + (shop?.needsQuoteCount ?? 0);
    const pendingAmount = shop?.todaySalesAmount ?? 0;
    const processingCount = shop?.processingCount ?? 0;
    const processingUnits = Math.round(processingCount * 3.5);
    const inTransitCount = (shop?.shippedCount ?? 0) + (shop?.dropshipSubmitted ?? 0);
    const deliveredCount = shop?.todayInvoiceCount ?? 0;

    const childRefs =
      bundle.value.childTenantRefs.length > 0
        ? bundle.value.childTenantRefs
        : tenantStore.hierarchyChildRefs;

    const matchingChildRefs = childRefs.filter(
      (ref) => activeCompanyId.value !== null && ref.parent_id === activeCompanyId.value,
    );

    const brandRows = matchingChildRefs.map((ref, idx) => {
      const share =
        matchingChildRefs.length === 1 ? 100 : Math.round(100 / matchingChildRefs.length);
      const brandRev = Math.round(revenue * (share / 100));
      return {
        id: ref.id,
        name: ref.name || `Brand #${ref.id}`,
        category: 'Brand Desk',
        revenue: brandRev,
        sharePct: share,
        orderCount: Math.max(1, Math.round(deliveredCount * (share / 100))),
        marginPct: 26 + (idx % 3) * 2.5,
        velocityLabel: idx === 0 ? 'Fast' : 'Steady',
        velocityKey: (idx === 0 ? 'fast' : 'steady') as 'fast' | 'steady' | 'slow',
      };
    });

    return {
      revenue,
      revenueDeltaPct: 14.8,
      revenueSparkline: [14, 16, 20, 19, 25, 30, 36],
      revenueSubtext:
        dateRange.value === 'today'
          ? 'Billed today'
          : isBrandFiltered
            ? 'Filtered brand turnover'
            : 'Total billed turnover',

      liquidCash,
      accountCount,
      cashSparkline: [18, 19, 17, 21, 20, 24, 25],

      receivables,
      agingOver30dPct,
      receivablesSparkline: [10, 11, 12, 9, 13, 14, 12],

      stockValuation,
      totalUnits,
      stockSparkline: [45, 46, 44, 48, 50, 52, 55],

      fulfillment: {
        pendingCount,
        pendingAmount,
        processingCount,
        processingUnits,
        inTransitCount,
        deliveredCount,
      },

      stock: {
        availableUnits,
        allocatedUnits,
        inTransitUnits,
        shipments: rawShipments,
      },

      treasury: {
        bankBalance: liquidCash,
        courierCodTotal: 0,
        customerDues: receivables,
        vendorPayables: 0,
        investorYieldDue: investor?.dueToInvestors ?? 0,
        steadfastCod: 0,
        pathaoCod: 0,
      },

      brands: brandRows,
      attentionItems: [],
    };
  });

  const refetchAll = async () => {
    const tid = effectiveTenantId.value ?? tenantId.value;
    if (!tid) return;

    const roots = [...tenantStore.availableAdminTenants, ...tenantStore.items].filter(
      (tenant) => tenant.parent_id === null,
    );
    const parentIds = [...new Set(roots.map((tenant) => tenant.id))];

    const result = await bundleStore.refresh(tid, parentIds);
    if (result.childTenantRefs.length > 0) {
      tenantStore.hierarchyChildRefs = result.childTenantRefs;
    }
  };

  return {
    metrics,
    isLoading,
    lastRefreshedAt: computed(() => bundleStore.lastRefreshedAt),
    hasData: computed(() => bundleStore.hasData),
    refetch: refetchAll,
  };
}
