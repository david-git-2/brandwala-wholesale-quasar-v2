import { THRIFT_DASHBOARD_SLOTS } from 'src/modules/thrift/dashboard/thriftDashboardSlots';
import { SALES_INVOICE_DASHBOARD_SLOTS } from 'src/modules/sales_invoice/dashboard/salesInvoiceDashboardSlots';
import { WALLET_DASHBOARD_SLOTS } from 'src/modules/wallet/dashboard/walletDashboardSlots';
import { INVESTOR_CAPITAL_DASHBOARD_SLOTS } from 'src/modules/investor_capital/dashboard/investorCapitalDashboardSlots';
import { TASKS_DASHBOARD_SLOTS } from 'src/modules/tasks/dashboard/tasksDashboardSlots';
import { AFTER_SALES_DASHBOARD_SLOTS } from 'src/modules/after_sales/dashboard/afterSalesDashboardSlots';
import {
  getModuleDefinition,
  type ModuleAction,
  type ModuleKey,
} from 'src/modules/navigation/moduleRegistry';
import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin';
import type {
  DashboardSlot,
  DashboardSlotGroup,
  DashboardSlotScope,
  DashboardWorkspaceKind,
  ResolvedDashboardSlots,
} from '../types/dashboardSlot';

/** Fixed group order weights. Lower first. Unknown parents sort after. */
const GROUP_WEIGHT: Partial<Record<ModuleKey, number>> = {
  sales_invoice: 10,
  after_sales: 15,
  universal_wallet: 20,
  investor_capital: 30,
  tasks: 40,
  thrift: 50,
};

export const DASHBOARD_SLOT_REGISTRY: readonly DashboardSlot[] = [
  ...SALES_INVOICE_DASHBOARD_SLOTS,
  ...AFTER_SALES_DASHBOARD_SLOTS,
  ...WALLET_DASHBOARD_SLOTS,
  ...INVESTOR_CAPITAL_DASHBOARD_SLOTS,
  ...TASKS_DASHBOARD_SLOTS,
  ...THRIFT_DASHBOARD_SLOTS,
];

const matchesWorkspaceKind = (
  slot: DashboardSlot,
  workspaceKind: DashboardWorkspaceKind | null,
): boolean => {
  if (!slot.workspaceKinds?.length) {
    return true;
  }
  if (!workspaceKind) {
    return false;
  }
  return slot.workspaceKinds.includes(workspaceKind);
};

export const resolveDashboardSlots = ({
  scope,
  workspaceKind,
  hasAccess,
}: {
  scope: AuthScope | null;
  workspaceKind?: DashboardWorkspaceKind | null;
  hasAccess: (moduleKey: ModuleKey, action: ModuleAction) => boolean;
}): ResolvedDashboardSlots => {
  if (scope !== 'app') {
    return { primaries: [], groups: [] };
  }

  const appScope: DashboardSlotScope = 'app';
  const visible = DASHBOARD_SLOT_REGISTRY.filter(
    (slot) =>
      slot.scopes.includes(appScope) &&
      matchesWorkspaceKind(slot, workspaceKind ?? null) &&
      hasAccess(slot.moduleKey, slot.action ?? 'view'),
  );

  const primaries = visible
    .filter((slot) => slot.primary === true)
    .slice()
    .sort((a, b) => (a.primaryOrder ?? 99) - (b.primaryOrder ?? 99));

  const byParent = new Map<ModuleKey, DashboardSlot[]>();
  for (const slot of visible) {
    const list = byParent.get(slot.parentGroupKey) ?? [];
    list.push(slot);
    byParent.set(slot.parentGroupKey, list);
  }

  const groups: DashboardSlotGroup[] = [];
  for (const [parentGroupKey, slots] of byParent) {
    const def = getModuleDefinition(parentGroupKey);
    groups.push({
      parentGroupKey,
      title: def?.name ?? parentGroupKey,
      icon: def?.navIcon ?? 'ph ph-squares-four',
      weight: GROUP_WEIGHT[parentGroupKey] ?? 99,
      slots: slots.slice().sort((a, b) => a.order - b.order),
    });
  }

  groups.sort((a, b) => a.weight - b.weight || a.title.localeCompare(b.title));

  return { primaries, groups };
};
