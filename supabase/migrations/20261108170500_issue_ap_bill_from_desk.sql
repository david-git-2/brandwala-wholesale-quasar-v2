-- Issue draft AP from bills desk without shipment lock / in-transit prerequisites.

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_issue_allowed(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if current_setting('app.bill_desk_issue_shipment_ap', true) = '1' then
    return;
  end if;

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Shipment % must be in transit or received before issuing AP bills', p_shipment_id;
  end if;

  if not coalesce(v_ship.costs_locked, false) then
    raise exception 'Shipment % costs are not locked; use Lock costs on the shipment first', p_shipment_id;
  end if;

  if current_setting('app.shipment_ap_issue', true) is distinct from '1'
     and coalesce(auth.role(), '') is distinct from 'service_role' then
    raise exception 'Issue shipment AP only via lock_global_shipment_costs on the shipment';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_ap_bill_from_desk(p_bill_id bigint)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_result public.bills;
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;

  if v_bill.invoice_type is distinct from 'ap'::public.global_invoice_type then
    raise exception 'Only AP bills can be issued from the bills desk';
  end if;

  if v_bill.document_kind is distinct from 'standard'::public.bill_document_kind then
    raise exception 'Only standard AP bills can be issued from the bills desk';
  end if;

  if v_bill.invoice_status is distinct from 'draft'::public.global_invoice_status then
    raise exception 'Only draft AP bills can be issued from the bills desk';
  end if;

  if coalesce(v_bill.total_amount, 0) <= 0 then
    raise exception 'Bill total must be greater than zero';
  end if;

  if not public.user_can_manage_books_tenant(v_bill.tenant_id) then
    raise exception 'Permission denied';
  end if;

  perform set_config('app.bill_desk_issue_shipment_ap', '1', true);
  perform set_config('app.shipment_ap_issue', '1', true);
  begin
    v_result := public.issue_bill(p_bill_id);
  exception
    when others then
      perform set_config('app.bill_desk_issue_shipment_ap', '0', true);
      perform set_config('app.shipment_ap_issue', '0', true);
      raise;
  end;
  perform set_config('app.bill_desk_issue_shipment_ap', '0', true);
  perform set_config('app.shipment_ap_issue', '0', true);
  return v_result;
end;
$$;

GRANT EXECUTE ON FUNCTION public.issue_ap_bill_from_desk(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_ap_bill_from_desk(bigint) TO service_role;
