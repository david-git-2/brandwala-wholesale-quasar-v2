CREATE FUNCTION public.list_shop_customer_stocks (
  p_shop_id           bigint,
  p_customer_group_id bigint DEFAULT NULL::bigint
)
  RETURNS TABLE (
    id                bigint,
    shop_id           bigint,
    customer_group_id bigint,
    product_id        bigint,
    product_name      text,
    product_code      text,
    item_label        text,
    quantity_on_hand  integer,
    updated_at        timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shop public.shops%rowtype;
begin
  select s.* into v_shop
  from public.shops s
  where s.id = p_shop_id;

  if v_shop.id is null then
    raise exception 'shop not found';
  end if;

  if not public.is_tenant_staff(v_shop.tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    scs.id,
    scs.shop_id,
    scs.customer_group_id,
    scs.product_id,
    coalesce(p.name, scs.item_label) as product_name,
    p.product_code,
    scs.item_label,
    scs.quantity_on_hand,
    scs.updated_at
  from public.shop_customer_stocks scs
  left join public.products p on p.id = scs.product_id
  where scs.shop_id = p_shop_id
    and (
      p_customer_group_id is null
      or scs.customer_group_id = p_customer_group_id
    )
  order by coalesce(p.name, scs.item_label), scs.id;
end;
$function$;

GRANT ALL ON FUNCTION public.list_shop_customer_stocks(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_shop_customer_stocks(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_shop_customer_stocks(bigint, bigint) TO service_role;