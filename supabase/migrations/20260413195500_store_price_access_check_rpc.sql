-- =========================================================
-- Store module: reusable store price visibility check RPC
-- =========================================================

create or replace function public.check_store_price_access(
  p_store_id bigint
)
returns boolean
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
  v_has_internal_access boolean;
begin
  select s.tenant_id
  into v_tenant_id
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    return false;
  end if;

  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id = v_tenant_id
      and m.role in ('admin', 'staff')
  ) into v_has_internal_access;

  if v_has_internal_access then
    return true;
  end if;

  return public.can_customer_see_store_price(p_store_id);
end;
$$;

grant execute on function public.check_store_price_access(bigint)
to authenticated;
