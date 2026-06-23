import fs from 'fs';

const permSrc = fs.readFileSync('web/src/modules/navigation/modulePermissions.ts', 'utf8');
const roles = ['superadmin', 'admin', 'staff', 'viewer', 'customer_admin', 'customer_negotiator', 'customer_staff', 'investor_portal'];
const matrix = {};
const re = /(\w+):\s*\{([\s\S]*?)\n  \},/g;
let m;
while ((m = re.exec(permSrc)) !== null) {
  if (!roles.includes(m[1])) continue;
  matrix[m[1]] = {};
  for (const line of m[2].split('\n')) {
    const km = line.match(/^\s+(\w+):\s*(.+?),?\s*$/);
    if (!km) continue;
    matrix[m[1]][km[1]] = km[2].includes('NO_ACCESS') ? '—' : 'view';
  }
}

function permTableForKey(key) {
  if (!key || key === '—') {
    return '| Role | Access (today) |\n|------|----------------|\n| superadmin | platform routes |\n| others | — |\n';
  }
  let lines = '| Role | Access (today) |\n|------|----------------|\n';
  for (const r of roles) {
    lines += `| ${r} | ${matrix[r]?.[key] ?? '—'} |\n`;
  }
  return lines;
}

const modules = [
  {
    name: 'Platform & Tenancy',
    key: '—',
    domain: 'Platform & Access',
    submodules: 'None — platform routes: Tenants, Markets, Superadmins, Module assignment (`/platform/*`).',
    should: 'Create and manage tenants (parent/child/standalone), markets, and superadmin memberships. Enforce one-level hierarchy.',
    current: 'Tables `tenants`, `memberships`, `markets`. Routes `/platform/tenants`, `/platform/markets`, `/platform/modules`. RPCs `create_tenant_for_superadmin`, `list_tenants_for_superadmin`.',
    improve: 'None required — stable foundation.',
    schema: `| Table | Fields |\n|-------|--------|\n| \`tenants\` | \`id\`, \`name\`, \`slug\`, \`parent_id\`, \`public_domain\`, \`is_active\` |\n| \`memberships\` | \`id\`, \`email\`, \`tenant_id\`, \`role\`, \`is_active\` |\n| \`markets\` | \`id\`, \`code\`, \`name\`, \`is_active\` |`,
    tenant: 'Platform only (superadmin)',
    rls: 'Superadmin membership (`tenant_id` null). Tenant reads via `user_can_access_tenant_fetch`.',
    permKeys: null,
    extraPerm: null,
  },
  {
    name: 'Permission & Module System',
    key: 'modules / tenant_modules',
    domain: 'Platform & Access',
    submodules: 'None today. Optional future: `parent_module_key` on `modules` for nav bundling.',
    should: 'Define global feature catalog and per-tenant enablement. Bootstrap returns active keys for navigation.',
    current: '`modules` + `tenant_modules`. RPC `get_active_module_keys_for_tenant`. No inheritance between parent/child tenants.',
    improve: 'Expand `ModuleAction` beyond `view`. Consider submodule rows in catalog.',
    schema: `| Table | Fields |\n|-------|--------|\n| \`modules\` | \`id\`, \`key\`, \`name\`, \`description\`, \`is_active\` |\n| \`tenant_modules\` | \`id\`, \`tenant_id\`, \`module_key\`, \`is_active\` |`,
    tenant: 'All tenants (flags); platform manages catalog',
    rls: 'Superadmin writes catalog; bootstrap RPC reads tenant flags.',
    permKeys: null,
    extraPerm: null,
  },
  {
    name: 'Global Currency',
    key: 'thrift_currency → global_currency',
    domain: 'Currency',
    submodules: 'Single submodule: **Currency catalog** (list/manage).',
    should: 'Central currency registry (name, country, code, symbol, is_active) for shipments and UI.',
    current: 'Table `global_currencies` exists. Module key `thrift_currency` — read-only route `/thrift/currencies`.',
    improve: '**P0:** Add `global_currency` module key and platform CRUD. Wire FKs on redesigned shipments.',
    schema: `| Table | Fields |\n|-------|--------|\n| \`global_currencies\` | \`id\`, \`name\`, \`country\`, \`code\`, \`symbol\`, \`is_active\` |`,
    tenant: 'All tenants read; platform configures',
    rls: 'Authenticated read; platform write (target).',
    permKeys: ['thrift_currency'],
    extraPerm: null,
  },
  {
    name: 'Products',
    key: 'products',
    domain: 'Catalog & Supply',
    submodules: '**Products**, **Brands**, **Categories** (same key, separate routes).',
    should: 'Tenant product catalog feeding orders, shipments, and invoices.',
    current: '`products`, `product_brands`, `product_categories`, `product_sync_snapshots`. Routes `/app/products/*`.',
    improve: 'None — stable.',
    schema: `| Table | Key fields |\n|-------|------------|\n| \`products\` | \`tenant_id\`, \`name\`, \`product_code\`, \`barcode\`, \`price_gbp\`, weights, \`vendor_id\` |\n| \`product_brands\` | \`tenant_id\`, \`name\` |\n| \`product_categories\` | \`tenant_id\`, \`name\` |`,
    tenant: 'Parent + child',
    rls: '`can_manage_products` / customer read RPCs.',
    permKeys: ['products'],
    extraPerm: null,
  },
  {
    name: 'Vendors',
    key: 'vendor',
    domain: 'Catalog & Supply',
    submodules: 'None.',
    should: 'Supplier master linked to products and global shipments.',
    current: 'Table `vendors`. Route `/app/vendors`.',
    improve: '**P0:** Required on `global_shipments.vendor_id`.',
    schema: `| Table | Key fields |\n|-------|------------|\n| \`vendors\` | \`tenant_id\`, \`name\`, \`code\`, contact fields |`,
    tenant: 'Parent + child',
    rls: 'Tenant-scoped internal roles.',
    permKeys: ['vendor'],
    extraPerm: null,
  },
  {
    name: 'Order Management',
    key: 'order_management',
    domain: 'Procurement Inputs',
    submodules: '**Orders**, **Order items**, **Negotiation** (when `negotiate=true`).',
    should: 'B2B purchase intent and optional negotiation; feed parent shipment procurement.',
    current: '`orders`, `order_items`. App + shop `/orders`. Offer fields, `parent_tenant_id`, `shipment_id` on lines.',
    improve: '**P1:** Update FK when shipments renamed. Optional parent order dashboard.',
    schema: `| Table | Key fields |\n|-------|------------|\n| \`orders\` | \`tenant_id\`, \`customer_group_id\`, \`store_id\`, \`status\`, \`negotiate\`, \`parent_tenant_id\`, rates |\n| \`order_items\` | quantities, offers, \`price_gbp\`, \`cost_bdt\`, \`shipment_id\` |`,
    tenant: 'Child (primary)',
    rls: 'Tenant + customer_group on shop.',
    permKeys: ['order_management'],
    extraPerm: null,
  },
  {
    name: 'Costing File (Pre-order)',
    key: 'costing_file',
    domain: 'Procurement Inputs',
    submodules: '**Files**, **Items**, **Viewers**.',
    should: 'Pre-order costing worksheets with optional customer visibility.',
    current: '`costing_files`, `costing_file_items`, `costing_file_viewers`. Route `/costing`.',
    improve: 'None — stable.',
    schema: `| Table | Key fields |\n|-------|------------|\n| \`costing_files\` | header, status, pricing |\n| \`costing_file_items\` | lines |\n| \`costing_file_viewers\` | customer grants |`,
    tenant: 'Child',
    rls: 'Admin manage; viewer grants for shop.',
    permKeys: ['costing_file'],
    extraPerm: null,
  },
  {
    name: 'Product Based Costing',
    key: 'product_based_costing',
    domain: 'Procurement Inputs',
    submodules: '**Batch file**, **Batch items**.',
    should: 'Child costing batches → parent shipment lines (no mandatory order).',
    current: '`product_based_costing_files`, `product_based_costing_items`. Route `/product-based-costing`.',
    improve: 'None — stable.',
    schema: `| Table | Key fields |\n|-------|------------|\n| \`product_based_costing_files\` | batch metadata |\n| \`product_based_costing_items\` | product lines |`,
    tenant: 'Child',
    rls: 'Tenant admin/staff.',
    permKeys: ['product_based_costing'],
    extraPerm: null,
  },
  {
    name: 'Procurement & Stock',
    key: 'global_shipment, global_stock, inventory',
    domain: 'Procurement & Stock',
    submodules: '**Global Shipment** + items | **Global Stock** + quantities | **Stock type** (target) | **Tenant Stock** (allocations).',
    should: 'Parent receive shipments, compute landed cost, stock pools; child view allocations; stock types gate sales.',
    current: '`shipments`, `shipment_items`, `global_stocks`, `global_stock_quantities`, `child_tenant_stock_allocations`. Keys: `global_shipment`, `global_stock`, `inventory`.',
    improve: '**P0:** `global_shipments`/`global_shipment_items`, `calculated_landed_cost`, currency FKs, `global_stock_types`. **P1:** Retire `shipment` key.',
    schema: `**Current:** \`shipments\`, \`shipment_items\`, \`global_stocks\`, \`global_stock_quantities\`, \`child_tenant_stock_allocations\`\n\n**Target:** see §16.2–16.5`,
    tenant: 'Parent owns; child gets allocation view',
    rls: 'Parent tenant on shipment/stock; `search_stock_network` for cross-tenant pick.',
    permKeys: ['global_shipment', 'global_stock', 'inventory'],
    extraPerm: null,
  },
  {
    name: 'Profile & CRM',
    key: 'billing_profile, recipient_profile',
    domain: 'Profile & CRM',
    submodules: '**Billing profile** | **Recipient profile** (target dedicated table).',
    should: 'Separate financial account from delivery endpoint (dropship/retail).',
    current: '`billing_profiles` stable. Recipient via invoice snapshots + `business_parties`.',
    improve: '**P0:** `recipient_profiles` table. **P1:** `billing_profile` module key.',
    schema: `| Table | Key fields |\n|-------|------------|\n| \`billing_profiles\` | \`tenant_id\`, \`name\`, \`phone\`, \`email\`, \`address\`, \`customer_group_id\` |\n| \`recipient_profiles\` *(target)* | \`name\`, \`address\`, \`phone\` |`,
    tenant: 'Child',
    rls: 'Tenant-scoped profiles.',
    permKeys: ['global_invoice'],
    extraPerm: 'Billing UI today under `global_invoice` routes.',
  },
  {
    name: 'Sales & Invoice',
    key: 'global_invoice, commerce_invoice',
    domain: 'Sales & Invoice',
    submodules: '**Desk invoices** (wholesale/retail/dropship) | **Shop invoices** | **Items** | **Returns** | **Charges**.',
    should: 'Sell from stock with immutable cost snapshot; COD/shipping charges; commerce order invoices separate.',
    current: '`global_invoices`, items, returns, `invoice_charge_lines`. `commerce_invoices`. Legacy `invoice` key.',
    improve: '**P0:** `unit_cost_price`, inline charges, `shipment_item_id`. **P1:** Remove `invoice` key.',
    schema: `**Desk:** \`global_invoices\`, \`global_invoice_items\`, \`global_return_items\`, \`invoice_charge_lines\`\n**Commerce:** \`commerce_invoices\`\n**Target:** §16.8–16.9`,
    tenant: 'Child issues; parent rollup',
    rls: 'Issuer `tenant_id`; parent via `parent_tenant_id`.',
    permKeys: ['global_invoice', 'commerce_invoice'],
    extraPerm: null,
  },
  {
    name: 'Ledger & Treasury',
    key: 'accounting, global_accounting_ledger, global_payments',
    domain: 'Ledger & Treasury',
    submodules: '**Payments** | **Allocations** | **Customer payments UI** | **Global ledger** | **Rollups**.',
    should: 'Bulk payments with unallocated balance; manual invoice allocation; parent consolidated ledger.',
    current: '`payments`, `payment_allocations`, `global_accounting_ledger`, rollups. Module `accounting`.',
    improve: '**P0:** `global_payments` / `invoice_payments` with `unallocated_amount`.',
    schema: `**Current:** \`payments\`, \`payment_allocations\`, \`global_accounting_ledger\`, \`global_shipment_accounting\`, \`global_invoice_accounting\`\n**Target:** §16.10–16.11`,
    tenant: 'Child payments; parent ledger',
    rls: 'Tenant payments; parent filter on ledger.',
    permKeys: ['accounting', 'global_accounting_ledger', 'global_shipment_accounting', 'global_invoice_accounting'],
    extraPerm: null,
  },
  {
    name: 'Shop & B2B',
    key: 'store, cart',
    domain: 'Shop & B2B',
    submodules: '**Stores** | **Store access** | **Pricing** | **Cart**.',
    should: 'B2B storefront per customer group; cart → order flow.',
    current: '`stores`, `store_access`, `store_product_prices`, `carts`, `cart_items`.',
    improve: 'None — stable.',
    schema: `| Table | Key fields |\n|-------|------------|\n| \`stores\` | \`tenant_id\`, \`name\` |\n| \`store_access\` | group ↔ store |\n| \`carts\` / \`cart_items\` | shop carts |`,
    tenant: 'Child',
    rls: 'Customer group store access RPCs.',
    permKeys: ['store', 'cart'],
    extraPerm: null,
  },
  {
    name: 'Commerce',
    key: 'commerce_shop, commerce_order, commerce_cart, commerce_accounting',
    domain: 'Commerce',
    submodules: '**Shop** | **Cart** | **Orders** | **Invoices** | **Accounting** (five keys).',
    should: 'Isolated commerce flow selling parent global stock; no inbound shipments.',
    current: '`commerce_*` tables. Five module keys. F7 global stock integration.',
    improve: 'None — stable.',
    schema: `| Table | Key fields |\n|-------|------------|\n| \`commerce_orders\` | COD, delivery, recipient fields |\n| \`commerce_invoices\` | from orders |\n| \`commerce_accounting\` | ledger |`,
    tenant: 'Child only',
    rls: 'Tenant + customer group.',
    permKeys: ['commerce_shop', 'commerce_order', 'commerce_cart', 'commerce_accounting', 'commerce_invoice'],
    extraPerm: null,
  },
  {
    name: 'Capital & Investors',
    key: 'investor, global_investor, global_investor_shipment, investor_portal',
    domain: 'Capital',
    submodules: '**Profiles** | **Transactions** | **Shipment investments** | **Portal**.',
    should: 'Parent investor capital, cost-share per shipment, external portfolio login.',
    current: '`investors`, `shipment_investments`, `investor_accounts`. Legacy + global UI keys.',
    improve: 'None — stable.',
    schema: `| Table | Key fields |\n|-------|------------|\n| \`investors\` | parent tenant |\n| \`shipment_investments\` | cost_share, profit |\n| \`investor_accounts\` | portal email |`,
    tenant: 'Parent admin; external investors',
    rls: 'Parent tenant; portal via `investor_accounts`.',
    permKeys: ['investor', 'global_investor', 'global_investor_shipment', 'investor_portal'],
    extraPerm: null,
  },
  {
    name: 'Thrift',
    key: 'thrift_* (9 keys)',
    domain: 'Verticals',
    submodules: 'stock, shipment, box, shelf, barcode, category, type, settings, currency.',
    should: 'Standalone thrift vertical — not global parent/child integration (phase 1).',
    current: '14 `thrift_*` tables. Routes `/app/thrift/*`.',
    improve: 'None per locked decision D12.',
    schema: '`thrift_stocks`, `thrift_shipments`, `thrift_boxes`, `thrift_invoices`, etc.',
    tenant: 'Per tenant',
    rls: 'Tenant-scoped.',
    permKeys: ['thrift_stock', 'thrift_shipment', 'thrift_box', 'thrift_shelf', 'thrift_barcode', 'thrift_category', 'thrift_type', 'thrift_settings', 'thrift_currency'],
    extraPerm: null,
  },
  {
    name: 'Koba',
    key: 'koba_retail, koba_wholesale',
    domain: 'Verticals',
    submodules: '**Retail** (full flow) | **Wholesale** (catalog).',
    should: 'Scraped catalog orders — isolated from global stock.',
    current: '`koba_*` tables. Python sync. Routes `/koba/*`.',
    improve: 'None — stable.',
    schema: '`koba_products`, `koba_orders`, `koba_carts`, `koba_retail_settings`',
    tenant: 'Per tenant',
    rls: 'Tenant-scoped koba RPCs.',
    permKeys: ['koba_retail', 'koba_wholesale'],
    extraPerm: null,
  },
  {
    name: 'Tasks',
    key: 'tasks',
    domain: 'Verticals',
    submodules: 'project → module → submodule → task/note/discussion hierarchy.',
    should: 'Internal PM with `item_permissions` separate from business modules.',
    current: '`items`, `tags`, `comments`, `item_permissions`, `activity_logs`.',
    improve: 'None — stable.',
    schema: '| Table | Key fields |\n|-------|------------|\n| `items` | hierarchical type, parent_id |\n| `item_permissions` | per-user ACL |',
    tenant: 'Per tenant',
    rls: '`get_effective_item_role`.',
    permKeys: ['tasks'],
    extraPerm: null,
  },
];

