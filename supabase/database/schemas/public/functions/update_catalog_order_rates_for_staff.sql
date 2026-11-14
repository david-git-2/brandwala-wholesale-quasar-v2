CREATE FUNCTION public.update_catalog_order_rates_for_staff (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_payload   jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant and order required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found
     or (v_order.tenant_id is distinct from p_tenant_id
         and v_order.parent_tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  if v_order.status in (
    'procuring'::public.shop_order_status,
    'dispatch'::public.shop_order_status,
    'delivered'::public.shop_order_status,
    'closed'::public.shop_order_status,
    'ordered'::public.shop_order_status,
    'packed'::public.shop_order_status
  ) then
    raise exception 'order rates cannot be changed after procurement has started';
  end if;

  update public.shop_orders o
  set
    conversion_rate = case when p_payload ? 'conversion_rate' then (p_payload->>'conversion_rate')::numeric else o.conversion_rate end,
    cargo_rate = case when p_payload ? 'cargo_rate' then (p_payload->>'cargo_rate')::numeric else o.cargo_rate end,
    profit_rate = case when p_payload ? 'profit_rate' then (p_payload->>'profit_rate')::numeric else o.profit_rate end,
    first_offer_rate = case when p_payload ? 'first_offer_rate' then (p_payload->>'first_offer_rate')::numeric else o.first_offer_rate end,
    final_offer_rate = case when p_payload ? 'final_offer_rate' then (p_payload->>'final_offer_rate')::numeric else o.final_offer_rate end,
    profit_basis = case when p_payload ? 'profit_basis' then nullif(p_payload->>'profit_basis', '') else o.profit_basis end,
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$function$;

GRANT ALL ON FUNCTION public.update_catalog_order_rates_for_staff(bigint, bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.update_catalog_order_rates_for_staff(bigint, bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.update_catalog_order_rates_for_staff(bigint, bigint, jsonb) TO service_role;