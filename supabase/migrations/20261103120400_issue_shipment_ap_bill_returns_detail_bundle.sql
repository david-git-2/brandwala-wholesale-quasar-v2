-- issue_shipment_ap_bill_for_kind returns desk bundle (issue + get_bill_detail_bundle in one round trip)

DROP FUNCTION IF EXISTS public.issue_shipment_ap_bill_for_kind(bigint, text);

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bill_for_kind(
  p_shipment_id bigint,
  p_ap_kind text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_bill_id bigint;
  v_issued public.bills;
  v_last_issued bigint;
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select gs.parent_tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  perform public._shipment_money_advisory_lock(p_shipment_id);

  for v_bill_id in
    select b.id
    from public.bills b
    where b.parent_tenant_id = v_parent
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.invoice_status = 'draft'::public.global_invoice_status
      and coalesce(b.total_amount, 0) > 0
      and (
        (
          b.source_type = 'shipment_cost'
          and b.source_id = p_shipment_id::text
          and (
            b.source_key = p_ap_kind
            or b.source_key like p_ap_kind || ':%'
          )
        )
        or (b.ap_shipment_id = p_shipment_id and b.ap_kind = p_ap_kind)
      )
    order by b.id asc
  loop
    v_issued := public.issue_bill(v_bill_id);
    v_last_issued := v_issued.id;
  end loop;

  if v_last_issued is null then
    raise exception 'No draft AP bill to issue for bucket %', p_ap_kind;
  end if;

  return public.get_bill_detail_bundle(v_parent, v_last_issued);
end;
$$;

GRANT ALL ON FUNCTION public.issue_shipment_ap_bill_for_kind(bigint, text) TO authenticated;
GRANT ALL ON FUNCTION public.issue_shipment_ap_bill_for_kind(bigint, text) TO service_role;