let section17 = `## 17. Module reference

> **Per module:** Name → Submodule suggestion → Description (should do / current / improve) → Data schema → Permission control & data model.

`;

let n = 1;
for (const mod of modules) {
  let permBlock = '';
  if (mod.permKeys) {
    for (const pk of mod.permKeys) {
      permBlock += `\n**\`${pk}\`**\n\n${permTableForKey(pk)}`;
    }
  } else {
    permBlock = '\nPlatform / catalog — no single `module_key`. Superadmin manages via `/platform/*`.\n';
  }
  if (mod.extraPerm) permBlock += `\n${mod.extraPerm}\n`;

  section17 += `### ${n}. ${mod.name}

**Domain:** ${mod.domain}  
**\`module_key\`:** \`${mod.key}\`

#### Submodule suggestion
${mod.submodules}

#### Description
- **What it should do:** ${mod.should}
- **Current set:** ${mod.current}
- **Improvement needed:** ${mod.improve}

#### Data schema
${mod.schema}

#### Permission control & data model
- **Tenant assignment:** ${mod.tenant}
- **RLS / data model:** ${mod.rls}
${permBlock}
---

`;
  n++;
}

const base = fs.readFileSync('MASTER_PLAN.md', 'utf8');
const start = base.indexOf('## 17. Module');
const end = base.indexOf('## 18. End-to-end flows');
if (start === -1 || end === -1) throw new Error('sections not found');

let updated = base.slice(0, start) + section17 + '\n' + base.slice(end);
updated = updated.replace(
  /\*\*Quick navigation:\*\*[^\n]+/,
  '**Quick navigation:** §1–§13 architecture | **§14** feature matrix | **§15** global permissions | **§16** redesign schemas | **§17** modules (should/current/improve) | **§18** flows',
);

for (const path of ['MASTER_PLAN.md', 'doc/MASTER_PLAN.md', 'web/public/doc/MASTER_PLAN.md']) {
  fs.writeFileSync(path, updated);
}
console.log('Done:', n - 1, 'modules');
