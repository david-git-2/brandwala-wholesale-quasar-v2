import type { WorkspaceLink } from 'src/components/WorkspaceShell.vue';
import { buildModuleRoutePath, MODULE_REGISTRY, type ModuleKey } from './moduleRegistry';

export const SHOP_ORDER_PRIMARY_KEYS = ['orders', 'dropship_management', 'shops', 'product_based_costing'] as const;

export const PROCUREMENT_PRIMARY_KEYS = ['demand', 'fulfill', 'shipment', 'warehouse'] as const;

export const SHOP_ORDER_HUB_MODULE_KEYS: readonly ModuleKey[] = [
  'shop_config',
  'shop_category',
  'shop_permissions',
  'shop_pricing',
  'shop_order_mgmt',
  'shop_shipping',
  'product_based_costing',
];

export const PROCUREMENT_HUB_MODULE_KEYS: readonly ModuleKey[] = [
  'procurement_demand',
  'procurement_fulfill',
  'global_shipment',
  'global_stock',
  'global_stock_movement',
  'global_stock_location',
  'cargo_company',
  'shipment_progress_settings',
  'inventory',
];

export const REFERENCE_HUB_MODULE_KEYS: readonly ModuleKey[] = [
  'global_reference_currency',
  'global_reference_market',
  'global_reference_payment_method',
  'global_reference_unit_of_measure',
];

export type WeightedWorkspaceLink = WorkspaceLink & { navWeight: number };

type CanViewModule = (moduleKey: ModuleKey) => boolean;

type SettingsAccessContext = {
  role: string | null | undefined;
  isAdmin?: boolean | null | undefined;
  canView: CanViewModule;
};

type HubPrimaryLinkDef = {
  navWeight: number;
  moduleKey: ModuleKey;
  title: string;
  caption: string;
  icon: string;
  routeSegment: string;
};

type HubMoreLinkDef = {
  navWeight: number;
  title: string;
  caption: string;
  icon: string;
  routeSegment: string;
  hubModuleKeys: readonly ModuleKey[];
  primaryRouteSegments: readonly string[];
};

const SHOP_ORDER_HUB = {
  primaryLinks: [
    {
      navWeight: 20,
      moduleKey: 'shop_order_mgmt' as ModuleKey,
      title: 'Orders',
      caption: 'All shop orders — catalog, retail, wholesale, dropship',
      icon: 'ph ph-receipt',
      routeSegment: 'shop/orders',
    },
    {
      navWeight: 21,
      moduleKey: 'shop_order_mgmt' as ModuleKey,
      title: 'Dropship Management',
      caption: 'Dropship orders, returns, and settlements',
      icon: 'ph ph-package',
      routeSegment: 'shop/dropship-management',
    },
    {
      navWeight: 22,
      moduleKey: 'shop_config' as ModuleKey,
      title: 'Shops',
      caption: 'Create shops and manage storefront setup',
      icon: 'ph ph-storefront',
      routeSegment: 'shop/shops/list',
    },
    {
      navWeight: 23,
      moduleKey: 'product_based_costing' as ModuleKey,
      title: 'Product Based Costing',
      caption: 'Manage product based costing files',
      icon: 'ph ph-receipt',
      routeSegment: 'product-based-costing',
    },
  ] satisfies HubPrimaryLinkDef[],
  moreLink: {
    navWeight: 24,
    title: 'More',
    caption: 'Categories, pricing, and shipping',
    icon: 'ph ph-dots-three-outline',
    routeSegment: 'shop',
    hubModuleKeys: SHOP_ORDER_HUB_MODULE_KEYS,
    primaryRouteSegments: [
      'shop/orders',
      'shop/dropship-management',
      'shop/shops/list',
      'product-based-costing',
    ],
  } satisfies HubMoreLinkDef,
};

