-- public.bills / bill_lines are views: create_sales_invoice + issue_bill must use money_kernel RPCs.

CREATE OR REPLACE FUNCTION public.create_sales_invoice(
  p_tenant_id bigint,
  p_invoice_no text DEFAULT NULL,
  p_invoice_type public.global_invoice_type DEFAULT 'wholesale'::public.global_invoice_type,
  p_profile_id bigint DEFAULT NULL,
  p_recipient_profile_id bigint DEFAULT NULL,
  p_recipient_name text DEFAULT NULL,
  p_recipient_phone text DEFAULT NULL,
  p_recipient_address text DEFAULT NULL,
  p_retail_billing_mode public.retail_billing_mode DEFAULT NULL,
  p_due_date date DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_invoice_date date DEFAULT NULL
) RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_tenant_id bigint;
  v_tenant_self bigint;
  v_kind text;
  v_invoice_date date := coalesce(p_invoice_date, CURRENT_DATE);
  v_collection_source public.collection_source_type;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_rec_name text;
  v_rec_phone text;
  v_rec_address text;
  v_bill_name text;
  v_bill_phone text;
  v_bill_address text;
  v_rpc jsonb;
  v_bill_id bigint;
  v_row public.bills;
  v_from bigint;
  v_to bigint;
BEGIN
  v_books_tenant_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.user_can_manage_books_tenant(v_books_tenant_id)
    OR EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = v_books_tenant_id)
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
        AND m.role IN ('admin', 'staff', 'owner')
    )
    OR public.is_superadmin()
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_profile_id IS NOT NULL AND NOT public.profile_valid_for_issuer(p_profile_id, p_tenant_id) THEN
    RAISE EXCEPTION 'billing profile not accessible for this tenant';
  END IF;

  IF p_recipient_profile_id IS NOT NULL
     AND NOT public.recipient_profile_valid_for_issuer(p_recipient_profile_id, p_tenant_id) THEN
    RAISE EXCEPTION 'recipient profile not accessible for this tenant';
  END IF;

  v_kind := public._kernel_invoice_type_to_bill_kind(p_invoice_type);
  IF v_kind IS NULL THEN
    RAISE EXCEPTION 'unsupported invoice_type %', p_invoice_type;
  END IF;

  IF p_invoice_type = 'wholesale'::public.global_invoice_type THEN
    IF p_profile_id IS NULL THEN
      RAISE EXCEPTION 'billing profile is required for wholesale invoices';
    END IF;
    IF p_retail_billing_mode IS NOT NULL THEN
      RAISE EXCEPTION 'retail billing mode must be null for wholesale invoices';
    END IF;
    v_collection_source := 'profile'::public.collection_source_type;
  ELSIF p_invoice_type = 'retail'::public.global_invoice_type THEN
    IF p_retail_billing_mode IS NULL THEN
      RAISE EXCEPTION 'retail billing mode (account or direct) is required for retail invoices';
    END IF;
    IF p_retail_billing_mode = 'account'::public.retail_billing_mode THEN
      IF p_profile_id IS NULL THEN
        RAISE EXCEPTION 'billing profile is required for retail account invoices';
      END IF;
      v_collection_source := 'profile'::public.collection_source_type;
    ELSE
      IF p_profile_id IS NOT NULL THEN
        RAISE EXCEPTION 'billing profile must be null for retail direct invoices';
      END IF;
      v_collection_source := 'recipient'::public.collection_source_type;
    END IF;
  ELSIF p_invoice_type = 'dropship'::public.global_invoice_type THEN
    IF p_profile_id IS NULL THEN
      RAISE EXCEPTION 'billing profile (middle man) is required for dropship invoices';
    END IF;
    IF p_retail_billing_mode IS NOT NULL THEN
      RAISE EXCEPTION 'retail billing mode must be null for dropship invoices';
    END IF;
    v_collection_source := 'profile'::public.collection_source_type;
  ELSIF p_invoice_type = 'ap'::public.global_invoice_type THEN
    IF p_profile_id IS NULL THEN
      RAISE EXCEPTION 'payee profile_id is required for AP bills';
    END IF;
    v_collection_source := 'profile'::public.collection_source_type;
  END IF;

  IF p_recipient_profile_id IS NOT NULL THEN
    SELECT name, phone, address
    INTO v_rec_name, v_rec_phone, v_rec_address
    FROM public.recipient_profiles
    WHERE id = p_recipient_profile_id;
  END IF;

  v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_rec_name);
  v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_rec_phone);
  v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_rec_address);

  IF p_invoice_type = 'wholesale'::public.global_invoice_type AND p_profile_id IS NOT NULL THEN
    SELECT name, phone, address
    INTO v_bill_name, v_bill_phone, v_bill_address
    FROM public.profiles
    WHERE id = p_profile_id;

    v_recipient_name := coalesce(v_recipient_name, v_bill_name);
    v_recipient_phone := coalesce(v_recipient_phone, v_bill_phone);
    v_recipient_address := coalesce(v_recipient_address, v_bill_address);
  END IF;

  v_tenant_self := public._kernel_tenant_mirror_profile_id(v_books_tenant_id);
  IF v_tenant_self IS NULL THEN
    RAISE EXCEPTION 'tenant billing profile is required';
  END IF;

  -- Match compose adapters: counterparty on from, tenant books on to.
  v_from := coalesce(p_profile_id, v_tenant_self);
  v_to := v_tenant_self;

  v_rpc := public.rpc_create_bill(jsonb_strip_nulls(jsonb_build_object(
    'tenant_id', v_books_tenant_id,
    'kind', v_kind,
    'currency_code', 'BDT',
    'from_profile_id', v_from,
    'to_profile_id', v_to,
    'counterparty_profile_id', p_profile_id,
    'invoice_date', v_invoice_date,
    'due_date', p_due_date,
    'note', coalesce(
      nullif(trim(p_note), ''),
      nullif(trim(p_invoice_no), ''),
      format('Draft %s', p_invoice_type::text)
    ),
    'auto_issue', false,
    'meta', jsonb_strip_nulls(jsonb_build_object(
      'delivery_kind', 'take',
      'retail_billing_mode', p_retail_billing_mode,
      'recipient_name', v_recipient_name,
      'recipient_phone', v_recipient_phone,
      'recipient_address', v_recipient_address,
      'collection_source', v_collection_source,
      'requested_invoice_no', nullif(trim(p_invoice_no), ''),
      'subtotal_amount', 0
    )),
    -- Kernel requires ≥1 line; placeholder until caller syncs real lines / uses rpc_update.
    'lines', jsonb_build_array(jsonb_build_object(
      'item_kind', 'charge',
      'description', 'Draft placeholder',
      'quantity', 1,
      'unit_price', 0,
      'line_total', 0
    ))
  )));

  v_bill_id := nullif(v_rpc->>'bill_id', '')::bigint;
  IF v_bill_id IS NULL THEN
    RAISE EXCEPTION '%', coalesce(v_rpc->>'error', 'rpc_create_bill failed');
  END IF;

  PERFORM public.stamp_bill_kernel_fields(v_bill_id);
  SELECT * INTO v_row FROM public.bills WHERE id = v_bill_id;
  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_sales_invoice(
  bigint, text, public.global_invoice_type, bigint, bigint, text, text, text,
  public.retail_billing_mode, date, text, date
) TO authenticated, service_role;

