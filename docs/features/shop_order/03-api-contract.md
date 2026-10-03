# Shop Order & Dropship — API Contract & RPC Signatures

> **RPC Functions Target**: `supabase/schemas/shop_order/03_rpcs.sql`  
> **Security Level**: `SECURITY DEFINER`

---

## 1. Catalog Negotiation RPCs

### 1.1 Staff First Offer: `staff_price_shop_order`
```sql
create or replace function public.staff_price_shop_order(
  p_order_id uuid,
  p_items jsonb, -- [{ "item_id": "...", "first_offer_price": 550.00 }]
  p_notes text default null
)
returns jsonb
language plpgsql security definer;
```

### 1.2 Customer Action / Counter: `customer_counter_shop_order`
```sql
create or replace function public.customer_counter_shop_order(
  p_order_id uuid,
  p_actions jsonb -- [{ "item_id": "...", "action": "counter", "counter_price": 500.00 }]
)
returns jsonb
language plpgsql security definer;
```

### 1.3 Final Deal Confirmation: `customer_confirm_shop_order`
```sql
create or replace function public.customer_confirm_shop_order(
  p_order_id uuid,
  p_confirmed_items jsonb -- [{ "item_id": "...", "confirmed_quantity": 20 }]
)
returns jsonb
language plpgsql security definer;
```

---

## 2. Dropship Fulfillment & Stock Pick RPCs

### 2.1 Stock pick at processing: `add_shop_order_item_stock_pick`

Moves sellable qty to **held**. Writes `shop_order_item_stock_picks` (`global_stock_id` = source lot, `held_stock_id` = held lot, `quantity`). Do not bind held lots on `shop_order_items.global_stock_id` for the merchant bill.

### 2.2 Ship + merchant bill: `ship_dropship_order_and_issue_merchant_bill` (target)

One call. Status must be `ready_for_pickup`. Requires courier, pickup snapshot, every line picked or unavailable, `billing_profile_id`.

Inner issue: `issue_dropship_tenant_b2b_invoice` → `create_sales_invoice_from_payload` (`issue: true`). **Lines from picks** (`held_stock_id`, pick qty); skip unavailable. `collection_source` = `billing_profile`. COD/resell in `channel_meta` / order. Links `shop_orders.global_invoice_id`. Then sets `shipped`. Failure keeps `ready_for_pickup`.

Idempotent if already issued. Unique: one `sales_invoices.shop_order_id`. Dropship must not use `fulfill_shop_order_to_invoice`. Do not call `advance_dropship_order_status` → `shipped` from the UI.

### 2.3 Deliver and remittance (not this module’s cash)

`mark_dropship_order_delivered`: parcel only; require linked issued bill; no cash.

Cash-in: [bills_pays 01](../bills_pays/01-prd.md). Remittance allocates to merchant `total_amount`; leftover → merchant cashbook. `transfer_dropship_reseller_profit` is not the happy-path cash step.

### 2.4 Catalog shop order → bill (not dropship)

**Live today:** `fulfill_shop_order_to_invoice` issues (`issue: true`) from confirmed catalog orders. Links `shop_orders.global_invoice_id`.

**Target:** catalog pack-out is the procurement **Delivery paper** desk. Close take / condition / return; then **take** and/or **condition** bills. [SI19](../bills_pays/00-gaps.md). Dropship must not use this RPC. Walk-in remains invoice desk create.

### 2.5 Catalog procurement mark ready: `staff_set_catalog_ordered_qty`

Delivery paper desk **Mark ready for shipment**. **Live:** creates proforma via `create_invoice_from_preorder_demand_document` (lines from `preorder_demand.stock_picks`; sets `sales_invoices.shop_order_id` after create, not on payload). Backlog shortfall per line = `confirmed_quantity - delivered_quantity` (picks), not vendor `placed_quantity`. `p_items` is legacy; server reads all order lines.

---

## 3. Storefront Permissions RPC: `get_shop_permissions_for_customer`

```sql
create or replace function public.get_shop_permissions_for_customer(
  p_shop_id uuid,
  p_customer_group_id uuid default null
)
returns jsonb
language plpgsql security definer;
```

---

## 4. Storefront catalog browse (cursor)

Keyset list. Sort: `name asc`, `id asc` (vendor catalog uses product `id`; fixed_price/dropship listings use `listing_id` as cursor `id`). No total count.

### 4.1 Customer: `browse_shop_catalog_for_customer`

```sql
browse_shop_catalog_for_customer(
  p_tenant_id bigint,
  p_shop_slug text,
  p_search text default null,
  p_category text default null,
  p_brand text default null,
  p_limit integer default 20,
  p_cursor_name text default null,
  p_cursor_id bigint default null
) returns jsonb
```

Response `data`: catalog rows. `meta`: `has_more`, `next_cursor` (`{ name, id }`), `limit`, plus `shop` and `permissions` on the first page.

### 4.2 Admin preview: `browse_shop_catalog_for_admin`

```sql
browse_shop_catalog_for_admin(
  p_tenant_id bigint,
  p_shop_id bigint,
  p_search text default null,
  p_limit integer default 24,
  p_cursor_name text default null,
  p_cursor_id bigint default null,
  p_include_below_min_units boolean default false
) returns jsonb
```

`vendor_catalog` shops only. Same `meta` shape (`has_more`, `next_cursor`, `limit`).
