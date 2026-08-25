-- Customer admin email: unique per tenant (billing profile + admin members).
-- Per group: all member emails unique. Staff/manager may repeat across groups.

begin;

-- Fail if duplicate billing profile admin emails already exist in a tenant.
do $$
declare
  v_duplicate_count integer;
begin
  select count(*)::integer
  into v_duplicate_count
  from (
    select bp.tenant_id, lower(trim(bp.email)) as normalized_email
    from public.billing_profiles bp
    where bp.email is not null
      and trim(bp.email) <> ''
    group by bp.tenant_id, lower(trim(bp.email))
    having count(*) > 1
  ) duplicates;

  if v_duplicate_count > 0 then
    raise exception
      'Cannot apply migration: % duplicate billing profile admin email(s) per tenant. Clean up billing_profiles before retrying.',
      v_duplicate_count;
  end if;
end;
$$;

create or replace function public.find_customer_admin_email_conflict(
  p_tenant_id bigint,
  p_email text,
  p_exclude_billing_profile_id bigint default null,
  p_exclude_member_id bigint default null
)
returns text
language plpgsql
stable
set search_path = public
as $$
declare
  v_normalized_email text;
  v_group_name text;
begin
  v_normalized_email := nullif(lower(trim(coalesce(p_email, ''))), '');
  if v_normalized_email is null then
    return null;
  end if;

  select cg.name
  into v_group_name
  from public.billing_profiles bp
  join public.customer_groups cg on cg.id = bp.customer_group_id
  where bp.tenant_id = p_tenant_id
    and lower(trim(bp.email)) = v_normalized_email
    and bp.id <> coalesce(p_exclude_billing_profile_id, -1)
  order by cg.id asc
  limit 1;

  if v_group_name is not null then
    return v_group_name;
  end if;

  select cg.name
  into v_group_name
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cg.tenant_id = p_tenant_id
    and cgm.role = 'admin'::public.customer_group_role
    and lower(trim(cgm.email)) = v_normalized_email
    and cgm.id <> coalesce(p_exclude_member_id, -1)
  order by cg.id asc
  limit 1;

  return v_group_name;
end;
$$;

create or replace function public.enforce_customer_group_member_email_rules()
returns trigger
language plpgsql
as $$
declare
  v_tenant_id bigint;
  v_normalized_email text;
  v_conflict_group_name text;
begin
  select cg.tenant_id
  into v_tenant_id
  from public.customer_groups cg
  where cg.id = new.customer_group_id;

  if v_tenant_id is null then
    raise exception 'customer group tenant could not be resolved';
  end if;

  v_normalized_email := lower(trim(new.email));
  new.email := v_normalized_email;

  if exists (
    select 1
    from public.customer_group_members cgm
    where cgm.customer_group_id = new.customer_group_id
      and lower(trim(cgm.email)) = v_normalized_email
      and cgm.id <> coalesce(new.id, -1)
  ) then
    raise exception 'This email is already used in this group';
  end if;

  if new.role = 'admin'::public.customer_group_role then
    v_conflict_group_name := public.find_customer_admin_email_conflict(
      v_tenant_id,
      v_normalized_email,
      null,
      new.id
    );

    if v_conflict_group_name is not null then
      raise exception 'This email is already admin of group "%".', v_conflict_group_name;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_customer_group_members_email_unique_per_tenant
  on public.customer_group_members;

create trigger trg_customer_group_members_email_rules
before insert or update on public.customer_group_members
for each row
execute function public.enforce_customer_group_member_email_rules();

drop function if exists public.enforce_customer_group_member_email_unique_per_tenant();

create or replace function public.enforce_billing_profile_admin_email_unique_per_tenant()
returns trigger
language plpgsql
as $$
declare
  v_normalized_email text;
  v_conflict_group_name text;
begin
  v_normalized_email := nullif(lower(trim(coalesce(new.email, ''))), '');
  new.email := v_normalized_email;

  if v_normalized_email is null then
    return new;
  end if;

  v_conflict_group_name := public.find_customer_admin_email_conflict(
    new.tenant_id,
    v_normalized_email,
    new.id,
    null
  );

  if v_conflict_group_name is not null then
    raise exception 'This email is already admin of group "%".', v_conflict_group_name;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_billing_profiles_admin_email_unique_per_tenant
  on public.billing_profiles;

create trigger trg_billing_profiles_admin_email_unique_per_tenant
before insert or update on public.billing_profiles
for each row
execute function public.enforce_billing_profile_admin_email_unique_per_tenant();

commit;
