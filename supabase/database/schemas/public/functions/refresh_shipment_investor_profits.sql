CREATE FUNCTION public.refresh_shipment_investor_profits (
  p_global_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shipment public.global_shipments;
  v_pnl jsonb;
  v_buy numeric(12,2);
  v_profit numeric(12,2);
  v_updated integer := 0;
  v_inv record;
  v_status text;
  v_sold_qty numeric;
  v_received_qty numeric;
  v_computed_profit numeric(12,2);
begin
  select * into v_shipment from public.global_shipments where id = p_global_shipment_id;
  if v_shipment.id is null then raise exception 'global shipment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  v_pnl := public.get_shipment_pnl(v_shipment.tenant_id, p_global_shipment_id);
  v_buy := coalesce((v_pnl -> 'totals' ->> 'landed_cost')::numeric, 0.00);
  v_profit := coalesce((v_pnl -> 'totals' ->> 'gross_profit')::numeric, 0.00);

  select
    coalesce(sum(ordered_quantity), 0),
    coalesce(sum(sold_qty), 0)
  into v_received_qty, v_sold_qty
  from (
    select
      si.ordered_quantity,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    where si.shipment_id = p_global_shipment_id
    group by si.id, si.ordered_quantity
  ) t;

  if v_received_qty = 0 then
    v_status := 'open';
  elsif v_sold_qty >= v_received_qty then
    v_status := 'realized';
  elsif v_sold_qty > 0 then
    v_status := 'partial';
  else
    v_status := 'open';
  end if;

  for v_inv in
    select * from public.shipment_investments
    where global_shipment_id = p_global_shipment_id
      and status = 'active'
      and cost_share_pct is not null
  loop
    v_computed_profit := round(v_profit * v_inv.cost_share_pct / 100.0, 2);

    update public.shipment_investments
    set
      allocated_cost = round(v_buy * v_inv.cost_share_pct / 100.0, 2),
      computed_profit = v_computed_profit,
      profit_status = v_status
    where id = v_inv.id;

    -- Update investor pending profit bucket if profit is realized
    if v_computed_profit > 0 and v_status = 'realized' then
      if not exists (
        select 1 from public.cashbook_entries
        where tenant_id = v_shipment.tenant_id
          and entity_type = 'investor'
          and entity_id = v_inv.investor_id
          and source_type = 'vendor_purchase'
          and source_id = p_global_shipment_id::text
          and metadata->>'purpose' = 'shipment_investor_profit'
      ) then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => v_shipment.tenant_id, p_operating_tenant_id => coalesce(v_shipment.assigned_child_tenant_id, v_shipment.tenant_id),
          p_entity_type => 'investor',
          p_entity_id => v_inv.investor_id,
          p_type => 'credit',
          p_amount => v_computed_profit,
          p_currency_code => 'BDT',
          p_exchange_rate => 1.000000,
          p_source_type => 'vendor_purchase',
          p_source_id => p_global_shipment_id::text,
          p_metadata => jsonb_build_object(
            'section', 'investor_capital',
            'purpose', 'shipment_investor_profit',
            'transaction_type', 'profit_accrued',
            'label', 'Shipment Profit Distribution',
            'shipment_id', p_global_shipment_id
          ),
          p_target_bucket => 'pending'
        );
      end if;
    end if;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'global_shipment_id', p_global_shipment_id,
    'updated_count', v_updated,
    'buy_cost_total', v_buy,
    'profit_total', v_profit,
    'profit_status', v_status
  );
end;
$function$;

GRANT ALL ON FUNCTION public.refresh_shipment_investor_profits(bigint) TO anon;

GRANT ALL ON FUNCTION public.refresh_shipment_investor_profits(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.refresh_shipment_investor_profits(bigint) TO service_role;