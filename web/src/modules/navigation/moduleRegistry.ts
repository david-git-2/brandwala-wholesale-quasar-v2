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
  | 'global_accounting_ledger'
  | 'global_shipment_accounting'
  | 'global_invoice_accounting'
  | 'global_investor'
  | 'global_investor_shipment'
  | 'investor_portal'
  | 'procurement_stock'
  | 'global_stock_type'
  | 'sales_invoice'
  | 'billing_profile'
  | 'recipient_profile'
  | 'invoice_brand'


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
    key: 'shipment',
    name: 'Shipment',
    description: 'Legacy shipment module key (superseded by global_shipment).',
    routes: [],
  },
  {
    key: 'inventory',
    name: 'Tenant Stock',
    description: 'Tenant allocated stock view and parent allocation manager. Separate from global_stock.',
    parentModuleKey: 'procurement_stock',
    routes: [
      {
        scope: 'app',
        title: 'Tenant Stock',
        caption: 'Your allocated stock slices (not the global pool)',
        icon: 'inventory_2',
        routeSegment: 'procurement/tenant-stock',
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
    name: 'Shop Invoice',
    description: 'Order-generated shop invoices (wholesale and retail).',
    routes: [
      {
        scope: 'app',
        title: 'Shop Invoices',
        caption: 'Invoices generated from B2B shop orders',
        icon: 'description',
        routeSegment: 'commerce-shop/invoices',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Shop Billing Profiles',
        caption: 'Billing profiles for shop (shared with sales invoices)',
        icon: 'badge',
        routeSegment: 'commerce-shop/invoices/billing-profiles',
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
      {
        scope: 'app',
        title: 'Commerce Invoice Accounting',
        caption: 'Review commerce invoice accounting entries',
        icon: 'request_quote',
        routeSegment: 'commerce-shop/accounting/invoice',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Commerce Shipment Accounting',
        caption: 'Review commerce shipment accounting details',
        icon: 'local_shipping',
        routeSegment: 'commerce-shop/accounting/shipment',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Commerce Stock Shipment Summary',
        caption: 'View commerce shipment-wise totals',
        icon: 'inventory_2',
        routeSegment: 'commerce-shop/accounting/inventory-shipment',
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
        title: 'Stock Shipment Summary',
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
    name: 'Invoice (Legacy)',
    description: 'Deprecated — use Sales Invoices (global_invoice module). Routes redirect automatically.',
    parentModuleKey: 'sales_invoice',
    routes: [],
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
    key: 'global_accounting_ledger',
    name: 'Global Ledger',
    description: 'Consolidated accounting ledger across sister concerns.',
    routes: [
      {
        scope: 'app',
        title: 'Global Ledger',
        caption: 'Parent consolidated accounting',
        icon: 'account_balance',
        routeSegment: 'global/accounting/ledger',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_shipment_accounting',
    name: 'Shipment Accounting',
    description: 'Shipment buy/sell cost and profit summary.',
    routes: [
      {
        scope: 'app',
        title: 'Shipment Accounting',
        caption: 'Shipment P&L rollups',
        icon: 'local_shipping',
        routeSegment: 'global/accounting/shipments',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_invoice_accounting',
    name: 'Invoice Accounting',
    description: 'Invoice rollup including charge lines.',
    routes: [
      {
        scope: 'app',
        title: 'Invoice Accounting',
        caption: 'Invoice P&L and charges',
        icon: 'summarize',
        routeSegment: 'global/accounting/invoices',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_investor',
    name: 'Global Investor',
    description: 'Parent-managed investor profiles and balances.',
    routes: [
      {
        scope: 'app',
        title: 'Investors',
        caption: 'Manage investor capital',
        icon: 'savings',
        routeSegment: 'global/investors',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_investor_shipment',
    name: 'Investor Shipment',
    description: 'Investor cost-share per shipment.',
    routes: [
      {
        scope: 'app',
        title: 'Investor Shipments',
        caption: 'Cost-share and profit allocation',
        icon: 'pie_chart',
        routeSegment: 'global/investor-shipments',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'investor_portal',
    name: 'Investor Portal',
    description: 'External investor login and portfolio.',
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
] as const

export const MODULE_REGISTRY_KEYS = MODULE_REGISTRY.map((definition) => definition.key)

export const GLOBAL_MODULE_KEYS = [
  'global_shipment',
  'global_stock',
  'global_invoice',
  'global_accounting_ledger',
  'global_shipment_accounting',
  'global_invoice_accounting',
  'global_investor',
  'global_investor_shipment',
] as const satisfies readonly ModuleKey[]

/** Top-level tenant modules — must never appear under the Global nav group. */
export const TENANT_STOCK_MODULE_KEY = 'inventory' as const satisfies ModuleKey

/**
 * Sidebar nav families for domain grouping only (Invoices, Commerce, …).
 * Global-prefixed modules (`global_*`) use flat top-level links — not a shared "Global" parent menu.
 */
export type ModuleNavFamily =
  | 'global'
  | 'tenant_stock'
  | 'invoice'
  | 'accounting'
  | 'store'
  | 'products'
  | 'commerce_shop'
  | 'commerce_order'
  | 'commerce_invoice'
  | 'commerce_accounting'
  | 'investor'
  | 'koba_retail'
  | 'standalone'

export const getModuleNavFamily = (moduleKey: ModuleKey): ModuleNavFamily => {
  if (isGlobalModuleKey(moduleKey)) return 'standalone'
  if (moduleKey === TENANT_STOCK_MODULE_KEY) return 'tenant_stock'
  if (moduleKey === 'invoice') return 'invoice'
  if (moduleKey === 'accounting') return 'accounting'
  if (moduleKey === 'store') return 'store'
  if (moduleKey === 'products') return 'products'
  if (moduleKey === 'commerce_shop') return 'commerce_shop'
  if (moduleKey === 'commerce_order') return 'commerce_order'
  if (moduleKey === 'commerce_invoice') return 'commerce_invoice'
  if (moduleKey === 'commerce_accounting') return 'commerce_accounting'
  if (moduleKey === 'investor') return 'investor'
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
