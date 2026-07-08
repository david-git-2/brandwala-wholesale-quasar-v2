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

    hierarchyLinks.push({
      title: parentDefinition.name,
      caption: parentDefinition.description,
      icon: parentDefinition.navIcon ?? 'folder',
      children: childRoutes.map((route) => ({
        title: route.title,
        caption: route.caption,
        icon: 'chevron_right',
        to: route.to,
      })),
    });
  }

  const remainingRoutes = accessibleRoutes.filter(
    (route) => !routesInHierarchy.has(route.moduleKey),
  );

  return { hierarchyLinks, remainingRoutes };
};
