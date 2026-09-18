-- Invoice bill redesign: additive schema (shop_order_id, channel_meta, line_meta, charges tables).

begin;

alter table public.sales_invoices
  add column if not exists shop_order_id bigint,
  add column if not exists charges_amount numeric(12,2) default 0 not null,
  add column if not exists channel_meta jsonb default '{}'::jsonb not null;

alter table public.sales_invoice_items
  add column if not exists line_meta jsonb default '{}'::jsonb not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'global_invoices_charges_amount_check'
  ) then
    alter table public.sales_invoices
      add constraint global_invoices_charges_amount_check check (charges_amount >= 0);
  end if;
end $$;

create table if not exists public.sales_invoice_item_costs (
  invoice_item_id bigint not null,
  unit_cost_price numeric(12,2) default 0 not null,
  costing_locked_at timestamptz default now() not null,
  constraint sales_invoice_item_costs_unit_cost_price_check check (unit_cost_price >= 0),
  constraint sales_invoice_item_costs_pkey primary key (invoice_item_id),
  constraint sales_invoice_item_costs_invoice_item_id_fkey
    foreign key (invoice_item_id) references public.sales_invoice_items(id) on delete cascade
);

create sequence if not exists public.sales_invoice_charges_id_seq;

create table if not exists public.sales_invoice_charges (
  id bigint not null default nextval('public.sales_invoice_charges_id_seq'::regclass),
  invoice_id bigint not null,
  parent_tenant_id bigint not null,
  charge_type public.invoice_charge_type not null,
  amount numeric(12,2) default 0 not null,
  created_at timestamptz default now() not null,
  constraint sales_invoice_charges_amount_check check (amount >= 0),
  constraint sales_invoice_charges_pkey primary key (id),
  constraint sales_invoice_charges_invoice_id_fkey
    foreign key (invoice_id) references public.sales_invoices(id) on delete cascade,
  constraint sales_invoice_charges_parent_tenant_id_fkey
    foreign key (parent_tenant_id) references public.tenants(id) on delete cascade
);

alter sequence public.sales_invoice_charges_id_seq owned by public.sales_invoice_charges.id;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'sales_invoices_shop_order_id_fkey'
  ) then
    alter table public.sales_invoices
      add constraint sales_invoices_shop_order_id_fkey
      foreign key (shop_order_id) references public.shop_orders(id) on delete set null;
  end if;
end $$;

create index if not exists idx_sales_invoices_shop_order_id
  on public.sales_invoices using btree (shop_order_id);

create index if not exists idx_sales_invoice_charges_invoice_id
  on public.sales_invoice_charges using btree (invoice_id);

drop view if exists public.global_invoices;

create view public.global_invoices with (security_invoker = false) as
 select id,
    parent_tenant_id,
    parent_tenant_id as tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    retail_billing_mode,
    invoice_status,
    fulfillment_status,
    billing_profile_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    due_date,
    payment_status,
    total_amount,
    due_amount,
    paid_amount,
    written_off_amount,
    subtotal_amount,
    discount_amount,
    shipping_charge,
    wrapping_charge,
    print_charge,
    note,
    created_by,
    created_at,
    updated_at,
    cod_charge_amount,
    shop_order_id,
    charges_amount,
    channel_meta
   from public.sales_invoices;

drop view if exists public.global_invoice_items;

create view public.global_invoice_items with (security_invoker = false) as
 select id,
    parent_tenant_id as tenant_id,
    parent_tenant_id,
    invoice_id,
    global_stock_id,
    shipment_item_id,
    product_id,
    name_snapshot,
    barcode_snapshot,
    product_code_snapshot,
    quantity,
    unit_cost_price,
    sell_price_amount,
    line_discount_amount,
    line_total_amount,
    return_quantity,
    created_at,
    updated_at,
    assigned_child_tenant_id,
    line_meta
   from public.sales_invoice_items;

alter table public.sales_invoice_item_costs enable row level security;
alter table public.sales_invoice_charges enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'sales_invoice_item_costs' and policyname = 'sales_invoice_item_costs_all'
  ) then
    create policy sales_invoice_item_costs_all on public.sales_invoice_item_costs
      to authenticated
      using (exists (
        select 1 from public.sales_invoice_items sii
        where sii.id = sales_invoice_item_costs.invoice_item_id
      ))
      with check (exists (
        select 1 from public.sales_invoice_items sii
        where sii.id = sales_invoice_item_costs.invoice_item_id
      ));
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'sales_invoice_charges' and policyname = 'sales_invoice_charges_all'
  ) then
    create policy sales_invoice_charges_all on public.sales_invoice_charges
      to authenticated
      using (exists (
        select 1 from public.sales_invoices gi
        where gi.id = sales_invoice_charges.invoice_id
      ))
      with check (exists (
        select 1 from public.sales_invoices gi
        where gi.id = sales_invoice_charges.invoice_id
      ));
  end if;
end $$;

grant all on table public.sales_invoice_item_costs to authenticated;
grant all on table public.sales_invoice_item_costs to service_role;
grant all on table public.sales_invoice_charges to authenticated;
grant all on table public.sales_invoice_charges to service_role;
grant all on sequence public.sales_invoice_charges_id_seq to authenticated;
grant all on sequence public.sales_invoice_charges_id_seq to service_role;

grant references, trigger, truncate, maintain on table public.global_invoices to service_role;
grant references, trigger, truncate, maintain on table public.global_invoice_items to service_role;

commit;
