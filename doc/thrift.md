# Thrift Module Technical Specification

This documentation describes the architecture, database schema, math calculations, and automated processes designed for the multi-tenant **Thrift Module**. 

---

## Architecture & Design Decisions

During the alignment phase, the following architectural choices were finalized:
1. **Multi-Tenancy & Isolation**:
   - `sku` and `invoice_number` are strictly unique **per tenant** (e.g., `unique (tenant_id, sku)`).
   - Standard primary keys (`bigserial`) are used for all tables instead of UUIDs.
2. **Returns Tracking**:
   - Returns and status updates are managed by explicit **client/frontend actions** rather than database status change triggers.
3. **Mandatory Shipment Links**:
   - Every Thrift Stock item must be linked to a valid shipment (i.e. `shipment_id bigint not null references public.shipments(id)`).
4. **Accrual Ledger Logging**:
   - Invoice revenue is logged immediately in the ledger upon invoice creation.
5. **Dynamic COGS Challenge**:
   - Currently, COGS calculations are fetched statically from `thrift_pricings.cost_of_goods_sold`. More advanced dynamic cost calculation logic will be discussed and implemented later.

---

## 1. Database Schema

All tables have Row Level Security (RLS) enabled and are scoped to the `authenticated` role using tenant membership rules.

### Custom Enums
```sql
create type public.thrift_section as enum ('MALE', 'FEMALE', 'UNISEX', 'KIDS', 'HOME');
create type public.thrift_condition as enum ('NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR');
create type public.thrift_stock_type as enum ('SINGLE', 'BULK');
create type public.thrift_stock_status as enum ('AVAILABLE', 'OUT_OF_STOCK', 'DAMAGED', 'STOLEN');
create type public.thrift_transaction_method as enum ('CASH', 'CARD', 'MOBILE_BANKING', 'COD');
create type public.thrift_delivery_status as enum ('PENDING', 'SHIPPED', 'DELIVERED', 'RETURNED', 'PARTIALLY_RETURNED');
create type public.thrift_payment_status as enum ('UNPAID', 'PAID', 'REFUNDED');
create type public.thrift_item_status as enum ('SOLD', 'RETURNED');
create type public.thrift_return_action as enum ('RESTOCK', 'WRITE_OFF');
create type public.thrift_ledger_type as enum ('REVENUE', 'EXPENSE', 'REFUND', 'LOSS');
create type public.thrift_ledger_source as enum ('INVOICE', 'SHIPMENT', 'OPERATIONAL');
```

### Tables

#### `thrift_categories`
```sql
create table public.thrift_categories (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  description text null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_categories_name_tenant_unique unique (tenant_id, name)
);
```

#### `thrift_types`
```sql
create table public.thrift_types (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  description text null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_types_name_tenant_unique unique (tenant_id, name)
);
```

#### `thrift_shelves`
```sql
create table public.thrift_shelves (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  location_bay text null,
  shelf_code text not null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_shelves_code_tenant_unique unique (tenant_id, shelf_code)
);
```

#### `thrift_stocks`
```sql
create table public.thrift_stocks (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint not null references public.shipments(id) on delete cascade,
  name text not null,
  brand_name text null,
  category_id bigint not null references public.thrift_categories(id),
  type_id bigint not null references public.thrift_types(id),
  section public.thrift_section not null,
  shelf_id bigint not null references public.thrift_shelves(id),
  color text not null,
  size text not null,
  condition public.thrift_condition not null,
  sku text not null,
  stock_type public.thrift_stock_type not null default 'SINGLE',
  quantity integer not null default 1 check (quantity >= 0),
  weight_gm integer null check (weight_gm >= 0),
  status public.thrift_stock_status not null default 'AVAILABLE',
  note text null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_stocks_sku_tenant_unique unique (tenant_id, sku)
);
```

