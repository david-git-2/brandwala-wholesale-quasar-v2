CREATE FUNCTION public.get_shipment_settings_finance_bundle (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_workspace bigint;
  v_buckets jsonb;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_elem jsonb;
  v_slim jsonb := '[]'::jsonb;
begin
  select coalesce(gs.buckets, '[]'::jsonb)
    into v_buckets
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if not found then
    raise exception 'shipment not found';
  end if;

  v_workspace := public._shipment_money_workspace_tenant(p_shipment_id);

  if not (
    public.user_can_manage_books_tenant(v_workspace)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_workspace
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  v_cost_entries := '[]'::jsonb;

  for v_elem in
    select value
    from jsonb_array_elements(
      public._list_shipment_cost_ap_bills_json(v_workspace, p_shipment_id, false)
    )
  loop
    v_slim := v_slim || jsonb_build_array(
      jsonb_build_object(
        'id', v_elem->'id',
        'invoice_no', v_elem->'invoice_no',
        'ap_kind', v_elem->'ap_kind',
        'source_type', v_elem->'source_type',
        'source_id', v_elem->'source_id',
        'source_key', v_elem->'source_key',
        'invoice_status', v_elem->'invoice_status',
        'payment_status', v_elem->'payment_status',
        'total_amount', coalesce(
          nullif(v_elem->>'total_amount', '')::numeric,
          nullif(v_elem->'net_balances'->>'open_txn', '')::numeric,
          0
        ),
        'due_amount', coalesce(
          nullif(v_elem->'net_balances'->>'open_books', '')::numeric,
          nullif(v_elem->'net_balances'->>'open_txn', '')::numeric,
          nullif(v_elem->>'due_amount', '')::numeric,
          0
        ),
        'net_balances', v_elem->'net_balances',
        'section_id', v_elem->'section_id',
        'section_title', v_elem->'section_title',
        'cost_lines', coalesce(v_elem->'cost_lines', '[]'::jsonb)
      )
    );
  end loop;
  v_ap_bills := v_slim;

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  return jsonb_build_object(
    'buckets', v_buckets,
    'cost_entries', v_cost_entries,
    'ap_bills', v_ap_bills,
    'ap_fx', v_ap_fx,
    'ap_issue_parties', public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id)
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_shipment_settings_finance_bundle(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_shipment_settings_finance_bundle(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_shipment_settings_finance_bundle(bigint) TO service_role;