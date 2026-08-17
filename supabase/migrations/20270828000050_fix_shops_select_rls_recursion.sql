-- shops_select_customer_group queried shop_customer_group_access,
-- whose SELECT policy queries shops → 42P17 infinite recursion.
-- Helper is SECURITY DEFINER so it does not re-enter shops RLS.

create or replace function public.customer_can_select_shop(p_shop_id bigint, p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.shop_customer_group_access access
    join public.customer_groups cg on cg.id = access.customer_group_id
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id
     and profile.tenant_id = p_tenant_id
    where access.shop_id = p_shop_id
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
  );
$$;

revoke all on function public.customer_can_select_shop(bigint, bigint) from public;
grant execute on function public.customer_can_select_shop(bigint, bigint) to authenticated;

drop policy if exists "shops_select_customer_group" on public.shops;

create policy "shops_select_customer_group"
  on public.shops for select
  using (
    is_active = true
    and public.customer_can_select_shop(id, tenant_id)
  );
