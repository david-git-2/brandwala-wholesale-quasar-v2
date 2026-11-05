CREATE FUNCTION public.update_shipment_investment_cost_share (
  p_shipment_investment_id bigint,
  p_cost_share_pct         numeric
)
  RETURNS public.shipment_investments
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.shipment_investments;
  v_total numeric(5,2);
begin
  select * into v_row from public.shipment_investments where id = p_shipment_investment_id;
  if v_row.id is null then raise exception 'investment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_row.tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_cost_share_pct < 0 or p_cost_share_pct > 100 then
    raise exception 'cost_share_pct must be between 0 and 100';
  end if;

  select coalesce(sum(cost_share_pct), 0) into v_total
  from public.shipment_investments
  where shipment_id = v_row.shipment_id
    and id <> p_shipment_investment_id
    and cost_share_pct is not null;

  if v_total + p_cost_share_pct > 100 then
    raise exception 'total cost_share_pct cannot exceed 100';
  end if;

  update public.shipment_investments
  set cost_share_pct = p_cost_share_pct
  where id = p_shipment_investment_id
  returning * into v_row;

  perform public.refresh_shipment_investor_profits(v_row.shipment_id);

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.update_shipment_investment_cost_share(bigint, numeric) TO anon;

GRANT ALL ON FUNCTION public.update_shipment_investment_cost_share(bigint, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.update_shipment_investment_cost_share(bigint, numeric) TO service_role;