const PROCUREMENT_STOCK_HUB = {
  primaryLinks: [
    {
      navWeight: 30,
      moduleKey: 'procurement_demand' as ModuleKey,
      title: 'Demand',
      caption: 'Items to source from shop orders and costing files',
      icon: 'ph ph-list-checks',
      routeSegment: 'procurement/demand',
    },
    {
      navWeight: 30.5,
      moduleKey: 'procurement_fulfill' as ModuleKey,
      title: 'Fulfill',
      caption: 'Pick stock and invoice shop orders',
      icon: 'ph ph-package',
      routeSegment: 'procurement/fulfill',
    },
    {
      navWeight: 31,
      moduleKey: 'global_shipment' as ModuleKey,
      title: 'Shipments',
      caption: 'Inbound goods from vendors — add items and receive stock',
      icon: 'ph ph-truck',
      routeSegment: 'procurement/shipment/list',
    },
    {
      navWeight: 32,
      moduleKey: 'global_stock' as ModuleKey,
      title: 'Warehouse',
      caption: 'What is on the shelves and whether it can be sold',
      icon: 'ph ph-warehouse',
      routeSegment: 'procurement/stock',
    },
  ] satisfies HubPrimaryLinkDef[],
  moreLink: {
    navWeight: 34,
    title: 'More',
    caption: 'Movements, locations, and cargo',
    icon: 'ph ph-dots-three-outline',
    routeSegment: 'procurement',
    hubModuleKeys: PROCUREMENT_HUB_MODULE_KEYS,
    primaryRouteSegments: [
      'procurement/demand',
      'procurement/fulfill',
      'procurement/shipment/list',
      'procurement/stock',
    ],
  } satisfies HubMoreLinkDef,
};

export const SETTINGS_NAV_LINK = {
  navWeight: 70,
  title: 'Settings',
  caption: 'Access control and reference catalogs',
  icon: 'ph ph-gear',
  routeSegment: 'settings',
};

export type SettingsHubItemDef = {
  weight: number;
  key: string;
  title: string;
  caption: string;
  icon: string;
  routeSegment: string;
  adminOnly?: boolean;
  moduleKeys?: readonly ModuleKey[];
};

export const SETTINGS_HUB_ITEMS: readonly SettingsHubItemDef[] = [
  {
    weight: 1,
    key: 'access-control',
    title: 'Tenant Access Control',
    caption: 'Roles, team, modules, and customer groups',
    icon: 'ph ph-shield-check',
    routeSegment: 'access-control',
    adminOnly: true,
  },
  {
    weight: 2,
    key: 'reference',
    title: 'Reference',
    caption: 'Currencies, markets, payment methods, and units',
    icon: 'ph ph-books',
    routeSegment: 'reference',
    moduleKeys: REFERENCE_HUB_MODULE_KEYS,
  },
];

const buildAppPath = (tenantSlug: string | null | undefined, routeSegment: string): string =>
  buildModuleRoutePath({ scope: 'app', routeSegment, tenantSlug });

export const getShopOrderMoreModuleKeys = (): readonly ModuleKey[] => [
  'shop_category',
  'shop_pricing',
  'shop_shipping',
];

export const getProcurementMoreModuleKeys = (): readonly ModuleKey[] => [
  'global_shipment',
  'inventory',
  'global_stock_movement',
  'global_stock_location',
  'shipment_progress_settings',
  'cargo_company',
];

