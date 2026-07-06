import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin'

export type ModuleKey =
  | 'order_management'
  | 'vendor'
  | 'products'
  | 'product_based_costing'
  | 'costing_file'
  | 'koba_retail'
  | 'koba_wholesale'
  | 'tasks'
  | 'thrift_stock'
  | 'thrift_shipment'
  | 'thrift_box'
  | 'thrift_shelf'
  | 'thrift_barcode'
  | 'thrift_category'
  | 'thrift_type'
  | 'thrift_settings'
  | 'global_reference'
  | 'global_reference_currency'
  | 'global_reference_market'
  | 'global_reference_payment_method'
  | 'global_reference_unit_of_measure'
  | 'global_shipment'
  | 'global_stock'
  | 'global_invoice'
  | 'investor_portal'
  | 'procurement_stock'
  | 'global_stock_type'
  | 'invoice_brand'
  | 'reporting_treasury'
  | 'payments'
  | 'invoice_reports'
  | 'shipment_reports'
  | 'billing_balances'
  | 'parent_dashboard'
  | 'investor_reports'
  | 'investor_capital'
  | 'investor_profiles'
  | 'investor_capital_ledger'
  | 'investor_shipment_share'
  | 'shop_order'
  | 'shop_config'
  | 'shop_permissions'
  | 'shop_pricing'
  | 'shop_storefront'
  | 'shop_cart'
  | 'shop_order_mgmt'
  | 'shop_fulfillment'
  | 'sales_invoice'
  | 'billing_profile'
  | 'recipient_profile'


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
  parentModuleKey?: ModuleKey
  navIcon?: string
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
  {
    key: 'thrift_stock',
    name: 'Thrift Stock',
    description: 'Manage inventory stock items, brands, and quantities.',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Stock',
        caption: 'Review stock inventory',
        icon: 'inventory',
        routeSegment: 'thrift/stocks',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Marketing Tags',
        caption: 'Print live sale stickers',
        icon: 'local_offer',
        routeSegment: 'thrift/stock-tags',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_shipment',
    name: 'Thrift Shipment',
    description: 'Coordinate shipment logs and transport records within thrift workflows.',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Shipments',
        caption: 'Manage shipments and logs',
        icon: 'local_shipping',
        routeSegment: 'thrift/shipments',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_box',
    name: 'Thrift Box',
    description: 'Manage container boxes and weights under specific shipments.',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Boxes',
        caption: 'Manage container boxes & weights',
        icon: 'inventory_2',
        routeSegment: 'thrift/boxes',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_shelf',
    name: 'Thrift Shelf',
    description: 'Track physical shelf storage and aisle locations in the warehouse.',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Shelves',
        caption: 'Manage shelf locations',
        icon: 'shelves',
        routeSegment: 'thrift/shelves',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_category',
    name: 'Thrift Category',
    description: 'Manage classification categories for thrift stock items.',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Categories',
        caption: 'Manage stock categories',
        icon: 'category',
        routeSegment: 'thrift/categories',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_type',
    name: 'Thrift Type',
    description: 'Manage product styles and types within the thrift catalog.',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Types',
        caption: 'Manage dress and item types',
        icon: 'style',
        routeSegment: 'thrift/types',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_settings',
    name: 'Thrift Settings',
    description: 'Configure default origin purchase price for new stock items.',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Settings',
        caption: 'Default origin purchase price',
        icon: 'settings',
        routeSegment: 'thrift/settings',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_reference',
    name: 'Global Reference',
    description: 'Platform-wide reference catalogs shared across tenants.',
    navIcon: 'library_books',
    routes: [],
  },
  {
    key: 'global_reference_currency',
    name: 'Currencies',
    description: 'Global currency catalog for shipments, pricing, and money display.',
    parentModuleKey: 'global_reference',
    routes: [
      {
        scope: 'app',
        title: 'Currencies',
        caption: 'Currency catalog',
        icon: 'payments',
        routeSegment: 'reference/currencies',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_reference_market',
    name: 'Markets',
    description: 'ISO-style market and country reference catalog.',
    parentModuleKey: 'global_reference',
    routes: [
      {
        scope: 'app',
        title: 'Markets',
        caption: 'Market catalog',
        icon: 'public',
        routeSegment: 'reference/markets',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_reference_payment_method',
    name: 'Payment Methods',
    description: 'Bangladesh and international payment method reference catalog.',
    parentModuleKey: 'global_reference',
    routes: [
      {
        scope: 'app',
        title: 'Payment Methods',
        caption: 'Payment method catalog',
        icon: 'account_balance_wallet',
        routeSegment: 'reference/payment-methods',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_reference_unit_of_measure',
    name: 'Units of Measure',
    description: 'Weight, count, length, volume, and packaging units.',
    parentModuleKey: 'global_reference',
    routes: [
      {
        scope: 'app',
        title: 'Units of Measure',
        caption: 'Unit catalog',
        icon: 'straighten',
        routeSegment: 'reference/units',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_barcode',
    name: 'Thrift Barcode',
    description: 'Manage and print barcodes in bulk.',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Barcodes',
        caption: 'Generate and print barcodes',
        icon: 'qr_code_2',
        routeSegment: 'thrift/barcodes',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_shipment',
    name: 'Global Shipment',
    description: 'Parent-coordinated dispatch, logistics, and delivery.',
    parentModuleKey: 'procurement_stock',
    routes: [
      {
        scope: 'app',
        title: 'Shipment',
        caption: 'Track dispatch, handoff, and delivery progress',
        icon: 'local_shipping',
        routeSegment: 'procurement/shipment',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_stock',
    name: 'Global Stock',
    description: 'Parent-owned stock with child allocation bridge.',
    parentModuleKey: 'procurement_stock',
    routes: [
      {
        scope: 'app',
        title: 'Global Stock',
        caption: 'Parent stock and child allocations',
        icon: 'inventory_2',
        routeSegment: 'procurement/stock',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Allocate Stock',
        caption: 'Divide global stock quantities to child tenants',
        icon: 'call_split',
        routeSegment: 'procurement/stock/allocate',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'sales_invoice',
    name: 'Sales & Invoice',
    description: 'Parent module for sales invoices, billing profiles, recipient profiles, and invoice brands.',
    navIcon: 'receipt_long',
    routes: [],
  },
  {
    key: 'global_invoice',
    name: 'Sales Invoices',
    description: 'Desk invoices: wholesale, retail, and dropship across sister concerns.',
    parentModuleKey: 'sales_invoice',
    routes: [
      {
        scope: 'app',
        title: 'Invoices',
        caption: 'Create and manage desk invoices',
        icon: 'receipt',
        routeSegment: 'sales/invoices',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'billing_profile',
    name: 'Billing Profiles',
    description: 'Manage billing profiles and customer group configurations.',
    parentModuleKey: 'sales_invoice',
    routes: [
      {
        scope: 'app',
        title: 'Billing Profiles',
        caption: 'Manage billing profiles for sales invoices',
        icon: 'contacts',
        routeSegment: 'sales/invoices/billing-profiles',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'recipient_profile',
    name: 'Recipient Profiles',
    description: 'Manage end-customer delivery and drop-ship target profiles.',
    parentModuleKey: 'sales_invoice',
    routes: [
      {
        scope: 'app',
        title: 'Recipient Profiles',
        caption: 'Manage delivery and drop-ship targets',
        icon: 'badge',
        routeSegment: 'sales/invoices/recipient-profiles',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'invoice_brand',
    name: 'Invoice Brands',
    description: 'Configure invoice branding, logos, layout styles, and details.',
    parentModuleKey: 'sales_invoice',
    routes: [],
  },
  {
    key: 'reporting_treasury',
    name: 'Reports & Treasury',
    description: 'Parent module for payments, balances, and margin reports.',
    navIcon: 'account_balance',
    routes: [],
  },
  {
    key: 'payments',
    name: 'Payments & Collection',
    description: 'Record payments and allocate to invoices.',
    parentModuleKey: 'reporting_treasury',
    routes: [
      {
        scope: 'app',
        title: 'Payments',
        caption: 'Create customer payments and allocate across invoices',
        icon: 'payments',
        routeSegment: 'finance/payments',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'invoice_reports',
    name: 'Invoice Reports',
    description: 'Invoice margins and gross profit reports.',
    parentModuleKey: 'reporting_treasury',
    routes: [
      {
        scope: 'app',
        title: 'Invoice Reports',
        caption: 'Invoice margins and gross profit reports',
        icon: 'summarize',
        routeSegment: 'finance/invoices',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shipment_reports',
    name: 'Shipment Reports',
    description: 'Shipment batch landed cost vs realized margin P&L.',
    parentModuleKey: 'reporting_treasury',
    routes: [
      {
        scope: 'app',
        title: 'Shipment P&L',
        caption: 'Shipment batch landed cost vs realized margin P&L',
        icon: 'local_shipping',
        routeSegment: 'finance/shipments',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'billing_balances',
    name: 'Customer Balances',
    description: 'Total amount due per billing profile.',
    parentModuleKey: 'reporting_treasury',
    routes: [
      {
        scope: 'app',
        title: 'Customer Balances',
        caption: 'Total amount due per billing profile',
        icon: 'account_balance_wallet',
        routeSegment: 'finance/balances',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'parent_dashboard',
    name: 'Consolidated Dashboard',
    description: 'Roll up sales and margin across sister concerns.',
    parentModuleKey: 'reporting_treasury',
    routes: [
      {
        scope: 'app',
        title: 'Consolidated Dashboard',
        caption: 'Roll up sales and margin across sister concerns',
        icon: 'dashboard',
        routeSegment: 'finance/dashboard',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'investor_reports',
    name: 'Investor Reports',
    description: 'Profit share per shipment batch for investors.',
    parentModuleKey: 'reporting_treasury',
    routes: [
      {
        scope: 'app',
        title: 'Investor Reports',
        caption: 'Profit share per shipment batch for investors',
        icon: 'savings',
        routeSegment: 'finance/investors',
        requiredAction: 'view',
      },
    ],
  },

  {
    key: 'investor_portal',
    name: 'Investor Portal',
    description: 'External investor login and portfolio.',
    parentModuleKey: 'investor_capital',
    routes: [],
  },
  {
    key: 'procurement_stock',
    name: 'Procurement & Stock',
    description: 'Parent module for inbound procurement, warehouse pools, and tenant stock allocations.',
    navIcon: 'local_shipping',
    routes: [],
  },
  {
    key: 'global_stock_type',
    name: 'Stock Types',
    description: 'Stock classification types config (e.g. Standard Sellable, Box Damage).',
    parentModuleKey: 'procurement_stock',
    routes: [],
  },
  {
    key: 'investor_capital',
    name: 'Investor Capital',
    description: 'Parent module for investor profiles, capital ledger, shipment share allocations, and investor portal.',
    navIcon: 'savings',
    routes: [],
  },
  {
    key: 'investor_profiles',
    name: 'Investor Profiles',
    description: 'Manage investor profiles and client contact details.',
    parentModuleKey: 'investor_capital',
    routes: [
      {
        scope: 'app',
        title: 'Profiles',
        caption: 'Manage investor profiles',
        icon: 'groups',
        routeSegment: 'capital/profiles',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'investor_capital_ledger',
    name: 'Capital Ledger',
    description: 'Manage capital deposits, adjustments, and withdrawal transactions.',
    parentModuleKey: 'investor_capital',
    routes: [
      {
        scope: 'app',
        title: 'Capital Ledger',
        caption: 'Manage capital transactions and records',
        icon: 'sync_alt',
        routeSegment: 'capital/ledger',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'investor_shipment_share',
    name: 'Shipment Share Allocations',
    description: 'Assign investor cost-share percentage and track shipment profit allocations.',
    parentModuleKey: 'investor_capital',
    routes: [
      {
        scope: 'app',
        title: 'Shipment Allocations',
        caption: 'Track shipment allocations and cost share',
        icon: 'local_shipping',
        routeSegment: 'capital/shipments',
        requiredAction: 'view',
      },
    ],
  },
  // -----------------------------------------------------------
  // shop_order parent + submodules
  // -----------------------------------------------------------
  {
    key: 'shop_order',
    name: 'Shop & Order',
    description: 'Parent module for shop configuration, customer group permissions, product listings, storefront, carts, orders, and fulfillment.',
    navIcon: 'storefront',
    routes: [],
  },
  {
    key: 'shop_config',
    name: 'Shops',
    description: 'Create and manage shops — type, order mode, stock display defaults, and vendor link.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'app',
        title: 'Shops',
        caption: 'Manage shop configuration and settings',
        icon: 'store',
        routeSegment: 'shop/shops',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_permissions',
    name: 'Customer Access',
    description: 'Define default shop capabilities per customer group and override them per shop.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'app',
        title: 'Customer Access',
        caption: 'Manage customer group permissions for shops',
        icon: 'group',
        routeSegment: 'shop/customer-groups',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_pricing',
    name: 'Shop Pricing',
    description: 'Manage product listings per shop, sell prices, minimum sell prices, and display quantity overrides.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'app',
        title: 'Shop Pricing',
        caption: 'Manage listings and pricing per shop',
        icon: 'sell',
        routeSegment: 'shop/pricing',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_storefront',
    name: 'Storefront',
    description: 'Customer-facing browse surface — shows shops, products, and prices per group permission.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'shop',
        title: 'Browse',
        caption: 'Browse available shops and products',
        icon: 'shopping_bag',
        routeSegment: 'shop/browse',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_cart',
    name: 'Cart',
    description: 'Per-shop cart with soft stock reservation against global_stock_allocations.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'shop',
        title: 'Cart',
        caption: 'Build and manage your shop cart',
        icon: 'shopping_cart',
        routeSegment: 'shop/cart',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_order_mgmt',
    name: 'Orders',
    description: 'Place, negotiate, approve, price, confirm, and cancel shop orders.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'app',
        title: 'Orders',
        caption: 'Review and manage shop orders',
        icon: 'receipt_long',
        routeSegment: 'shop/orders',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'My Orders',
        caption: 'Track your placed and pending orders',
        icon: 'receipt_long',
        routeSegment: 'shop/orders',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_fulfillment',
    name: 'Fulfillment',
    description: 'Convert placed vendor-catalog orders to procurement lines or stock-backed orders to global invoices.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'app',
        title: 'Fulfillment',
        caption: 'Fulfill orders via procurement or invoice',
        icon: 'local_shipping',
        routeSegment: 'shop/fulfillment',
        requiredAction: 'view',
      },
    ],
  },
] as const

export const MODULE_REGISTRY_KEYS = MODULE_REGISTRY.map((definition) => definition.key)

export const GLOBAL_MODULE_KEYS = [
  'global_shipment',
  'global_stock',
  'global_invoice',
] as const satisfies readonly ModuleKey[]

/** Top-level tenant modules — must never appear under the Global nav group. */
export const TENANT_STOCK_MODULE_KEY = 'global_stock' as const satisfies ModuleKey

/**
 * Sidebar nav families for domain grouping only (Invoices, Commerce, …).
 * Global-prefixed modules (`global_*`) use flat top-level links — not a shared "Global" parent menu.
 */
export type ModuleNavFamily =
  | 'global'
  | 'products'
  | 'koba_retail'
  | 'standalone'

export const getModuleNavFamily = (moduleKey: ModuleKey): ModuleNavFamily => {
  if (isGlobalModuleKey(moduleKey)) return 'standalone'
  if (moduleKey === 'products') return 'products'
  if (moduleKey === 'koba_retail') return 'koba_retail'
  return 'standalone'
}

export const isGlobalModuleKey = (moduleKey: ModuleKey): moduleKey is (typeof GLOBAL_MODULE_KEYS)[number] =>
  (GLOBAL_MODULE_KEYS as readonly ModuleKey[]).includes(moduleKey)

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
