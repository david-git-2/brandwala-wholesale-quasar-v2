import type { ModuleKey } from 'src/modules/navigation/moduleRegistry'

export interface DocItem {
  key: string
  title: string
  description: string
  filename: string
  scope: 'app' | 'platform' | 'both'
  moduleKey?: ModuleKey
}

export const DOCUMENTATION_REGISTRY: readonly DocItem[] = [
  // General Platform & Technical Docs
  {
    key: 'app_scopes_and_access',
    title: 'Application Scopes and Access',
    description: 'Platform, App, Shop, and Investor scopes — redirects, route guards, and access control.',
    filename: 'doc/APP_SCOPES_AND_ACCESS.md',
    scope: 'both',
  },
  {
    key: 'tenant_model_and_access',
    title: 'Tenant Model and Access',
    description: 'Parent, child, and standalone tenants — hierarchy, URL resolution, modules, and data ownership.',
    filename: 'doc/TENANT_MODEL_AND_ACCESS.md',
    scope: 'both',
  },
  {
    key: 'global_reference_data',
    title: 'Global Reference Data',
    description: 'Platform-wide catalogs — currencies, markets, payment methods, units, and submodule assignment.',
    filename: 'doc/GLOBAL_REFERENCE_DATA.md',
    scope: 'both',
    moduleKey: 'global_reference',
  },
  {
    key: 'procurement_stock',
    title: 'Procurement & Stock',
    description: 'Inbound shipments, warehouse stock, tenant allocation, hardcoded landed-cost formulas, and drop-recreate schema.',
    filename: 'doc/PROCUREMENT_STOCK.md',
    scope: 'app',
    moduleKey: 'global_shipment',
  },
  {
    key: 'package_commands',
    title: 'Automation & Script Commands',
    description: 'Detailed walkthrough and descriptions of package.json automation commands, scrapers, and database sync scripts.',
    filename: 'doc/package_commands.md',
    scope: 'both',
  },
  {
    key: 'backend_features',
    title: 'Backend Features Description',
    description: 'Detailed analysis of background tasks, sync routines, and database roles.',
    filename: 'doc/backend_features.md',
    scope: 'platform',
  },
  {
    key: 'frontend_style_guide',
    title: 'Frontend Style Guide',
    description: 'Visual components, UI layout policies, and Quasar design tokens.',
    filename: 'doc/frontend style guilde.md',
    scope: 'platform',
  },
  {
    key: 'core_backend_architecture',
    title: 'Core Backend Architecture',
    description: 'Postgres schema, triggers, and Row-Level Security policy structure.',
    filename: 'document/core-backend-architecture.md',
    scope: 'platform',
  },
  {
    key: 'costing_backend_architecture',
    title: 'Costing Backend Architecture',
    description: 'Specific costing engine structures, math routines, and PO sync mechanics.',
    filename: 'document/costing-backend-architecture.md',
    scope: 'platform',
  },
  {
    key: 'tenant_documentation',
    title: 'Tenant Guide',
    description: 'Custom guidelines, contact details, and workspace instructions specific to this tenant.',
    filename: 'doc/tenant_{tenantId}.md',
    scope: 'app',
  },

  // Module Specific Docs - EXACT DATABASE NAMES
  {
    key: 'module_costing_file',
    title: 'Costing File',
    description: 'Guides on internal costing spreadsheets, margins, and quotation preparation.',
    filename: 'doc/costing_file.md',
    scope: 'app',
    moduleKey: 'costing_file',
  },
  {
    key: 'module_vendor',
    title: 'Vendor',
    description: 'Guides on vendor records, sourcing, and supplier collaboration.',
    filename: 'doc/vendor.md',
    scope: 'app',
    moduleKey: 'vendor',
  },
  {
    key: 'module_products',
    title: 'Products',
    description: 'Guides on managing product catalog, brands, and categories.',
    filename: 'doc/products.md',
    scope: 'app',
    moduleKey: 'products',
  },
  {
    key: 'module_product_based_costing',
    title: 'Product Based Costing',
    description: 'Guides on product-based costing files and margin overrides.',
    filename: 'doc/product_based_costing.md',
    scope: 'app',
    moduleKey: 'product_based_costing',
  },
  {
    key: 'module_accounting',
    title: 'Accounting',
    description: 'Guides on accounting entries, ledgers, and transactions.',
    filename: 'doc/accounting.md',
    scope: 'app',
    moduleKey: 'accounting',
  },
  {
    key: 'module_store',
    title: 'Store',
    description: 'Guides on storefront configuration and store-level operations.',
    filename: 'doc/store.md',
    scope: 'app',
    moduleKey: 'store',
  },
  {
    key: 'module_cart',
    title: 'Cart',
    description: 'Guides on shopping carts and item reservation workflows.',
    filename: 'doc/cart.md',
    scope: 'app',
    moduleKey: 'cart',
  },
  {
    key: 'module_order_management',
    title: 'Order Management',
    description: 'Guides on order approvals, track flows, and order intake.',
    filename: 'doc/order_management.md',
    scope: 'app',
    moduleKey: 'order_management',
  },
  {
    key: 'module_shipment',
    title: 'Shipment',
    description: 'Guides on logistics dispatch, freight tracking, and delivery.',
    filename: 'doc/shipment.md',
    scope: 'app',
    moduleKey: 'shipment',
  },
  {
    key: 'module_inventory',
    title: 'Inventory',
    description: 'Guides on stock monitoring, tracking movements, and locations.',
    filename: 'doc/inventory.md',
    scope: 'app',
    moduleKey: 'inventory',
  },
  {
    key: 'module_invoice',
    title: 'Invoice',
    description: 'Guides on billing, invoice generation, and payments.',
    filename: 'doc/invoice.md',
    scope: 'app',
    moduleKey: 'invoice',
  },
  {
    key: 'module_investor',
    title: 'Investor',
    description: 'Guides on investor transaction records, balances, and funding.',
    filename: 'doc/investor.md',
    scope: 'app',
    moduleKey: 'investor',
  },
  {
    key: 'module_commerce_shop',
    title: 'Commerce Shop',
    description: 'Guides on isolated commerce flow and storefront configurations.',
    filename: 'doc/commerce_shop.md',
    scope: 'app',
    moduleKey: 'commerce_shop',
  },
  {
    key: 'module_commerce_order',
    title: 'Commerce Order',
    description: 'Guides on checkout, negotiation, and tracking commerce orders.',
    filename: 'doc/commerce_order.md',
    scope: 'app',
    moduleKey: 'commerce_order',
  },
  {
    key: 'module_commerce_invoice',
    title: 'Commerce Invoice',
    description: 'Guides on billing profiles, payments, and commercial invoices.',
    filename: 'doc/commerce_invoice.md',
    scope: 'app',
    moduleKey: 'commerce_invoice',
  },
]