#### `thrift_stock_images`
```sql
create table public.thrift_stock_images (
  id bigserial primary key,
  stock_id bigint not null references public.thrift_stocks(id) on delete cascade,
  image_url text not null,
  is_primary boolean not null default false,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

#### `thrift_pricings`
```sql
create table public.thrift_pricings (
  id bigserial primary key,
  stock_id bigint not null unique references public.thrift_stocks(id) on delete cascade,
  cost_of_goods_sold numeric(12, 2) not null default 0.00 check (cost_of_goods_sold >= 0),
  target_price numeric(12, 2) not null default 0.00 check (target_price >= 0),
  listed_price numeric(12, 2) not null default 0.00 check (listed_price >= 0),
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

#### `thrift_invoices`
```sql
create table public.thrift_invoices (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_number text not null,
  recipient_name text not null,
  address text not null,
  phone text not null,
  transaction_method public.thrift_transaction_method not null,
  delivery_status public.thrift_delivery_status not null default 'PENDING',
  payment_status public.thrift_payment_status not null default 'UNPAID',
  cod_charge numeric(12, 2) not null default 0.00 check (cod_charge >= 0),
  packing_charge numeric(12, 2) not null default 0.00 check (packing_charge >= 0),
  invoice_print_charge numeric(12, 2) not null default 0.00 check (invoice_print_charge >= 0),
  shipping_charge_customer numeric(12, 2) not null default 0.00 check (shipping_charge_customer >= 0),
  total_invoice_amount numeric(12, 2) not null default 0.00 check (total_invoice_amount >= 0),
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint thrift_invoices_number_tenant_unique unique (tenant_id, invoice_number)
);
```

#### `thrift_invoice_items`
```sql
create table public.thrift_invoice_items (
  id bigserial primary key,
  invoice_id bigint not null references public.thrift_invoices(id) on delete cascade,
  stock_id bigint not null references public.thrift_stocks(id),
  quantity integer not null check (quantity > 0),
  sold_price numeric(12, 2) not null default 0.00 check (sold_price >= 0),
  platform_fees numeric(12, 2) not null default 0.00 check (platform_fees >= 0),
  shipping_cost_paid_by_shop numeric(12, 2) not null default 0.00 check (shipping_cost_paid_by_shop >= 0),
  item_status public.thrift_item_status not null default 'SOLD',
  return_reason text null,
  return_cost_charged_to_customer numeric(12, 2) not null default 0.00 check (return_cost_charged_to_customer >= 0),
  return_cost_paid_by_shop numeric(12, 2) not null default 0.00 check (return_cost_paid_by_shop >= 0),
  return_action public.thrift_return_action null,
  net_profit numeric(12, 2) not null default 0.00,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

#### `thrift_accounting_ledger`
```sql
create table public.thrift_accounting_ledger (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  type public.thrift_ledger_type not null,
  source public.thrift_ledger_source not null,
  reference_id bigint not null,
  amount numeric(12, 2) not null check (amount >= 0),
  date timestamptz not null default now(),
  inserted_by text not null,
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

## 2. Profit and Totals Automation

### Item Net Profit Trigger (`thrift_invoice_items`)
Automatically calculates line-item net profit before insert or update:
```sql
create or replace function public.calculate_thrift_item_net_profit()
returns trigger
language plpgsql
security definer
as $$
declare
  v_cogs numeric(12, 2);
begin
  select coalesce(cost_of_goods_sold, 0.00) into v_cogs
  from public.thrift_pricings
  where stock_id = new.stock_id;

  -- Profit Math:
  -- Net Profit = (Sold Price - COGS) * Quantity - Platform Fees - Shipping Cost Paid by Shop
  new.net_profit := (new.sold_price - coalesce(v_cogs, 0.00)) * new.quantity 
                    - new.platform_fees 
                    - new.shipping_cost_paid_by_shop;

  return new;
end;
$$;
```

### Invoice Total Trigger (`thrift_invoices`)
Recomputes invoice amount including delivery/packaging/COD charges:
```sql
create or replace function public.calculate_thrift_invoice_total()
returns trigger
language plpgsql
security definer
as $$
declare
  v_invoice_id bigint;
begin
  v_invoice_id := case when tg_op = 'DELETE' then old.invoice_id else new.invoice_id end;

  update public.thrift_invoices
  set total_invoice_amount = coalesce((
    select sum(sold_price * quantity)
    from public.thrift_invoice_items
    where invoice_id = v_invoice_id
  ), 0.00) 
  + cod_charge 
  + packing_charge 
  + invoice_print_charge 
  + shipping_charge_customer
  where id = v_invoice_id;

  return null;
end;
$$;
```

### Automated Stock Loss Ledger Trigger (`thrift_stocks`)
Logs a `LOSS` row in the ledger automatically based on COGS if stock status is marked `DAMAGED` or `STOLEN`:
```sql
create or replace function public.log_thrift_stock_loss_ledger()
returns trigger
language plpgsql
security definer
as $$
declare
  v_cogs numeric(12, 2);
begin
  if (new.status in ('DAMAGED'::public.thrift_stock_status, 'STOLEN'::public.thrift_stock_status))
     and (old.status is null or old.status <> new.status) then
     
    select coalesce(cost_of_goods_sold, 0.00) into v_cogs
    from public.thrift_pricings
    where stock_id = new.id;

    if v_cogs > 0 then
      insert into public.thrift_accounting_ledger (
        tenant_id,
        type,
        source,
        reference_id,
        amount,
        inserted_by,
        note
      )
      values (
        new.tenant_id,
        'LOSS'::public.thrift_ledger_type,
        'SHIPMENT'::public.thrift_ledger_source,
        new.shipment_id,
        v_cogs * new.quantity,
        new.inserted_by,
        'Auto-logged loss for stock item status set to ' || new.status || ' (SKU: ' || new.sku || ')'
      );
    end if;
  end if;
  return new;
end;
$$;
```

---

## 3. "Mark as Sold" Automation RPC

The RPC config handles atomic transaction creation of invoice and items, inventory quantity reduction, and ledger insertions:

```sql
create or replace function public.mark_thrift_items_as_sold(
  p_tenant_id bigint,
  p_invoice_number text,
  p_recipient_name text,
  p_address text,
  p_phone text,
  p_transaction_method public.thrift_transaction_method,
  p_cod_charge numeric,
  p_packing_charge numeric,
  p_invoice_print_charge numeric,
  p_shipping_charge_customer numeric,
  p_inserted_by text,
  p_items jsonb -- Array of { stock_id: bigint, quantity: int, sold_price: numeric, platform_fees: numeric, shipping_cost_paid_by_shop: numeric }
)
returns bigint
language plpgsql
security definer
as $$
declare
  v_invoice_id bigint;
  v_item jsonb;
  v_stock_id bigint;
  v_qty integer;
  v_sold_price numeric(12,2);
  v_platform_fees numeric(12,2);
  v_ship_paid_by_shop numeric(12,2);
  v_available_qty integer;
  v_total_ship_paid_by_shop numeric(12,2) := 0.00;
begin
  -- 1. Insert Invoice
  insert into public.thrift_invoices (
    tenant_id, invoice_number, recipient_name, address, phone, transaction_method,
    cod_charge, packing_charge, invoice_print_charge, shipping_charge_customer, inserted_by
  )
  values (
    p_tenant_id, p_invoice_number, p_recipient_name, p_address, p_phone, p_transaction_method,
    p_cod_charge, p_packing_charge, p_invoice_print_charge, p_shipping_charge_customer, p_inserted_by
  )
  returning id into v_invoice_id;

  -- 2. Process Items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_stock_id := (v_item->>'stock_id')::bigint;
    v_qty := (v_item->>'quantity')::integer;
    v_sold_price := (v_item->>'sold_price')::numeric;
    v_platform_fees := coalesce((v_item->>'platform_fees')::numeric, 0.00);
    v_ship_paid_by_shop := coalesce((v_item->>'shipping_cost_paid_by_shop')::numeric, 0.00);
    v_total_ship_paid_by_shop := v_total_ship_paid_by_shop + v_ship_paid_by_shop;

    -- Qty validation
    select quantity into v_available_qty
    from public.thrift_stocks
    where id = v_stock_id and tenant_id = p_tenant_id;

    if v_available_qty < v_qty then
      raise exception 'Insufficient stock for stock ID %', v_stock_id;
    end if;

    insert into public.thrift_invoice_items (
      invoice_id, stock_id, quantity, sold_price, platform_fees, shipping_cost_paid_by_shop, item_status
    )
    values (
      v_invoice_id, v_stock_id, v_qty, v_sold_price, v_platform_fees, v_ship_paid_by_shop, 'SOLD'::public.thrift_item_status
    );

    update public.thrift_stocks
    set 
      quantity = quantity - v_qty,
      status = case when (quantity - v_qty) = 0 then 'OUT_OF_STOCK'::public.thrift_stock_status else status end,
      updated_at = now()
    where id = v_stock_id;
  end loop;

  -- 3. Log Revenue (accrual basis)
  insert into public.thrift_accounting_ledger (
    tenant_id, type, source, reference_id, amount, inserted_by, note
  )
  select 
    p_tenant_id, 'REVENUE'::public.thrift_ledger_type, 'INVOICE'::public.thrift_ledger_source,
    v_invoice_id, total_invoice_amount, p_inserted_by, 'Auto-logged revenue from Thrift Invoice #' || invoice_number
  from public.thrift_invoices
  where id = v_invoice_id;

  -- 4. Log Absorbed Shipping Expense (if applicable)
  if v_total_ship_paid_by_shop > 0 then
    insert into public.thrift_accounting_ledger (
      tenant_id, type, source, reference_id, amount, inserted_by, note
    )
    values (
      p_tenant_id, 'EXPENSE'::public.thrift_ledger_type, 'INVOICE'::public.thrift_ledger_source,
      v_invoice_id, v_total_ship_paid_by_shop, p_inserted_by,
      'Auto-logged shipping cost absorbed by shop for Invoice #' || p_invoice_number
    );
  end if;

  return v_invoice_id;
end;
$$;
```
