CREATE FUNCTION public.delete_shop_product_listing (
  p_listing_id bigint,
  p_tenant_id  bigint
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  delete from public.shop_product_listings
  where id = p_listing_id and tenant_id = p_tenant_id;

  return true;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_shop_product_listing(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_shop_product_listing(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_shop_product_listing(bigint, bigint) TO service_role;