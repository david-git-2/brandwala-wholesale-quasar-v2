import type { InvestorCapitalDashboardMetrics } from 'src/modules/investor_capital/repositories/investorCapitalDashboardRepository';
import type { ProcurementDashboardMetrics } from 'src/modules/procurement_stock/repositories/procurementDashboardRepository';
import type { ShopOrderDashboardMetrics } from 'src/modules/shop_order/repositories/shopOrderDashboardRepository';
import type { TasksDashboardMetrics } from 'src/modules/tasks/repositories/tasksDashboardRepository';

export type DashboardChildTenantRef = {
  id: number;
  parent_id: number;
  name: string;
};

export type AppDashboardBundle = {
  refreshedAt: string | null;
  procurement: ProcurementDashboardMetrics | null;
  shopOrder: ShopOrderDashboardMetrics | null;
  tasks: TasksDashboardMetrics | null;
  investorCapital: InvestorCapitalDashboardMetrics | null;
  childTenantRefs: DashboardChildTenantRef[];
};

export type StoredAppDashboardBundle = {
  schemaVersion: 1;
  tenantId: number;
  refreshedAt: string;
  bundle: AppDashboardBundle;
};
