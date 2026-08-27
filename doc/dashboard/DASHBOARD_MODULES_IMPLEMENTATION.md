# Dashboard Module Integration & Implementation Blueprint

This document outlines the **architecture, module eligibility criteria, and implementation standards** for integrating domain modules into the Brandwala Workspace Dashboard (`/:tenantSlug?/app/dashboard`).

---

## 🎯 1. Core Philosophy: The "Operational Cockpit"

A dashboard is only valuable if it answers two immediate questions for staff on login:
1. **"What needs my immediate attention?"** *(Pending customs clearance, orders awaiting approval, overdue receivables, unreconciled COD).*
2. **"What is the live operational pulse today?"** *(Inbound freight in transit, warehouse capacity, daily sales volume, operating liquidity).*

> [!IMPORTANT]
> **Anti-Pattern (Vanity Boards):** Avoid cluttering the dashboard with static links or master data configurations (e.g. tag lists, currency tables, role management). The sidebar already handles full system navigation. The dashboard is strictly for **live metrics, pipeline stages, and triage queues**.

---

## 🏢 2. Multi-Tenant Adaptation: Parent vs. Child Tenants

The dashboard adapts its components based on the workspace hierarchy:

```
┌─────────────────────────────────────────────────────────────┐
│                    PARENT COMPANY (parent_id = NULL)        │
│                    "Supply Chain, Logistics & Treasury"     │
├─────────────────────────────────────────────────────────────┤
│  • Inbound International Shipments (Sea/Air) & Customs Port │
│  • Warehouse Physical Stock Inventory & Bins                │
│  • Investor Capital Pools & Container ROI                   │
│  • Consolidated Company Liquidity & Sister Concern Velocity │
└──────────────────────────────┬──────────────────────────────┘
                               │ Virtual Stock Allocation
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    SISTER CONCERN (parent_id !== NULL)      │
│                    "Wholesale, Storefront & Dropshipping"   │
├─────────────────────────────────────────────────────────────┤
│  • B2B Shop Orders & Reseller Dropship Approval Queues      │
│  • Courier Dispatch Batches (Pathao / Steadfast)            │
│  • Wholesale Invoicing, Credit Terms & Receivables          │
│  • Courier Cash-on-Delivery (COD) Remittance Tracking       │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ 3. Modules That Need Dashboard Space

Out of the 26 codebase modules, only **6 core operational domains** qualify for dedicated dashboard slots:

### 1. `procurement_stock` (Parent Only)
* **Why it needs dashboard space:** Parent companies manage international purchasing, freight forwarding, customs clearance, and warehouse bin allocation.
* **Component Location:** [`web/src/modules/procurement_stock/dashboard/`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/procurement_stock/dashboard)
* **Dashboard Widgets Provided:**
  * `ProcurementInsightsPanel.vue`: 4-stage pipeline tracker (`In Sourcing` ➔ `In Transit` ➔ `Customs Port` ➔ `Warehouse Arrived`), warehouse capacity gauge, and active cargo payables.
  * `ProcurementDashboardActions.vue`: One-click actions (`+ Inbound shipment`, `Receive shipment`, `Stock movements`).

---

### 2. `shop_order` & Dropship Hub (Child / Sister Concern Only)
* **Why it needs dashboard space:** Sister concerns are high-velocity sales channels handling reseller orders, stock picks, packaging, and courier dispatches.
* **Component Location:** [`web/src/modules/shop_order/dashboard/`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/dashboard)
* **Dashboard Widgets Provided:**
  * `SalesOrderInsightsPanel.vue`: Live fulfillment matrix (`Needs Approval`, `Processing`, `Ready for Pickup`, `In Transit`) and active merchant reseller counts.
  * `SalesOrderDashboardActions.vue`: One-click actions (`+ New order / POS`, `Fulfillment hub`, `Dropship orders`).

---

### 3. `sales_invoice` (Universal / Child Priority)
* **Why it needs dashboard space:** Invoicing and payment recovery are critical daily tasks for tracking receivables, overdue accounts, and return credits.
* **Component Location:** [`web/src/modules/sales_invoice/dashboard/`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/sales_invoice/dashboard)
* **Dashboard Widgets Provided:**
  * `WholesaleInvoiceInsightsPanel.vue`: Paid vs Partial vs Overdue status bar ratio, total invoiced today (৳), and pending sales return adjustments.
  * `WholesaleInvoiceDashboardActions.vue`: One-click actions (`+ New invoice`, `Invoices ledger`, `Sales returns`).

---

### 4. `wallet` & `reporting_treasury` (Universal)
* **Why it needs dashboard space:** Operating liquidity, merchant payouts, and courier COD cash reconciliations directly impact daily solvency.
* **Component Location:** [`web/src/modules/wallet/dashboard/`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/wallet/dashboard)
* **Dashboard Widgets Provided:**
  * `WalletTreasuryInsightsPanel.vue`: Entity liquidity distribution (Company Reserve vs Courier COD Held vs Merchant Balances), pending courier COD collections, and double-entry audit status.
  * `WalletTreasuryDashboardActions.vue`: One-click actions (`Universal ledger`, `Entity accounts`, `Fund transfer`).

---

### 5. `investor_capital` (Parent Only)
* **Why it needs dashboard space:** Parent companies deploy investor capital into container batches and need high-level ROI monitoring.
* **Component Location:** [`web/src/modules/investor_capital/dashboard/`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/investor_capital/dashboard)
* **Dashboard Widgets Provided:**
  * `investorDashboardSlots.ts`: Quick status on active capital pools, deployed shares, and dividend ledger balances.

---

### 6. `tasks` (Universal)
* **Why it needs dashboard space:** Operational staff need an immediate view of high-priority checklist assignments and action logs.
* **Component Location:** [`web/src/modules/tasks/dashboard/`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/tasks/dashboard)
* **Dashboard Widgets Provided:**
  * `tasksDashboardSlots.ts`: Instant checklist counter and taskboard launcher.

---

## 🚫 4. Modules Excluded From Dashboard Space (And Why)

| Module | Classification | Reason for Exclusion from Main Dashboard |
| :--- | :--- | :--- |
| `global_reference` | Master Reference Data | Currencies, Markets, and UOMs are configured once; they have zero daily operational delta. |
| `tag` | Cross-Entity Infrastructure | Taxonomies are assigned inside item forms, not managed via a daily pulse. |
| `access_control` / `membership` | Security & RBAC | Staff invitations and permissions are managed in dedicated admin settings. |
| `navigation` / `featureCatalog` | System Registry | Module licensing and menu trees are platform-level configuration. |
| `invoice_shared` | Utility UI | Shared PDF layout rendering helper with no independent data domain. |
| `tenant` | Infrastructure | Tenant provisioning and danger zone tools belong on `/superadmin/dashboard`. |
| `koba` / `thrift` | Specialized Retail Verticals | Gated to specific niche tenants and excluded from standard wholesale/supply-chain workspaces. |

---

## 🛠️ 5. Step-by-Step Implementation Guide for New Modules

To add a new module to the dashboard without modifying the core shell, follow this 3-step contract:

### Step 1: Create Domain Components Inside Your Module Folder
Create a `dashboard/` subdirectory in your module folder:
```
web/src/modules/<module_name>/dashboard/
├── <Module>InsightsPanel.vue       (The visual status / pipeline card)
├── <Module>DashboardActions.vue    (The quick action button bar)
└── <module>DashboardSlots.ts       (The slot registration array)
```

### Step 2: Define Slot Metadata (`<module>DashboardSlots.ts`)
Export a `readonly DashboardSlot[]` array:
```ts
import { defineAsyncComponent } from 'vue';
import type { DashboardSlot } from 'src/modules/dashboard/types/dashboardSlot';

