# Shop Order & Dropship — Product Requirements Document (PRD)

> **Module**: Storefront Commerce, Catalog Negotiation & Dropship Fulfillment  
> **Status**: Approved & Active  
> **Target Release**: v2.4.0  
> **Target Audience**: B2B Storefront Customers, Dropship Resellers, Procurement Officers, Fulfillment Operators, Finance Managers

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/shop_order/` |
| UI | `web/src/modules/shop_order/` |
| SQL | **Split** `supabase/schemas/shop_order/` |
| State | Vue Query composables + `shopOrderQueryKeys` |
| Access | `shop` storefront + `app` desks. Admin order URL is `/:slug/app/shop/orders/:id`; catalog vs dropship UI is chosen from `shop_type_snapshot`. |
| Model | **BW** shop + dropship; catalog quotes are **pre-order**. [business models](../../architecture/business-models.md). |

## Scope

| | |
| :--- | :--- |
| Surfaces | `shop` storefront; `app` shop config + dropship desk |
| In | Shops, carts, catalog/dropship orders, pricing, stock pick, **pickup locations** (warehouse sender address for courier), reseller payout trigger |
| Out | Physical warehouse receive, Koba carts, thrift POS. **Wholesale invoice desk** (create/issue/collect). Parent invoice engine for dropship (call it, don’t own it). Reseller identity is billing profiles, not pickup locations. |

Dropship money path (target): pick → **one** ship+issue RPC → deliver (parcel only) → remittance **receipt**. Packing slip is not a `sales_invoices` row.

Wholesale money path lives on the **invoice desk**, not this fulfillment desk. Catalog `fulfill_shop_order_to_invoice` is not dropship. Numbers: [money-story](../sales_invoice/money-story.md). Open gaps: [00-gaps](00-gaps.md).

---

## 1. Executive Summary

The **Shop Order & Dropship** module powers B2B storefront commerce (`shop` scope), storefront catalog administration (`shop_config`), supplier preorder negotiation, demand aggregation, and the 5-stage Dropship fulfillment desk (`app` scope).

It orchestrates packing slips for end-recipients and a **merchant** B2B bill (`sales_invoices`, issued at ship), courier dispatch, customer group price tiering, and reseller payouts (from remittance remainder, not from deliver).

---

## 2. User Personas & Permissions

| Role | Access Level | Permitted Actions |
| :--- | :--- | :--- |
| **Storefront Customer** | B2B Customer | Browse accessible shops, submit cart preorders, accept/counter first-offer price quotes, set final quantities. |
| **Dropship Reseller** | Reseller Partner | Place dropship orders for end recipients with custom resell prices, track courier deliveries, withdraw wallet profits. |
| **Fulfillment Staff** | Operational | Pick stock for dropship orders, generate packing slips, assign couriers, issue B2B accounting invoices. |
| **Procurement Staff** | Operational | Review preorder demand list, log vendor PO placements, advance orders to `ready_for_shipment`. |
| **Shop Admin / Manager**| Full Access | Create and configure shops (`vendor_catalog`, `fixed_price`, `dropship`), set price visibility permissions, configure categories. |

---

## 3. User Stories & Acceptance Criteria

### US-1: Storefront Types & Price Tier Permissions
- **As a** Shop Administrator  
- **I want to** configure storefronts as `vendor_catalog`, `fixed_price`, or `dropship`, and grant selective price visibility to customer groups  
- **So that** distinct wholesale and reseller groups see appropriate buy/sell/resell prices.

#### Acceptance Criteria
- [x] `vendor_catalog`: storefront shows list/`unit_price` when the customer group has `can_see_buy_price`.
- [x] `fixed_price`: storefront shows sell/`unit_price` when the customer group has `can_see_sell_price`.
- [x] `dropship`: cart/checkout enforces `minimum_sell_price_amount` (resell cannot go below floor); floor amount is shown when `can_see_sell_price`.

### US-2: 5-Phase Catalog Order Negotiation
- **As a** B2B Buyer and Procurement Manager  
- **I want to** participate in interactive price negotiation (`submitted` $\rightarrow$ `priced` $\rightarrow$ `countered` $\rightarrow$ `final_offered` $\rightarrow$ `confirmed`)  
- **So that** custom import quotes can be agreed before committing to supplier purchases.

#### Acceptance Criteria
- [x] Staff prepares first-offer margin (`staff_price_shop_order` $\rightarrow$ `priced`).
- [x] Customer can accept all lines (transitions directly to `confirmed`) or submit counter offers (`countered`).
- [x] Final confirmed quantities lock the order for procurement demand aggregation.

### US-3: Dropship 5-Stage Fulfillment & Reseller Margin Settlement
- **As a** Dropship Operator  
- **I want to** pick stock at `processing`, print a packing slip and issue the merchant bill when the parcel ships, and settle reseller leftover when the courier remits  
- **So that** dropship operations are fully automated and financially auditable.

#### Acceptance Criteria
- [x] Picking at `processing` writes `shop_order_item_stock_picks` (held lots). Live: `add_shop_order_item_stock_pick`.
- [x] **Mark as shipped** is one RPC `ship_dropship_order_and_issue_merchant_bill` (bill from picks, then `shipped`). No ship without `billing_profile_id` and a linked issued bill.
- [x] Deliver does not issue a bill and does not post cash.
- [x] Reseller leftover is the remittance remainder (wallet), not a required extra profit click after deliver.

---

## 4. UI Layout & Wireframe

### Dropship Fulfillment Desk

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Dropship > Fulfillment Desk                                                     |
+----------------------------------------------------------------------------------------------------+
| [ Tabs: Placed (5) | Processing (12) | Ready for Pickup (8) | Shipped (15) | Delivered (42) ]      |
+----------------------------------------------------------------------------------------------------+
| ORDER #      | MERCHANT / STORE | END RECIPIENT    | COURIER / AWB | RESELL TOTAL | PROFIT | ACTION|
|--------------+------------------+------------------+---------------+--------------+--------+-------|
| DS-ORD-10021 | Glamour Closet   | Karim (Chittag)  | Steadfast-881 | 3,200 BDT    | 650 BDT| [Pick]|
| DS-ORD-10022 | Trendy Reseller  | Nusrat (Sylhet)  | Pathao-4412   | 1,850 BDT    | 400 BDT| [Pick]|
+----------------------------------------------------------------------------------------------------+
```