-- issue_bill must not UPDATE the public.bills view.
CREATE OR REPLACE FUNCTION public.issue_bill(p_bill_id bigint)
RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_kernel money_kernel.bills;
  v_bill public.bills;
  v_shipment_id bigint;
  v_invoice_type text;
BEGIN
  SELECT * INTO v_kernel
  FROM money_kernel.bills
  WHERE id = p_bill_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  IF v_kernel.status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'only draft bills can be issued';
  END IF;

  IF NOT public.user_can_manage_books_tenant(v_kernel.tenant_id) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_invoice_type := public._desk_kernel_kind_invoice_type(v_kernel.kind);
  IF v_invoice_type = 'ap' THEN
    v_shipment_id := nullif(v_kernel.meta->>'shipment_id', '')::bigint;
    IF v_shipment_id IS NULL AND v_kernel.source_type = 'shipment_cost' THEN
      v_shipment_id := nullif(btrim(v_kernel.source_id), '')::bigint;
    END IF;
    IF v_shipment_id IS NOT NULL THEN
      PERFORM public._assert_shipment_ap_issue_allowed(v_shipment_id);
    END IF;
  END IF;

  PERFORM public._kernel_backfill_stock_bill_lines(p_bill_id);
  PERFORM public.rpc_issue_bill(v_kernel.tenant_id, p_bill_id);
  PERFORM public._kernel_freeze_bill_txn_face(p_bill_id);

  SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found after issue';
  END IF;
  RETURN v_bill;
END;
$$;

GRANT EXECUTE ON FUNCTION public.issue_bill(bigint) TO authenticated, service_role;
