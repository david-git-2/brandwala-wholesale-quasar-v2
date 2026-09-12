import { supabase } from 'src/boot/supabase';
import { asDashboardNumber } from 'src/modules/dashboard/utils/formatDashboardMetric';

export type InvestorCapitalOpenContainer = {
  name: string;
  allocatedCost: number;
};

export type InvestorCapitalDashboardMetrics = {
  tenantId: number;
  activePoolAmount: number;
  deployedAmount: number;
  deployedThisMonth: number;
  dueToInvestors: number;
  returnedAmount: number;
  openContainerCount: number;
  openContainers: InvestorCapitalOpenContainer[];
};

export const investorCapitalDashboardRepository = {
  async getMetrics(tenantId: number): Promise<InvestorCapitalDashboardMetrics> {
    const { data, error } = await supabase.rpc('get_staff_investor_capital_metrics', {
      p_tenant_id: tenantId,
    });
    if (error) {
      throw error;
    }

    const raw = (data ?? {}) as Record<string, unknown>;
    const containersRaw = Array.isArray(raw.open_containers) ? raw.open_containers : [];

    return {
      tenantId: asDashboardNumber(raw.tenant_id) || tenantId,
      activePoolAmount: asDashboardNumber(raw.active_pool_amount),
      deployedAmount: asDashboardNumber(raw.deployed_amount),
      deployedThisMonth: asDashboardNumber(raw.deployed_this_month),
      dueToInvestors: asDashboardNumber(raw.due_to_investors),
      returnedAmount: asDashboardNumber(raw.returned_amount),
      openContainerCount: asDashboardNumber(raw.open_container_count),
      openContainers: containersRaw.map((row) => {
        const item = row as Record<string, unknown>;
        return {
          name: typeof item.name === 'string' ? item.name : 'Unnamed batch',
          allocatedCost: asDashboardNumber(item.allocated_cost),
        };
      }),
    };
  },
};
