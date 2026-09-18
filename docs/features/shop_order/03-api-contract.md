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

Cash-in: [wallet 01](../wallet/01-prd.md). Remittance allocates to merchant `total_amount`; leftover → merchant wallet. `transfer_dropship_reseller_profit` is not the happy-path cash step.

### 2.4 Catalog shop order → bill (not dropship)

`fulfill_shop_order_to_invoice`: confirmed **catalog** orders only (`wholesale` / `retail`). Dropship must raise. Builds `create_sales_invoice_from_payload` with `issue: true`, `collection_source=billing_profile`, tenant sell from order lines (not customer/resell face), merchant-owed charges only. Links `shop_orders.global_invoice_id`. Wholesale desk create remains the main walk-in path.

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
