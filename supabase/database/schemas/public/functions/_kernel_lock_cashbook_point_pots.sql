CREATE FUNCTION public._kernel_lock_cashbook_point_pots (
  p_cashbook_point_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
declare
  v_id bigint;
begin
  if p_cashbook_point_id is null then
    return;
  end if;
  for v_id in
    select cpp.id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
    order by cpp.currency_code asc, cpp.id asc
  loop
    perform 1 from public.cashbook_point_pots where id = v_id for update;
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_lock_cashbook_point_pots(bigint) TO anon;

GRANT ALL ON FUNCTION public._kernel_lock_cashbook_point_pots(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_lock_cashbook_point_pots(bigint) TO service_role;