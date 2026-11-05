CREATE FUNCTION public.insert_global_payment_instruments (
  p_payment_id  bigint,
  p_instruments jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_sort int := 0;
begin
  if coalesce(jsonb_typeof(p_instruments), 'null') <> 'array' then
    return;
  end if;

  for v_line in
    select value from jsonb_array_elements(p_instruments)
  loop
    v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
    v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
    if v_line_amount <= 0 then
      continue;
    end if;

    if not exists (
      select 1 from public.payment_methods pm
      where pm.code = v_method_code and pm.is_active = true
    ) then
      raise exception 'Invalid payment method: %', v_method_code;
    end if;

    if v_method_code = 'CHEQUE' then
      if (v_line.value ->> 'bd_bank_id') is null then
        raise exception 'Cheque line requires a bank';
      end if;
      if nullif(trim(coalesce(v_line.value ->> 'cheque_number', '')), '') is null then
        raise exception 'Cheque line requires a cheque number';
      end if;
      if (v_line.value ->> 'cheque_date') is null then
        raise exception 'Cheque line requires a cheque date';
      end if;
    end if;

    if v_method_code = 'BANK_TRANSFER'
       and (v_line.value ->> 'bd_bank_id') is null
       and nullif(trim(coalesce(v_line.value ->> 'reference', '')), '') is null then
      raise exception 'Bank transfer line requires a bank or transaction reference';
    end if;

    if v_method_code in ('CHEQUE', 'BANK_TRANSFER')
       and (v_line.value ->> 'bd_bank_id') is not null
       and not exists (
      select 1 from public.bd_banks b
      where b.id = (v_line.value ->> 'bd_bank_id')::bigint and b.is_active = true
    ) then
      raise exception 'Invalid bank on payment line';
    end if;

    v_sort := v_sort + 1;
    insert into public.pay_instruments (
      payment_id, payment_method_code, amount, reference,
      bd_bank_id, cheque_number, cheque_date, sort_order, cashbook_point_id
    ) values (
      p_payment_id,
      v_method_code,
      v_line_amount,
      nullif(trim(coalesce(v_line.value ->> 'reference', '')), ''),
      case when v_method_code in ('CHEQUE', 'BANK_TRANSFER') then (v_line.value ->> 'bd_bank_id')::bigint else null end,
      case when v_method_code = 'CHEQUE' then nullif(trim(v_line.value ->> 'cheque_number'), '') else null end,
      case
        when v_method_code in ('CHEQUE', 'BANK_TRANSFER') then (v_line.value ->> 'cheque_date')::date
        else null
      end,
      v_sort,
      nullif(v_line.value ->> 'cashbook_point_id', '')::bigint
    );
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public.insert_global_payment_instruments(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.insert_global_payment_instruments(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.insert_global_payment_instruments(bigint, jsonb) TO service_role;