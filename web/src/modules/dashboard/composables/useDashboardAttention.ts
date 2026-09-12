import { computed } from 'vue';
import { storeToRefs } from 'pinia';
import { useRoute } from 'vue-router';
import type { RouteLocationRaw } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useProcurementDashboardQuery } from 'src/modules/procurement_stock/composables/useProcurementDashboardQuery';
import { useShopOrderDashboardQuery } from 'src/modules/shop_order/composables/useShopOrderDashboardQuery';
import { useSalesInvoiceDashboardQuery } from 'src/modules/sales_invoice/composables/useSalesInvoiceDashboardQuery';
import { useWalletAccounts } from 'src/modules/wallet/composables/useWalletAccounts';
import { useTasksDashboardQuery } from 'src/modules/tasks/composables/useTasksDashboardQuery';
import { useInvestorCapitalDashboardQuery } from 'src/modules/investor_capital/composables/useInvestorCapitalDashboardQuery';
import {
  formatDashboardCount,
  formatDashboardMoney,
} from '../utils/formatDashboardMetric';

export type DashboardAttentionItem = {
  id: string;
  label: string;
  value: string;
  to: RouteLocationRaw;
  tone: 'warn';
};

const MAX_ITEMS = 5;

export const useDashboardAttention = () => {
  const route = useRoute();
  const authStore = useAuthStore();
  const tenantStore = useTenantStore();
  const { hasModuleAccess } = useModulePermissions();
  const { tenantId } = storeToRefs(authStore);

  const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');
  const withSlug = () => (tenantSlug.value ? { tenantSlug: tenantSlug.value } : {});
  const isParent = computed(() => !tenantStore.selectedTenant?.parent_id);

  const canStock = computed(() => isParent.value && hasModuleAccess('global_stock', 'view'));
  const canShopOrder = computed(() => !isParent.value && hasModuleAccess('shop_order', 'view'));
  const canInvoices = computed(() => hasModuleAccess('global_invoice', 'view'));
  const canWallet = computed(() => hasModuleAccess('universal_wallet', 'view'));
  const canTasks = computed(() => hasModuleAccess('tasks', 'view'));
  const canInvestor = computed(() => isParent.value && hasModuleAccess('investor_capital_ledger', 'view'));

  const procurementQuery = useProcurementDashboardQuery(tenantId);
  const shopOrderQuery = useShopOrderDashboardQuery(tenantId);
  const invoiceQuery = useSalesInvoiceDashboardQuery(tenantId);
  const { dashboardSummary } = useWalletAccounts();
  const tasksQuery = useTasksDashboardQuery(tenantId);
  const investorQuery = useInvestorCapitalDashboardQuery(tenantId);

  const items = computed<DashboardAttentionItem[]>(() => {
    const rows: DashboardAttentionItem[] = [];

    if (canInvoices.value) {
      const overdue = invoiceQuery.data.value?.overdueCount ?? 0;
      if (overdue > 0) {
        rows.push({
          id: 'overdue-invoices',
          label: `${formatDashboardCount(overdue)} overdue invoices`,
          value: formatDashboardCount(overdue),
          to: {
            name: 'app-global-invoices-page',
            params: withSlug(),
            query: { payment_status: 'overdue' },
          },
          tone: 'warn',
        });
      }
    }

    if (canShopOrder.value) {
      const pickup = shopOrderQuery.data.value?.readyForPickupCount ?? 0;
      if (pickup > 0) {
        rows.push({
          id: 'ready-pickup',
          label: `${formatDashboardCount(pickup)} orders ready for pickup`,
          value: formatDashboardCount(pickup),
          to: { name: 'shop-orders-page', params: withSlug() },
          tone: 'warn',
        });
      }
    }

    if (canWallet.value) {
      const cod = dashboardSummary.value?.courier_cod_holding_total ?? 0;
      if (cod > 0) {
        rows.push({
          id: 'cod-collect',
          label: `${formatDashboardMoney(cod)} COD to collect`,
          value: formatDashboardMoney(cod),
          to: { name: 'app-wallet-home-page', params: withSlug() },
          tone: 'warn',
        });
      }
    }

    if (canStock.value) {
      const inTransit = procurementQuery.data.value?.inTransitCount ?? 0;
      if (inTransit > 0) {
        rows.push({
          id: 'in-transit',
          label: `${formatDashboardCount(inTransit)} batches in transit`,
          value: formatDashboardCount(inTransit),
          to: { name: 'app-procurement-shipment-list', params: withSlug() },
          tone: 'warn',
        });
      }
    }

    if (canTasks.value) {
      const overdue = tasksQuery.data.value?.overdueCount ?? 0;
      if (overdue > 0) {
        rows.push({
          id: 'overdue-tasks',
          label: `${formatDashboardCount(overdue)} overdue tasks`,
          value: formatDashboardCount(overdue),
          to: { name: 'tasks-page', params: withSlug() },
          tone: 'warn',
        });
      }
    }

    if (canInvestor.value) {
      const due = investorQuery.data.value?.dueToInvestors ?? 0;
      if (due > 0) {
        rows.push({
          id: 'due-investors',
          label: `${formatDashboardMoney(due)} due to investors`,
          value: formatDashboardMoney(due),
          to: { name: 'app-capital-ledger-page', params: withSlug() },
          tone: 'warn',
        });
      }
    }

    return rows.slice(0, MAX_ITEMS);
  });

  return { items };
};
