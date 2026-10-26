-- Roll back the two 20260617 Supabase access changes.

drop policy if exists "customer_groups_select_customer_member"
on public.customer_groups;

drop policy if exists "customer_group_members_select_self"
on public.customer_group_members;

create or replace function public.check_shop_login_access(
  p_email text,
  p_tenant_id bigint default null
)
returns table(
  has_match boolean,
  matched_role public.customer_group_role,
  member_id bigint,
  member_name text,
  member_email text,
  member_tenant_id bigint,
  customer_group_id bigint,
  customer_group_name text,
  member_is_active boolean,
  customer_group_is_active boolean,
  member_created_at timestamptz,
  member_updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  select
    cgm.role,
    cgm.id,
    cgm.name,
    lower(trim(cgm.email)),
    cg.tenant_id,
    cg.id,
    cg.name,
    cgm.is_active,
    cg.is_active,
    cgm.created_at,
    cgm.updated_at
  into
    matched_role,
    member_id,
    member_name,
    member_email,
    member_tenant_id,
    customer_group_id,
    customer_group_name,
    member_is_active,
    customer_group_is_active,
    member_created_at,
    member_updated_at
  from public.customer_group_members cgm
  inner join public.customer_groups cg
    on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and (p_tenant_id is null or cg.tenant_id = p_tenant_id)
  order by
    cg.tenant_id asc,
    cg.id asc,
    case cgm.role
      when 'admin' then 1
      when 'negotiator' then 2
      when 'staff' then 3
      else 99
    end asc,
    cgm.id asc
  limit 1;

  has_match := member_id is not null;
  return next;
end;
$$;

grant execute on function public.check_shop_login_access(text, bigint)
to authenticated;

drop function if exists public.resolve_tenant_for_entry(text, text);

create function public.resolve_tenant_for_entry(
  p_slug text default null,
  p_hostname text default null
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text
)
language sql
security definer
set search_path = public
stable
as $$
  with domain_match as (
    select *
    from public.find_active_tenant_by_public_domain(p_hostname)
  ),
  slug_match as (
    select *
    from public.find_active_tenant_by_slug(p_slug)
  )
  select *
  from domain_match
  union all
  select *
  from slug_match
  where not exists (select 1 from domain_match)
  limit 1;
$$;

grant execute on function public.resolve_tenant_for_entry(text, text)
to anon, authenticated;
