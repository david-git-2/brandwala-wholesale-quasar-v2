CREATE FUNCTION public.update_shop_order_status_for_staff (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_status    text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null or p_status is null then
    raise exception 'tenant, order, and status required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found or (v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    status = p_status::public.shop_order_status,
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$function$;

GRANT ALL ON FUNCTION public.update_shop_order_status_for_staff(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.update_shop_order_status_for_staff(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.update_shop_order_status_for_staff(bigint, bigint, text) TO service_role;