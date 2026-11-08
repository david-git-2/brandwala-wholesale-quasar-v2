CREATE FUNCTION public.list_shipment_outcome_vendor_credits (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent bigint;
begin
  select tenant_id into v_parent
  from public.global_shipments
  where id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  return coalesce(
    (
      select jsonb_agg(row_to_json(r) order by r.created_at desc)
      from (
        select
          c.id,
          c.shipment_id,
          c.shipment_item_id,
          c.outcome_id,
          c.quantity,
          c.previous_purchase_price,
          c.new_purchase_price,
          c.credit_amount,
          c.created_by_email,
          c.created_at,
          gsi.name as item_name
        from public.global_shipment_outcome_vendor_credits c
        inner join public.global_shipment_items gsi on gsi.id = c.shipment_item_id
        where c.shipment_id = p_shipment_id
      ) r
    ),
    '[]'::jsonb
  );
end;
$function$;

GRANT ALL ON FUNCTION public.list_shipment_outcome_vendor_credits(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_shipment_outcome_vendor_credits(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_shipment_outcome_vendor_credits(bigint) TO service_role;