export function buildShopProcurementHubNavLinks(
  canView: CanViewModule,
  tenantSlug: string | null | undefined,
): WeightedWorkspaceLink[] {
  const groups: WeightedWorkspaceLink[] = [];

  const shopChildren: WorkspaceLink[] = [];

  for (const primary of SHOP_ORDER_HUB.primaryLinks) {
    if (!canView(primary.moduleKey)) {
      continue;
    }
    shopChildren.push({
      title: primary.title,
      caption: primary.caption,
      icon: primary.icon,
      to: buildAppPath(tenantSlug, primary.routeSegment),
    });
  }

  const hasShopSecondary = getShopOrderMoreModuleKeys().some((moduleKey) => canView(moduleKey));
  if (hasShopSecondary) {
    shopChildren.push({
      title: SHOP_ORDER_HUB.moreLink.title,
      caption: SHOP_ORDER_HUB.moreLink.caption,
      icon: SHOP_ORDER_HUB.moreLink.icon,
      to: buildAppPath(tenantSlug, SHOP_ORDER_HUB.moreLink.routeSegment),
    });
  }

  if (shopChildren.length > 0) {
    groups.push({
      navWeight: 20,
      navGroup: true,
      title: 'Shop & Order',
      caption: 'Shops, orders, and shipping',
      icon: 'ph ph-storefront',
      children: shopChildren,
    });
  }

  const procurementChildren: WorkspaceLink[] = [];

  for (const primary of PROCUREMENT_STOCK_HUB.primaryLinks) {
    if (!canView(primary.moduleKey)) {
      continue;
    }
    procurementChildren.push({
      title: primary.title,
      caption: primary.caption,
      icon: primary.icon,
      to: buildAppPath(tenantSlug, primary.routeSegment),
    });
  }

  const hasProcurementSecondary = getProcurementMoreModuleKeys().some((moduleKey) =>
    canView(moduleKey),
  );
  if (hasProcurementSecondary) {
    procurementChildren.push({
      title: PROCUREMENT_STOCK_HUB.moreLink.title,
      caption: PROCUREMENT_STOCK_HUB.moreLink.caption,
      icon: PROCUREMENT_STOCK_HUB.moreLink.icon,
      to: buildAppPath(tenantSlug, PROCUREMENT_STOCK_HUB.moreLink.routeSegment),
    });
  }

  if (procurementChildren.length > 0) {
    groups.push({
      navWeight: 30,
      navGroup: true,
      title: 'Procurement & Stock',
      caption: 'Demand, shipments, and warehouse',
      icon: 'ph ph-truck',
      children: procurementChildren,
    });
  }

  return groups;
}

export function buildSettingsNavLink(
  context: SettingsAccessContext,
  tenantSlug: string | null | undefined,
): WeightedWorkspaceLink | null {
  const visibleItems = filterSettingsHubItems(context);
  if (visibleItems.length === 0) {
    return null;
  }

  return {
    navWeight: SETTINGS_NAV_LINK.navWeight,
    title: SETTINGS_NAV_LINK.title,
    caption: SETTINGS_NAV_LINK.caption,
    icon: SETTINGS_NAV_LINK.icon,
    to: buildAppPath(tenantSlug, SETTINGS_NAV_LINK.routeSegment),
  };
}

export function filterSettingsHubItems(context: SettingsAccessContext): SettingsHubItemDef[] {
  return SETTINGS_HUB_ITEMS.filter((item) => {
    if (item.adminOnly) {
      return context.role === 'admin' || context.isAdmin === true;
    }
    if (item.moduleKeys?.length) {
      return item.moduleKeys.some((moduleKey) => context.canView(moduleKey));
    }
    return true;
  });
}

export function getShopOrderFamilyModuleKeys(): readonly ModuleKey[] {
  return MODULE_REGISTRY.filter(
    (definition) =>
      definition.key === 'shop_order' || definition.parentModuleKey === 'shop_order',
  ).map((definition) => definition.key);
}

export function getProcurementFamilyModuleKeys(): readonly ModuleKey[] {
  return MODULE_REGISTRY.filter(
    (definition) =>
      definition.key === 'procurement_stock' || definition.parentModuleKey === 'procurement_stock',
  ).map((definition) => definition.key);
}

export function getReferenceFamilyModuleKeys(): readonly ModuleKey[] {
  return MODULE_REGISTRY.filter(
    (definition) =>
      definition.key === 'global_reference' || definition.parentModuleKey === 'global_reference',
  ).map((definition) => definition.key);
}

export function mergeNavLinksByWeight(...linkGroups: WeightedWorkspaceLink[][]): WorkspaceLink[] {
  return linkGroups
    .flat()
    .sort((a, b) => {
      if (a.navWeight !== b.navWeight) {
        return a.navWeight - b.navWeight;
      }
      return a.title.localeCompare(b.title, undefined, { sensitivity: 'base' });
    })
    .map((item) => {
      const { navWeight: _, ...link } = item;
      void _;
      return link;
    });
}
