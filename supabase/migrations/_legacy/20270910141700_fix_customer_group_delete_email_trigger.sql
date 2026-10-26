-- Soft-delete updates billing_profiles.is_phone_unique, which re-fired admin-email
-- uniqueness even when email did not change. Skip unchanged email on UPDATE and
-- ignore soft-deleted groups in conflict lookup.

begin;

create or replace function public.find_customer_admin_email_conflict(
  p_tenant_id bigint,
  p_email text,
  p_exclude_billing_profile_id bigint default null,
  p_exclude_member_id bigint default null,
  p_exclude_customer_group_id bigint default null
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
  v_normalized_email text;
  v_group_name text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  v_normalized_email := nullif(lower(trim(coalesce(p_email, ''))), '');
  if v_normalized_email is null then
    return null;
  end if;

  select cg.name
  into v_group_name
  from public.billing_profiles bp
  join public.customer_groups cg on cg.id = bp.customer_group_id
  where bp.parent_tenant_id = v_books_id
    and cg.deleted_at is null
    and lower(trim(bp.email)) = v_normalized_email
    and bp.id <> coalesce(p_exclude_billing_profile_id, -1)
    and cg.id <> coalesce(p_exclude_customer_group_id, -1)
  order by cg.id asc
  limit 1;

  if v_group_name is not null then
    return v_group_name;
  end if;

  select cg.name
  into v_group_name
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cg.parent_tenant_id = v_books_id
    and cg.deleted_at is null
    and cgm.role = 'admin'::public.customer_group_role
    and lower(trim(cgm.email)) = v_normalized_email
    and cgm.id <> coalesce(p_exclude_member_id, -1)
    and cg.id <> coalesce(p_exclude_customer_group_id, -1)
  order by cg.id asc
  limit 1;

  return v_group_name;
end;
$$;

create or replace function public.enforce_billing_profile_admin_email_unique_per_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_normalized_email text;
  v_conflict_group_name text;
begin
  if tg_op = 'UPDATE'
     and lower(trim(coalesce(old.email, ''))) = lower(trim(coalesce(new.email, ''))) then
    return new;
  end if;

  v_normalized_email := nullif(lower(trim(coalesce(new.email, ''))), '');
  new.email := v_normalized_email;

  if v_normalized_email is null then
    return new;
  end if;

  v_conflict_group_name := public.find_customer_admin_email_conflict(
    coalesce(new.parent_tenant_id, new.tenant_id),
    v_normalized_email,
    new.id,
    null,
    new.customer_group_id
  );

  if v_conflict_group_name is not null then
    raise exception 'This email is already admin of group "%".', v_conflict_group_name;
  end if;

  return new;
end;
$$;

create or replace function public.trg_customer_groups_soft_delete_phone_unique()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    alter table public.billing_profiles disable trigger trg_billing_profiles_admin_email_unique_per_tenant;

    update public.billing_profiles
    set is_phone_unique = false
    where customer_group_id = new.id;

    alter table public.billing_profiles enable trigger trg_billing_profiles_admin_email_unique_per_tenant;
  elsif new.deleted_at is null and old.deleted_at is not null then
    alter table public.billing_profiles disable trigger trg_billing_profiles_admin_email_unique_per_tenant;

    update public.billing_profiles
    set is_phone_unique = true
    where customer_group_id = new.id;

    alter table public.billing_profiles enable trigger trg_billing_profiles_admin_email_unique_per_tenant;
  end if;
  return new;
end;
$$;

commit;
