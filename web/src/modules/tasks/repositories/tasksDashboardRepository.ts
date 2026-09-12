import { supabase } from 'src/boot/supabase';
import { asDashboardNumber } from 'src/modules/dashboard/utils/formatDashboardMetric';

export type TasksDashboardMetrics = {
  tenantId: number;
  assignedToMe: number;
  overdueCount: number;
  dueTodayCount: number;
  unassignedCount: number;
  myTodo: number;
  myDoing: number;
  myStuck: number;
  myDone: number;
};

export const tasksDashboardRepository = {
  async getMetrics(tenantId: number): Promise<TasksDashboardMetrics> {
    const { data, error } = await supabase.rpc('get_tasks_dashboard_metrics', {
      p_tenant_id: tenantId,
    });
    if (error) {
      throw error;
    }

    const raw = (data ?? {}) as Record<string, unknown>;
    return {
      tenantId: asDashboardNumber(raw.tenant_id) || tenantId,
      assignedToMe: asDashboardNumber(raw.assigned_to_me),
      overdueCount: asDashboardNumber(raw.overdue_count),
      dueTodayCount: asDashboardNumber(raw.due_today_count),
      unassignedCount: asDashboardNumber(raw.unassigned_count),
      myTodo: asDashboardNumber(raw.my_todo),
      myDoing: asDashboardNumber(raw.my_doing),
      myStuck: asDashboardNumber(raw.my_stuck),
      myDone: asDashboardNumber(raw.my_done),
    };
  },
};
