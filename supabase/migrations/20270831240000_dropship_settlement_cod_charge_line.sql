-- Dropship settlement: default COD courier fee charge line from shop_orders.cod_charge_amount

begin;

create or replace function public.build_default_dropship_settlement_charge_lines(
  p_order public.shop_orders
)
returns jsonb
language plpgsql
stable
as $$
begin
  return jsonb_build_array(
    jsonb_build_object(
      'charge_type', 'delivery',
      'amount', coalesce(p_order.delivery_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_delivery_from_margin, false) then 'merchant' else 'recipient' end
    ),
    jsonb_build_object(
      'charge_type', 'print',
      'amount', coalesce(p_order.print_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_print_from_margin, false) then 'merchant' else 'recipient' end
    ),
    jsonb_build_object(
      'charge_type', 'packing',
      'amount', coalesce(p_order.packing_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_packing_from_margin, false) then 'merchant' else 'recipient' end
    ),
    jsonb_build_object(
      'charge_type', 'return',
      'amount', coalesce(p_order.return_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_return_charge_from_middle_man, true) then 'merchant' else 'company' end
    ),
    jsonb_build_object(
      'charge_type', 'cod',
      'amount', coalesce(p_order.cod_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_cod_from_margin, false) then 'merchant' else 'recipient' end
    )
  );
end;
$$;

commit;
