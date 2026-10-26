-- Step 1: billing_profile on global_invoices, wholesale rules, dropship enum
begin;

-- Extend invoice type enum
alter type public.global_invoice_type add value if not exists 'dropship';

-- Header columns
alter table public.global_invoices
  add column if not exists billing_profile_id bigint null references public.billing_profiles(id) on delete restrict,
  add column if not exists recipient_name text null,
  add column if not exists recipient_phone text null,
  add column if not exists recipient_address text null;

create index if not exists global_invoices_billing_profile_id_idx
  on public.global_invoices (billing_profile_id);

-- Block charge lines on wholesale invoices
create or replace function public.trg_invoice_charge_lines_block_wholesale()
returns trigger
language plpgsql
as $$
declare
  v_type public.global_invoice_type;
begin
  select invoice_type into v_type
  from public.global_invoices
  where id = coalesce(new.invoice_id, old.invoice_id);

  if v_type = 'wholesale' then
    raise exception 'Wholesale invoices cannot have charge lines.';
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_invoice_charge_lines_block_wholesale on public.invoice_charge_lines;
create trigger trg_invoice_charge_lines_block_wholesale
before insert or update on public.invoice_charge_lines
for each row execute function public.trg_invoice_charge_lines_block_wholesale();

-- Replace create_global_invoice (new signature with billing profile)
drop function if exists public.create_global_invoice(
  bigint, text, public.global_invoice_type, public.global_source_module, bigint, bigint, bigint, text
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

  if v_invoice_type not in ('wholesale', 'retail', 'dropship') then
    raise exception 'Invalid invoice type: %', v_invoice_type;
  end if;

  -- Step 1: only wholesale is fully supported at creation; retail/dropship ship in later steps
  if v_invoice_type <> 'wholesale' then
    raise exception 'Only wholesale invoices can be created in this release step.';
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

  -- Wholesale: recipient = billing profile
  v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_profile.name);
  v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_profile.phone);
  v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_profile.address);

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
