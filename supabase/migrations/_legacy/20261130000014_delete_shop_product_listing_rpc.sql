-- RPC: delete_shop_product_listing

create or replace function public.delete_shop_product_listing(
  p_listing_id bigint,
  p_tenant_id bigint
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  delete from public.shop_product_listings
  where id = p_listing_id and tenant_id = p_tenant_id;

  return true;
end;
$$;

grant execute on function public.delete_shop_product_listing(bigint, bigint) to authenticated;
