CREATE FUNCTION public.delete_shop_auto_gift_item (
  p_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.shop_auto_gift_items%rowtype;
begin
  select * into v_row from public.shop_auto_gift_items where id = p_id;
  if v_row.id is null then
    return jsonb_build_object('success', false, 'error', 'not found');
  end if;
  if not public.is_tenant_staff(v_row.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  delete from public.shop_auto_gift_items where id = p_id;
  return jsonb_build_object('success', true);
end;
$function$;

GRANT ALL ON FUNCTION public.delete_shop_auto_gift_item(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_shop_auto_gift_item(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_shop_auto_gift_item(bigint) TO service_role;