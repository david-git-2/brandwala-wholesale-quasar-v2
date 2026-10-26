-- Migration: Edit Invoice Date and Auto-Update Name
-- Created: 2026-09-20T00:00:00Z

-- 1. Drop existing create_global_invoice signature
drop function if exists public.create_global_invoice(
  bigint, text, public.global_invoice_type, bigint, bigint, text, text, text, public.retail_billing_mode, date, text
) cascade;

-- 2. Re-create create_global_invoice with optional p_invoice_date
create or replace function public.create_global_invoice(
  p_tenant_id bigint,
  p_invoice_no text,
  p_invoice_type public.global_invoice_type,
  p_billing_profile_id bigint default null,
  p_recipient_profile_id bigint default null,
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_retail_billing_mode public.retail_billing_mode default null,
  p_due_date date default null,
  p_note text default null,
  p_invoice_date date default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
  v_rec_name text;
  v_rec_phone text;
  v_rec_address text;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_bill_name text;
  v_bill_phone text;
  v_bill_address text;
  v_collection_source public.collection_source_type;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  -- Authorization check
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

  -- Validate profile matching
  if p_billing_profile_id is not null then
    if not exists (
      select 1 from public.billing_profiles
      where id = p_billing_profile_id and tenant_id = p_tenant_id
    ) then
      raise exception 'billing profile must belong to the same tenant';
    end if;
  end if;

  if p_recipient_profile_id is not null then
    if not exists (
      select 1 from public.recipient_profiles
      where id = p_recipient_profile_id and tenant_id = p_tenant_id
    ) then
      raise exception 'recipient profile must belong to the same tenant';
    end if;
  end if;

  -- Resolve collection source and enforce business rules per invoice type
  if p_invoice_type = 'wholesale'::public.global_invoice_type then
    if p_billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for wholesale invoices';
    end if;
    v_collection_source := 'billing_profile'::public.collection_source_type;

  elsif p_invoice_type = 'retail'::public.global_invoice_type then
    if p_retail_billing_mode is null then
      raise exception 'retail billing mode (account or direct) is required for retail invoices';
    end if;
    
    if p_retail_billing_mode = 'account'::public.retail_billing_mode then
      if p_billing_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
      v_collection_source := 'billing_profile'::public.collection_source_type;
    else
      if p_billing_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
      v_collection_source := 'recipient'::public.collection_source_type;
    end if;

  elsif p_invoice_type = 'dropship'::public.global_invoice_type then
    if p_billing_profile_id is null then
      raise exception 'billing profile (middle man) is required for dropship invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for dropship invoices';
    end if;
    v_collection_source := 'recipient'::public.collection_source_type;
  end if;

  -- Fetch recipient details from profile if provided
  if p_recipient_profile_id is not null then
    select name, phone, address
    into v_rec_name, v_rec_phone, v_rec_address
    from public.recipient_profiles
    where id = p_recipient_profile_id;
  end if;

  v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_rec_name);
  v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_rec_phone);
  v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_rec_address);

  -- For wholesale, fall back to billing profile address if recipient is still empty
  if p_invoice_type = 'wholesale'::public.global_invoice_type and p_billing_profile_id is not null then
    select name, phone, address
    into v_bill_name, v_bill_phone, v_bill_address
    from public.billing_profiles
    where id = p_billing_profile_id;
    
    v_recipient_name := coalesce(v_recipient_name, v_bill_name);
    v_recipient_phone := coalesce(v_recipient_phone, v_bill_phone);
    v_recipient_address := coalesce(v_recipient_address, v_bill_address);
  end if;

  -- Insert invoice header
  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
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
    note
  )
  values (
    p_tenant_id,
    v_parent_id,
    trim(p_invoice_no),
    p_invoice_type,
    coalesce(p_invoice_date, current_date),
    p_retail_billing_mode,
    'draft'::public.global_invoice_status,
    'pending'::public.global_fulfillment_status,
    p_billing_profile_id,
    p_recipient_profile_id,
    v_recipient_name,
    v_recipient_phone,
    v_recipient_address,
    v_collection_source,
    p_due_date,
    'due',
    nullif(trim(coalesce(p_note, '')), '')
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- Grant permissions for new signature
grant execute on function public.create_global_invoice(
  bigint, text, public.global_invoice_type, bigint, bigint, text, text, text, public.retail_billing_mode, date, text, date
) to authenticated;


-- 3. Drop existing update_global_invoice_header signature
drop function if exists public.update_global_invoice_header(
  bigint, numeric, numeric, numeric, numeric, numeric, text, text, text, text
) cascade;

-- 4. Re-create update_global_invoice_header with p_invoice_no and p_invoice_date
create or replace function public.update_global_invoice_header(
  p_invoice_id bigint,
  p_discount_amount numeric default null,
  p_shipping_charge numeric default null,
  p_cod_charge numeric default null,
  p_wrapping_charge numeric default null,
  p_print_charge numeric default null,
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_note text default null,
  p_invoice_no text default null,
  p_invoice_date date default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot update header of a non-draft invoice';
  end if;

  update public.global_invoices
  set
    discount_amount = coalesce(p_discount_amount, discount_amount),
    shipping_charge = coalesce(p_shipping_charge, shipping_charge),
    cod_charge = coalesce(p_cod_charge, cod_charge),
    wrapping_charge = coalesce(p_wrapping_charge, wrapping_charge),
    print_charge = coalesce(p_print_charge, print_charge),
    recipient_name = coalesce(nullif(trim(p_recipient_name), ''), recipient_name),
    recipient_phone = coalesce(nullif(trim(p_recipient_phone), ''), recipient_phone),
    recipient_address = coalesce(nullif(trim(p_recipient_address), ''), recipient_address),
    note = coalesce(nullif(trim(p_note), ''), note),
    invoice_no = coalesce(nullif(trim(p_invoice_no), ''), invoice_no),
    invoice_date = coalesce(p_invoice_date, invoice_date)
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);
end;
$$;

-- Grant permissions for new signature
grant execute on function public.update_global_invoice_header(
  bigint, numeric, numeric, numeric, numeric, numeric, text, text, text, text, text, date
) to authenticated;
