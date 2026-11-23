import type { Component } from 'vue';

import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin';
import type { ModuleAction, ModuleKey } from 'src/modules/navigation/moduleRegistry';

/** shortcut/action = link tiles; section/attention/stat = lazy Vue components. */
export type DashboardSlotKind = 'shortcut' | 'action' | 'stat' | 'attention' | 'section';

export type DashboardSlotScope = Extract<AuthScope, 'app'>;

/** Parent owns books/policy; child is the operating shop desk. */
export type DashboardWorkspaceKind = 'parent' | 'child';

export type DashboardSlot = {
  id: string;
  scopes: readonly DashboardSlotScope[];
  moduleKey: ModuleKey;
  /** Default `view`. Use `create` for primary CTAs. */
  action?: ModuleAction;
  /** Parent vertical for group chrome (e.g. `thrift`). */
  parentGroupKey: ModuleKey;
  kind: DashboardSlotKind;
  title: string;
  caption?: string;
  icon: string;
  /** Sort within group (ascending). */
  order: number;
  /** Named route for shortcut/action tiles. */
  routeName?: string;
  routeParams?: Record<string, string | number>;
  /** Lazy or sync component for section/attention/stat. */
  component?: Component;
  /** Promote into the top workspace primary-actions strip. */
  primary?: boolean;
  primaryOrder?: number;
  /** When set, slot only renders for these workspace kinds. Omit = both. */
  workspaceKinds?: readonly DashboardWorkspaceKind[];
};

export const isDashboardTileKind = (kind: DashboardSlotKind) =>
  kind === 'shortcut' || kind === 'action';

export const isDashboardBlockKind = (kind: DashboardSlotKind) =>
  kind === 'section' || kind === 'attention' || kind === 'stat';

export type DashboardSlotGroup = {
  parentGroupKey: ModuleKey;
  title: string;
  icon: string;
  weight: number;
  slots: DashboardSlot[];
};

export type ResolvedDashboardSlots = {
  primaries: DashboardSlot[];
  groups: DashboardSlotGroup[];
};
