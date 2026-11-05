CREATE FUNCTION public.bounce_cheque_instrument (
  p_tenant_id     bigint,
  p_instrument_id bigint,
  p_reason        text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_inst public.pay_instruments;
  v_pay public.pays;
  v_reason text;
  v_active_count int;
  v_parent_id bigint;
begin
  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required.';
  end if;
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_inst
  from public.pay_instruments
  where id = p_instrument_id
  for update;

  if v_inst.id is null then
    raise exception 'Instrument not found.';
  end if;

  if upper(trim(v_inst.payment_method_code)) <> 'CHEQUE' then
    raise exception 'Instrument is not a cheque.';
  end if;

  if v_inst.bounced_at is not null then
    raise exception 'Cheque already marked bounced.';
  end if;

  select * into v_pay from public.pays where id = v_inst.payment_id for update;
  if v_pay.voided_at is not null then
    raise exception 'Payment is already voided.';
  end if;

  if v_pay.tenant_id <> v_parent_id then
    raise exception 'Payment tenant mismatch.';
  end if;

  select count(*)::int into v_active_count
  from public.pay_instruments pi
  where pi.payment_id = v_pay.id
    and pi.bounced_at is null;

  if v_active_count <= 1 then
    update public.pay_instruments
    set bounced_at = now()
    where id = v_inst.id;

    perform public.reverse_pay(
      v_pay.id,
      'Cheque bounced: ' || v_reason
    );

    return jsonb_build_object(
      'success', true,
      'partial', false,
      'payment_id', v_pay.id,
      'instrument_id', v_inst.id
    );
  end if;

  return public._kernel_bounce_cheque_instrument_partial(
    p_tenant_id,
    p_instrument_id,
    v_reason
  );
end;
$function$;

GRANT ALL ON FUNCTION public.bounce_cheque_instrument(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.bounce_cheque_instrument(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.bounce_cheque_instrument(bigint, bigint, text) TO service_role;