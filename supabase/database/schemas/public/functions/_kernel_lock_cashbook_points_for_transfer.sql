CREATE FUNCTION public._kernel_lock_cashbook_points_for_transfer (
  p_from_point_id bigint,
  p_to_point_id   bigint,
  p_currency_code text
)
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
declare
  v_ccy text := upper(trim(coalesce(p_currency_code, 'BDT')));
  v_first bigint;
  v_second bigint;
begin
  if p_from_point_id is null or p_to_point_id is null then
    raise exception 'Both cash points are required.';
  end if;
  if v_ccy = '' then
    v_ccy := 'BDT';
  end if;

  if p_from_point_id < p_to_point_id then
    v_first := p_from_point_id;
    v_second := p_to_point_id;
  else
    v_first := p_to_point_id;
    v_second := p_from_point_id;
  end if;

  perform 1
  from public.cashbook_point_pots cpp
  where cpp.cashbook_point_id = v_first
    and upper(trim(cpp.currency_code)) = v_ccy
  order by cpp.id
  for update;

  perform 1
  from public.cashbook_point_pots cpp
  where cpp.cashbook_point_id = v_second
    and upper(trim(cpp.currency_code)) = v_ccy
  order by cpp.id
  for update;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_lock_cashbook_points_for_transfer(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public._kernel_lock_cashbook_points_for_transfer(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_lock_cashbook_points_for_transfer(bigint, bigint, text) TO service_role;