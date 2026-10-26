begin;

-- =========================================================
-- RPC: delete_shop
-- Deletes a shop and all cascading child records (carts, orders, listings, access rules).
-- =========================================================
create or replace function public.delete_shop(
  p_shop_id bigint,
  p_tenant_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  delete from public.shops
  where id = p_shop_id and tenant_id = p_tenant_id;

  if not found then
    raise exception 'shop not found or already deleted';
  end if;
end;
$$;

grant execute on function public.delete_shop(bigint, bigint) to authenticated;

commit;
