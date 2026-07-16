begin;

-- =========================================================
-- 1. RPC: delete_shop_order
-- =========================================================
create or replace function public.delete_shop_order(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_status public.shop_order_status;
begin
  select tenant_id, status into v_tenant_id, v_status
  from public.shop_orders
  where id = p_order_id;

  if v_tenant_id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'Access denied';
  end if;

  if v_status = 'fulfilled' then
    raise exception 'Cannot delete a fulfilled order';
  end if;

  delete from public.shop_orders where id = p_order_id;
end;
$$;

grant execute on function public.delete_shop_order(bigint) to authenticated;

commit;
