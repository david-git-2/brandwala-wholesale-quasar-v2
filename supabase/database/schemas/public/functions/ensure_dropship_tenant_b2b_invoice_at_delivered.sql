CREATE FUNCTION public.ensure_dropship_tenant_b2b_invoice_at_delivered (
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;
  return public.issue_dropship_tenant_b2b_invoice(v_tenant_id, p_order_id);
end;
$function$;

GRANT ALL ON FUNCTION public.ensure_dropship_tenant_b2b_invoice_at_delivered(bigint) TO anon;

GRANT ALL ON FUNCTION public.ensure_dropship_tenant_b2b_invoice_at_delivered(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.ensure_dropship_tenant_b2b_invoice_at_delivered(bigint) TO service_role;