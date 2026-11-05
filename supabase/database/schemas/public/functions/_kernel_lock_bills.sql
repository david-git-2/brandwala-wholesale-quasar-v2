CREATE FUNCTION public._kernel_lock_bills (
  p_bill_ids bigint[]
)
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
declare
  v_id bigint;
begin
  if p_bill_ids is null then
    return;
  end if;
  for v_id in
    select distinct u.x
    from unnest(p_bill_ids) as u(x)
    where u.x is not null
    order by u.x
  loop
    perform 1 from public.bills where id = v_id for update;
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_lock_bills(bigint[]) TO anon;

GRANT ALL ON FUNCTION public._kernel_lock_bills(bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_lock_bills(bigint[]) TO service_role;