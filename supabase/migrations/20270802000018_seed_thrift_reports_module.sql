-- =========================================================
-- Seed thrift_reports module (view only) + sales report RPC
-- =========================================================

begin;

-- 1. Module catalog
insert into public.modules (key, name, description, is_active)
values (
  'thrift_reports',
  'Thrift Reports',
  'Shipment sales and profit reports for thrift inventory.',
  true
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('thrift_reports', 'view', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'thrift_reports', 'view', true),
  ('app', 'manager', 'thrift_reports', 'view', true),
  ('app', 'cashier', 'thrift_reports', 'view', true),
  ('app', 'viewer', 'thrift_reports', 'view', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Enable for tenants that already have thrift_stock
insert into public.tenant_modules (tenant_id, module_key, is_active)
select tm.tenant_id, 'thrift_reports', true
from public.tenant_modules tm
where tm.module_key = 'thrift_stock'
  and tm.is_active = true
on conflict (tenant_id, module_key) do update set
  is_active = true;

-- Backfill role grants from templates (additive only)
select public.seed_tenant_roles_and_grants(id) from public.tenants;

-- 2. Shipment sales & profit report RPC
create or replace function public.get_thrift_shipment_sales_report(
  p_tenant_id bigint,
  p_shipment_id bigint
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_shipment jsonb;
  v_summary jsonb;
  v_lines jsonb;
  v_units_sold bigint := 0;
  v_gross_sales numeric(14, 2) := 0;
  v_discounts numeric(14, 2) := 0;
  v_net_revenue numeric(14, 2) := 0;
  v_cogs numeric(14, 2) := 0;
  v_net_profit numeric(14, 2) := 0;
  v_margin_pct numeric(8, 2) := 0;
begin
  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  select jsonb_build_object(
    'id', s.id,
    'name', s.name,
    'created_at', s.created_at,
    'updated_at', s.updated_at
  )
  into v_shipment
  from public.thrift_shipments s
  where s.id = p_shipment_id
    and s.tenant_id = p_tenant_id;

  if v_shipment is null then
    raise exception 'Shipment % not found for tenant %', p_shipment_id, p_tenant_id;
  end if;

  select
    coalesce(sum(i.quantity), 0),
    coalesce(sum(i.sell_price * i.quantity), 0),
    coalesce(sum(i.discount_amount * i.quantity), 0),
    coalesce(sum(i.final_price * i.quantity), 0),
    coalesce(sum(i.landed_unit_cost_at_sale * i.quantity), 0),
    coalesce(sum(i.net_profit), 0)
  into
    v_units_sold,
    v_gross_sales,
    v_discounts,
    v_net_revenue,
    v_cogs,
    v_net_profit
  from public.thrift_sales_invoice_items i
  inner join public.thrift_stocks st
    on st.id = i.stock_id
   and st.tenant_id = i.tenant_id
  inner join public.thrift_sales_invoices inv
    on inv.id = i.invoice_id
   and inv.tenant_id = i.tenant_id
  where i.tenant_id = p_tenant_id
    and st.shipment_id = p_shipment_id
    and coalesce(inv.status, 'ACTIVE') = 'ACTIVE';

  if v_net_revenue > 0 then
    v_margin_pct := round((v_net_profit / v_net_revenue) * 100, 2);
  else
    v_margin_pct := 0;
  end if;

  v_summary := jsonb_build_object(
    'units_sold', v_units_sold,
    'gross_sales', v_gross_sales,
    'discounts', v_discounts,
    'net_revenue', v_net_revenue,
    'cogs', v_cogs,
    'net_profit', v_net_profit,
    'margin_pct', v_margin_pct
  );

  select coalesce(jsonb_agg(row_to_json(r)::jsonb order by r.invoice_date desc, r.id), '[]'::jsonb)
  into v_lines
  from (
    select
      i.id,
      i.invoice_id,
      inv.invoice_number,
      inv.date as invoice_date,
      i.stock_id,
      st.name as stock_name,
      st.barcode,
      i.quantity,
      i.sell_price,
      i.discount_amount,
      i.final_price,
      i.landed_unit_cost_at_sale,
      i.net_profit
    from public.thrift_sales_invoice_items i
    inner join public.thrift_stocks st
      on st.id = i.stock_id
     and st.tenant_id = i.tenant_id
    inner join public.thrift_sales_invoices inv
      on inv.id = i.invoice_id
     and inv.tenant_id = i.tenant_id
    where i.tenant_id = p_tenant_id
      and st.shipment_id = p_shipment_id
      and coalesce(inv.status, 'ACTIVE') = 'ACTIVE'
  ) r;

  return jsonb_build_object(
    'shipment', v_shipment,
    'summary', v_summary,
    'lines', v_lines
  );
end;
$$;

grant execute on function public.get_thrift_shipment_sales_report(bigint, bigint) to authenticated;
grant execute on function public.get_thrift_shipment_sales_report(bigint, bigint) to service_role;

commit;
