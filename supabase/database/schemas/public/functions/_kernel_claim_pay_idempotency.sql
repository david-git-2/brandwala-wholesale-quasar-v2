CREATE FUNCTION public._kernel_claim_pay_idempotency (
  p_parent_tenant_id bigint,
  p_key              text
)
  RETURNS public.pays
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pay public.pays;
  v_key text := nullif(btrim(p_key), '');
begin
  if v_key is null then
    return v_pay;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('pay_idem:' || p_parent_tenant_id::text || ':' || v_key)
  );

  select * into v_pay
  from public.pays p
  where p.tenant_id = p_parent_tenant_id
    and p.idempotency_key = v_key
  limit 1;

  return v_pay;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_claim_pay_idempotency(bigint, text) TO anon;

GRANT ALL ON FUNCTION public._kernel_claim_pay_idempotency(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_claim_pay_idempotency(bigint, text) TO service_role;