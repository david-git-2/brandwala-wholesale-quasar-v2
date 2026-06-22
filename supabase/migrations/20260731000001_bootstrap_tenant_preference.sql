begin;

drop function if exists public.get_app_bootstrap_context(text, bigint, bigint);

create or replace function public.get_app_bootstrap_context(
  p_email text default null,
  p_tenant_id bigint default null,
  p_membership_id bigint default null
)
returns table(
  member_id bigint,
  member_email text,
  member_role public.app_role,
  member_is_active boolean,
  tenant_id bigint,
  tenant_name text,
  tenant_slug text,
  tenant_is_active boolean,
  tenant_preference jsonb,
  active_module_keys text[]
)
language sql
security definer
set search_path = public
stable
as $$
  with matched_member as (
    select
      m.id,
      lower(trim(m.email)) as email,
      m.role,
      m.is_active,
      t.id as tenant_id,
      t.name as tenant_name,
      t.slug as tenant_slug,
      t.is_active as tenant_is_active,
      t.preference as tenant_preference
    from public.memberships m
    inner join public.tenants t
      on t.id = m.tenant_id
    where lower(trim(m.email)) = lower(trim(coalesce(p_email, public.current_user_email())))
      and m.is_active = true
      and m.role in ('admin', 'staff', 'viewer')
      and (p_tenant_id is null or m.tenant_id = p_tenant_id)
      and (p_membership_id is null or m.id = p_membership_id)
    order by
      case m.role
        when 'admin' then 1
        when 'staff' then 2
        when 'viewer' then 3
        else 99
      end,
      m.id asc
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
    mm.email as member_email,
    mm.role as member_role,
    mm.is_active as member_is_active,
    mm.tenant_id,
    mm.tenant_name,
    mm.tenant_slug,
    mm.tenant_is_active,
    coalesce(mm.tenant_preference, '{}'::jsonb) as tenant_preference,
    coalesce(mk.active_module_keys, '{}'::text[]) as active_module_keys
  from matched_member mm
  left join module_keys mk
    on mk.tenant_id = mm.tenant_id;
$$;

grant execute on function public.get_app_bootstrap_context(text, bigint, bigint)
to authenticated;

commit;
