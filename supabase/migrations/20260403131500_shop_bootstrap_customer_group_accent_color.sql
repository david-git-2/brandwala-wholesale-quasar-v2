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
  select
    cgm.id as member_id,
    cgm.name as member_name,
    lower(trim(cgm.email)) as member_email,
    cgm.role as member_role,
    cgm.is_active as member_is_active,
    cg.id as customer_group_id,
    cg.name as customer_group_name,
    cg.is_active as customer_group_is_active,
    cg.accent_color as customer_group_accent_color,
    t.id as tenant_id,
    t.name as tenant_name,
    t.slug as tenant_slug,
    t.is_active as tenant_is_active,
    public.get_active_module_keys_for_tenant(t.id) as active_module_keys
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
  limit 1;
$$;

grant execute on function public.get_shop_bootstrap_context(text, bigint, bigint)
to authenticated;
