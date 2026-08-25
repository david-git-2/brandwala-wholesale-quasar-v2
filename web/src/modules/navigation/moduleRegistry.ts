import type { AuthScope } from 'src/modules/auth/composables/useOAuthLogin';

export type ModuleKey =
  | 'order_management'
  | 'vendor'
  | 'products'
  | 'product_based_costing'
  | 'costing_file'
  | 'koba_retail'
  | 'koba_wholesale'
  | 'tasks'
  | 'thrift'
  | 'thrift_sales'
  | 'thrift_customers'
  | 'thrift_reports'
  | 'thrift_stock'
  | 'thrift_marketing_tag'
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
  | 'procurement_demand'
  | 'global_stock'
  | 'global_stock_movement'
  | 'global_stock_location'
  | 'cargo_company'
  | 'shipment_progress_settings'
  | 'inventory'
  | 'global_invoice'
  | 'investor_portal'
  | 'procurement_stock'
  | 'global_stock_type'
  | 'invoice_brand'
  | 'reporting_treasury'
  | 'payments'
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
  | 'shop_dropship'
  | 'shop_shipping'
  | 'shop_category'
  | 'sales_invoice'
  | 'customer'
  | 'billing_profile'
  | 'billing_profile_wallet'
  | 'recipient_profile'
  | 'universal_wallet';

export type ModuleAction =
  | 'view'
  | 'create'
  | 'edit'
  | 'delete'
  | 'download'
  | 'edit_quantity'
  | 'edit_price'
  | 'view_cost'
  | 'apply_discount'
  | 'view_landed_cost'
  | 'edit_landed_cost'
  | 'view_measurements'
  | 'edit_measurements'
  | 'edit_listed_price'
  | 'receive'
  | 'return'
  | 'force_return'
  | 'staff_mistake';
export type InteractiveScope = Extract<AuthScope, 'app' | 'shop'>;

export interface ModuleRouteDefinition {
  scope: InteractiveScope;
  title: string;
  caption: string;
  icon: string;
  routeSegment: string;
  requiredAction?: ModuleAction;
}

