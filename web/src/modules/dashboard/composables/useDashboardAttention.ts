import { computed } from 'vue';
import { storeToRefs } from 'pinia';
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
  const { hasModuleAccess } = useModulePermissions();
  const { tenantId } = storeToRefs(authStore);
  const routes = useAppDashboardRoutes();

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
          to: routes.globalInvoices({ payment_status: 'overdue' }),
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
          to: routes.shopOrders(),
          tone: 'warn',
        });
      }

      const dropshipSubmitted = shopOrderQuery.data.value?.dropshipSubmitted ?? 0;
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

    if (canWallet.value) {
      const cod = dashboardSummary.value?.courier_cod_holding_total ?? 0;
      if (cod > 0) {
        rows.push({
          id: 'cod-collect',
          label: `${formatDashboardMoney(cod)} COD to collect`,
          value: formatDashboardMoney(cod),
          to: routes.walletHome(),
          tone: 'warn',
        });
      }

      const payables = dashboardSummary.value?.vendor_payables_total ?? 0;
      if (payables > 0) {
        rows.push({
          id: 'vendor-payables',
          label: `${formatDashboardMoney(payables)} vendor payables`,
          value: formatDashboardMoney(payables),
          to: routes.walletHome(),
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
          to: routes.procurementShipmentList(),
          tone: 'warn',
        });
      }

      const draft = procurementQuery.data.value?.draftCount ?? 0;
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

    if (canTasks.value) {
      const overdue = tasksQuery.data.value?.overdueCount ?? 0;
      if (overdue > 0) {
        rows.push({
          id: 'overdue-tasks',
          label: `${formatDashboardCount(overdue)} overdue tasks`,
          value: formatDashboardCount(overdue),
          to: routes.tasks(),
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
          to: routes.capitalLedger(),
          tone: 'warn',
        });
      }
    }

    return rows.slice(0, MAX_ITEMS);
  });

  return { items };
};
