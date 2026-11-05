CREATE FUNCTION public.upsert_shipment_investment (
  p_id                 bigint,
  p_tenant_id          bigint,
  p_global_shipment_id bigint,
  p_investor_id        bigint,
  p_cost_share_pct     numeric
)
  RETURNS public.shipment_investments
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_total_cost_share numeric;
  v_row public.shipment_investments;
  v_action text;
begin
  v_action := case when p_id is null then 'create' else 'edit' end;
  if not public.membership_has_module_action(p_tenant_id, 'investor_shipment_share', v_action) then
    raise exception 'not allowed';
  end if;

  if p_cost_share_pct < 0 or p_cost_share_pct > 100 then
    raise exception 'cost share percentage must be between 0 and 100';
  end if;

  select coalesce(sum(cost_share_pct), 0) into v_total_cost_share
  from public.shipment_investments
  where global_shipment_id = p_global_shipment_id
    and status = 'active'
    and (p_id is null or id <> p_id);

  if v_total_cost_share + p_cost_share_pct > 100 then
    raise exception 'total cost share percentage cannot exceed 100%%';
  end if;

  if p_id is not null then
    update public.shipment_investments
    set
      cost_share_pct = p_cost_share_pct,
      updated_at = now()
    where id = p_id and tenant_id = p_tenant_id
    returning * into v_row;
  else
    insert into public.shipment_investments (
      tenant_id, global_shipment_id, investor_id, cost_share_pct, status
    ) values (
      p_tenant_id, p_global_shipment_id, p_investor_id, p_cost_share_pct, 'active'
    )
    returning * into v_row;
  end if;

  perform public.refresh_shipment_investor_profits(p_global_shipment_id);

  select * into v_row from public.shipment_investments where id = v_row.id;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_shipment_investment(bigint, bigint, bigint, bigint, numeric) TO anon;

GRANT ALL ON FUNCTION public.upsert_shipment_investment(bigint, bigint, bigint, bigint, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_shipment_investment(bigint, bigint, bigint, bigint, numeric) TO service_role;