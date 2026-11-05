CREATE FUNCTION public.reverse_pay (
  p_payment_id bigint,
  p_reason     text   DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pay public.pays;
  v_reason text;
begin
  select * into v_pay from public.pays where id = p_payment_id;
  if v_pay.id is null then
    raise exception 'Payment not found.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required.';
  end if;

  perform public._kernel_reverse_payment(v_pay.tenant_id, p_payment_id, v_reason);
end;
$function$;

CREATE FUNCTION public.reverse_pay (
  p_payment_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform public.void_customer_receipt(p_payment_id);
end;
$function$;

GRANT ALL ON FUNCTION public.reverse_pay(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.reverse_pay(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.reverse_pay(bigint, text) TO service_role;

GRANT ALL ON FUNCTION public.reverse_pay(bigint) TO anon;

GRANT ALL ON FUNCTION public.reverse_pay(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.reverse_pay(bigint) TO service_role;