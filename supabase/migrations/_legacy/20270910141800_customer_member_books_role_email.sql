-- Groups live on the books parent. Shop roles may still belong to a child
-- tenant in the same family. Allow that match so member insert/update works.
-- Phone is the company key: email may repeat across groups, unique inside one group.

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
begin
  -- Phone is the company key. Email is unique per group only.
  return null;
end;
$$;

create or replace function public.enforce_customer_group_member_email_rules()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_normalized_email text;
begin
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

  return new;
end;
$$;

create or replace function public.enforce_billing_profile_admin_email_unique_per_tenant()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.email := nullif(lower(trim(coalesce(new.email, ''))), '');
  return new;
end;
$$;

create or replace function public.trg_fn_cgm_permission_guardrails()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role_scope text;
  v_role_books bigint;
  v_cg_books bigint;
begin
  if new.tenant_role_id is not null then
    select tr.scope, public.resolve_parent_tenant_id(tr.tenant_id)
    into v_role_scope, v_role_books
    from public.tenant_roles tr
    where tr.id = new.tenant_role_id;

    select coalesce(cg.parent_tenant_id, public.resolve_parent_tenant_id(cg.tenant_id))
    into v_cg_books
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_role_books is distinct from v_cg_books then
      raise exception 'Cross-tenant role assignment is not allowed';
    end if;

    if v_role_scope is distinct from 'shop' then
      raise exception 'Scope mismatch: customer group member cannot be assigned a % scoped role', v_role_scope;
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.assign_customer_group_member_role(
  p_cgm_id bigint,
  p_tenant_role_id bigint
)
returns public.customer_group_members
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member public.customer_group_members;
  v_group public.customer_groups;
  v_role public.tenant_roles;
  v_books_id bigint;
begin
  select * into v_member from public.customer_group_members where id = p_cgm_id;
  if v_member.id is null then
    raise exception 'Customer group member not found';
  end if;

  select * into v_group from public.customer_groups where id = v_member.customer_group_id;
  if v_group.id is null then
    raise exception 'Customer group not found';
  end if;

  v_books_id := coalesce(v_group.parent_tenant_id, public.resolve_parent_tenant_id(v_group.tenant_id));

  if not public.user_is_tenant_admin(v_books_id) then
    raise exception 'Unauthorized';
  end if;

  select * into v_role from public.tenant_roles where id = p_tenant_role_id;
  if v_role.id is null then
    raise exception 'Role not found';
  end if;

  if public.resolve_parent_tenant_id(v_role.tenant_id) is distinct from v_books_id then
    raise exception 'Role and Customer group member must belong to the same tenant';
  end if;

  if v_role.scope <> 'shop' then
    raise exception 'Role scope must be shop for customer group members';
  end if;

  update public.customer_group_members
  set
    tenant_role_id = p_tenant_role_id,
    updated_at = now()
  where id = p_cgm_id
  returning * into v_member;

  return v_member;
end;
$$;

create or replace function public.trg_fn_assign_default_customer_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_role_slug text;
  v_role_id bigint;
begin
  if new.tenant_role_id is null and new.customer_group_id is not null and new.role is not null then
    select coalesce(parent_tenant_id, tenant_id)
    into v_tenant_id
    from public.customer_groups
    where id = new.customer_group_id;

    if v_tenant_id is not null then
      v_role_slug := case new.role
        when 'admin' then 'customer-admin'
        when 'manager' then 'manager'
        when 'staff' then 'customer-staff'
        else 'customer-staff'
      end;

      select id into v_role_id
      from public.tenant_roles
      where tenant_id = v_tenant_id
        and scope = 'shop'
        and slug = v_role_slug;

      new.tenant_role_id := v_role_id;
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.trg_fn_sync_cgm_tenant_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_target_slug text;
  v_role_id bigint;
  v_role_books bigint;
  v_cg_books bigint;
begin
  if new.tenant_role_id is not null then
    select public.resolve_parent_tenant_id(tr.tenant_id)
    into v_role_books
    from public.tenant_roles tr
    where tr.id = new.tenant_role_id;

    select coalesce(cg.parent_tenant_id, public.resolve_parent_tenant_id(cg.tenant_id))
    into v_cg_books
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_role_books is not distinct from v_cg_books
       and not (tg_op = 'UPDATE' and old.role is distinct from new.role) then
      return new;
    end if;
  end if;

  if new.tenant_role_id is null or (tg_op = 'UPDATE' and old.role is distinct from new.role) then
    select coalesce(cg.parent_tenant_id, cg.tenant_id)
    into v_tenant_id
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_tenant_id is not null then
      v_target_slug := case new.role
        when 'admin' then 'customer-admin'
        when 'manager' then 'manager'
        when 'staff' then 'customer-staff'
        else 'customer-staff'
      end;

      select tr.id into v_role_id
      from public.tenant_roles tr
      where tr.tenant_id = v_tenant_id
        and tr.scope = 'shop'
        and (tr.slug = v_target_slug or (new.role = 'admin' and tr.is_admin = true))
      order by tr.is_admin desc, tr.id asc
      limit 1;

      if v_role_id is not null then
        new.tenant_role_id := v_role_id;
      end if;
    end if;
  end if;

  return new;
end;
$$;

commit;
