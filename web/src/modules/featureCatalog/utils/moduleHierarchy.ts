import type { WorkspaceLink } from 'src/components/WorkspaceShell.vue';
import type { ModuleDefinition, ModuleKey } from 'src/modules/navigation/moduleRegistry';

export interface ModuleHierarchyRow {
  key: string;
  name: string;
  parent_module_key?: string | null;
  is_active?: boolean;
}

export interface AccessibleModuleRoute {
  moduleKey: ModuleKey;
  title: string;
  caption: string;
  icon: string;
  to: string;
}

export interface ModuleTree {
  parents: ModuleHierarchyRow[];
  childrenByParent: Map<string, ModuleHierarchyRow[]>;
}

export const isSubmodule = (module: Pick<ModuleHierarchyRow, 'parent_module_key'>): boolean =>
  Boolean(module.parent_module_key);

export const buildModuleTree = (modules: ModuleHierarchyRow[]): ModuleTree => {
  const parents = modules.filter((module) => !module.parent_module_key);
  const childrenByParent = new Map<string, ModuleHierarchyRow[]>();

  for (const module of modules) {
    if (!module.parent_module_key) continue;
    const siblings = childrenByParent.get(module.parent_module_key) ?? [];
    siblings.push(module);
    childrenByParent.set(module.parent_module_key, siblings);
  }

  return { parents, childrenByParent };
};

export const getAssignableModules = <T extends ModuleHierarchyRow>(modules: T[]): T[] =>
  modules.filter((module) => !isSubmodule(module));

export const getSubmodulesForParent = <T extends ModuleHierarchyRow>(
  modules: T[],
  parentKey: string,
): T[] => modules.filter((module) => module.parent_module_key === parentKey);

export const getRegistryParentKey = (
  moduleKey: string,
  registry: readonly ModuleDefinition[],
): ModuleKey | undefined =>
  registry.find((definition) => definition.key === moduleKey)?.parentModuleKey;

const getSubmoduleSectionAndWeight = (
  parentKey: string,
  moduleKey: string,
): { section: string; weight: number } => {
  if (parentKey === 'shop_order') {
    switch (moduleKey) {
      case 'shop_config':
      case 'shop_permissions':
      case 'shop_pricing':
        return { section: 'Shop Setup', weight: 10 };
      case 'shop_order_mgmt':
      case 'shop_fulfillment':
        return { section: 'Operations', weight: 20 };
      case 'shop_dropship':
        return { section: 'Dropship Desk', weight: 30 };
      default:
        return { section: '', weight: 99 };
    }
  }

  if (parentKey === 'reporting_treasury') {
    switch (moduleKey) {
      case 'parent_dashboard':
      case 'billing_balances':
        return { section: 'Overview', weight: 10 };
      case 'payments':
        return { section: 'Transactions', weight: 20 };
      case 'invoice_reports':
      case 'shipment_reports':
      case 'investor_reports':
        return { section: 'Reports', weight: 30 };
      default:
        return { section: '', weight: 99 };
    }
  }

  if (parentKey === 'sales_invoice') {
    switch (moduleKey) {
      case 'global_invoice':
        return { section: 'Invoicing', weight: 10 };
      case 'billing_profile':
      case 'recipient_profile':
      case 'invoice_brand':
        return { section: 'Profiles & Brands', weight: 20 };
      default:
        return { section: '', weight: 99 };
    }
  }

  if (parentKey === 'thrift') {
    switch (moduleKey) {
      case 'thrift_stock':
        return { section: 'Inventory & Tags', weight: 10 };
      case 'thrift_shipment':
      case 'thrift_box':
      case 'thrift_shelf':
        return { section: 'Logistics & Storage', weight: 20 };
      case 'thrift_category':
      case 'thrift_type':
        return { section: 'Classification', weight: 30 };
      case 'thrift_barcode':
      case 'thrift_settings':
        return { section: 'Tools & Settings', weight: 40 };
      default:
        return { section: '', weight: 99 };
    }
  }

  return { section: '', weight: 99 };
};

export const buildNavLinksFromModuleHierarchy = (
  accessibleRoutes: AccessibleModuleRoute[],
  registry: readonly ModuleDefinition[],
): { hierarchyLinks: WorkspaceLink[]; remainingRoutes: AccessibleModuleRoute[] } => {
  const registryByKey = new Map(registry.map((definition) => [definition.key, definition]));
  const parentKeys = registry
    .filter((definition) => registry.some((child) => child.parentModuleKey === definition.key))
    .map((definition) => definition.key);

  const hierarchyLinks: WorkspaceLink[] = [];
  const routesInHierarchy = new Set<ModuleKey>();

  for (const parentKey of parentKeys) {
    const parentDefinition = registryByKey.get(parentKey);
    if (!parentDefinition) continue;

    const childRoutes = accessibleRoutes.filter((route) => {
      const childDefinition = registryByKey.get(route.moduleKey);
      return childDefinition?.parentModuleKey === parentKey;
    });

    if (childRoutes.length === 0) continue;

    childRoutes.forEach((route) => routesInHierarchy.add(route.moduleKey));

    const mappedChildren = childRoutes
      .map((route) => {
        const { section, weight } = getSubmoduleSectionAndWeight(parentKey, route.moduleKey);
        return {
          title: route.title,
          caption: route.caption,
          icon: route.icon || 'fiber_manual_record',
          to: route.to,
          section: section || undefined,
          weight,
        };
      })
      .sort((a, b) => {
        if (a.weight !== b.weight) {
          return a.weight - b.weight;
        }
        return a.title.localeCompare(b.title);
      });

    hierarchyLinks.push({
      title: parentDefinition.name,
      caption: parentDefinition.description,
      icon: parentDefinition.navIcon ?? 'folder',
      children: mappedChildren.map(({ title, caption, icon, to, section }) => ({
        title,
        caption,
        icon,
        to,
        section,
      })),
    });
  }

  const remainingRoutes = accessibleRoutes.filter(
    (route) => !routesInHierarchy.has(route.moduleKey),
  );

  return { hierarchyLinks, remainingRoutes };
};
