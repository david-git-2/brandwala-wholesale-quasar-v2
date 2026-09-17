# Dashboard & Insights — Product Requirements Document (PRD)

> **Module**: Dynamic Slot Registry, Operational Work Desks & Executive Analytics  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: Company Owners, Operations Staff, Storefront Customers, Superadmins

---

## 1. Executive Summary

The **Dashboard & Insights** module provides a dynamic, decentralized home surface for tenant administrators and storefront customers. Instead of a monolithic hard-coded dashboard, domain modules register modular widget slots (`section`, `stat`, `attention`, `shortcut`) that are dynamically mounted based on tenant module enablement and user role permissions.

The staff home acts as an **operational work desk** featuring a unified Attention Work Queue (`DashboardAttentionList`), pulse metric cards (`DashboardPulseCard`), and domain-specific glance panels.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Company Owner / CFO** | Full Company | View enterprise KPI pulse cards, revenue trends, universal wallet liquidity, and multi-brand analytics. |
| **Operations Staff** | Operational | View actionable Attention Work Queue items (overdue invoices, pending COD, stock shortfalls). |
| **Storefront Customer** | Shop Scope | View order glance status donut, recent orders, and active cart resumes. |
| **Platform Superadmin** | Global Platform | View platform-wide tenant counts, health status, and infrastructure metrics. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Decentralized Slot Registry Architecture
- **As a** Feature Developer  
- **I want to** export widget slots from domain feature folders and register them in `dashboardSlotRegistry.ts`  
- **So that** new widgets appear automatically on the dashboard without modifying core shell components.

#### Acceptance Criteria
- [ ] Slots are categorized by kind: `section`, `stat`, `attention`, and `shortcut`.
- [ ] Widgets are filtered dynamically via `useDashboardSlots` respecting tenant module enablement and user permissions.

### US-2: Operational Attention Work Queue
- **As an** Operations Clerk  
- **I want to** see an urgent attention queue (`Needs work` vs `Nothing waiting`) directly at the top of the dashboard  
- **So that** actionable exceptions (overdue invoices, in-transit shipments needing receipt, uncollected COD) are resolved immediately.

#### Acceptance Criteria
- [ ] Attention list displays up to 8 prioritized operational action items with direct navigational links.
- [ ] Unfinished or stub modules render `DashboardStubBadge` and are excluded from active attention counts.

### US-3: Customer Storefront Dashboard
- **As a** B2B Buyer  
- **I want to** view an order glance donut and my recent purchase orders upon logging in to the storefront  
- **So that** I can track pending orders and resume active shopping carts with one click.

#### Acceptance Criteria
- [ ] Backed by unified single RPC `get_customer_dashboard_summary`.
- [ ] Renders interactive order status segments (`needs_you`, `in_progress`, `delivered`, `paid`).

---

## 4. UI Layout & Wireframe

### Staff Enterprise Operational Desk

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Home > Operations Dashboard                                                     |
+----------------------------------------------------------------------------------------------------+
| ATTENTION WORK QUEUE (3 items need action):                                                        |
| [!] 4 Invoices Overdue for Metro Mart (Due: 145,000 BDT) -> [Collect Payment]                      |
| [!] Shipment SHP-2026-001 Arrived at Port -> [Open Receive Checklist]                             |
| [!] 2 Dropship Orders Awaiting Stock Pick -> [Open Processing Desk]                               |
+----------------------------------------------------------------------------------------------------+
| ENTERPRISE PULSE METRICS:                                                                          |
| [ TOTAL REVENUE: 4.85M BDT ] [ LIQUID CASH: 3.40M BDT ] [ INBOUND WEIGHT: 1.25 T ] [ ATP: 4,820 ] |
+----------------------------------------------------------------------------------------------------+
| DOMAIN INSIGHT PANELS:                                                                             |
| [ Wholesale Invoices Glance ]   [ Procurement Shipments Pipeline ]   [ Dropship Fulfillment Desk ] |
+----------------------------------------------------------------------------------------------------+
```
