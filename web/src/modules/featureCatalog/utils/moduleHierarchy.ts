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
        return { section: 'Shop Setup', weight: 10 };
      case 'shop_category':
        return { section: 'Shop Setup', weight: 20 };
      case 'shop_permissions':
        return { section: 'Shop Setup', weight: 30 };
      case 'shop_pricing':
        return { section: 'Shop Setup', weight: 40 };
      case 'shop_order_mgmt':
        return { section: 'Operations', weight: 50 };
      case 'shop_fulfillment':
        return { section: 'Operations', weight: 60 };
      case 'shop_dropship':
        return { section: 'Dropship Desk', weight: 70 };
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
      case 'thrift_sales':
        return { section: 'Sell', weight: 10 };
      case 'thrift_customers':
        return { section: 'Sell', weight: 15 };
      case 'thrift_reports':
        return { section: 'Sell', weight: 20 };
      case 'thrift_stock':
        return { section: 'Floor', weight: 30 };
      case 'thrift_marketing_tag':
        return { section: 'Floor', weight: 40 };
      case 'thrift_shipment':
        return { section: 'Inbound', weight: 50 };
      case 'thrift_box':
        return { section: 'Inbound', weight: 60 };
      case 'thrift_shelf':
        return { section: 'Inbound', weight: 70 };
      case 'thrift_category':
        return { section: 'Setup', weight: 80 };
      case 'thrift_type':
        return { section: 'Setup', weight: 90 };
      case 'thrift_barcode':
        return { section: 'Setup', weight: 100 };
      case 'thrift_settings':
        return { section: 'Setup', weight: 110 };
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
