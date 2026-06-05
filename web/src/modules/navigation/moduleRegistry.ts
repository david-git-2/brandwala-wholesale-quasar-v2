import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'

export type ModuleKey =
  | 'order_management'
  | 'shipment'
  | 'inventory'
  | 'commerce_shop'
  | 'commerce_order'
  | 'commerce_invoice'
  | 'commerce_accounting'
  | 'commerce_cart'
  | 'investor'
  | 'vendor'
  | 'products'
  | 'product_based_costing'
  | 'costing_file'
  | 'store'
  | 'cart'
  | 'accounting'
  | 'invoice'
  | 'koba_retail'
  | 'koba_wholesale'
  | 'tasks'

export type ModuleAction = 'view'
export type InteractiveScope = Extract<AuthScope, 'app' | 'shop'>

export interface ModuleRouteDefinition {
  scope: InteractiveScope
  title: string
  caption: string
  icon: string
  routeSegment: string
  requiredAction?: ModuleAction
}

export interface ModuleDefinition {
  key: ModuleKey
  name: string
  description: string
  routes: ModuleRouteDefinition[]
}

export const MODULE_REGISTRY: readonly ModuleDefinition[] = [
  {
    key: 'order_management',
    name: 'Order Management',
    description: 'Create, review, approve, and track order flow.',
    routes: [
      {
        scope: 'app',
        title: 'Orders',
        caption: 'Manage order intake and internal workflow',
        icon: 'receipt_long',
        routeSegment: 'orders',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Orders',
        caption: 'Build carts, place orders, and follow negotiation',
        icon: 'shopping_bag',
        routeSegment: 'orders',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shipment',
    name: 'Shipment',
    description: 'Coordinate dispatch, logistics, and delivery status.',
    routes: [
      {
        scope: 'app',
        title: 'Shipment',
        caption: 'Track dispatch, handoff, and delivery progress',
        icon: 'local_shipping',
        routeSegment: 'shipment',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'inventory',
    name: 'Inventory',
    description: 'Monitor stock, availability, and inventory movement.',
    routes: [
      {
        scope: 'app',
        title: 'Inventory',
        caption: 'Review stock levels and inventory operations',
        icon: 'inventory_2',
        routeSegment: 'inventory',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'commerce_shop',
    name: 'Commerce Shop',
    description: 'Isolated commerce module using dedicated pricing and inventory summary flow.',
    routes: [
      {
        scope: 'app',
        title: 'Commerce Shop Manage',
        caption: 'Manage commerce shop stores',
        icon: 'storefront',
        routeSegment: 'commerce-shop/manage-store',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Commerce Shop Access',
        caption: 'Manage commerce shop customer-group access',
        icon: 'lock_open',
        routeSegment: 'commerce-shop/manage-access',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Commerce Shop Products',
        caption: 'Manage products for commerce shop stores',
        icon: 'inventory_2',
        routeSegment: 'commerce-shop/store-products',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Commerce Shop Pricing',
        caption: 'Manage prices and sell prices for store products',
        icon: 'payments',
        routeSegment: 'commerce-shop/pricing',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Commerce Shop',
        caption: 'Browse products in isolated commerce flow',
        icon: 'storefront',
        routeSegment: 'commerce-shop',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'commerce_order',
    name: 'Commerce Order',
    description: 'Dedicated order module for commerce shop flows.',
    routes: [
      {
        scope: 'app',
        title: 'Commerce Orders',
        caption: 'Manage commerce orders',
        icon: 'receipt_long',
        routeSegment: 'commerce-shop/orders',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Order Settings',
        caption: 'Manage default charges',
        icon: 'settings',
        routeSegment: 'commerce-shop/settings',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Commerce Orders',
        caption: 'Track your commerce orders',
        icon: 'shopping_bag',
        routeSegment: 'commerce-shop/orders',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'commerce_invoice',
    name: 'Commerce Invoice',
    description: 'Dedicated invoice module for commerce shop flows.',
    routes: [
      {
        scope: 'app',
        title: 'Commerce Invoices',
        caption: 'Manage commerce invoices',
        icon: 'description',
        routeSegment: 'commerce-shop/invoices',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'commerce_accounting',
    name: 'Commerce Accounting',
    description: 'Dedicated accounting module for commerce shop workflows.',
    routes: [
      {
        scope: 'app',
        title: 'Commerce Accounting',
        caption: 'Review commerce accounting entries',
        icon: 'account_balance',
        routeSegment: 'commerce-shop/accounting',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'commerce_cart',
    name: 'Commerce Cart',
    description: 'Dedicated cart module for commerce shop workflows.',
    routes: [
      {
        scope: 'shop',
        title: 'Commerce Cart',
        caption: 'Review and manage your commerce cart',
        icon: 'shopping_cart',
        routeSegment: 'commerce-shop/cart',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'investor',
    name: 'Investor',
    description: 'Manage investor profiles and investor transaction records.',
    routes: [
      {
        scope: 'app',
        title: 'Investor Profile',
        caption: 'Manage investor profiles',
        icon: 'groups',
        routeSegment: 'investors/profile',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Investor Transaction',
        caption: 'Manage investor transactions',
        icon: 'sync_alt',
        routeSegment: 'investors/transactions',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Investor Shipment',
        caption: 'Manage shipment investments',
        icon: 'local_shipping',
        routeSegment: 'investors/shipments',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'vendor',
    name: 'Vendor',
    description: 'Manage vendor records, sourcing, and supplier collaboration.',
    routes: [
      {
        scope: 'app',
        title: 'Vendors',
        caption: 'Manage suppliers and vendor operations',
        icon: 'storefront',
        routeSegment: 'vendors',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'products',
    name: 'Products',
    description: 'Manage the product catalog and product-level records.',
    routes: [
      {
        scope: 'app',
        title: 'Products',
        caption: 'Manage tenant product catalog',
        icon: 'inventory_2',
        routeSegment: 'products',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Brands',
        caption: 'Manage product brands',
        icon: 'inventory_2',
        routeSegment: 'products/brands',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Categories',
        caption: 'Manage product categories',
        icon: 'inventory_2',
        routeSegment: 'products/categories',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'product_based_costing',
    name: 'Product Based Costing',
    description: 'Support product-based costing files for internal workflows.',
    routes: [
      {
        scope: 'app',
        title: 'Product Based Costing',
        caption: 'Manage product based costing files',
        icon: 'request_quote',
        routeSegment: 'product-based-costing',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'costing_file',
    name: 'Costing File',
    description: 'Manage internal costing references and pricing preparation.',
    routes: [
      {
        scope: 'app',
        title: 'Pre order',
        caption: 'Prepare internal costing files and price support',
        icon: 'price_change',
        routeSegment: 'costing',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Pre order',
        caption: 'Open customer-facing costing references',
        icon: 'request_quote',
        routeSegment: 'costing',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'accounting',
    name: 'Accounting',
    description: 'Handle accounting workflows tied to tenant operations.',
    routes: [
      {
        scope: 'app',
        title: 'Accounting',
        caption: 'Review accounting workflows and financial handoff',
        icon: 'account_balance',
        routeSegment: 'accounting',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Invoice Accounting',
        caption: 'Review invoice accounting entries and payments',
        icon: 'request_quote',
        routeSegment: 'accounting/invoice',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Customer Payments',
        caption: 'Create customer payments and allocate across invoices',
        icon: 'payments',
        routeSegment: 'accounting/customer-payments',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Shipment Accounting',
        caption: 'Review shipments and open shipment accounting details',
        icon: 'local_shipping',
        routeSegment: 'accounting/shipment',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Inventory Shipment Summary',
        caption: 'View shipment-wise usable, damaged, stolen, and expired accounting totals',
        icon: 'inventory_2',
        routeSegment: 'accounting/inventory-shipment',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'store',
    name: 'Store',
    description: 'Manage storefront configuration and store-level operations.',
    routes: [
      {
        scope: 'app',
        title: 'Stores',
        caption: 'Manage tenant stores and customer access',
        icon: 'store',
        routeSegment: 'stores',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Stores',
        caption: 'View stores available to your customer group',
        icon: 'storefront',
        routeSegment: 'stores',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'cart',
    name: 'Cart',
    description: 'Manage customer shopping carts and line items.',
    routes: [
      {
        scope: 'shop',
        title: 'Cart',
        caption: 'Review and manage your cart',
        icon: 'shopping_cart',
        routeSegment: 'cart',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'invoice',
    name: 'Invoice',
    description: 'Manage invoice creation, status, and reconciliation flow.',
    routes: [
      {
        scope: 'app',
        title: 'Invoices',
        caption: 'Create and review invoice activity',
        icon: 'description',
        routeSegment: 'invoices',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Billing Profiles',
        caption: 'Manage billing profile records for invoices',
        icon: 'badge',
        routeSegment: 'invoices/billing-profiles',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'koba_retail',
    name: 'Koba Retail',
    description: 'Browse scraped Koba Retail products catalog.',
    routes: [
      {
        scope: 'app',
        title: 'Products',
        caption: 'Browse Koba Retail products',
        icon: 'shopping_bag',
        routeSegment: 'koba/retail',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Cart',
        caption: 'Review and manage your retail cart',
        icon: 'shopping_cart',
        routeSegment: 'koba/retail/cart',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Orders',
        caption: 'Track placed retail orders',
        icon: 'receipt_long',
        routeSegment: 'koba/retail/orders',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Settings',
        caption: 'Configure retail settings and charges',
        icon: 'settings',
        routeSegment: 'koba/retail/settings',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Customers',
        caption: 'View customer profiles and order frequency',
        icon: 'people',
        routeSegment: 'koba/retail/customers',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Products',
        caption: 'Browse Koba Retail products',
        icon: 'shopping_bag',
        routeSegment: 'koba/retail',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Cart',
        caption: 'Review and manage your retail cart',
        icon: 'shopping_cart',
        routeSegment: 'koba/retail/cart',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Orders',
        caption: 'Track placed retail orders',
        icon: 'receipt_long',
        routeSegment: 'koba/retail/orders',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'koba_wholesale',
    name: 'Koba Wholesale',
    description: 'Browse scraped Koba Wholesale products catalog.',
    routes: [
      {
        scope: 'app',
        title: 'Koba Wholesale',
        caption: 'Browse Koba Wholesale products',
        icon: 'shopping_cart',
        routeSegment: 'koba/wholesale',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'tasks',
    name: 'Tasks',
    description: 'Manage projects, modules, submodules, tasks, notes, discussions, bugs, features.',
    routes: [
      {
        scope: 'app',
        title: 'Tasks',
        caption: 'Manage tasks and project hierarchy',
        icon: 'assignment',
        routeSegment: 'tasks',
        requiredAction: 'view',
      },
    ],
  },
] as const

export const MODULE_REGISTRY_KEYS = MODULE_REGISTRY.map((definition) => definition.key)

export const MODULE_REGISTRY_BY_KEY: Readonly<Record<ModuleKey, ModuleDefinition>> =
  Object.freeze(
    MODULE_REGISTRY.reduce(
      (accumulator, definition) => {
        accumulator[definition.key] = definition
        return accumulator
      },
      {} as Record<ModuleKey, ModuleDefinition>,
    ),
  )

export const getModuleDefinition = (moduleKey: ModuleKey) =>
  MODULE_REGISTRY_BY_KEY[moduleKey]

export const buildModuleRoutePath = ({
  scope,
  routeSegment,
  tenantSlug,
}: {
  scope: InteractiveScope
  routeSegment: string
  tenantSlug?: string | null | undefined
}) => {
  if (scope === 'shop') {
    return tenantSlug ? `/${tenantSlug}/shop/${routeSegment}` : `/shop/${routeSegment}`
  }

  return tenantSlug ? `/${tenantSlug}/app/${routeSegment}` : `/app/${routeSegment}`
}

export const getModuleRoutesForScope = (
  scope: InteractiveScope,
  options?: {
    tenantSlug?: string | null | undefined
  },
) =>
  MODULE_REGISTRY.flatMap((definition) =>
    definition.routes
      .filter((routeDefinition) => routeDefinition.scope === scope)
      .map((routeDefinition) => ({
        moduleKey: definition.key,
        moduleName: definition.name,
        to: buildModuleRoutePath({
          scope: routeDefinition.scope,
          routeSegment: routeDefinition.routeSegment,
          tenantSlug: options?.tenantSlug,
        }),
        ...routeDefinition,
      })),
  ).sort((a, b) => {
    const aIsDashboard = a.title.trim().toLowerCase() === 'dashboard'
    const bIsDashboard = b.title.trim().toLowerCase() === 'dashboard'

    if (aIsDashboard && !bIsDashboard) return -1
    if (!aIsDashboard && bIsDashboard) return 1

    return a.title.localeCompare(b.title, undefined, { sensitivity: 'base' })
  })
