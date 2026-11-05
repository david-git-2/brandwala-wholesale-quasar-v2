CREATE FUNCTION public._assert_shipment_ap_allocations_payable (
  p_allocations jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_elem jsonb;
  v_bill_id bigint;
  v_bill public.bills;
begin
  if p_allocations is null or jsonb_typeof(p_allocations) <> 'array' then
    return;
  end if;

  for v_elem in select value from jsonb_array_elements(p_allocations)
  loop
    v_bill_id := nullif(v_elem->>'bill_id', '')::bigint;
    if v_bill_id is null then
      continue;
    end if;

    select * into v_bill from public.bills where id = v_bill_id;
    if v_bill.id is null then
      raise exception 'Allocation bill % not found', v_bill_id;
    end if;

    if v_bill.invoice_type = 'ap'::public.global_invoice_type
       and v_bill.source_type = 'shipment_cost'
       and v_bill.invoice_status <> 'issued'::public.global_invoice_status then
      raise exception 'Bill % must be issued before shipment AP payout', v_bill_id;
    end if;

    if v_bill.ap_shipment_id is not null then
      perform public._assert_shipment_ap_payable(v_bill.ap_shipment_id);
    elsif v_bill.source_type = 'shipment_cost' and nullif(trim(v_bill.source_id), '') is not null then
      perform public._assert_shipment_ap_payable(nullif(trim(v_bill.source_id), '')::bigint);
    end if;
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public._assert_shipment_ap_allocations_payable(jsonb) TO anon;

GRANT ALL ON FUNCTION public._assert_shipment_ap_allocations_payable(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public._assert_shipment_ap_allocations_payable(jsonb) TO service_role;