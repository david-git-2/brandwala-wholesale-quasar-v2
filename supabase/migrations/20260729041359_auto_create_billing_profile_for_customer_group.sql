-- Migration: Auto-create Billing Profile for Customer Groups & Harden Billing Profile Resolution

-- 1. Trigger function to auto-create a billing profile whenever a customer group is inserted
create or replace function public.trg_auto_create_billing_profile_for_customer_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.billing_profiles
    where tenant_id = new.tenant_id
      and customer_group_id = new.id
  ) then
    insert into public.billing_profiles (
      tenant_id,
      customer_group_id,
      name,
      phone,
      created_at,
      updated_at
    )
    values (
      new.tenant_id,
      new.id,
      new.name,
      null,
      now(),
      now()
    );
  end if;
  return new;
end;
$$;

-- 2. Attach trigger to customer_groups table
drop trigger if exists trg_customer_groups_auto_billing_profile on public.customer_groups;
create trigger trg_customer_groups_auto_billing_profile
after insert on public.customer_groups
for each row
execute function public.trg_auto_create_billing_profile_for_customer_group();

-- 3. Backfill missing billing profiles for existing customer groups
insert into public.billing_profiles (
  tenant_id,
  customer_group_id,
  name,
  created_at,
  updated_at
)
select
  cg.tenant_id,
  cg.id,
  cg.name,
  now(),
  now()
from public.customer_groups cg
left join public.billing_profiles bp
  on bp.tenant_id = cg.tenant_id
 and bp.customer_group_id = cg.id
where bp.id is null;

-- 4. Harden resolve_billing_profile_for_customer_group helper function
-- Fallbacks: 1) customer_group_id match, 2) default billing profile for tenant, 3) any first billing profile for tenant
create or replace function public.resolve_billing_profile_for_customer_group(
  p_tenant_id bigint,
  p_customer_group_id bigint
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_billing_profile_id bigint;
begin
  -- 1) Direct match on customer_group_id
  if p_customer_group_id is not null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = p_tenant_id
      and customer_group_id = p_customer_group_id
    order by id asc
    limit 1;
  end if;

  -- 2) Fallback to default billing profile for tenant
  if v_billing_profile_id is null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = p_tenant_id
      and is_default = true
    order by id asc
    limit 1;
  end if;

  -- 3) Ultimate fallback: any billing profile for tenant
  if v_billing_profile_id is null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = p_tenant_id
    order by created_at asc, id asc
    limit 1;
  end if;

  return v_billing_profile_id;
end;
$$;

grant execute on function public.resolve_billing_profile_for_customer_group(bigint, bigint) to authenticated;

-- 5. Backfill any existing shop_orders that have NULL billing_profile_id
update public.shop_orders so
set billing_profile_id = public.resolve_billing_profile_for_customer_group(so.tenant_id, so.customer_group_id)
where so.billing_profile_id is null;