export interface ModuleDefinition {
  key: ModuleKey;
  name: string;
  description: string;
  parentModuleKey?: ModuleKey;
  navIcon?: string;
  routes: ModuleRouteDefinition[];
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
        icon: 'ph ph-receipt',
        routeSegment: 'orders',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Orders',
        caption: 'Build carts, place orders, and follow negotiation',
        icon: 'ph ph-tote',
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
        icon: 'ph ph-storefront',
        routeSegment: 'vendors',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'products',
    name: 'Products',
    description: 'Manage the product catalog and product-level records.',
    navIcon: 'ph ph-archive-box',
    routes: [
      {
        scope: 'app',
        title: 'Products',
        caption: 'Catalog, brands, and categories hub',
        icon: 'ph ph-package',
        routeSegment: 'products',
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
        icon: 'ph ph-receipt',
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
        icon: 'ph ph-tag',
        routeSegment: 'costing',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Pre order',
        caption: 'Open customer-facing costing references',
        icon: 'ph ph-receipt',
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
        icon: 'ph ph-tote',
        routeSegment: 'koba/retail',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Cart',
        caption: 'Review and manage your retail cart',
        icon: 'ph ph-shopping-cart',
        routeSegment: 'koba/retail/cart',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Orders',
        caption: 'Track placed retail orders',
        icon: 'ph ph-receipt',
        routeSegment: 'koba/retail/orders',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Settings',
        caption: 'Configure retail settings and charges',
        icon: 'ph ph-gear',
        routeSegment: 'koba/retail/settings',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Customers',
        caption: 'View customer profiles and order frequency',
        icon: 'ph ph-users',
        routeSegment: 'koba/retail/customers',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Products',
        caption: 'Browse Koba Retail products',
        icon: 'ph ph-tote',
        routeSegment: 'koba/retail',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Cart',
        caption: 'Review and manage your retail cart',
        icon: 'ph ph-shopping-cart',
        routeSegment: 'koba/retail/cart',
        requiredAction: 'view',
      },
      {
        scope: 'shop',
        title: 'Orders',
        caption: 'Track placed retail orders',
        icon: 'ph ph-receipt',
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
        icon: 'ph ph-shopping-cart',
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
        icon: 'ph ph-clipboard-text',
        routeSegment: 'tasks',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift',
    name: 'Thrift Model',
    description:
      'Parent module for thrift stock inventory, shipments, boxes, shelves, categories, types, barcodes, and settings.',
    navIcon: 'ph ph-t-shirt',
    routes: [],
  },
  {
    key: 'thrift_sales',
    name: 'Thrift Sales',
    description: 'Create and manage sales invoices for thrift inventory.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Sales & Invoices',
        caption: 'Create sales invoices',
        icon: 'ph ph-receipt',
        routeSegment: 'thrift/sales',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Returns',
        caption: 'Post-pay returns hub',
        icon: 'ph ph-arrow-u-up-left',
        routeSegment: 'thrift/sales/returns',
        requiredAction: 'view',
      },
      {
        scope: 'app',
        title: 'Courier Providers',
        caption: 'System + custom couriers',
        icon: 'ph ph-truck',
        routeSegment: 'thrift/couriers',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_customers',
    name: 'Thrift Customers',
    description: 'Browse thrift customer profiles created from sales invoices.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Customers',
        caption: 'Customer profiles from sales',
        icon: 'ph ph-users',
        routeSegment: 'thrift/customers',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_reports',
    name: 'Thrift Reports',
    description: 'Shipment sales and profit reports for thrift inventory.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Reports',
        caption: 'Earn · COD · Purchases',
        icon: 'ph ph-chart-bar',
        routeSegment: 'thrift/reports',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_stock',
    name: 'Thrift Stock',
    description: 'Manage inventory stock items, brands, and quantities.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Stock',
        caption: 'Review stock inventory',
        icon: 'ph ph-package',
        routeSegment: 'thrift/stocks',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_marketing_tag',
    name: 'Thrift Marketing Tags',
    description: 'Print live sale stickers and marketing tags for thrift stock.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Marketing Tags',
        caption: 'Print live sale stickers',
        icon: 'ph ph-tag',
        routeSegment: 'thrift/stock-tags',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_shipment',
    name: 'Thrift Shipment',
    description: 'Coordinate shipment logs and transport records within thrift workflows.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Shipments',
        caption: 'Manage shipments and logs',
        icon: 'ph ph-truck',
        routeSegment: 'thrift/shipments',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_box',
    name: 'Thrift Box',
    description: 'Manage container boxes and weights under specific shipments.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Boxes',
        caption: 'Manage container boxes & weights',
        icon: 'ph ph-archive-box',
        routeSegment: 'thrift/boxes',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_shelf',
    name: 'Thrift Shelf',
    description: 'Track physical shelf storage and aisle locations in the warehouse.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Shelves',
        caption: 'Manage shelf locations',
        icon: 'ph ph-books',
        routeSegment: 'thrift/shelves',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_category',
    name: 'Thrift Category',
    description: 'Manage classification categories for thrift stock items.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Categories',
        caption: 'Manage stock categories',
        icon: 'ph ph-squares-four',
        routeSegment: 'thrift/categories',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_type',
    name: 'Thrift Type',
    description: 'Manage product styles and types within the thrift catalog.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Types',
        caption: 'Manage dress and item types',
        icon: 'ph ph-tag',
        routeSegment: 'thrift/types',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'thrift_settings',
    name: 'Thrift Settings',
    description: 'Configure default origin purchase price for new stock items.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Settings',
        caption: 'Default origin purchase price',
        icon: 'ph ph-gear',
        routeSegment: 'thrift/settings',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_reference',
    name: 'Global Reference',
    description:
      'Feature-catalog parent for reference submodules. No sidebar link — use global_reference_currency.',
    routes: [],
  },
  {
    key: 'global_reference_currency',
    name: 'Reference',
    description: 'Global currency catalog for shipments, pricing, and money display.',
    navIcon: 'ph ph-books',
    routes: [
      {
        scope: 'app',
        title: 'Reference',
        caption: 'Currencies, markets, payment methods, and units',
        icon: 'ph ph-books',
        routeSegment: 'reference',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'global_reference_market',
    name: 'Markets',
    description: 'ISO-style market and country reference catalog.',
    routes: [],
  },
  {
    key: 'global_reference_payment_method',
    name: 'Payment Methods',
    description: 'Bangladesh and international payment method reference catalog.',
    routes: [],
  },
  {
    key: 'global_reference_unit_of_measure',
    name: 'Units of Measure',
    description: 'Weight, count, length, volume, and packaging units.',
    routes: [],
  },
  {
    key: 'thrift_barcode',
    name: 'Thrift Barcode',
    description: 'Manage and print barcodes in bulk.',
    parentModuleKey: 'thrift',
    routes: [
      {
        scope: 'app',
        title: 'Thrift Barcodes',
        caption: 'Generate and print barcodes',
        icon: 'ph ph-qr-code',
        routeSegment: 'thrift/barcodes',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'procurement_demand',
    name: 'Demand',
    description: 'Aggregated line items from shop orders and costing files in procurement.',
    parentModuleKey: 'procurement_stock',
    routes: [],
  },
  {
    key: 'global_shipment',
    name: 'Shipments',
    description: 'Inbound shipments from vendors — add items and receive stock.',
    parentModuleKey: 'procurement_stock',
    routes: [],
  },
  {
    key: 'global_stock',
    name: 'Warehouse',
    description: 'What is on the shelves, and whether it can be sold.',
    parentModuleKey: 'procurement_stock',
    routes: [],
  },
  {
    key: 'global_stock_movement',
    name: 'Movements',
    description: 'Move stock between shelves or sellable / held / unsellable.',
    parentModuleKey: 'procurement_stock',
    routes: [],
  },
  {
    key: 'global_stock_location',
    name: 'Locations',
    description: 'Shelves and boxes where warehouse stock sits.',
    parentModuleKey: 'procurement_stock',
    routes: [],
  },
  {
    key: 'cargo_company',
    name: 'Cargo Companies',
    description: 'Freight agents used on inbound shipments.',
    parentModuleKey: 'procurement_stock',
    routes: [],
  },
  {
    key: 'shipment_progress_settings',
    name: 'Shipment Progress',
    description: 'Configure journey stages shown on shipments and the public tracking page.',
    parentModuleKey: 'procurement_stock',
    routes: [],
  },
  {
    key: 'inventory',
    name: 'Stock',
    description: 'Stock this shop can sell from received shipments.',
    parentModuleKey: 'procurement_stock',
    routes: [],
  },
  {
    key: 'sales_invoice',
    name: 'Sales & Invoice',
    description:
      'Feature-catalog parent for invoice submodules. No sidebar link — use global_invoice.',
    routes: [],
  },
  {
    key: 'global_invoice',
    name: 'Sales Invoices',
    description: 'Desk invoices: wholesale, retail, and dropship.',
    navIcon: 'ph ph-receipt',
    routes: [
      {
        scope: 'app',
        title: 'Invoices',
        caption: 'Sales & invoice operations hub',
        icon: 'ph ph-receipt',
        routeSegment: 'sales/invoices',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'customer',
    name: 'Customers',
    description:
      'Customer groups, billing profiles, delivery recipients, member access, and wallets.',
    navIcon: 'ph ph-users',
    routes: [
      {
        scope: 'app',
        title: 'Customers',
        caption: 'Accounts, billing profiles, and delivery recipients hub',
        icon: 'ph ph-users',
        routeSegment: 'customers',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'billing_profile',
    name: 'Billing Profiles',
    description: 'Financial identity for invoices. Opened from Customers, not a sidebar item.',
    parentModuleKey: 'customer',
    routes: [],
  },
  {
    key: 'billing_profile_wallet',
    name: 'Billing Wallets',
    description: 'Unified wallet balances, debits, credits, and bulk payouts for billing profiles.',
    parentModuleKey: 'sales_invoice',
    routes: [],
  },
  {
    key: 'universal_wallet',
    name: 'Wallets',
    description: 'Balances for the company, customers, suppliers, cargo, couriers, and investors.',
    navIcon: 'ph ph-wallet',
    routes: [
      {
        scope: 'app',
        title: 'Wallets',
        caption: 'Whose money do you want to see?',
        icon: 'ph ph-wallet',
        routeSegment: 'wallet',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'recipient_profile',
    name: 'Recipient Profiles',
    description: 'Manage end-customer delivery and drop-ship target profiles.',
    parentModuleKey: 'customer',
    routes: [],
  },
  {
    key: 'invoice_brand',
    name: 'Invoice Brands',
    description: 'Print layout presets for the issuing child. Config only — no sidebar.',
    parentModuleKey: 'sales_invoice',
    routes: [],
  },
  {
    key: 'reporting_treasury',
    name: 'Reports & Treasury',
    description: 'Cash, dues, sales, and profit reports.',
    navIcon: 'ph ph-bank',
    routes: [
      {
        scope: 'app',
        title: 'Reports',
        caption: 'Cash, dues, sales, and profit',
        icon: 'ph ph-chart-bar',
        routeSegment: 'finance/reports',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'payments',
    name: 'Payments & Collection',
    description: 'Record payments and allocate to invoices.',
    parentModuleKey: 'reporting_treasury',
    routes: [],
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
    description:
      'Demand desk, inbound shipments, warehouse stock, movements, and procurement operations.',
    navIcon: 'ph ph-truck',
    routes: [
      {
        scope: 'app',
        title: 'Procurement & Stock',
        caption: 'Demand, shipments, warehouse, and stock operations hub',
        icon: 'ph ph-truck',
        routeSegment: 'procurement',
        requiredAction: 'view',
      },
    ],
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
    description:
      'Parent module for investor profiles, capital ledger, shipment share allocations, and investor portal.',
    navIcon: 'ph ph-piggy-bank',
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
        icon: 'ph ph-users-three',
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
        icon: 'ph ph-arrows-left-right',
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
        icon: 'ph ph-truck',
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
    description:
      'Parent module. Staff nav is Shops, Orders, and Shipping. Dropship is a shop type; courier is shared delivery.',
    navIcon: 'ph ph-storefront',
    routes: [
      {
        scope: 'app',
        title: 'Shop & Order',
        caption: 'Shops, orders, pricing, and shipping hub',
        icon: 'ph ph-storefront',
        routeSegment: 'shop',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_config',
    name: 'Shops',
    description:
      'Create shops and manage categories, customer access, and listings.',
    parentModuleKey: 'shop_order',
    routes: [],
  },
  {
    key: 'shop_category',
    name: 'Shop Categories',
    description: 'Page guard for shop categories. Opened from Shops, not a sidebar item.',
    parentModuleKey: 'shop_order',
    routes: [],
  },
  {
    key: 'shop_permissions',
    name: 'Shop Permissions',
    description: 'Page guard for per-shop storefront access matrix. Opened from Shops.',
    parentModuleKey: 'shop_order',
    routes: [],
  },
  {
    key: 'shop_pricing',
    name: 'Shop Pricing',
    description: 'Page guard for listings and prices. Opened from Shops.',
    parentModuleKey: 'shop_order',
    routes: [],
  },
  {
    key: 'shop_storefront',
    name: 'Storefront',
    description:
      'Customer-facing browse surface — shows shops, products, and prices per group permission.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'shop',
        title: 'Catalog',
        caption: 'Browse products and order',
        icon: 'ph ph-storefront',
        routeSegment: 'browse',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_cart',
    name: 'Cart',
    description: 'Per-shop cart with soft stock reservation against global_stock_id ATP.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'shop',
        title: 'Cart',
        caption: 'Build and manage your shop cart',
        icon: 'ph ph-shopping-cart',
        routeSegment: 'cart',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_order_mgmt',
    name: 'Orders',
    description:
      'All shop orders (catalog, retail, wholesale, dropship). Process-order and fulfill live on the order page.',
    parentModuleKey: 'shop_order',
    routes: [
      {
        scope: 'shop',
        title: 'Orders',
        caption: 'Track and reply',
        icon: 'ph ph-receipt',
        routeSegment: 'orders',
        requiredAction: 'view',
      },
    ],
  },
  {
    key: 'shop_fulfillment',
    name: 'Fulfillment (legacy key)',
    description: 'Retired from nav. Fulfill on the order page under shop_order_mgmt.',
    parentModuleKey: 'shop_order',
    routes: [],
  },
  {
    key: 'shop_dropship',
    name: 'Dropship (legacy key)',
    description:
      'Retired from nav. Dropship is a shop type; process-order is shop_order_mgmt; couriers are shop_shipping.',
    parentModuleKey: 'shop_order',
    routes: [],
  },
  {
    key: 'shop_shipping',
    name: 'Shipping',
    description:
      'Shared courier catalog, pickup, and COD remittance for any delivered shop order.',
    parentModuleKey: 'shop_order',
    routes: [],
  },
] as const;

export const MODULE_REGISTRY_KEYS = MODULE_REGISTRY.map((definition) => definition.key);

export const GLOBAL_MODULE_KEYS = [
  'global_shipment',
  'global_stock',
  'global_stock_movement',
  'global_stock_location',
  'global_invoice',
] as const satisfies readonly ModuleKey[];

/** Child-facing stock sidebar module under procurement. */
export const TENANT_STOCK_MODULE_KEY = 'inventory' as const satisfies ModuleKey;

/**
 * Sidebar nav families for domain grouping only (Invoices, Commerce, …).
 * Global-prefixed modules (`global_*`) use flat top-level links — not a shared "Global" parent menu.
 */
export type ModuleNavFamily = 'global' | 'products' | 'koba_retail' | 'standalone';

export const getModuleNavFamily = (moduleKey: ModuleKey): ModuleNavFamily => {
  if (isGlobalModuleKey(moduleKey)) return 'standalone';
  if (moduleKey === 'products') return 'products';
  if (moduleKey === 'koba_retail') return 'koba_retail';
  return 'standalone';
};

export const isGlobalModuleKey = (
  moduleKey: ModuleKey,
): moduleKey is (typeof GLOBAL_MODULE_KEYS)[number] =>
  (GLOBAL_MODULE_KEYS as readonly ModuleKey[]).includes(moduleKey);

export const MODULE_REGISTRY_BY_KEY: Readonly<Record<ModuleKey, ModuleDefinition>> = Object.freeze(
  MODULE_REGISTRY.reduce(
    (accumulator, definition) => {
      accumulator[definition.key] = definition;
      return accumulator;
    },
    {} as Record<ModuleKey, ModuleDefinition>,
  ),
);

export const getModuleDefinition = (moduleKey: ModuleKey) => MODULE_REGISTRY_BY_KEY[moduleKey];

export const buildModuleRoutePath = ({
  scope,
  routeSegment,
  tenantSlug,
}: {
  scope: InteractiveScope;
  routeSegment: string;
  tenantSlug?: string | null | undefined;
}) => {
  if (scope === 'shop') {
    return tenantSlug ? `/${tenantSlug}/shop/${routeSegment}` : `/shop/${routeSegment}`;
  }

  return tenantSlug ? `/${tenantSlug}/app/${routeSegment}` : `/app/${routeSegment}`;
};

export const getModuleRoutesForScope = (
  scope: InteractiveScope,
  options?: {
    tenantSlug?: string | null | undefined;
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
    const aIsDashboard = a.title.trim().toLowerCase() === 'dashboard';
    const bIsDashboard = b.title.trim().toLowerCase() === 'dashboard';

    if (aIsDashboard && !bIsDashboard) return -1;
    if (!aIsDashboard && bIsDashboard) return 1;

    return a.title.localeCompare(b.title, undefined, { sensitivity: 'base' });
  });
