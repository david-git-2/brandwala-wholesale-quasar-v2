CREATE FUNCTION public._kernel_ensure_cashbook_point_pot (
  p_parent_tenant_id  bigint,
  p_cashbook_point_id bigint,
  p_currency_code     text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id bigint;
  v_ccy text := upper(trim(coalesce(p_currency_code, 'BDT')));
begin
  if p_cashbook_point_id is null then
    return null;
  end if;
  if v_ccy = '' then
    v_ccy := 'BDT';
  end if;

  insert into public.cashbook_point_pots (
    parent_tenant_id, cashbook_point_id, currency_code, amount
  ) values (
    p_parent_tenant_id, p_cashbook_point_id, v_ccy, 0
  )
  on conflict (cashbook_point_id, currency_code)
  do update set updated_at = now()
  returning id into v_id;

  return v_id;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_ensure_cashbook_point_pot(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public._kernel_ensure_cashbook_point_pot(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_ensure_cashbook_point_pot(bigint, bigint, text) TO service_role;