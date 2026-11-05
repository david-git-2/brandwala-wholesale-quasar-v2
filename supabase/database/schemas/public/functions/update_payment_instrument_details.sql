CREATE FUNCTION public.update_payment_instrument_details (
  p_tenant_id     bigint,
  p_instrument_id bigint,
  p_reference     text   DEFAULT NULL::text,
  p_bd_bank_id    bigint DEFAULT NULL::bigint,
  p_cheque_number text   DEFAULT NULL::text,
  p_cheque_date   date   DEFAULT NULL::date
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_line public.pay_instruments;
  v_payment public.pays;
  v_method text;
begin
  if p_tenant_id is null or p_instrument_id is null then
    raise exception 'Tenant and instrument are required.';
  end if;

  select gpi.* into v_line
  from public.pay_instruments gpi
  where gpi.id = p_instrument_id;

  if v_line.id is null then
    raise exception 'Instrument line not found.';
  end if;

  select * into v_payment
  from public.pays gp
  where gp.id = v_line.payment_id
    and gp.tenant_id = p_tenant_id;

  if v_payment.id is null then
    raise exception 'Payment not found for tenant.';
  end if;

  if v_payment.voided_at is not null then
    raise exception 'Cannot edit a voided receipt.';
  end if;

  v_method := upper(trim(v_line.payment_method_code));

  if v_method = 'CHEQUE' then
    if p_bd_bank_id is null then
      raise exception 'Cheque line requires a bank.';
    end if;
    if nullif(trim(coalesce(p_cheque_number, '')), '') is null then
      raise exception 'Cheque line requires a cheque number.';
    end if;
    if p_cheque_date is null then
      raise exception 'Cheque line requires a cheque date.';
    end if;
    if not exists (
      select 1 from public.bd_banks b
      where b.id = p_bd_bank_id and b.is_active = true
    ) then
      raise exception 'Invalid bank for cheque line.';
    end if;
  elsif v_method = 'BANK_TRANSFER' then
    if p_bd_bank_id is null then
      raise exception 'Bank transfer line requires a bank.';
    end if;
    if not exists (
      select 1 from public.bd_banks b
      where b.id = p_bd_bank_id and b.is_active = true
    ) then
      raise exception 'Invalid bank for bank transfer line.';
    end if;
  end if;

  update public.pay_instruments
  set
    reference = nullif(trim(coalesce(p_reference, '')), ''),
    bd_bank_id = case when v_method in ('CHEQUE', 'BANK_TRANSFER') then p_bd_bank_id else null end,
    cheque_number = case when v_method = 'CHEQUE' then nullif(trim(coalesce(p_cheque_number, '')), '') else null end,
    cheque_date = case when v_method in ('CHEQUE', 'BANK_TRANSFER') then p_cheque_date else null end
  where id = p_instrument_id
  returning * into v_line;

  return jsonb_build_object(
    'success', true,
    'instrument_id', v_line.id,
    'payment_id', v_line.payment_id
  );
end;
$function$;

GRANT ALL ON FUNCTION public.update_payment_instrument_details(bigint, bigint, text, bigint, text, date) TO anon;

GRANT ALL ON FUNCTION public.update_payment_instrument_details(bigint, bigint, text, bigint, text, date) TO authenticated;

GRANT ALL ON FUNCTION public.update_payment_instrument_details(bigint, bigint, text, bigint, text, date) TO service_role;