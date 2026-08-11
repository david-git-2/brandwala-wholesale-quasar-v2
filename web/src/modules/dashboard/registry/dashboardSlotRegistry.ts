import { THRIFT_DASHBOARD_SLOTS } from 'src/modules/thrift/dashboard/thriftDashboardSlots';
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
  ResolvedDashboardSlots,
} from '../types/dashboardSlot';

/** Fixed group order weights. Lower first. Unknown parents sort after. */
const GROUP_WEIGHT: Partial<Record<ModuleKey, number>> = {
  thrift: 10,
};

export const DASHBOARD_SLOT_REGISTRY: readonly DashboardSlot[] = [...THRIFT_DASHBOARD_SLOTS];

export const resolveDashboardSlots = ({
  scope,
  hasAccess,
}: {
  scope: AuthScope | null;
  hasAccess: (moduleKey: ModuleKey, action: ModuleAction) => boolean;
}): ResolvedDashboardSlots => {
  if (scope !== 'app') {
    return { primaries: [], groups: [] };
  }

  const appScope: DashboardSlotScope = 'app';
  const visible = DASHBOARD_SLOT_REGISTRY.filter(
    (slot) =>
      slot.scopes.includes(appScope) && hasAccess(slot.moduleKey, slot.action ?? 'view'),
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
