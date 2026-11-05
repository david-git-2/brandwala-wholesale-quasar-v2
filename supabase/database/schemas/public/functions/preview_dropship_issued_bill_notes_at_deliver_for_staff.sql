CREATE FUNCTION public.preview_dropship_issued_bill_notes_at_deliver_for_staff (
  p_tenant_id bigint,
  p_order_id  bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  return public.preview_dropship_issued_bill_notes_at_deliver(p_order_id);
end;
$function$;

GRANT ALL ON FUNCTION public.preview_dropship_issued_bill_notes_at_deliver_for_staff(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.preview_dropship_issued_bill_notes_at_deliver_for_staff(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.preview_dropship_issued_bill_notes_at_deliver_for_staff(bigint, bigint) TO service_role;