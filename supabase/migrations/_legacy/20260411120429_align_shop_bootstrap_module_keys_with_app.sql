drop function if exists public.get_shop_bootstrap_context(text, bigint, bigint);

create or replace function public.get_shop_bootstrap_context(
  p_email text default null,
  p_tenant_id bigint default null,
  p_customer_group_member_id bigint default null
)
returns table(
  member_id bigint,
  member_name text,
  member_email text,
  member_role public.customer_group_role,
  member_is_active boolean,
  customer_group_id bigint,
  customer_group_name text,
  customer_group_is_active boolean,
  customer_group_accent_color text,
  tenant_id bigint,
  tenant_name text,
  tenant_slug text,
  tenant_is_active boolean,
  active_module_keys text[]
)
language sql
security definer
set search_path = public
stable
as $$
  with matched_member as (
    select
      cgm.id,
      cgm.name,
      lower(trim(cgm.email)) as email,
      cgm.role,
      cgm.is_active,
      cg.id as customer_group_id,
      cg.name as customer_group_name,
      cg.is_active as customer_group_is_active,
      cg.accent_color as customer_group_accent_color,
      t.id as tenant_id,
      t.name as tenant_name,
      t.slug as tenant_slug,
      t.is_active as tenant_is_active
    from public.customer_group_members cgm
    inner join public.customer_groups cg
      on cg.id = cgm.customer_group_id
    inner join public.tenants t
      on t.id = cg.tenant_id
    where p_tenant_id is not null
      and lower(trim(cgm.email)) = lower(trim(coalesce(p_email, public.current_user_email())))
      and cgm.is_active = true
      and cg.is_active = true
      and t.is_active = true
      and cg.tenant_id = p_tenant_id
      and (p_customer_group_member_id is null or cgm.id = p_customer_group_member_id)
    order by
      case cgm.role
        when 'admin' then 1
        when 'negotiator' then 2
        when 'staff' then 3
        else 99
      end,
      cgm.id asc
    limit 1
  ),
  module_keys as (
    select
      tm.tenant_id,
      coalesce(
        array_agg(tm.module_key order by tm.module_key)
          filter (where tm.module_key is not null),
        '{}'::text[]
      ) as active_module_keys
    from public.tenant_modules tm
    inner join public.modules mo
      on mo.key = tm.module_key
    where tm.is_active = true
      and mo.is_active = true
    group by tm.tenant_id
  )
  select
    mm.id as member_id,
    mm.name as member_name,
    mm.email as member_email,
    mm.role as member_role,
    mm.is_active as member_is_active,
    mm.customer_group_id,
    mm.customer_group_name,
    mm.customer_group_is_active,
    mm.customer_group_accent_color,
    mm.tenant_id,
    mm.tenant_name,
    mm.tenant_slug,
    mm.tenant_is_active,
    coalesce(mk.active_module_keys, '{}'::text[]) as active_module_keys
  from matched_member mm
  left join module_keys mk
    on mk.tenant_id = mm.tenant_id;
$$;

grant execute on function public.get_shop_bootstrap_context(text, bigint, bigint)
to authenticated;
