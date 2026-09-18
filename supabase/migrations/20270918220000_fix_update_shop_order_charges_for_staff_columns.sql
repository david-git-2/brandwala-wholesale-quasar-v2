-- Restore staff charge updates onto shop_orders.delivery_charge_amount (etc).
-- 20270915232000 overwrote this RPC with recipient_* columns that are not on shop_orders.

create or replace function public.update_shop_order_charges_for_staff(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
  if not found or (v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    delivery_charge_amount = coalesce((p_payload->>'delivery_charge_amount')::numeric, o.delivery_charge_amount),
    deduct_delivery_from_margin = coalesce((p_payload->>'deduct_delivery_from_margin')::boolean, o.deduct_delivery_from_margin),
    cod_charge_amount = coalesce((p_payload->>'cod_charge_amount')::numeric, o.cod_charge_amount),
    deduct_cod_from_margin = coalesce((p_payload->>'deduct_cod_from_margin')::boolean, o.deduct_cod_from_margin),
    print_charge_amount = coalesce((p_payload->>'print_charge_amount')::numeric, o.print_charge_amount),
    deduct_print_from_margin = coalesce((p_payload->>'deduct_print_from_margin')::boolean, o.deduct_print_from_margin),
    packing_charge_amount = coalesce((p_payload->>'packing_charge_amount')::numeric, o.packing_charge_amount),
    deduct_packing_from_margin = coalesce((p_payload->>'deduct_packing_from_margin')::boolean, o.deduct_packing_from_margin),
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;

revoke all on function public.update_shop_order_charges_for_staff(bigint, bigint, jsonb) from public;
revoke all on function public.update_shop_order_charges_for_staff(bigint, bigint, jsonb) from anon;
grant execute on function public.update_shop_order_charges_for_staff(bigint, bigint, jsonb) to authenticated;
grant execute on function public.update_shop_order_charges_for_staff(bigint, bigint, jsonb) to service_role;
