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

### 2.1 Stock Assignment at Processing: `assign_dropship_order_stock_pick`
```sql
create or replace function public.assign_dropship_order_stock_pick(
  p_order_id uuid,
  p_picked_lines jsonb -- [{ "order_item_id": "...", "global_stock_id": "...", "picked_qty": 2 }]
)
returns jsonb
language plpgsql security definer;
```

### 2.2 Ready for Pickup & B2B Accounting Invoice Issue
Calls `create_sales_invoice_from_payload` with `options.issue = true` and links `shop_orders.global_invoice_id`.

### 2.3 Reseller Margin Credit: `transfer_dropship_reseller_profit`
```sql
create or replace function public.transfer_dropship_reseller_profit(
  p_order_id uuid
)
returns jsonb
language plpgsql security definer;
```
*(Credits profit spread to the merchant billing profile wallet upon delivery).*

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
