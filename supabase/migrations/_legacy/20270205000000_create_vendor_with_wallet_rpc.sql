-- Create RPC: create_vendor_with_wallet
-- Description: Atomically creates a vendor and provisions its wallet_accounts ledger entry in a single transaction.

drop function if exists public.create_vendor_with_wallet(bigint, text, text, text, bigint, text, text, text, text);
drop function if exists public.create_vendor_with_wallet(bigint, text, text, text, text, text, text, text);

create or replace function public.create_vendor_with_wallet(
  p_tenant_id bigint,
  p_name text,
  p_code text,
  p_market_code text,
  p_email text default null,
  p_phone text default null,
  p_address text default null,
  p_website text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vendor public.vendors;
  v_wallet public.wallet_accounts;
  v_currency_code text := 'BDT';
begin
  -- 1. Permission checks
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;
  else
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    end if;
  end if;

  -- 2. Insert vendor record
  insert into public.vendors (
    tenant_id,
    name,
    code,
    market_code,
    email,
    phone,
    address,
    website
  )
  values (
    p_tenant_id,
    trim(p_name),
    upper(trim(p_code)),
    upper(trim(p_market_code)),
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_website), '')
  )
  returning * into v_vendor;

  -- 3. Create or fetch wallet_accounts anchor for vendor (Default BDT)
  insert into public.wallet_accounts (
    tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    'vendor',
    v_vendor.id,
    v_currency_code,
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  -- 4. Return JSON payload matching documentation specification
  return jsonb_build_object(
    'vendor', to_jsonb(v_vendor),
    'wallet', to_jsonb(v_wallet)
  );
end;
$$;

-- Grant execution permission to authenticated users
grant execute on function public.create_vendor_with_wallet to authenticated;
grant execute on function public.create_vendor_with_wallet to service_role;
