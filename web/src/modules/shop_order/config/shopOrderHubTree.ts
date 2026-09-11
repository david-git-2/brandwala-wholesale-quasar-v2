import type { ModuleKey } from 'src/modules/navigation/modulePermissions';

export type ShopHubTreeNodeDef = {
  key: string;
  labelKey: string;
  icon: string;
  routeName?: string;
  moduleKey?: ModuleKey;
  children?: ShopHubTreeNodeDef[];
};

export const SHOP_ORDER_HUB_TREE: ShopHubTreeNodeDef[] = [
  {
    key: 'store_setup',
    labelKey: 'shop_admin.shop_hub_group_store_setup',
    icon: 'ph ph-storefront',
    children: [
      {
        key: 'shops',
        labelKey: 'navigation.shops',
        icon: 'ph ph-storefront',
        routeName: 'app-shop-shops-list-page',
        moduleKey: 'shop_config',
      },
      {
        key: 'categories',
        labelKey: 'navigation.categories',
        icon: 'ph ph-squares-four',
        routeName: 'app-shop-categories-page',
        moduleKey: 'shop_category',
      },
    ],
  },
  {
    key: 'orders',
    labelKey: 'navigation.orders',
    icon: 'ph ph-receipt',
    routeName: 'app-shop-orders-page',
    moduleKey: 'shop_order_mgmt',
  },
  {
    key: 'dropship_management',
    labelKey: 'shop_admin.dropship_management',
    icon: 'ph ph-package',
    routeName: 'app-shop-dropship-management-page',
    moduleKey: 'shop_order_mgmt',
  },
  {
    key: 'shipping',
    labelKey: 'navigation.shipping',
    icon: 'ph ph-truck',
    children: [
      {
        key: 'couriers',
        labelKey: 'shop_admin.shipping_couriers',
        icon: 'ph ph-truck',
        routeName: 'app-shop-dropship-couriers-page',
        moduleKey: 'shop_shipping',
      },
      {
        key: 'remittance',
        labelKey: 'shop_admin.shipping_remittance',
        icon: 'ph ph-bank',
        routeName: 'app-shop-dropship-finance-hub-page',
        moduleKey: 'shop_shipping',
      },
    ],
  },
];

export function filterHubTree(
  nodes: ShopHubTreeNodeDef[],
  canView: (moduleKey: ModuleKey) => boolean,
): ShopHubTreeNodeDef[] {
  const result: ShopHubTreeNodeDef[] = [];

  for (const node of nodes) {
    if (node.children?.length) {
      const children = filterHubTree(node.children, canView);
      if (children.length > 0) {
        result.push({ ...node, children });
      }
      continue;
    }

    if (node.moduleKey && node.routeName && canView(node.moduleKey)) {
      result.push(node);
    }
  }

  return result;
}

export type ShopHubTreeNode = {
  key: string;
  label: string;
  icon: string;
  routeName?: string;
  children?: ShopHubTreeNode[];
};

export function mapHubTreeToQTreeNodes(
  nodes: ShopHubTreeNodeDef[],
  translate: (key: string) => string,
): ShopHubTreeNode[] {
  return nodes.map((node) => ({
    key: node.key,
    label: translate(node.labelKey),
    icon: node.icon,
    routeName: node.routeName,
    children: node.children ? mapHubTreeToQTreeNodes(node.children, translate) : undefined,
  }));
}

export function findHubTreeNodeByKey(
  nodes: ShopHubTreeNode[],
  key: string,
): ShopHubTreeNode | null {
  for (const node of nodes) {
    if (node.key === key) {
      return node;
    }
    if (node.children?.length) {
      const match = findHubTreeNodeByKey(node.children, key);
      if (match) {
        return match;
      }
    }
  }
  return null;
}
