CREATE FUNCTION public._kernel_finalize_pay_idempotency (
  p_pay_id           bigint,
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
    select * into v_pay from public.pays where id = p_pay_id;
    return v_pay;
  end if;

  begin
    update public.pays
    set idempotency_key = v_key
    where id = p_pay_id;
  exception
    when unique_violation then
      select * into v_pay
      from public.pays p
      where p.tenant_id = p_parent_tenant_id
        and p.idempotency_key = v_key
      limit 1;
      return v_pay;
  end;

  select * into v_pay from public.pays where id = p_pay_id;
  return v_pay;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_finalize_pay_idempotency(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public._kernel_finalize_pay_idempotency(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_finalize_pay_idempotency(bigint, bigint, text) TO service_role;