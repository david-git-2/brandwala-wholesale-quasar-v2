-- Deferred from 20260826200000: shop customer auth for parent-tenant stock (needs shop_order tables).
-- create_and_post_stock_movement is applied by later stock movement migrations (20270817+).

create or replace function public.can_act_on_parent_tenant_stock(p_parent_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.has_active_tenant_membership(p_parent_tenant_id)
    or public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      inner join public.tenants t on t.id = m.tenant_id
      where t.parent_id = p_parent_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or exists (
      select 1
      from public.customer_group_members cgm
      inner join public.customer_groups cg on cg.id = cgm.customer_group_id
      inner join public.shop_customer_group_access scga on scga.customer_group_id = cg.id
      inner join public.shops s on s.id = scga.shop_id
      where public.resolve_parent_tenant_id(s.tenant_id) = p_parent_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
        and cg.is_active = true
        and scga.status = true
        and s.is_active = true
    );
$$;

grant execute on function public.can_act_on_parent_tenant_stock(bigint) to authenticated;
