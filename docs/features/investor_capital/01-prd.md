# Investor Portal & Capital — Product Requirements Document (PRD)

> **Module**: Capital Partner Profiles, Batch Investments & Profit Share Yields  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: External Capital Investors, Company Managing Partners, CFOs

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/investor_capital/` |
| UI | `web/src/modules/investor_capital/`, `investor_portal/` |
| SQL | Stub `supabase/schemas/investor/`; live in `public.sql` |
| Access | `investor` scope read-only; staff manage capital in `app` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` staff capital; `investor` portal |
| In | Profiles, deposits, shipment shares, read-side yield |
| Out | Withdrawal requests; selling stock |

See [scopes](../../architecture/scopes.md).

---

## 1. Executive Summary

The **Investor Portal & Capital** module manages external capital partners, cash deposits, batch investment shares in inbound shipments, and read-side profit yield distribution without shadow ledgers.

Investors receive real-time visibility into their invested capital, shipment batch performance, and realized yields through a dedicated, read-only investor portal (`/:slug/investor/*`), while staff administrators manage capital transactions and shipment share percentages in the backoffice.

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Managing Partner / Owner** | Full Access | Create investor profiles, record capital deposits/withdrawals, allocate shipment cost-share percentages, refresh profit sync. |
| **External Investor** | Investor Portal | Read-only view of invested capital, active shipment batches, realized gross profit shares, and yield history. |
| **Auditor** | Read Only | Audit shipment cost allocations and verify capital ledger transaction logs. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Read-Side Profit Derivation & Remainder Rule
- **As a** Managing Partner  
- **I want** investor profit shares derived on-demand directly from live shipment batch gross profit  
- **So that** calculations remain completely aligned with true sales margins without duplicate accounting ledgers.

#### Acceptance Criteria
- [ ] Formula computes: $\text{Investor Profit Share} = \text{Shipment Batch Gross Profit} \times \text{cost\_share\_pct}$.
- [ ] If total investor shares are $< 100\%$, the parent company automatically absorbs the remainder.

### US-2: Dedicated Investor Portal Scope (`/investor/*`)
- **As an** External Capital Investor  
- **I want to** log in to a dedicated, streamlined portal to review my active portfolio  
- **So that** I can track shipment progress, annualized return on investment (ROI), and available capital balance.

#### Acceptance Criteria
- [ ] Investor layout (`InvestorLayout.vue`) restricts navigation exclusively to capital statements and shipment yields.
- [ ] Realized profits default to active reinvestment until an explicit cash withdrawal is recorded.

---

## 4. UI Layout & Wireframe

### Investor Capital Dashboard & Allocations Desk

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Capital > Investor Profiles                                                     |
+----------------------------------------------------------------------------------------------------+
| [ Search investor name... ] [ Status: Active v ]                                  [ + New Partner ]|
+----------------------------------------------------------------------------------------------------+
| INVESTOR NAME          | TOTAL CAPITAL   | ALLOCATED TO BATCHES | REALIZED PROFIT | LIFETIME ROI % |
|------------------------+-----------------+----------------------+-----------------+----------------|
| Kabir Capital Holdings | 2,500,000 BDT   | 1,850,000 BDT (74%)  | 480,000 BDT     | 19.2%          |
| Nexus Syndicate Alpha  | 1,200,000 BDT   | 900,000 BDT (75%)    | 210,000 BDT     | 17.5%          |
+----------------------------------------------------------------------------------------------------+
| [ Record Capital Deposit ]      [ Record Withdrawal Payout ]     [ Manage Batch Allocations ]      |
+----------------------------------------------------------------------------------------------------+
```
