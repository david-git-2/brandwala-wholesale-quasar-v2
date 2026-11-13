-- Pass cost_lines through finance bundle; return cost_lines from update_shipment_ap_bill_v2.

CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_buckets jsonb;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
  v_elem jsonb;
  v_slim jsonb := '[]'::jsonb;
begin
  select gs.tenant_id, coalesce(gs.buckets, '[]'::jsonb)
    into v_parent, v_buckets
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_books_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  v_cost_entries := '[]'::jsonb;
  v_sid := p_shipment_id::text;

  for v_elem in
    select value
    from jsonb_array_elements(
      public._list_shipment_cost_ap_bills_json(v_parent, p_shipment_id, false)
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
$$;

CREATE OR REPLACE FUNCTION public.update_shipment_ap_bill_v2(
  p_shipment_id bigint,
  p_bill_id bigint,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_parent bigint;
  v_bill money_kernel.bills;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_line_obj jsonb;
  v_amount numeric(18, 4);
  v_component text;
  v_desc text;
  v_update_payload jsonb;
  v_result jsonb;
BEGIN
  IF p_shipment_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'shipment_id and bill_id are required';
  END IF;

  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.tenant_id;
  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id = v_parent;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_bill.status <> 'draft' THEN
    RAISE EXCEPTION 'only draft bills can be edited';
  END IF;

  IF p_payload ? 'lines' THEN
    FOR v_line IN SELECT * FROM jsonb_array_elements(p_payload->'lines')
    LOOP
      v_amount := round(COALESCE((v_line->>'amount')::numeric, (v_line->>'unit_price')::numeric, 0), 2);
      IF v_amount <= 0 THEN
        CONTINUE;
      END IF;
      v_component := COALESCE(NULLIF(btrim(v_line->>'cost_component'), ''), 'misc');
      v_desc := COALESCE(
        NULLIF(btrim(v_line->>'description'), ''),
        initcap(replace(v_component, '_', ' '))
      );
      v_line_obj := jsonb_build_object(
        'item_kind', 'charge',
        'description', v_desc,
        'quantity', 1,
        'unit_price', v_amount,
        'line_total', v_amount,
        'meta', jsonb_build_object(
          'cost_component', v_component,
          'is_capitalizable', COALESCE((v_line->>'is_capitalizable')::boolean, true),
          'shipment_id', p_shipment_id
        )
      );
      v_lines := v_lines || jsonb_build_array(v_line_obj);
    END LOOP;

    IF jsonb_array_length(v_lines) = 0 THEN
      RAISE EXCEPTION 'invalid_arguments: at least one positive amount line required';
    END IF;
  END IF;

  v_update_payload := COALESCE(p_payload, '{}'::jsonb);
  IF jsonb_array_length(v_lines) > 0 THEN
    v_update_payload := v_update_payload || jsonb_build_object('lines', v_lines);
  END IF;

  v_result := public.rpc_update_draft_bill_v2(v_parent, p_bill_id, v_update_payload);

  RETURN v_result
    || jsonb_build_object(
      'shipment_id', p_shipment_id,
      'bill_id', p_bill_id,
      'cost_lines', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'cost_component', COALESCE(NULLIF(btrim(bl.meta->>'cost_component'), ''), 'misc'),
            'amount', bl.line_total,
            'description', bl.description
          )
          ORDER BY bl.line_no
        )
        FROM money_kernel.bill_lines bl
        WHERE bl.tenant_id = v_parent
          AND bl.bill_id = p_bill_id
      ), '[]'::jsonb)
    );
END;
$$;
