begin;

-- =========================================================
-- 1. Create Performance Indexes for Read-Side Rollups
-- =========================================================
create index if not exists idx_global_invoices_scoping
  on public.global_invoices (parent_tenant_id, tenant_id, invoice_status, invoice_date);

create index if not exists idx_global_invoice_items_shipment
  on public.global_invoice_items (shipment_item_id);

create index if not exists idx_global_invoices_billing_profile
  on public.global_invoices (billing_profile_id);

-- =========================================================
-- 2. list_invoice_margin_report RPC
-- =========================================================
create or replace function public.list_invoice_margin_report(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_start_date date default null,
  p_end_date date default null,
  p_search text default null,
  p_invoice_type text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_parent_id bigint;
  v_is_parent boolean;
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_is_parent := public.is_parent_company(p_tenant_id);

  -- 1. Get total count of matching posted invoices
  select count(*)
  into v_total_count
  from public.global_invoices i
  where (
    (v_is_parent = true and i.parent_tenant_id = v_parent_id)
    or (v_is_parent = false and i.tenant_id = p_tenant_id)
  )
    and i.invoice_status = 'posted'::public.global_invoice_status
    and (p_start_date is null or i.invoice_date >= p_start_date)
    and (p_end_date is null or i.invoice_date <= p_end_date)
    and (p_invoice_type is null or p_invoice_type = '' or p_invoice_type = '__all__' or i.invoice_type::text = p_invoice_type)
    and (
      p_search is null or p_search = '' or (
        i.invoice_no ilike '%' || p_search || '%'
        or i.recipient_name ilike '%' || p_search || '%'
      )
    );

  -- 2. Get paginated records as a jsonb array with derived gross profit
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    with invoice_line_margin as (
      select
        invoice_id,
        sum((sell_price_amount - unit_cost_price) * quantity - line_discount_amount) as lines_margin
      from public.global_invoice_items
      group by invoice_id
    ),
    invoice_return_margin as (
      select
        ri.invoice_id,
        sum(ri.return_accounting_amount - (ii.unit_cost_price * ri.quantity)) as returns_margin
      from public.global_return_items ri
      join public.global_invoice_items ii on ii.id = ri.invoice_item_id
      group by ri.invoice_id
    )
    select
      i.*,
      coalesce(lm.lines_margin, 0.00) 
        - i.discount_amount 
        + (case 
             when i.invoice_type = 'wholesale' or i.invoice_type = 'dropship' then i.shipping_charge
             when i.invoice_type = 'retail' then i.shipping_charge + i.cod_charge + i.print_charge + i.wrapping_charge
             else 0.00 
           end)
        - coalesce(rm.returns_margin, 0.00) as gross_profit
    from public.global_invoices i
    left join invoice_line_margin lm on lm.invoice_id = i.id
    left join invoice_return_margin rm on rm.invoice_id = i.id
    where (
      (v_is_parent = true and i.parent_tenant_id = v_parent_id)
      or (v_is_parent = false and i.tenant_id = p_tenant_id)
    )
      and i.invoice_status = 'posted'::public.global_invoice_status
      and (p_start_date is null or i.invoice_date >= p_start_date)
      and (p_end_date is null or i.invoice_date <= p_end_date)
      and (p_invoice_type is null or p_invoice_type = '' or p_invoice_type = '__all__' or i.invoice_type::text = p_invoice_type)
      and (
        p_search is null or p_search = '' or (
          i.invoice_no ilike '%' || p_search || '%'
          or i.recipient_name ilike '%' || p_search || '%'
        )
      )
    order by i.invoice_date desc, i.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- 3. Calculate total pages
  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

grant execute on function public.list_invoice_margin_report(bigint, integer, integer, date, date, text, text) to authenticated;
grant execute on function public.list_invoice_margin_report(bigint, integer, integer, date, date, text, text) to anon;
grant execute on function public.list_invoice_margin_report(bigint, integer, integer, date, date, text, text) to service_role;

-- =========================================================
-- 3. get_invoice_margin_detail RPC
-- =========================================================
create or replace function public.get_invoice_margin_detail(
  p_invoice_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_invoice jsonb;
  v_lines jsonb;
  v_returns jsonb;
  v_gross_profit numeric(12,2);
begin
  -- 1. Get invoice details
  select row_to_json(i)::jsonb
  into v_invoice
  from public.global_invoices i
  where i.id = p_invoice_id;

  if v_invoice is null then
    raise exception 'invoice not found';
  end if;

  -- 2. Get line margins
  select coalesce(jsonb_agg(row_to_json(l)), '[]'::jsonb)
  into v_lines
  from (
    select
      ii.*,
      ((ii.sell_price_amount - ii.unit_cost_price) * ii.quantity - ii.line_discount_amount) as line_margin
    from public.global_invoice_items ii
    where ii.invoice_id = p_invoice_id
  ) l;

  -- 3. Get return margins
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_returns
  from (
    select
      ri.*,
      (ri.return_accounting_amount - (ii.unit_cost_price * ri.quantity)) as return_margin
    from public.global_return_items ri
    join public.global_invoice_items ii on ii.id = ri.invoice_item_id
    where ri.invoice_id = p_invoice_id
  ) r;

  -- 4. Calculate total gross profit
  declare
    v_lines_margin numeric(12,2) := 0;
    v_returns_margin numeric(12,2) := 0;
    v_discount numeric(12,2);
    v_charges numeric(12,2);
  begin
    select coalesce(sum((sell_price_amount - unit_cost_price) * quantity - line_discount_amount), 0)
    into v_lines_margin
    from public.global_invoice_items
    where invoice_id = p_invoice_id;

    select coalesce(sum(ri.return_accounting_amount - (ii.unit_cost_price * ri.quantity)), 0)
    into v_returns_margin
    from public.global_return_items ri
    join public.global_invoice_items ii on ii.id = ri.invoice_item_id
    where ri.invoice_id = p_invoice_id;

    select 
      coalesce(discount_amount, 0),
      case 
        when invoice_type = 'wholesale' or invoice_type = 'dropship' then shipping_charge
        when invoice_type = 'retail' then shipping_charge + cod_charge + print_charge + wrapping_charge
        else 0.00 
      end
    into v_discount, v_charges
    from public.global_invoices
    where id = p_invoice_id;

    v_gross_profit := v_lines_margin - v_discount + v_charges - v_returns_margin;
  end;

  return jsonb_build_object(
    'invoice', v_invoice,
    'lines', v_lines,
    'returns', v_returns,
    'gross_profit', v_gross_profit
  );
end;
$$;

grant execute on function public.get_invoice_margin_detail(bigint) to authenticated;
grant execute on function public.get_invoice_margin_detail(bigint) to anon;
grant execute on function public.get_invoice_margin_detail(bigint) to service_role;

-- =========================================================
-- 4. get_shipment_pnl RPC
-- =========================================================
create or replace function public.get_shipment_pnl(
  p_tenant_id bigint,
  p_shipment_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_shipment jsonb;
  v_items jsonb;
  v_total_landed_cost numeric(12,2) := 0;
  v_total_sold_cost numeric(12,2) := 0;
  v_total_revenue numeric(12,2) := 0;
  v_total_gross_profit numeric(12,2) := 0;
  v_total_unsold_value numeric(12,2) := 0;
begin
  -- Resolve parent tenant to enforce access
  if public.resolve_parent_tenant_id(p_tenant_id) <> (select parent_tenant_id from public.global_shipments where id = p_shipment_id) then
    raise exception 'unauthorized tenant access to shipment';
  end if;

  -- 1. Get shipment header
  select row_to_json(s)::jsonb
  into v_shipment
  from public.global_shipments s
  where s.id = p_shipment_id;

  -- 2. Get shipment items details with on-the-fly margins
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_items
  from (
    select
      si.*,
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty,
      coalesce(sum(ii.unit_cost_price * (ii.quantity - ii.return_quantity)), 0) as sold_cost,
      coalesce(sum(ii.sell_price_amount * ii.quantity - coalesce((
        select sum(ri.return_accounting_amount)
        from public.global_return_items ri
        where ri.invoice_item_id = ii.id
      ), 0.00)), 0) as revenue
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.global_invoices inv on inv.id = ii.invoice_id and inv.invoice_status = 'posted'::public.global_invoice_status
    where si.shipment_id = p_shipment_id
    group by si.id
  ) r;

  -- 3. Sum total metrics
  select
    coalesce(sum(landed_unit_cost * received_qty), 0),
    coalesce(sum(sold_cost), 0),
    coalesce(sum(revenue), 0),
    coalesce(sum((received_qty - sold_qty) * landed_unit_cost), 0)
  into
    v_total_landed_cost,
    v_total_sold_cost,
    v_total_revenue,
    v_total_unsold_value
  from (
    select
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      si.ordered_quantity as received_qty,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty,
      coalesce(sum(ii.unit_cost_price * (ii.quantity - ii.return_quantity)), 0) as sold_cost,
      coalesce(sum(ii.sell_price_amount * ii.quantity - coalesce((
        select sum(ri.return_accounting_amount)
        from public.global_return_items ri
        where ri.invoice_item_id = ii.id
      ), 0.00)), 0) as revenue
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.global_invoices inv on inv.id = ii.invoice_id and inv.invoice_status = 'posted'::public.global_invoice_status
    where si.shipment_id = p_shipment_id
    group by si.id
  ) rollup;

  v_total_gross_profit := v_total_revenue - v_total_sold_cost;

  return jsonb_build_object(
    'shipment', v_shipment,
    'items', v_items,
    'totals', jsonb_build_object(
      'landed_cost', v_total_landed_cost,
      'sold_cost', v_total_sold_cost,
      'revenue', v_total_revenue,
      'gross_profit', v_total_gross_profit,
      'unsold_value', v_total_unsold_value
    )
  );
end;
$$;

grant execute on function public.get_shipment_pnl(bigint, bigint) to authenticated;
grant execute on function public.get_shipment_pnl(bigint, bigint) to anon;
grant execute on function public.get_shipment_pnl(bigint, bigint) to service_role;

-- =========================================================
-- 5. list_billing_balances RPC
-- =========================================================
create or replace function public.list_billing_balances(
  p_tenant_id bigint,
  p_search text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_data jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      bp.id,
      bp.name,
      bp.email,
      bp.phone,
      bp.color,
      coalesce(sum(i.due_amount), 0.00) as balance_due,
      coalesce(sum(i.total_amount), 0.00) as total_invoiced,
      coalesce(sum(i.paid_amount), 0.00) as total_paid
    from public.billing_profiles bp
    left join public.global_invoices i on i.billing_profile_id = bp.id and i.invoice_status = 'posted'::public.global_invoice_status
    where bp.tenant_id = p_tenant_id
      and (p_search is null or p_search = '' or bp.name ilike '%' || p_search || '%' or bp.email ilike '%' || p_search || '%')
    group by bp.id
    order by balance_due desc, bp.name asc
  ) r;

  return v_data;
end;
$$;

grant execute on function public.list_billing_balances(bigint, text) to authenticated;
grant execute on function public.list_billing_balances(bigint, text) to anon;
grant execute on function public.list_billing_balances(bigint, text) to service_role;

-- =========================================================
-- 6. list_invoice_outstanding RPC
-- =========================================================
create or replace function public.list_invoice_outstanding(
  p_tenant_id bigint,
  p_search text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_data jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      i.id,
      i.invoice_no,
      i.invoice_date,
      i.invoice_type,
      i.payment_status,
      i.total_amount,
      i.due_amount,
      i.paid_amount,
      i.recipient_name,
      i.recipient_phone,
      i.billing_profile_id,
      bp.name as billing_profile_name
    from public.global_invoices i
    left join public.billing_profiles bp on bp.id = i.billing_profile_id
    where i.tenant_id = p_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.due_amount > 0
      and (p_search is null or p_search = '' or i.invoice_no ilike '%' || p_search || '%' or i.recipient_name ilike '%' || p_search || '%')
    order by i.invoice_date desc, i.id desc
  ) r;

  return v_data;
end;
$$;

grant execute on function public.list_invoice_outstanding(bigint, text) to authenticated;
grant execute on function public.list_invoice_outstanding(bigint, text) to anon;
grant execute on function public.list_invoice_outstanding(bigint, text) to service_role;

commit;
