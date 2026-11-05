CREATE FUNCTION public._kernel_unwind_pay_settlements_up_to (
  p_payment_id bigint,
  p_books_cap  numeric
)
  RETURNS numeric
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_remaining numeric(12, 2);
  v_unwound numeric(12, 2) := 0.00;
  v_row record;
  v_bill_ids bigint[] := '{}';
  v_bill_id bigint;
begin
  if p_payment_id is null then
    raise exception 'payment_id is required';
  end if;
  v_remaining := round(coalesce(p_books_cap, 0), 2);
  if v_remaining <= 0 then
    return 0;
  end if;

  for v_row in
    select bs.id, bs.bill_id, bs.pay_allocation_id, bs.allocated_books_amount
    from public.bill_settlements bs
    where bs.allocator_kind = 'pay'
      and bs.allocator_id = p_payment_id
    order by bs.id desc
  loop
    exit when v_remaining <= 0;
    if v_row.allocated_books_amount > v_remaining then
      exit;
    end if;

    delete from public.bill_settlements where id = v_row.id;
    if v_row.pay_allocation_id is not null then
      delete from public.pay_allocations where id = v_row.pay_allocation_id;
    end if;

    v_unwound := v_unwound + v_row.allocated_books_amount;
    v_remaining := v_remaining - v_row.allocated_books_amount;

    if v_row.bill_id is not null
       and not (v_row.bill_id = any(v_bill_ids)) then
      v_bill_ids := array_append(v_bill_ids, v_row.bill_id);
    end if;
  end loop;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public.recompute_global_invoice_payment_status(v_bill_id);
  end loop;

  return v_unwound;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_unwind_pay_settlements_up_to(bigint, numeric) TO anon;

GRANT ALL ON FUNCTION public._kernel_unwind_pay_settlements_up_to(bigint, numeric) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_unwind_pay_settlements_up_to(bigint, numeric) TO service_role;