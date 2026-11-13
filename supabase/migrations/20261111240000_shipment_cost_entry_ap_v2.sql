-- Shipment cost entry AP v2: kernel profiles + one-call issue + bundle parties
-- Mirror a public.profiles row into money_kernel.profiles (stable link via meta.public_profile_id).
CREATE OR REPLACE FUNCTION money_kernel.ensure_profile_for_public_party(
  p_books_tenant_id bigint,
  p_public_profile_id bigint
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_pub public.profiles%ROWTYPE;
  v_kernel_id bigint;
  v_is_self boolean;
BEGIN
  IF p_books_tenant_id IS NULL OR p_public_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant and public profile required';
  END IF;

  SELECT * INTO v_pub
    FROM public.profiles pr
   WHERE pr.id = p_public_profile_id
     AND pr.tenant_id = p_books_tenant_id
     AND pr.is_active = true
     AND pr.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: public profile % in tenant %', p_public_profile_id, p_books_tenant_id;
  END IF;

  SELECT mk.id INTO v_kernel_id
    FROM money_kernel.profiles mk
   WHERE mk.tenant_id = p_books_tenant_id
     AND mk.meta->>'public_profile_id' = p_public_profile_id::text
   LIMIT 1;

  IF v_kernel_id IS NOT NULL THEN
    RETURN v_kernel_id;
  END IF;

  v_is_self := v_pub.profile_type = 'tenant'::public.profile_party_type;

  INSERT INTO money_kernel.profiles (
    tenant_id, profile_type, name, phone, phone_country_code, email, address,
    is_active, is_tenant_self, meta
  ) VALUES (
    p_books_tenant_id,
    v_pub.profile_type::text,
    v_pub.name,
    v_pub.phone,
    COALESCE(v_pub.phone_country_code, '+880'),
    v_pub.email,
    v_pub.address,
    true,
    v_is_self,
    jsonb_build_object(
      'public_profile_id', p_public_profile_id,
      'profile_type', v_pub.profile_type::text,
      'subject_id', v_pub.subject_id
    )
  )
  RETURNING id INTO v_kernel_id;

  RETURN v_kernel_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Shipment cost entry AP v2 (money_kernel.bills via rpc_create_bill)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._shipment_cost_ap_ensure_public_from_profile(p_books_tenant_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_id bigint;
  v_name text;
BEGIN
  v_id := public._kernel_tenant_mirror_profile_id(p_books_tenant_id);
  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = p_books_tenant_id;
  RETURN public.upsert_profile_for_party(
    p_books_tenant_id,
    'tenant'::public.profile_party_type,
    p_books_tenant_id,
    COALESCE(v_name, 'Tenant #' || p_books_tenant_id::text),
    NULL, NULL, '+880', NULL, false, NULL, true, NULL
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._shipment_cost_ap_ensure_public_to_profile(
  p_books_tenant_id bigint,
  p_ship       public.global_shipments,
  p_bucket     public.global_shipment_cost_bucket,
  OUT profile_id bigint,
  OUT diagnostic text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_name text;
BEGIN
  profile_id := NULL;
  diagnostic := NULL;

  IF p_bucket = 'material'::public.global_shipment_cost_bucket THEN
    IF p_ship.vendor_id IS NULL THEN
      diagnostic := 'shipment vendor_id is required for material AP';
      RETURN;
    END IF;
    SELECT pr.id INTO profile_id
      FROM public.profiles pr
     WHERE pr.tenant_id = p_books_tenant_id
       AND pr.profile_type = 'vendor'::public.profile_party_type
       AND pr.subject_id = p_ship.vendor_id
       AND pr.is_active = true
       AND pr.deleted_at IS NULL
     LIMIT 1;
    IF profile_id IS NULL THEN
      SELECT v.name INTO v_name FROM public.vendors v WHERE v.id = p_ship.vendor_id;
      profile_id := public.upsert_profile_for_party(
        p_books_tenant_id,
        'vendor'::public.profile_party_type,
        p_ship.vendor_id,
        COALESCE(v_name, 'Vendor #' || p_ship.vendor_id::text),
        NULL, NULL, '+880', NULL, false, NULL, true, NULL
      );
    END IF;
    RETURN;
  END IF;

  IF p_bucket IN ('freight'::public.global_shipment_cost_bucket, 'customs'::public.global_shipment_cost_bucket) THEN
    IF p_ship.cargo_company_id IS NULL THEN
      diagnostic := 'shipment cargo_company_id is required for freight/customs AP';
      RETURN;
    END IF;
    SELECT pr.id INTO profile_id
      FROM public.profiles pr
     WHERE pr.tenant_id = p_books_tenant_id
       AND pr.profile_type = 'cargo'::public.profile_party_type
       AND pr.subject_id = p_ship.cargo_company_id
       AND pr.is_active = true
       AND pr.deleted_at IS NULL
     LIMIT 1;
    IF profile_id IS NULL THEN
      SELECT c.name INTO v_name FROM public.cargo_companies c WHERE c.id = p_ship.cargo_company_id;
      profile_id := public.upsert_profile_for_party(
        p_books_tenant_id,
        'cargo'::public.profile_party_type,
        p_ship.cargo_company_id,
        COALESCE(v_name, 'Cargo #' || p_ship.cargo_company_id::text),
        NULL, NULL, '+880', NULL, false, NULL, true, NULL
      );
    END IF;
    RETURN;
  END IF;

  SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = p_books_tenant_id;
  profile_id := public.upsert_profile_for_party(
    p_books_tenant_id,
    'company'::public.profile_party_type,
    p_books_tenant_id,
    'Local opex',
    NULL, NULL, '+880', NULL, false, NULL, true, NULL
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_parent bigint;
  v_from_public bigint;
  v_from_kernel bigint;
  v_buckets text[] := ARRAY[
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ];
  v_bucket text;
  v_bucket_enum public.global_shipment_cost_bucket;
  v_to_public bigint;
  v_to_kernel bigint;
  v_diag text;
  v_payees jsonb := '{}'::jsonb;
BEGIN
  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.tenant_id;

  BEGIN
    v_from_public := public._shipment_cost_ap_ensure_public_from_profile(v_parent);
    v_from_kernel := money_kernel.ensure_profile_for_public_party(v_parent, v_from_public);
  EXCEPTION WHEN OTHERS THEN
  v_from_kernel := NULL;
  END;

  FOREACH v_bucket IN ARRAY v_buckets
  LOOP
    v_bucket_enum := v_bucket::public.global_shipment_cost_bucket;
    SELECT tp.profile_id, tp.diagnostic
      INTO v_to_public, v_diag
      FROM public._shipment_cost_ap_ensure_public_to_profile(v_parent, v_ship, v_bucket_enum) tp;

    v_to_kernel := NULL;
    IF v_to_public IS NOT NULL THEN
      BEGIN
        v_to_kernel := money_kernel.ensure_profile_for_public_party(v_parent, v_to_public);
      EXCEPTION WHEN OTHERS THEN
        v_diag := COALESCE(v_diag, SQLERRM);
      END;
    END IF;

    v_payees := v_payees || jsonb_build_object(
      v_bucket,
      jsonb_build_object(
        'profile_id', v_to_kernel,
        'public_profile_id', v_to_public,
        'ready', (v_to_kernel IS NOT NULL AND v_from_kernel IS NOT NULL),
        'diagnostic', v_diag
      )
    );
  END LOOP;

  RETURN jsonb_build_object(
    'books_tenant_id', v_parent,
    'from_profile_id', v_from_kernel,
    'from_public_profile_id', v_from_public,
    'payees_by_bucket', v_payees
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_cost_entry_ap_v2(p_cost_entry_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_entry public.global_shipment_cost_entries%ROWTYPE;
  v_ship public.global_shipments%ROWTYPE;
  v_parent bigint;
  v_parties jsonb;
  v_from_kernel bigint;
  v_to_kernel bigint;
  v_currency_code text;
  v_paper jsonb;
  v_amount numeric(18, 4);
  v_desc text;
  v_payload jsonb;
  v_result jsonb;
  v_bill_id bigint;
  v_invoice_no text;
  v_ap_kind text;
BEGIN
  IF p_cost_entry_id IS NULL THEN
    RAISE EXCEPTION 'cost_entry_id is required';
  END IF;

  SELECT * INTO v_entry
    FROM public.global_shipment_cost_entries
   WHERE id = p_cost_entry_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'cost entry not found';
  END IF;

  SELECT * INTO v_ship
    FROM public.global_shipments
   WHERE id = v_entry.shipment_id
   FOR UPDATE;

  v_parent := v_ship.tenant_id;

  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  PERFORM public._assert_shipment_cost_entry_mutable(p_cost_entry_id);

  IF COALESCE(v_entry.amount, 0) <= 0 THEN
    RAISE EXCEPTION 'cost amount must be greater than zero';
  END IF;

  IF COALESCE(v_entry.metadata->>'ap_bill_id', '') <> '' THEN
    RAISE EXCEPTION 'cost entry already has ap_bill_id';
  END IF;

  v_parties := public._resolve_shipment_cost_ap_kernel_parties(v_ship.id);
  v_from_kernel := NULLIF(v_parties->>'from_profile_id', '')::bigint;
  v_ap_kind := v_entry.cost_bucket::text;
  v_to_kernel := NULLIF(v_parties->'payees_by_bucket'->v_ap_kind->>'profile_id', '')::bigint;

  IF v_from_kernel IS NULL OR v_to_kernel IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: AP parties not ready for bucket % (% )',
      v_ap_kind,
      COALESCE(v_parties->'payees_by_bucket'->v_ap_kind->>'diagnostic', 'missing profile');
  END IF;

  SELECT upper(coalesce(gc.code, 'BDT')) INTO v_currency_code
    FROM public.global_currencies gc
   WHERE gc.id = COALESCE(
     v_entry.currency_id,
     v_ship.shipment_cost_currency_id,
     v_ship.shipment_purchase_currency_id
   );

  IF v_currency_code IS NULL OR v_currency_code = '' THEN
    v_currency_code := 'BDT';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM money_kernel.currencies c WHERE c.code = v_currency_code
  ) THEN
    RAISE EXCEPTION 'invalid_arguments: currency % not in money_kernel.currencies', v_currency_code;
  END IF;

  v_paper := public._build_shipment_ap_cost_entry_paper(v_entry, v_ship);
  v_amount := round(COALESCE((v_paper->>'foreign_total')::numeric, v_entry.amount), 2);

  v_desc := COALESCE(
    NULLIF(trim(v_entry.description), ''),
    NULLIF(trim(v_entry.metadata->>'description'), ''),
  initcap(replace(v_entry.cost_component::text, '_', ' '))
  );

  v_payload := jsonb_build_object(
    'tenant_id', v_parent,
    'kind', 'shipment_cost_ap',
    'source_type', 'shipment_cost',
    'source_id', v_ship.id::text,
    'source_key', 'entry:' || v_entry.id::text,
    'idempotency_key', 'shipment-' || v_ship.id::text || '-cost-entry-' || v_entry.id::text || '-issue',
    'currency_code', v_currency_code,
    'from_profile_id', v_from_kernel,
    'to_profile_id', v_to_kernel,
    'counterparty_profile_id', v_to_kernel,
    'auto_issue', true,
    'note', 'Shipment ' || COALESCE(v_ship.name, v_ship.id::text) || ' — '
            || initcap(v_ap_kind) || ' AP (entry:' || v_entry.id::text || ')',
    'meta', jsonb_build_object(
      'ap_kind', v_ap_kind,
      'shipment_id', v_ship.id,
      'ap_paper', v_paper
    ),
    'lines', jsonb_build_array(
      jsonb_build_object(
        'item_kind', 'charge',
        'description', v_desc,
        'quantity', 1,
        'unit_price', v_amount,
        'line_total', v_amount,
        'meta', jsonb_build_object('cost_entry_id', v_entry.id)
      )
    )
  );

  v_result := public.rpc_create_bill(v_payload);
  v_bill_id := NULLIF(v_result->>'bill_id', '')::bigint;
  v_invoice_no := v_result->>'invoice_no';

  IF v_bill_id IS NULL THEN
    RAISE EXCEPTION 'rpc_create_bill returned no bill_id';
  END IF;

  UPDATE public.global_shipment_cost_entries
     SET metadata = COALESCE(metadata, '{}'::jsonb)
       || jsonb_build_object(
         'ap_bill_id', v_bill_id,
         'ap_bill_issued_at', to_char(now() AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
         'money_kernel_v2', true
       ),
         updated_at = now()
   WHERE id = p_cost_entry_id;

  RETURN v_result || jsonb_build_object('cost_entry_id', p_cost_entry_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
  v_elem jsonb;
  v_slim jsonb := '[]'::jsonb;
begin
  select gs.tenant_id into v_parent
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

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  v_sid := p_shipment_id::text;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ce.id,
        'shipment_id', ce.shipment_id,
        'cost_bucket', ce.cost_bucket,
        'cost_component', ce.cost_component,
        'is_capitalizable', ce.is_capitalizable,
        'description', ce.description,
        'amount', ce.amount,
        'currency_id', ce.currency_id,
        'metadata', ce.metadata,
        'section_id', ce.section_id
      )
      order by ce.cost_bucket, ce.cost_component, ce.id
    ),
    '[]'::jsonb
  )
  into v_cost_entries
  from public.global_shipment_cost_entries ce
  where ce.shipment_id = p_shipment_id;

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
        'net_balances', v_elem->'net_balances'
      )
    );
  end loop;
  v_ap_bills := v_slim;

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  return jsonb_build_object(
    'cost_entries', v_cost_entries,
    'ap_bills', v_ap_bills,
    'ap_fx', v_ap_fx,
    'ap_issue_parties', public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id)
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_money_kernel_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bundle jsonb;
  v_ap_bills jsonb;
  v_enriched jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_bill_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  v_bundle := public.get_shipment_settings_finance_bundle(p_shipment_id);
  v_ap_bills := coalesce(v_bundle->'ap_bills', '[]'::jsonb);

  for v_elem in select value from jsonb_array_elements(v_ap_bills)
  loop
    v_bill_id := nullif(v_elem->>'id', '')::bigint;
    if v_bill_id is not null then
      v_enriched := v_enriched || jsonb_build_array(
        v_elem || jsonb_build_object('net_balances', public.get_bill_net_balances(v_bill_id))
      );
    else
      v_enriched := v_enriched || jsonb_build_array(v_elem);
    end if;
  end loop;

  return v_bundle
    || jsonb_build_object('ap_bills', v_enriched)
    || jsonb_build_object(
      'kernel',
      jsonb_build_object(
        'source_type', 'shipment_cost',
        'source_id', p_shipment_id::text,
        'pay_out_rpc', 'post_shipment_ap_money_out',
        'issue_rpc', 'issue_shipment_cost_entry_ap_v2'
      )
    );
end;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_overview_details (
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent bigint;
  v_ship jsonb;
  v_sections jsonb;
  v_items jsonb;
  v_boxes jsonb;
  v_cost_entries jsonb;
  v_flow_stages jsonb;
  v_progress_flow_id bigint;
  v_ap_fx jsonb;
  v_item_outcomes jsonb;
  v_outcome_vendor_credits jsonb;
  v_batch_code_list jsonb;
  v_batch_code_items jsonb;
  v_batch_list_id bigint;
begin
  select tenant_id, progress_flow_id, to_jsonb(s.*)
  into v_parent, v_progress_flow_id, v_ship
  from public.global_shipments s
  where s.id = p_shipment_id;

  if v_ship is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  -- Ensure cost entries from header are synced
  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  perform public.ensure_global_shipment_default_section(p_shipment_id);

  -- 1. Sections with vendor info
  select coalesce(
    jsonb_agg(
      to_jsonb(sec.*) || jsonb_build_object('vendor', to_jsonb(v.*))
      order by sec.sort_order asc, sec.id asc
    ),
    '[]'::jsonb
  )
  into v_sections
  from public.global_shipment_sections sec
  left join public.vendors v on v.id = sec.vendor_id
  where sec.shipment_id = p_shipment_id;

  -- 2. Items
  select coalesce(
    jsonb_agg(
      to_jsonb(i.*)
      order by coalesce(i.sort_order, 0) asc, i.id asc
    ),
    '[]'::jsonb
  )
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = p_shipment_id;

  -- 3. Boxes
  select coalesce(
    jsonb_agg(
      to_jsonb(b.*)
      order by b.box_number asc, b.id asc
    ),
    '[]'::jsonb
  )
  into v_boxes
  from public.global_shipment_boxes b
  where b.shipment_id = p_shipment_id;

  -- 4. Cost entries (narrow projection)
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ce.id,
        'shipment_id', ce.shipment_id,
        'cost_bucket', ce.cost_bucket,
        'cost_component', ce.cost_component,
        'is_capitalizable', ce.is_capitalizable,
        'description', ce.description,
        'amount', ce.amount,
        'currency_id', ce.currency_id,
        'metadata', ce.metadata,
        'section_id', ce.section_id
      )
      order by ce.cost_bucket asc, ce.cost_component asc, ce.id asc
    ),
    '[]'::jsonb
  )
  into v_cost_entries
  from public.global_shipment_cost_entries ce
  where ce.shipment_id = p_shipment_id;

  -- 5. Flow stages if flow assigned
  if v_progress_flow_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'flow_stage_id', st.id,
          'flow_id', st.flow_id,
          'tag_id', st.tag_id,
          'sort_order', st.sort_order,
          'name', coalesce(t.name, ''),
          'slug', coalesce(t.slug, ''),
          'color', t.color,
          'is_active', coalesce(t.is_active, true)
        )
        order by st.sort_order asc
      ),
      '[]'::jsonb
    )
    into v_flow_stages
    from public.shipment_progress_flow_stages st
    join public.tags t on t.id = st.tag_id
    where st.flow_id = v_progress_flow_id and t.is_active = true;
  else
    v_flow_stages := '[]'::jsonb;
  end if;

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'tenant_id', o.tenant_id,
        'shipment_item_id', o.shipment_item_id,
        'quantity', o.quantity,
        'kind', o.kind,
        'reason', o.reason,
        'purchase_price', o.purchase_price,
        'cost', o.cost,
        'description', o.description,
        'batch_label', o.batch_label
      )
      order by o.id asc
    ),
    '[]'::jsonb
  )
  into v_item_outcomes
  from public.global_shipment_item_outcomes o
  inner join public.global_shipment_items i on i.id = o.shipment_item_id
  where i.shipment_id = p_shipment_id;

  select coalesce(
    (
      select jsonb_agg(row_to_json(r) order by r.created_at desc)
      from (
        select
          c.id,
          c.shipment_id,
          c.shipment_item_id,
          c.outcome_id,
          c.quantity,
          c.previous_purchase_price,
          c.new_purchase_price,
          c.credit_amount,
          c.created_by_email,
          c.created_at,
          gsi.name as item_name
        from public.global_shipment_outcome_vendor_credits c
        inner join public.global_shipment_items gsi on gsi.id = c.shipment_item_id
        where c.shipment_id = p_shipment_id
      ) r
    ),
    '[]'::jsonb
  )
  into v_outcome_vendor_credits;

  v_batch_list_id := null;
  v_batch_code_list := null;
  v_batch_code_items := '[]'::jsonb;

  select to_jsonb(bcl.*), bcl.id
  into v_batch_code_list, v_batch_list_id
  from public.batch_code_lists bcl
  where bcl.shipment_id = p_shipment_id;

  if v_batch_list_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', bci.id,
          'list_id', bci.list_id,
          'barcode', bci.barcode,
          'product_code', bci.product_code,
          'batch_id', bci.batch_id,
          'manufacturing_date', bci.manufacturing_date,
          'expire_date', bci.expire_date,
          'is_arrived', bci.is_arrived
        )
        order by bci.id asc
      ),
      '[]'::jsonb
    )
    into v_batch_code_items
    from public.batch_code_items bci
    where bci.list_id = v_batch_list_id;
  end if;

  return jsonb_build_object(
    'shipment', v_ship,
    'sections', v_sections,
    'items', v_items,
    'boxes', v_boxes,
    'cost_entries', v_cost_entries,
    'flow_stages', v_flow_stages,
    'ap_fx', v_ap_fx,
    'ap_issue_parties', public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id),
    'item_outcomes', v_item_outcomes,
    'outcome_vendor_credits', v_outcome_vendor_credits,
    'batch_code_list', v_batch_code_list,
    'batch_code_items', v_batch_code_items
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_shipment_overview_details(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_shipment_overview_details(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_shipment_overview_details(bigint) TO service_role;