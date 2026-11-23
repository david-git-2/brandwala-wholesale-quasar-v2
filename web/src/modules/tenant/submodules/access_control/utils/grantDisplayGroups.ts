/** Display-only split for thrift_shipment actions in Access Control matrices. */
const THRIFT_SHIPMENT_LIST_ACTIONS = new Set([
  'view',
  'create',
  'edit',
  'delete',
  'download',
]);

const THRIFT_SHIPMENT_DETAILS_ACTIONS = new Set([
  'view_landed_cost',
  'edit_landed_cost',
  'view_measurements',
  'edit_measurements',
  'edit_listed_price',
]);

export type GrantDisplayGroup = {
  /** Stable UI group id (may differ from grant module_key). */
  displayKey: string;
  /** Human title for the card header. */
  displayTitle: string;
  /** Real module_key used for grant read/write. */
  grantModuleKey: string;
  actions: Array<{ action: string; module_key: string; [key: string]: unknown }>;
};

function formatModuleKey(key: string): string {
  return key
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

/** Resolve display grouping key for a module_key + action pair. */
export function resolveGrantDisplayKey(moduleKey: string, action: string): string {
  if (moduleKey === 'thrift_shipment') {
    if (THRIFT_SHIPMENT_DETAILS_ACTIONS.has(action)) {
      return 'thrift_shipment_details';
    }
    if (THRIFT_SHIPMENT_LIST_ACTIONS.has(action)) {
      return 'thrift_shipment';
    }
  }
  return moduleKey;
}

export function resolveGrantDisplayTitle(displayKey: string): string {
  if (displayKey === 'thrift_shipment_details') {
    return 'Thrift Shipment Details';
  }
  return formatModuleKey(displayKey);
}

/**
 * Group configurable actions for Access Control UI.
 * Grants still use each action's real `module_key`.
 */
export function groupActionsForGrantMatrix(
  actions: Array<{ module_key: string; action: string; [key: string]: unknown }>,
): GrantDisplayGroup[] {
  const groups = new Map<string, GrantDisplayGroup>();

  for (const act of actions) {
    const displayKey = resolveGrantDisplayKey(act.module_key, act.action);
    const existing = groups.get(displayKey);
    if (existing) {
      existing.actions.push(act);
      continue;
    }
    groups.set(displayKey, {
      displayKey,
      displayTitle: resolveGrantDisplayTitle(displayKey),
      grantModuleKey: act.module_key,
      actions: [act],
    });
  }

  return Array.from(groups.values()).map((group) => ({
    ...group,
    actions: [...group.actions].sort((a, b) => a.action.localeCompare(b.action)),
  }));
}

export { formatModuleKey };
