-- Step 2: retail invoices, charge totals recompute
begin;

create or replace function public.recompute_global_invoice_totals(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subtotal numeric(12,2) := 0;
  v_charges numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_paid numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
begin
  select coalesce(sum(line_total_amount), 0)
  into v_subtotal
  from public.global_invoice_items
  where invoice_id = p_invoice_id;

  select coalesce(sum(amount), 0)
  into v_charges
  from public.invoice_charge_lines
  where invoice_id = p_invoice_id;

  select coalesce(discount_amount, 0), coalesce(paid_amount, 0)
  into v_discount, v_paid
  from public.global_invoices
  where id = p_invoice_id;

  v_total := greatest(v_subtotal + v_charges - v_discount, 0);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    total_amount = v_total,
    due_amount = greatest(v_total - v_paid, 0),
    updated_at = now()
  where id = p_invoice_id;
end;
$$;

grant execute on function public.recompute_global_invoice_totals(bigint) to authenticated;

create or replace function public.upsert_invoice_charge_line(
  p_invoice_id bigint,
  p_charge_type public.invoice_charge_type,
  p_amount numeric,
  p_note text default null
)
returns public.invoice_charge_lines
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_row public.invoice_charge_lines;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;

  if v_invoice.invoice_type = 'wholesale' then
    raise exception 'Wholesale invoices cannot have charge lines.';
  end if;

  insert into public.invoice_charge_lines (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    charge_type,
    amount,
    note
  )
  values (
    v_invoice.tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_charge_type,
    greatest(coalesce(p_amount, 0), 0),
    nullif(trim(coalesce(p_note, '')), '')
  )
  on conflict do nothing
  returning * into v_row;

  if v_row.id is null then
    update public.invoice_charge_lines
    set amount = greatest(coalesce(p_amount, 0), 0),
        note = nullif(trim(coalesce(p_note, '')), '')
    where invoice_id = p_invoice_id and charge_type = p_charge_type
    returning * into v_row;
  end if;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

-- Update add_global_invoice_item to use recompute
create or replace function public.add_global_invoice_item(
  p_invoice_id bigint,
  p_global_stock_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_line_discount_amount numeric default 0
)
returns public.global_invoice_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_stock public.global_stocks;
  v_row public.global_invoice_items;
  v_line_total numeric(12,2);
  v_status public.global_stock_status := 'excellent';
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;

  select * into v_stock from public.global_stocks where id = p_global_stock_id;
  if v_stock.id is null then raise exception 'stock not found'; end if;

  if v_stock.parent_tenant_id <> v_invoice.parent_tenant_id then
    raise exception 'stock does not belong to invoice parent tenant';
  end if;

  v_line_total := greatest((p_quantity * p_sell_price_amount) - coalesce(p_line_discount_amount, 0), 0);

  insert into public.global_invoice_items (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    global_stock_id,
    product_id,
    name_snapshot,
    barcode_snapshot,
    product_code_snapshot,
    quantity,
    cost_amount,
    sell_price_amount,
    line_discount_amount,
    line_total_amount
  )
  values (
    v_invoice.tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_global_stock_id,
    v_stock.product_id,
    v_stock.name,
    v_stock.barcode,
    v_stock.product_code,
    p_quantity,
    v_stock.cost,
    p_sell_price_amount,
    coalesce(p_line_discount_amount, 0),
    v_line_total
  )
  returning * into v_row;

  update public.global_stock_quantities
  set quantity = greatest(quantity - ceil(p_quantity)::integer, 0)
  where stock_id = p_global_stock_id and status = v_status;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

drop function if exists public.create_global_invoice(
  bigint, text, bigint, public.global_invoice_type, public.global_source_module,
  text, text, text, bigint, text
);

create or replace function public.create_global_invoice(
  p_tenant_id bigint,
  p_invoice_no text,
  p_billing_profile_id bigint,
  p_invoice_type public.global_invoice_type default 'wholesale',
  p_source_module public.global_source_module default 'wholesale',
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_recipient_party_id bigint default null,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
  v_profile public.billing_profiles;
  v_invoice_type public.global_invoice_type;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
begin
  if p_billing_profile_id is null then
    raise exception 'Billing profile is required.';
  end if;

  v_invoice_type := coalesce(p_invoice_type, 'wholesale');

  if v_invoice_type not in ('wholesale', 'retail') then
    raise exception 'Only wholesale and retail invoices are supported in this step.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'not allowed';
  end if;

  select * into v_profile
  from public.billing_profiles
  where id = p_billing_profile_id;

  if v_profile.id is null then
    raise exception 'Billing profile not found.';
  end if;

  if v_profile.tenant_id <> p_tenant_id then
    raise exception 'Billing profile does not belong to issuing tenant.';
  end if;

  if v_invoice_type = 'wholesale' then
    v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_profile.name);
    v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_profile.phone);
    v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_profile.address);
  else
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then
      raise exception 'Recipient name is required for retail invoices.';
    end if;
  end if;

  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
    invoice_no,
    invoice_type,
    source_module,
    billing_profile_id,
    customer_group_id,
    recipient_party_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    sold_in_tenant_id,
    note,
    due_amount
  )
  values (
    p_tenant_id,
    v_parent_id,
    trim(p_invoice_no),
    v_invoice_type,
    coalesce(p_source_module, 'wholesale'),
    p_billing_profile_id,
    v_profile.customer_group_id,
    p_recipient_party_id,
    v_recipient_name,
    v_recipient_phone,
    v_recipient_address,
    p_tenant_id,
    nullif(trim(coalesce(p_note, '')), ''),
    0
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_global_invoice(
  bigint, text, bigint, public.global_invoice_type, public.global_source_module,
  text, text, text, bigint, text
) to authenticated;

commit;
