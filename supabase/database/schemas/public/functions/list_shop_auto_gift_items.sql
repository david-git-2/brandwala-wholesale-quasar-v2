CREATE FUNCTION public.list_shop_auto_gift_items (
  p_shop_id bigint
)
  RETURNS SETOF public.shop_auto_gift_items
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shop public.shops%rowtype;
begin
  select * into v_shop from public.shops where id = p_shop_id;
  if v_shop.id is null then
    raise exception 'shop not found';
  end if;
  if not public.is_tenant_staff(v_shop.tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select *
  from public.shop_auto_gift_items ag
  where ag.shop_id = p_shop_id
  order by ag.id;
end;
$function$;

GRANT ALL ON FUNCTION public.list_shop_auto_gift_items(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_shop_auto_gift_items(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_shop_auto_gift_items(bigint) TO service_role;