const MyModuleInsights = defineAsyncComponent(() => import('./MyModuleInsightsPanel.vue'));
const MyModuleActions = defineAsyncComponent(() => import('./MyModuleDashboardActions.vue'));

export const MY_MODULE_DASHBOARD_SLOTS: readonly DashboardSlot[] = [
  {
    id: 'my_module.ops.actions',
    scopes: ['app'],
    moduleKey: 'my_module_key',
    action: 'view',
    parentGroupKey: 'my_module_key',
    kind: 'section',
    title: 'Actions',
    icon: 'ph ph-lightning',
    order: 5,
    component: MyModuleActions,
    hierarchyScope: 'all', // 'all' | 'parent_only' | 'child_only'
  },
  {
    id: 'my_module.ops.insights',
    scopes: ['app'],
    moduleKey: 'my_module_key',
    action: 'view',
    parentGroupKey: 'my_module_key',
    kind: 'section',
    title: 'Operational Pulse',
    icon: 'ph ph-chart-bar',
    order: 10,
    component: MyModuleInsights,
    hierarchyScope: 'all',
  },
];
```

### Step 3: Register Slots in Central Registry
Append the exported array into [`dashboardSlotRegistry.ts`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/dashboard/registry/dashboardSlotRegistry.ts):
```ts
import { MY_MODULE_DASHBOARD_SLOTS } from 'src/modules/<module_name>/dashboard/<module>DashboardSlots';

export const DASHBOARD_SLOT_REGISTRY: readonly DashboardSlot[] = [
  ...MY_MODULE_DASHBOARD_SLOTS,
  // ...other slots
];
```

---

## 🎨 6. UI & Design System Rules for Dashboard Widgets

1. **Card Radius & Elevation:** Use `border-radius: 12px` (or `16px`), `1px solid var(--bw-theme-border)`, and zero heavy box-shadows.
2. **Action Buttons:** Use rounded-square buttons (`border-radius: 8px` / `10px`, `unelevated`, `no-caps`). Never use pill buttons on ops dashboards.
3. **Status Indicators:** Use soft background badges with 6px circular indicator dots (`urgent` red, `warn` amber, `info` blue, `success` green).
4. **Charts & Graphics:** Use Chart.js with Chart.js registration from [`dashboardChartSetup.ts`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/dashboard/utils/dashboardChartSetup.ts). Always use theme color variables (`--bw-theme-primary-rgb`) for dark/light mode harmony.