Fulfillment stages live on `/:slug/app/shop/orders/:id` (confirmed → processing → ready → ship). After ship, staff open **Dropship settlement** at `/:slug/app/shop/dropship-management/:id`.

### Dropship settlement desk (post-ship)

```text
+----------------------------------------------------------------------------------------------------+
| Breadcrumbs: App > Shop > Dropship settlement                                                      |
+----------------------------------------------------------------------------------------------------+
| [ Search ] [ Status: Shipped | Delivered | … ]                                                     |
+----------------------------------------------------------------------------------------------------+
| ORDER #   | MERCHANT      | RECIPIENT     | COURIER        | STATUS                              |
|-----------+---------------+---------------+----------------+-------------------------------------|
| DS-10021  | Glamour Closet| Karim         | Steadfast-881  | Shipped                             |
+----------------------------------------------------------------------------------------------------+

Detail — status `shipped` (one job: parcel outcome)
  Banner: parcel in transit
  Recap: bill due, settlement numbers (read-only; Adjust fees → save draft)
  [ Mark as delivered ]  [ Mark as returned ]

Detail — status `delivered` (one job: remittance)
  Banner: record courier bank in
  [ Bank transfer from courier ]  → receipt pays merchant bill; remainder → merchant wallet
  `record_dropship_courier_remittance` (Payments / finance hub) is the single writer: receipt + ledger + `dropship_order_settlements.remittance_at`. `payout_settlement_status` changes only on merchant payout (cash out), not on remittance remainder.

Detail — `payment_received` / `reseller_paid` / `returned`: read-only recap; view merchant bill only
```
