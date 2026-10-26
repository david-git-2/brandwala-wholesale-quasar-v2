-- Migration: Allow shop customers to fetch tenant-scoped options (brands, categories)
begin;

create or replace function public.user_can_access_tenant_fetch(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      where cg.tenant_id = p_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
        and cg.is_active = true
    );
$$;

commit;
