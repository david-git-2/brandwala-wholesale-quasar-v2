-- document numbering

CREATE TABLE IF NOT EXISTS "public"."document_number_configs" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "doc_type" "text" NOT NULL,
    "prefix" "text" NOT NULL,
    "sub_type_mode" "text" DEFAULT 'none'::"text" NOT NULL,
    "sub_type_literal" "text",
    "date_format" "text",
    "period" "text" NOT NULL,
    "padding" smallint DEFAULT 4 NOT NULL,
    "separator" "text" DEFAULT '-'::"text" NOT NULL,
    "timezone" "text" DEFAULT 'UTC'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    CONSTRAINT "document_number_configs_padding_check" CHECK (("padding" >= 1)),
    CONSTRAINT "document_number_configs_period_check" CHECK (("period" = ANY (ARRAY['day'::"text", 'month'::"text", 'year'::"text", 'none'::"text"]))),
    CONSTRAINT "document_number_configs_sub_type_mode_check" CHECK (("sub_type_mode" = ANY (ARRAY['none'::"text", 'invoice_type'::"text", 'literal'::"text"])))
);


ALTER TABLE "public"."document_number_configs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."document_number_configs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."document_number_configs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."document_number_configs_id_seq" OWNED BY "public"."document_number_configs"."id";



CREATE TABLE IF NOT EXISTS "public"."document_number_counters" (
    "tenant_id" bigint NOT NULL,
    "doc_type" "text" NOT NULL,
    "sub_type" "text" DEFAULT ''::"text" NOT NULL,
    "period_key" "text" NOT NULL,
    "last_value" bigint DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "document_number_counters_last_value_check" CHECK (("last_value" >= 0))
);


ALTER TABLE "public"."document_number_counters" OWNER TO "postgres";



CREATE SEQUENCE IF NOT EXISTS "public"."document_number_configs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."document_number_configs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."document_number_configs_id_seq" OWNED BY "public"."document_number_configs"."id";

ALTER TABLE ONLY "public"."document_number_configs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."document_number_configs_id_seq"'::"regclass");

ALTER TABLE ONLY "public"."document_number_configs"
    ADD CONSTRAINT "document_number_configs_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."document_number_counters"
    ADD CONSTRAINT "document_number_counters_pkey" PRIMARY KEY ("tenant_id", "doc_type", "sub_type", "period_key");

CREATE UNIQUE INDEX "document_number_configs_default_doc_type_idx" ON "public"."document_number_configs" USING "btree" ("doc_type") WHERE ("tenant_id" IS NULL);

CREATE UNIQUE INDEX "document_number_configs_tenant_doc_type_idx" ON "public"."document_number_configs" USING "btree" ("tenant_id", "doc_type") WHERE ("tenant_id" IS NOT NULL);

ALTER TABLE ONLY "public"."document_number_configs"
    ADD CONSTRAINT "document_number_configs_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."document_number_counters"
    ADD CONSTRAINT "document_number_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

CREATE OR REPLACE TRIGGER "trg_document_number_counters_set_updated_at" BEFORE UPDATE ON "public"."document_number_counters" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

-- Default document_number_configs (run once; safe to re-run via NOT EXISTS).

INSERT INTO public.document_number_configs (
  tenant_id, doc_type, prefix, sub_type_mode, period, padding, separator, timezone, is_active
)
SELECT v.*
FROM (
  VALUES
    (NULL::bigint, 'shop_order', 'SO', 'none', 'day', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'sales_invoice', 'INV', 'invoice_type', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'credit_note', 'CN', 'invoice_type', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'debit_note', 'DN', 'invoice_type', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'ap_bill', 'AP', 'none', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'dropship_b2b_invoice', 'DS', 'none', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'shipment', 'SHP', 'none', 'none', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'stock_movement', 'MOV', 'none', 'day', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'stock_movement_manual', 'SM', 'none', 'day', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'receive_putaway', 'RP', 'none', 'day', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'vendor_return', 'VR', 'none', 'day', 4::smallint, '-', 'UTC', true)
) AS v(tenant_id, doc_type, prefix, sub_type_mode, period, padding, separator, timezone, is_active)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.document_number_configs c
  WHERE c.tenant_id IS NULL AND c.doc_type = v.doc_type
);


CREATE OR REPLACE FUNCTION "public"."_document_number_tenant_timezone"("p_tenant_id" bigint, "p_fallback" "text" DEFAULT 'UTC'::"text") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT COALESCE(
    NULLIF(btrim(t.preference->>'timezone'), ''),
    NULLIF(btrim(p_fallback), ''),
    'UTC'::text
  )
  FROM public.tenants t
  WHERE t.id = p_tenant_id;
$$;

CREATE OR REPLACE FUNCTION "public"."_resolve_document_number_config"("p_tenant_id" bigint, "p_doc_type" "text") RETURNS "public"."document_number_configs"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  cfg public.document_number_configs%ROWTYPE;
BEGIN
  SELECT * INTO cfg
  FROM public.document_number_configs
  WHERE doc_type = p_doc_type
    AND is_active
    AND (tenant_id = p_tenant_id OR tenant_id IS NULL)
  ORDER BY tenant_id NULLS LAST
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'no number config for doc_type=%', p_doc_type;
  END IF;

  RETURN cfg;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."_document_number_format"("cfg" "public"."document_number_configs", "p_sub_type" "text", "p_period" "text", "p_seq" bigint) RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_sub text;
BEGIN
  v_sub := CASE cfg.sub_type_mode
    WHEN 'invoice_type'::text THEN upper(COALESCE(p_sub_type, ''))
    WHEN 'literal'::text THEN COALESCE(cfg.sub_type_literal, '')
    ELSE ''
  END;

  RETURN concat_ws(
    cfg.separator,
    cfg.prefix,
    NULLIF(v_sub, ''),
    NULLIF(p_period, ''),
    lpad(p_seq::text, cfg.padding, '0')
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."map_global_invoice_type_to_sub_type"("p_invoice_type" "public"."global_invoice_type") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
BEGIN
  CASE p_invoice_type
    WHEN 'wholesale'::public.global_invoice_type THEN RETURN 'WS';
    WHEN 'retail'::public.global_invoice_type THEN RETURN 'RT';
    WHEN 'dropship'::public.global_invoice_type THEN RETURN 'DS';
    ELSE RAISE EXCEPTION 'invoice_type % cannot map to document sub_type', p_invoice_type;
  END CASE;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."next_document_number"("p_tenant_id" bigint, "p_doc_type" "text", "p_sub_type" "text" DEFAULT NULL::"text", "p_at" timestamp with time zone DEFAULT "now"()) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  cfg public.document_number_configs%ROWTYPE;
  v_tz text;
  v_local timestamp;
  v_period text;
  v_sub text;
  v_seq bigint;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  IF p_doc_type IS NULL OR btrim(p_doc_type) = '' THEN
    RAISE EXCEPTION 'doc_type is required';
  END IF;

  cfg := public._resolve_document_number_config(p_tenant_id, p_doc_type);
  v_tz := public._document_number_tenant_timezone(p_tenant_id, cfg.timezone);
  v_local := p_at AT TIME ZONE v_tz;

  v_period := CASE cfg.period
    WHEN 'day'::text THEN to_char(v_local, 'YYMMDD')
    WHEN 'month'::text THEN to_char(v_local, 'YYMM')
    WHEN 'year'::text THEN to_char(v_local, 'YYYY')
    ELSE ''
  END;

  v_sub := CASE cfg.sub_type_mode
    WHEN 'invoice_type'::text THEN upper(COALESCE(p_sub_type, ''))
    WHEN 'literal'::text THEN COALESCE(cfg.sub_type_literal, '')
    ELSE ''
  END;

  INSERT INTO public.document_number_counters (tenant_id, doc_type, sub_type, period_key, last_value)
  VALUES (p_tenant_id, p_doc_type, v_sub, v_period, 1)
  ON CONFLICT (tenant_id, doc_type, sub_type, period_key)
  DO UPDATE
    SET last_value = public.document_number_counters.last_value + 1,
        updated_at = now()
  RETURNING last_value INTO v_seq;

  RETURN public._document_number_format(cfg, p_sub_type, v_period, v_seq);
END;
$$;

CREATE OR REPLACE FUNCTION "public"."peek_document_number"("p_tenant_id" bigint, "p_doc_type" "text", "p_sub_type" "text" DEFAULT NULL::"text", "p_at" timestamp with time zone DEFAULT "now"()) RETURNS "text"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  cfg public.document_number_configs%ROWTYPE;
  v_tz text;
  v_local timestamp;
  v_period text;
  v_sub text;
  v_seq bigint;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  cfg := public._resolve_document_number_config(p_tenant_id, p_doc_type);
  v_tz := public._document_number_tenant_timezone(p_tenant_id, cfg.timezone);
  v_local := p_at AT TIME ZONE v_tz;

  v_period := CASE cfg.period
    WHEN 'day'::text THEN to_char(v_local, 'YYMMDD')
    WHEN 'month'::text THEN to_char(v_local, 'YYMM')
    WHEN 'year'::text THEN to_char(v_local, 'YYYY')
    ELSE ''
  END;

  v_sub := CASE cfg.sub_type_mode
    WHEN 'invoice_type'::text THEN upper(COALESCE(p_sub_type, ''))
    WHEN 'literal'::text THEN COALESCE(cfg.sub_type_literal, '')
    ELSE ''
  END;

  SELECT c.last_value + 1 INTO v_seq
  FROM public.document_number_counters c
  WHERE c.tenant_id = p_tenant_id
    AND c.doc_type = p_doc_type
    AND c.sub_type = v_sub
    AND c.period_key = v_period;

  v_seq := COALESCE(v_seq, 1);

  RETURN public._document_number_format(cfg, p_sub_type, v_period, v_seq);
END;
$$;

CREATE OR REPLACE FUNCTION "public"."next_stock_movement_number"("p_tenant_id" bigint, "p_doc_type" "text" DEFAULT 'stock_movement'::"text") RETURNS "text"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT public.next_document_number(p_tenant_id, p_doc_type, NULL::text, now());
$$;

CREATE OR REPLACE FUNCTION "public"."backfill_document_number_counters_from_sales_invoice_counters"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count integer := 0;
BEGIN
  INSERT INTO public.document_number_counters (tenant_id, doc_type, sub_type, period_key, last_value)
  SELECT
    sic.tenant_id,
    'sales_invoice',
    CASE sic.invoice_type
      WHEN 'wholesale'::public.global_invoice_type THEN 'WS'
      WHEN 'retail'::public.global_invoice_type THEN 'RT'
      WHEN 'dropship'::public.global_invoice_type THEN 'DS'
      ELSE 'WS'
    END,
    substring(sic.date_key from 3 for 4),
    sic.last_value
  FROM public.sales_invoice_counters sic
  WHERE sic.invoice_type <> 'ap'::public.global_invoice_type
  ON CONFLICT (tenant_id, doc_type, sub_type, period_key)
  DO UPDATE SET last_value = GREATEST(public.document_number_counters.last_value, EXCLUDED.last_value);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."backfill_document_number_counters_from_tenant_shipments"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count integer := 0;
BEGIN
  INSERT INTO public.document_number_counters (tenant_id, doc_type, sub_type, period_key, last_value)
  SELECT
    gs.tenant_id,
    'shipment',
    '',
    '',
    GREATEST(
      coalesce(max(gs.tenant_shipment_id), 0),
      coalesce((
        SELECT tsc.last_value
        FROM public.tenant_scoped_counters tsc
        WHERE tsc.tenant_id = gs.tenant_id
          AND tsc.scope = 'shipment'
      ), 0)
    )
  FROM public.global_shipments gs
  WHERE gs.tenant_id IS NOT NULL
  GROUP BY gs.tenant_id
  ON CONFLICT (tenant_id, doc_type, sub_type, period_key)
  DO UPDATE SET last_value = GREATEST(public.document_number_counters.last_value, EXCLUDED.last_value);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."generate_sales_invoice_number"("p_tenant_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_date" "date" DEFAULT CURRENT_DATE) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_at timestamptz;
  v_sub text;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  IF p_invoice_type IS NULL THEN
    RAISE EXCEPTION 'invoice_type is required';
  END IF;

  v_at := (COALESCE(p_date, CURRENT_DATE)::timestamp AT TIME ZONE public._document_number_tenant_timezone(p_tenant_id, 'UTC'));

  IF p_invoice_type = 'ap'::public.global_invoice_type THEN
    RETURN public.next_document_number(p_tenant_id, 'ap_bill', NULL::text, v_at);
  END IF;

  v_sub := public.map_global_invoice_type_to_sub_type(p_invoice_type);
  RETURN public.next_document_number(p_tenant_id, 'sales_invoice', v_sub, v_at);
END;
$$;

CREATE OR REPLACE FUNCTION "public"."generate_shop_order_number"("p_tenant_id" bigint, "p_shop_id" bigint) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return public.next_document_number(p_tenant_id, 'shop_order', null::text, now());
end;
$$;

CREATE OR REPLACE FUNCTION "public"."assign_tenant_shipment_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_code text;
begin
  if new.tenant_id is null then
    raise exception 'tenant_id is required for shipments';
  end if;

  if tg_op = 'UPDATE' and new.tenant_id <> old.tenant_id then
    raise exception 'changing shipment tenant_id is not allowed';
  end if;

  if new.tenant_shipment_id is null then
    v_code := public.next_document_number(new.tenant_id, 'shipment', null::text, now());
    new.tenant_shipment_id := split_part(v_code, '-', 2)::integer;
  end if;

  return new;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."next_tenant_scoped_counter"("p_tenant_id" bigint, "p_scope" "text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_next bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if p_scope not in ('shipment', 'order') then
    raise exception 'invalid scope: %', p_scope;
  end if;

  if p_scope = 'shipment' then
    return split_part(
      public.next_document_number(p_tenant_id, 'shipment', null::text, now()),
      '-',
      2
    )::bigint;
  end if;

  insert into public.tenant_scoped_counters (tenant_id, scope, last_value)
  values (p_tenant_id, p_scope, 1)
  on conflict (tenant_id, scope)
  do update
    set last_value = public.tenant_scoped_counters.last_value + 1
  returning last_value into v_next;

  return v_next;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."create_and_post_stock_movement"("p_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer, "p_to_location_id" bigint DEFAULT NULL::bigint, "p_to_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_to_grade_tag_id" bigint DEFAULT NULL::bigint, "p_movement_type" "public"."stock_movement_type" DEFAULT 'grade_change'::"public"."stock_movement_type", "p_notes" "text" DEFAULT NULL::"text", "p_reference_type" "text" DEFAULT NULL::"text", "p_reference_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stock public.global_stocks%rowtype;
  v_mov_id bigint;
  v_mov_no text;
  v_is_customer_return boolean;
begin
  if not public.can_act_on_stock_movement_context(p_tenant_id, p_reference_type, p_reference_id) then
    raise exception 'not authorized';
  end if;

  select * into v_stock
  from public.global_stocks
  where id = p_stock_id
    and parent_tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'stock % not found', p_stock_id;
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be > 0';
  end if;

  v_is_customer_return := (
    p_movement_type = 'return_inbound'::public.stock_movement_type
    and coalesce(p_reference_type, '') is distinct from 'shipment_return'
  );

  if not v_is_customer_return and v_stock.quantity < p_quantity then
    raise exception 'insufficient stock quantity (requested %, available %)', p_quantity, v_stock.quantity;
  end if;

  v_mov_no := public.next_stock_movement_number(p_tenant_id, 'stock_movement');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    p_tenant_id,
    v_mov_no,
    p_movement_type,
    coalesce(p_reference_type, 'global_stock'),
    coalesce(p_reference_id, p_stock_id::text),
    p_notes,
    public.current_user_email(),
    false,
    null
  )
  returning id into v_mov_id;

  insert into public.stock_movement_lines (
    movement_id,
    stock_id,
    quantity,
    from_location_id,
    to_location_id,
    from_availability,
    to_availability,
    from_grade_tag_id,
    to_grade_tag_id
  ) values (
    v_mov_id,
    p_stock_id,
    p_quantity,
    v_stock.location_id,
    case
      when v_is_customer_return then coalesce(
        p_to_location_id,
        public.default_returns_stock_location_id(p_tenant_id)
      )
      else coalesce(p_to_location_id, v_stock.location_id)
    end,
    v_stock.availability,
    case
      when v_is_customer_return then coalesce(p_to_availability, 'held'::public.stock_availability)
      else coalesce(p_to_availability, v_stock.availability)
    end,
    v_stock.grade_tag_id,
    coalesce(p_to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  );

  perform public.post_stock_movement(v_mov_id);

  return jsonb_build_object(
    'success', true,
    'movement_id', v_mov_id,
    'movement_no', v_mov_no
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."create_stock_movement"("p_tenant_id" bigint, "p_movement_type" "public"."stock_movement_type", "p_notes" "text" DEFAULT NULL::"text", "p_reference_type" "text" DEFAULT NULL::"text", "p_reference_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_mov public.stock_movements%rowtype;
  v_no text;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_no := public.next_stock_movement_number(p_tenant_id, 'stock_movement_manual');

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    p_tenant_id,
    v_no,
    p_movement_type,
    p_reference_type,
    p_reference_id,
    p_notes,
    public.current_user_email()
  )
  returning * into v_mov;

  return jsonb_build_object('movement', to_jsonb(v_mov));
end;
$$;

CREATE OR REPLACE FUNCTION "public"."build_dropship_tenant_b2b_invoice_payload"("p_order_id" bigint, "p_invoice_id" bigint DEFAULT NULL::bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_profile_id bigint;
  v_invoice_no text;
  v_pick record;
  v_items jsonb := '[]'::jsonb;
  v_item_json jsonb;
  v_item_sell_price numeric(12,2);
  v_resell_price numeric(12,2);
  v_unit_cost numeric(12,2);
  v_line_id bigint;
  v_held public.global_stocks;
  v_charges record;
  v_channel_meta jsonb;
  v_gift record;
  v_gift_stock_id bigint;
  v_gift_shipment_item_id bigint;
  v_gift_name text;
  v_gift_barcode text;
  v_gift_product_code text;
  v_gift_assigned_child bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in (
    'ready_for_pickup'::public.shop_order_status,
    'shipped'::public.shop_order_status,
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'tenant B2B invoice requires ready_for_pickup, shipped, or delivered (current: %s)',
        v_order.status
      )
    );
  end if;

  v_profile_id := coalesce(p_profile_id, v_order.profile_id);
  if v_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required on the order');
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := public.next_document_number(v_order.tenant_id, 'dropship_b2b_invoice', null::text, now());
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  v_channel_meta := jsonb_strip_nulls(jsonb_build_object(
    'cod_collect_amount', v_order.cod_collect_amount,
    'collection_source', 'profile',
    'recipient_name', coalesce(v_order.recipient_name, v_order.name),
    'recipient_phone', v_order.recipient_phone,
    'recipient_address', v_order.shipping_address
  ));

  select * into v_charges
  from public.get_dropship_merchant_billable_charges(p_order_id);

  for v_pick in (
    select
      sp.id as pick_id,
      sp.order_item_id,
      sp.quantity as pick_quantity,
      sp.held_stock_id,
      sp.global_stock_id as source_stock_id,
      soi.product_id,
      soi.name as line_name,
      soi.unit_sell_price_amount,
      soi.final_price_amount,
      soi.customer_sell_price_amount,
      coalesce(soi.is_gift, false) as is_gift,
      soi.gift_source,
      coalesce(soi.gift_cost_amount, 0) as gift_cost_amount,
      soi.gift_cost_charged_to,
      gs.shipment_item_id as stock_shipment_item_id,
      coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0) as stock_cost,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code,
      sh.assigned_child_tenant_id as stock_assigned_child
    from public.shop_order_item_stock_picks sp
    join public.shop_order_items soi on soi.id = sp.order_item_id
    left join public.global_stocks gs on gs.id = sp.held_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where sp.order_id = v_order.id
      and sp.quantity > 0
      and coalesce(soi.is_fulfillment_unavailable, false) = false
  ) loop
    if v_pick.held_stock_id is null then
      return jsonb_build_object(
        'success', false,
        'error', format('pick %s is missing held_stock_id', v_pick.pick_id)
      );
    end if;

    select * into v_held from public.global_stocks where id = v_pick.held_stock_id;
    if v_held.id is null then
      return jsonb_build_object(
        'success', false,
        'error', format('held stock %s not found for pick %s', v_pick.held_stock_id, v_pick.pick_id)
      );
    end if;

    if v_held.availability <> 'held'::public.stock_availability then
      return jsonb_build_object(
        'success', false,
        'error', format('held stock %s must be held before issue (current: %s)', v_pick.held_stock_id, v_held.availability)
      );
    end if;

    if coalesce(v_pick.is_gift, false) and v_pick.gift_source = 'stock' and v_pick.gift_cost_charged_to = 'reseller' then
      v_item_sell_price := case
        when coalesce(v_pick.pick_quantity, 0) > 0 then
          round(coalesce(v_pick.gift_cost_amount, 0) / v_pick.pick_quantity, 2)
        else coalesce(v_pick.gift_cost_amount, 0)
      end;
    else
      v_item_sell_price := coalesce(v_pick.unit_sell_price_amount, v_pick.final_price_amount, 0);
    end if;
    v_resell_price := coalesce(
      v_pick.customer_sell_price_amount,
      v_pick.final_price_amount,
      v_pick.unit_sell_price_amount,
      0
    );
    v_unit_cost := coalesce(v_pick.stock_cost, 0);
    v_line_id := null;

    if p_invoice_id is not null then
      select sii.id into v_line_id
      from public.bill_lines sii
      where sii.invoice_id = p_invoice_id
        and sii.global_stock_id = v_pick.held_stock_id
      order by sii.id
      limit 1;
    end if;

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'id', v_line_id,
      'global_stock_id', v_pick.held_stock_id,
      'product_id', v_pick.product_id,
      'shipment_item_id', v_pick.stock_shipment_item_id,
      'name_snapshot',
        coalesce(v_pick.stock_name, v_pick.line_name)
        || case
          when coalesce(v_pick.is_gift, false)
            and v_pick.gift_source = 'stock'
            and v_pick.gift_cost_charged_to = 'reseller'
          then ' (Gift)'
          else ''
        end,
      'barcode_snapshot', v_pick.stock_barcode,
      'product_code_snapshot', v_pick.stock_product_code,
      'quantity', v_pick.pick_quantity,
      'sell_price_amount', v_item_sell_price,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_pick.stock_assigned_child,
      'line_meta',
        jsonb_build_object('resell_price_amount', v_resell_price)
        || case
          when coalesce(v_pick.is_gift, false)
            and v_pick.gift_source = 'stock'
            and v_pick.gift_cost_charged_to = 'reseller'
          then jsonb_build_object(
            'gift_line_total_amount', coalesce(v_pick.gift_cost_amount, 0),
            'is_warehouse_gift', true
          )
          else '{}'::jsonb
        end
    ));

    if v_line_id is null then
      v_item_json := v_item_json - 'id';
    end if;

    v_items := v_items || jsonb_build_array(v_item_json);
  end loop;

  for v_gift in
    select
      soi.id as order_item_id,
      soi.product_id,
      soi.name as line_name,
      soi.quantity,
      coalesce(soi.gift_cost_amount, 0) as gift_cost_amount,
      p.barcode as product_barcode,
      p.product_code as product_code
    from public.shop_order_items soi
    left join public.products p on p.id = soi.product_id
    where soi.order_id = v_order.id
      and coalesce(soi.is_gift, false)
      and soi.gift_source = 'stock'
      and soi.gift_cost_charged_to = 'reseller'
      and coalesce(soi.gift_cost_amount, 0) > 0
      and not exists (
        select 1
        from public.shop_order_item_stock_picks sp
        where sp.order_item_id = soi.id
          and sp.quantity > 0
      )
  loop
    v_gift_shipment_item_id := null;
    v_gift_name := v_gift.line_name;
    v_gift_barcode := v_gift.product_barcode;
    v_gift_product_code := v_gift.product_code;
    v_gift_assigned_child := null;

    select
      gs.shipment_item_id,
      coalesce(gsi.name, v_gift.line_name),
      gsi.barcode,
      gsi.product_code,
      sh.assigned_child_tenant_id
    into
      v_gift_shipment_item_id,
      v_gift_name,
      v_gift_barcode,
      v_gift_product_code,
      v_gift_assigned_child
    from public.global_stock_allocations gsa
    inner join public.global_stocks gs on gs.id = gsa.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where gsa.shop_id = v_order.shop_id
      and gs.product_id = v_gift.product_id
    order by public.global_stock_atp_qty(gs.id) desc, gs.id
    limit 1;

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'product_id', v_gift.product_id,
      'shipment_item_id', v_gift_shipment_item_id,
      'name_snapshot', v_gift_name || ' (Gift)',
      'barcode_snapshot', v_gift_barcode,
      'product_code_snapshot', v_gift_product_code,
      'quantity', v_gift.quantity,
      'sell_price_amount', case
        when coalesce(v_gift.quantity, 0) > 0 then
          round(coalesce(v_gift.gift_cost_amount, 0) / v_gift.quantity, 2)
        else coalesce(v_gift.gift_cost_amount, 0)
      end,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_gift_assigned_child,
      'line_meta', jsonb_build_object(
        'resell_price_amount', 0,
        'is_warehouse_gift', true,
        'gift_line_total_amount', coalesce(v_gift.gift_cost_amount, 0),
        'order_item_id', v_gift.order_item_id
      )
    ));

    v_items := v_items || jsonb_build_array(v_item_json);
  end loop;

  if jsonb_array_length(v_items) = 0 then
    return jsonb_build_object('success', false, 'error', 'no billable picked lines for merchant invoice');
  end if;

  return jsonb_build_object(
    'success', true,
    'payload', jsonb_build_object(
      'invoice', jsonb_strip_nulls(jsonb_build_object(
        'invoice_type', 'dropship',
        'invoice_no', v_invoice_no,
        'profile_id', v_profile_id,
        'recipient_profile_id', v_order.recipient_profile_id,
        'recipient_name', coalesce(v_order.recipient_name, v_order.name),
        'recipient_phone', v_order.recipient_phone,
        'recipient_address', v_order.shipping_address,
        'note', coalesce(p_note, 'Merchant bill from dropship order #' || v_order.order_no),
        'discount_amount', coalesce(v_order.discount_amount, 0),
        'shipping_charge', coalesce(v_charges.delivery, 0),
        'cod_charge_amount', coalesce(v_charges.cod, 0),
        'print_charge', coalesce(v_charges.print, 0),
        'wrapping_charge', coalesce(v_charges.packing, 0),
        'collection_source', 'profile'::public.collection_source_type,
        'channel_meta', v_channel_meta
      )),
      'items', v_items,
      'shop_order_id', p_order_id
    )
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."canonicalize_dropship_order_wallet_source_ids"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice_no text;
  v_parent_tenant_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null or v_order.shop_type_snapshot <> 'dropship' then
    return;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  v_invoice_no := null;
  if v_order.global_invoice_id is not null then
    select i.invoice_no into v_invoice_no
    from public.bills i
    where i.id = v_order.global_invoice_id;
  end if;

  update public.cashbook_entries u
  set
    source_id = p_order_id::text,
    metadata = coalesce(u.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'order_id', p_order_id,
        'invoice_no', coalesce(v_invoice_no, v_order.order_no)
      )
  where u.source_type = 'shop_order'
    and u.parent_tenant_id = v_parent_tenant_id
    and u.source_id in (
      coalesce(v_invoice_no, ''),
      v_order.order_no,
      'INV-DS-' || v_order.order_no
    );

  if v_order.global_invoice_id is not null then
    update public.cashbook_entries u
    set
      source_id = p_order_id::text,
      metadata = coalesce(u.metadata, '{}'::jsonb)
        || jsonb_build_object('order_id', p_order_id, 'invoice_id', v_order.global_invoice_id)
    from public.bills i
    where i.id = v_order.global_invoice_id
      and u.source_type = 'shop_order'
      and u.parent_tenant_id = v_parent_tenant_id
      and u.source_id = i.invoice_no;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."purge_shop_order_financial_artifacts"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_invoice_id bigint;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id;

  if v_order.id is null then
    return;
  end if;

  v_invoice_id := v_order.global_invoice_id;

  if v_invoice_id is null and v_order.shop_type_snapshot = 'dropship' then
    select i.id into v_invoice_id
    from public.bills i
    where i.shop_order_id = p_order_id
    order by i.id desc
    limit 1;

    if v_invoice_id is null then
      select i.id into v_invoice_id
      from public.bills i
      where i.invoice_no = 'INV-DS-' || v_order.order_no
        and not exists (
          select 1
          from public.shop_orders o2
          where o2.global_invoice_id = i.id
            and o2.id <> v_order.id
        )
      order by i.id desc
      limit 1;
    end if;
  end if;

  if v_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_invoice_id;
  end if;

  delete from public.courier_remittance_items
  where shop_order_id = p_order_id;

  perform public.purge_shop_order_wallet_ledger(
    p_order_id => p_order_id,
    p_tenant_id => v_order.tenant_id,
    p_order_no => v_order.order_no,
    p_invoice_id => v_invoice_id,
    p_invoice_no => v_invoice.invoice_no
  );

  if v_invoice_id is not null then
    perform public.purge_shop_order_invoice(v_invoice_id);
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."fulfill_shop_order_to_invoice"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice_type public.global_invoice_type;
  v_retail_billing_mode public.retail_billing_mode;
  v_invoice_no text;
  v_item record;
  v_items jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status = 'fulfilled' and v_order.global_invoice_id is not null then
    return;
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'only confirmed orders can be fulfilled to an invoice';
  end if;

  if v_order.shop_type_snapshot = 'vendor_catalog' then
    raise exception 'vendor catalog orders cannot be fulfilled to an invoice directly';
  end if;

  if v_order.shop_type_snapshot = 'fixed_price' then
    raise exception 'stock-backed catalog orders must close on Delivery paper (take / condition / return), not fulfill_shop_order_to_invoice';
  end if;

  if v_order.shop_type_snapshot = 'dropship' then
    raise exception 'dropship orders must use ship_dropship_order_and_issue_merchant_bill';
  end if;

  if exists (
    select 1
    from public.bills si
    where si.shop_order_id = p_order_id
  ) then
    raise exception 'order already has a linked sales invoice';
  end if;

  if v_order.order_mode_snapshot = 'checkout_wholesale' then
    v_invoice_type := 'wholesale'::public.global_invoice_type;
    v_retail_billing_mode := null;
    if v_order.profile_id is null then
      raise exception 'billing profile is required for wholesale shop orders';
    end if;
  else
    v_invoice_type := 'retail'::public.global_invoice_type;
    if v_order.profile_id is not null then
      v_retail_billing_mode := 'account'::public.retail_billing_mode;
    else
      v_retail_billing_mode := 'direct'::public.retail_billing_mode;
    end if;
  end if;

  v_invoice_no := public.generate_sales_invoice_number(v_order.tenant_id, v_invoice_type, current_date);

  for v_item in
    select *
    from public.shop_order_items
    where order_id = p_order_id
      and coalesce(is_fulfillment_unavailable, false) = false
      and quantity > 0
  loop
    if v_item.global_stock_id is null then
      raise exception 'item % is missing global_stock_id association', v_item.name;
    end if;

    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'global_stock_id', v_item.global_stock_id,
        'quantity', v_item.quantity::numeric,
        'sell_price_amount', coalesce(
          v_item.final_price_amount,
          v_item.unit_sell_price_amount,
          v_item.unit_list_price_amount
        ),
        'line_discount_amount', 0,
        'line_meta', case
          when v_item.customer_sell_price_amount is not null then
            jsonb_build_object('resell_price_amount', v_item.customer_sell_price_amount)
          else '{}'::jsonb
        end
      )
    );
  end loop;

  if jsonb_array_length(v_items) = 0 then
    raise exception 'order has no fulfillable line items';
  end if;

  v_payload := jsonb_build_object(
    'invoice', jsonb_build_object(
      'invoice_no', v_invoice_no,
      'invoice_type', v_invoice_type,
      'profile_id', v_order.profile_id,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_address', v_order.shipping_address,
      'retail_billing_mode', v_retail_billing_mode,
      'discount_amount', coalesce(v_order.discount_amount, 0),
      'shipping_charge', coalesce(v_order.delivery_charge_amount, 0),
      'print_charge', coalesce(v_order.print_charge_amount, 0),
      'wrapping_charge', coalesce(v_order.packing_charge_amount, 0),
      'note', coalesce(v_order.delivery_instructions, 'Fulfillment of Shop Order: ' || v_order.order_no)
    ),
    'items', v_items,
    'issue', true
  );

  v_result := public.create_sales_invoice_from_payload(v_order.tenant_id, v_payload);

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to fulfill shop order to invoice');
  end if;

  v_invoice_id := (v_result->>'invoice_id')::bigint;

  update public.bills
  set
    shop_order_id = p_order_id,
    collection_source = 'profile'::public.collection_source_type,
    updated_at = now()
  where id = v_invoice_id;

  update public.shop_orders
  set
    status = 'fulfilled',
    global_invoice_id = v_invoice_id,
    fulfilled_at = now(),
    updated_at = now()
  where id = p_order_id;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."create_bill_adjustment"("p_parent_bill_id" bigint, "p_kind" "text", "p_amount" numeric, "p_reason" "text", "p_issue" boolean DEFAULT true, "p_refund_amount" numeric DEFAULT NULL::numeric, "p_cashbook_point_id" bigint DEFAULT NULL::bigint, "p_lines" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent public.bills;
  v_kind public.bill_document_kind;
  v_row public.bills;
  v_no text;
  v_reason text;
  v_amount numeric(12,2);
  v_status public.global_invoice_status;
  v_refund numeric(12,2);
  v_child_due numeric(12,2);
  v_pay public.pays;
  v_line_elem jsonb;
  v_line_total numeric(12,2);
  v_books numeric(12,2);
  v_line_kind text;
  v_stock_id bigint;
  v_lines_sum numeric(12,2) := 0.00;
begin
  if p_parent_bill_id is null then
    raise exception 'parent_bill_id is required';
  end if;

  v_kind := case lower(trim(coalesce(p_kind, '')))
    when 'credit_note' then 'credit_note'::public.bill_document_kind
    when 'credit' then 'credit_note'::public.bill_document_kind
    when 'debit_note' then 'debit_note'::public.bill_document_kind
    when 'debit' then 'debit_note'::public.bill_document_kind
    else null
  end;
  if v_kind is null then
    raise exception 'kind must be credit_note or debit_note';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'reason is required';
  end if;

  select * into v_parent from public.bills where id = p_parent_bill_id for update;
  if v_parent.id is null then
    raise exception 'bill not found';
  end if;
  if v_parent.document_kind <> 'standard'::public.bill_document_kind then
    raise exception 'adjustments must attach to a standard bill';
  end if;
  if v_parent.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'parent bill must be issued';
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent.parent_tenant_id)
    or public.membership_has_module_action(v_parent.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' and jsonb_array_length(p_lines) > 0 then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_lines_sum := v_lines_sum + v_books;
    end loop;
    v_amount := round(v_lines_sum, 2);
  else
    v_amount := round(coalesce(p_amount, 0), 2);
  end if;

  if v_amount <= 0 then
    raise exception 'amount must be greater than zero';
  end if;

  v_no := public.next_document_number(
    v_parent.issued_by_tenant_id,
    case
      when v_kind = 'credit_note'::public.bill_document_kind then 'credit_note'
      else 'debit_note'
    end,
    public.map_global_invoice_type_to_sub_type(v_parent.invoice_type),
    (current_date::timestamp AT TIME ZONE public._document_number_tenant_timezone(v_parent.issued_by_tenant_id, 'UTC'))
  );

  v_status := case when coalesce(p_issue, true)
    then 'issued'::public.global_invoice_status
    else 'draft'::public.global_invoice_status
  end;

  insert into public.bills (
    parent_tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    invoice_status,
    profile_id,
    collection_source,
    payment_status,
    subtotal_amount,
    total_amount,
    due_amount,
    paid_amount,
    note,
    document_kind,
    parent_bill_id,
    ap_shipment_id,
    ap_kind,
    channel_meta
  ) values (
    v_parent.parent_tenant_id,
    v_parent.issued_by_tenant_id,
    v_no,
    v_parent.invoice_type,
    current_date,
    v_status,
    v_parent.profile_id,
    v_parent.collection_source,
    'due',
    v_amount,
    v_amount,
    v_amount,
    0,
    v_reason,
    v_kind,
    v_parent.id,
    v_parent.ap_shipment_id,
    v_parent.ap_kind,
    jsonb_build_object(
      'adjustment', jsonb_build_object(
        'kind', v_kind::text,
        'reason', v_reason,
        'parent_invoice_no', v_parent.invoice_no
      )
    )
  )
  returning * into v_row;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_line_kind := lower(trim(coalesce(v_line_elem ->> 'line_kind', 'description')));
      if v_line_kind not in ('stock', 'description', 'charge') then
        v_line_kind := 'description';
      end if;
      v_stock_id := nullif(trim(coalesce(v_line_elem ->> 'global_stock_id', '')), '')::bigint;

      insert into public.bill_lines (
        parent_tenant_id,
        invoice_id,
        line_kind,
        name_snapshot,
        quantity,
        sell_price_amount,
        line_discount_amount,
        line_total_amount,
        currency_code,
        books_amount,
        line_meta,
        global_stock_id
      ) values (
        v_parent.parent_tenant_id,
        v_row.id,
        v_line_kind,
        coalesce(nullif(trim(coalesce(v_line_elem ->> 'name_snapshot', '')), ''), 'Adjustment line'),
        greatest(coalesce((v_line_elem ->> 'quantity')::numeric, 1.000), 0.001),
        v_line_total,
        0.00,
        v_line_total,
        upper(trim(coalesce(v_line_elem ->> 'currency_code', 'BDT'))),
        v_books,
        coalesce(v_line_elem -> 'line_meta', '{}'::jsonb)
          || case
            when nullif(trim(coalesce(v_line_elem ->> 'parent_line_id', '')), '') is not null
            then jsonb_build_object('parent_line_id', v_line_elem ->> 'parent_line_id')
            else '{}'::jsonb
          end,
        v_stock_id
      );
    end loop;
  end if;

  perform public.stamp_bill_kernel_fields(v_row.id);

  if v_status = 'issued'::public.global_invoice_status then
    perform public.recompute_global_invoice_payment_status(v_parent.id);
    select * into v_row from public.bills where id = v_row.id;
  end if;

  v_refund := round(coalesce(p_refund_amount, 0), 2);
  if v_refund > 0 then
    if v_kind <> 'credit_note'::public.bill_document_kind then
      raise exception 'Cash refund applies only to credit notes';
    end if;
    if v_parent.profile_id is null then
      raise exception 'Bill has no profile for refund';
    end if;
    if p_cashbook_point_id is null then
      raise exception 'Choose a cash point for the refund';
    end if;
    if not exists (
      select 1
      from public.cashbook_points cp
      join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
      where cp.id = p_cashbook_point_id
        and cp.is_active = true
        and ca.parent_tenant_id = v_parent.parent_tenant_id
        and ca.entity_type = 'tenant'
        and ca.entity_id = v_parent.parent_tenant_id
    ) then
      raise exception 'Invalid cash point for this tenant';
    end if;

    v_child_due := coalesce(v_row.due_amount, 0.00);
    if v_refund > v_child_due then
      raise exception 'Refund % exceeds open credit % on the note', v_refund, v_child_due;
    end if;

    insert into public.pays (
      tenant_id,
      profile_id,
      source,
      amount,
      unallocated_amount,
      payment_date,
      method,
      note,
      cashbook_point_id
    ) values (
      v_parent.parent_tenant_id,
      v_parent.profile_id,
      'ap_payout',
      v_refund,
      0,
      current_date,
      'cash',
      v_reason,
      p_cashbook_point_id
    )
    returning * into v_pay;

    insert into public.pay_instruments (
      payment_id,
      payment_method_code,
      amount,
      sort_order,
      cashbook_point_id
    ) values (
      v_pay.id,
      'CASH',
      v_refund,
      1,
      p_cashbook_point_id
    );

    insert into public.pay_allocations (
      tenant_id,
      payment_id,
      global_invoice_id,
      bill_id,
      amount
    ) values (
      v_parent.parent_tenant_id,
      v_pay.id,
      v_row.id,
      v_row.id,
      v_refund
    );

    perform public.recompute_global_invoice_payment_status(v_row.id);
    perform public.recompute_global_invoice_payment_status(v_parent.id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent.parent_tenant_id,
      p_operating_tenant_id => v_parent.issued_by_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent.parent_tenant_id,
      p_type => 'debit',
      p_amount => v_refund,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_pay.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'credit_note_refund',
        'transaction_type', 'credit_note_cash_refund',
        'label', 'Credit note cash refund',
        'payment_id', v_pay.id,
        'credit_note_id', v_row.id,
        'credit_note_no', v_row.invoice_no,
        'parent_bill_id', v_parent.id,
        'parent_invoice_no', v_parent.invoice_no
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => p_cashbook_point_id
    );

    select * into v_row from public.bills where id = v_row.id;
  elsif p_cashbook_point_id is not null and coalesce(p_refund_amount, 0) <= 0 then
    raise exception 'Refund amount is required when a cash point is selected';
  end if;

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."issue_wholesale_invoice"("p_invoice_id" bigint, "p_items" "jsonb" DEFAULT NULL::"jsonb") RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_item_record jsonb;
  v_item_id bigint;
  v_item_qty numeric;
  v_item_price numeric;
  v_line_total numeric;
  v_db_item public.bill_lines%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Only draft or proforma invoices can be issued';
  end if;

  if v_invoice.profile_id is null then
    raise exception 'Billing profile is required for wholesale invoices';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  -- 1. Optionally apply batch quantity/price updates from dialog payload
  if p_items is not null and jsonb_typeof(p_items) = 'array' and jsonb_array_length(p_items) > 0 then
    for v_item_record in select * from jsonb_array_elements(p_items) loop
      v_item_id := (v_item_record->>'id')::bigint;
      v_item_qty := (v_item_record->>'quantity')::numeric;
      v_item_price := (v_item_record->>'sell_price_amount')::numeric;

      if v_item_id is not null and v_item_qty is not null and v_item_qty > 0 then
        select * into v_db_item from public.bill_lines where id = v_item_id and invoice_id = p_invoice_id;
        if v_db_item.id is not null then
          v_item_price := coalesce(v_item_price, v_db_item.sell_price_amount);
          v_line_total := greatest((v_item_qty * v_item_price) - coalesce(v_db_item.line_discount_amount, 0.00), 0.00);

          update public.bill_lines
          set
            quantity = v_item_qty,
            sell_price_amount = v_item_price,
            line_total_amount = v_line_total
          where id = v_item_id;
        end if;
      end if;
    end loop;

    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  if not exists (select 1 from public.bill_lines where invoice_id = p_invoice_id) then
    raise exception 'Cannot issue an empty invoice';
  end if;


  -- 3. Create stock movement audit record
  v_mov_no := public.next_stock_movement_number(v_parent_id, 'stock_movement');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    v_parent_id,
    v_mov_no,
    'adjustment'::public.stock_movement_type,
    'sales_invoice',
    p_invoice_id::text,
    'Issued Wholesale Invoice #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  -- 4. Deduct warehouse stock and record movement lines
  for v_db_item in select * from public.bill_lines where invoice_id = p_invoice_id loop
    v_qty := ceil(v_db_item.quantity)::integer;

    select * into v_stock from public.global_stocks where id = v_db_item.global_stock_id for update;
    if v_stock.id is not null then
      if v_stock.quantity < v_qty then
        raise exception 'Insufficient stock for % (requested %, available %)', v_db_item.name_snapshot, v_qty, v_stock.quantity;
      end if;

      -- Deduct from global_stocks
      update public.global_stocks
      set quantity = quantity - v_qty
      where id = v_db_item.global_stock_id;

      -- Insert movement line
      insert into public.stock_movement_lines (
        movement_id,
        stock_id,
        quantity,
        from_location_id,
        to_location_id,
        from_availability,
        to_availability
      ) values (
        v_mov_id,
        v_db_item.global_stock_id,
        v_qty,
        v_stock.location_id,
        v_stock.location_id,
        v_stock.availability,
        v_stock.availability
      );
    end if;
  end loop;

  -- 5. Mark invoice as issued (status = 'issued'::public.global_invoice_status)
  update public.bills
  set
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(payment_status, ''), 'due')
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."post_sales_invoice"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
  v_delivery_kind text;
  v_held_stock_id bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'only draft or proforma invoices can be posted/issued';
  end if;

  if not exists (select 1 from public.global_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'cannot post an empty invoice';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type then
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  v_delivery_kind := lower(trim(coalesce(v_invoice.channel_meta->>'delivery_kind', 'take')));
  if v_delivery_kind not in ('take', 'condition') then
    v_delivery_kind := 'take';
  end if;

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type
     and v_delivery_kind = 'condition' then
    for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
      v_qty := ceil(v_item.quantity)::integer;

      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if v_stock.id is null then
        continue;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'insufficient stock quantity on stock % (requested %, available %)',
          v_item.global_stock_id, v_qty, v_stock.quantity;
      end if;

      if v_stock.availability = 'sellable'::public.stock_availability then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_id,
          p_stock_id => v_item.global_stock_id,
          p_quantity => v_qty,
          p_to_availability => 'held'::public.stock_availability,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Condition bill #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
          p_reference_type => 'sales_invoice',
          p_reference_id => p_invoice_id::text
        );

        select gs.id
        into v_held_stock_id
        from public.global_stocks gs
        where gs.shipment_item_id = v_stock.shipment_item_id
          and gs.availability = 'held'::public.stock_availability
          and gs.location_id = v_stock.location_id
          and gs.grade_tag_id = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
        order by gs.id desc
        limit 1;

        if v_held_stock_id is null then
          raise exception 'held stock not found after condition transfer for line %', v_item.id;
        end if;

        update public.bill_lines
        set global_stock_id = v_held_stock_id
        where id = v_item.id;
      elsif v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'condition bill stock % must be sellable or held (current: %)',
          v_item.global_stock_id, v_stock.availability;
      end if;
    end loop;
  else
    v_mov_no := public.next_stock_movement_number(v_parent_id, 'stock_movement');

    insert into public.stock_movements (
      tenant_id,
      movement_no,
      movement_type,
      reference_type,
      reference_id,
      notes,
      created_by_email,
      is_posted,
      posted_at
    ) values (
      v_parent_id,
      v_mov_no,
      'adjustment'::public.stock_movement_type,
      'sales_invoice',
      p_invoice_id::text,
      'Issued ' || upper(v_invoice.invoice_type::text) || ' Invoice #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
      public.current_user_email(),
      true,
      now()
    ) returning id into v_mov_id;

    for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
      v_qty := ceil(v_item.quantity)::integer;

      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if v_stock.id is not null then
        if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
           and v_stock.availability <> 'held'::public.stock_availability then
          raise exception 'dropship invoice stock % must be held before issue', v_item.global_stock_id;
        end if;

        if v_stock.quantity < v_qty then
          raise exception 'insufficient stock quantity on stock % (requested %, available %)',
            v_item.global_stock_id, v_qty, v_stock.quantity;
        end if;

        update public.global_stocks
        set quantity = quantity - v_qty
        where id = v_item.global_stock_id;

        insert into public.stock_movement_lines (
          movement_id,
          stock_id,
          quantity,
          from_location_id,
          to_location_id,
          from_availability,
          to_availability
        ) values (
          v_mov_id,
          v_item.global_stock_id,
          v_qty,
          v_stock.location_id,
          v_stock.location_id,
          v_stock.availability,
          v_stock.availability
        );
      end if;
    end loop;
  end if;

  update public.bills
  set invoice_status = 'issued'::public.global_invoice_status
  where id = p_invoice_id;

  perform public._kernel_freeze_bill_txn_face(p_invoice_id);
  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  if v_invoice.invoice_type = 'retail'::public.global_invoice_type
     and v_invoice.profile_id is not null
     and coalesce(v_invoice.total_amount, 0) > 0
  then
    if not exists (
      select 1 from public.cashbook_entries
      where source_type = 'sales_invoice'
        and source_id = p_invoice_id::text
        and entity_type = 'customer'
        and entity_id = v_invoice.profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'invoices',
          'purpose', 'invoice_billed',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', v_invoice.id,
          'invoice_type', v_invoice.invoice_type
        )
      );
    end if;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."post_shipment_outcome_stock"("p_shipment_id" bigint, "p_stock_rows" "jsonb" DEFAULT NULL::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_stamped integer;
  v_stock_count integer := 0;
  v_parent bigint;
  v_loc bigint;
  v_grade_tag bigint;
  v_avail public.stock_availability;
  v_stock_id bigint;
  v_mov_id bigint;
  v_mov_no text;
  v_posted int;
  v_delta int;
  r_out record;
  v_stock_type bigint;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.parent_tenant_id;

  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if v_ship.status = 'cancelled' then
    raise exception 'shipment is cancelled';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  if not exists (
    select 1 from public.global_shipment_cost_entries where shipment_id = p_shipment_id
  ) then
    raise exception 'shipment has no cost entries';
  end if;

  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);
  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

  v_mov_no := public.next_stock_movement_number(v_parent, 'receive_putaway');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    v_parent,
    v_mov_no,
    'receive_putaway',
    'global_shipment',
    p_shipment_id::text,
    'Outcome receive put-away for shipment ' || p_shipment_id::text,
    public.current_user_email(),
    true,
    now()
  )
  returning id into v_mov_id;

  for r_out in
    select o.*
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where gsi.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
    order by o.id
  loop
    if r_out.kind = 'unsellable'::public.global_shipment_outcome_kind then
      continue;
    end if;

    select coalesce(sum(gs.quantity), 0)::int into v_posted
    from public.global_stocks gs where gs.outcome_id = r_out.id;

    v_delta := r_out.quantity - v_posted;
    if v_delta <= 0 then
      continue;
    end if;

    v_loc := null;
    if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'location_id')::bigint into v_loc
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'outcome_id')::bigint = r_out.id
      limit 1;
    end if;

    if v_loc is null and p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'location_id')::bigint into v_loc
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
      limit 1;
    end if;

    v_loc := coalesce(v_loc, public.default_putaway_stock_location_id(v_parent));

    if v_loc is null then
      raise exception 'no put-away location configured';
    end if;

    if not exists (
      select 1 from public.stock_locations sl
      where sl.id = v_loc and sl.parent_tenant_id = v_parent and sl.is_active = true
        and public._stock_location_is_leaf(v_loc)
    ) then
      raise exception 'invalid put-away location';
    end if;

    v_avail := 'sellable'::public.stock_availability;
    v_grade_tag := public.default_stock_grade_tag_id();

    v_stock_type := null;
    if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'stock_type_id')::bigint into v_stock_type
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'outcome_id')::bigint = r_out.id
        and nullif(elem->>'stock_type_id', '') is not null
      limit 1;
    end if;

    if v_stock_type is null and p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'stock_type_id')::bigint into v_stock_type
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
        and nullif(elem->>'stock_type_id', '') is not null
      limit 1;
    end if;

    if v_stock_type is null then
      select gs.stock_type_id into v_stock_type
      from public.global_stocks gs
      where gs.shipment_item_id = r_out.shipment_item_id
        and gs.stock_type_id is not null
      order by gs.quantity desc, gs.id
      limit 1;
    end if;

    if v_stock_type is null then
      v_stock_type := public.default_sellable_global_stock_type_id(v_parent);
    end if;

    if v_stock_type is null then
      raise exception 'no sellable stock type configured';
    end if;

    insert into public.global_stocks (
      parent_tenant_id, shipment_item_id, outcome_id, stock_type_id, quantity,
      is_usable, availability, location_id, grade_tag_id
    ) values (
      v_parent, r_out.shipment_item_id, r_out.id, v_stock_type, v_delta,
      true, v_avail, v_loc, v_grade_tag
    )
    on conflict (outcome_id, availability, location_id, grade_tag_id)
    do update set quantity = public.global_stocks.quantity + excluded.quantity, updated_at = now()
    returning id into v_stock_id;

    insert into public.stock_movement_lines (
      movement_id, stock_id, quantity, to_location_id, to_availability
    ) values (v_mov_id, v_stock_id, v_delta, v_loc, v_avail);

    v_stock_count := v_stock_count + 1;
  end loop;

  update public.global_shipment_items gsi
  set received_quantity = coalesce(extra_totals.total_qty, 0), updated_at = now()
  from (
    select o.shipment_item_id as item_id, sum(o.quantity)::int as total_qty
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi2 on gsi2.id = o.shipment_item_id
    where gsi2.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
    group by o.shipment_item_id
  ) extra_totals
  where gsi.id = extra_totals.item_id and gsi.shipment_id = p_shipment_id;

  if v_stock_count > 0 then
    update public.global_shipments
    set status = 'received',
        stock_ready = true, inventory_added = true, updated_at = now()
    where id = p_shipment_id;
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'stock_rows_posted', v_stock_count,
    'stock_ready', (select stock_ready from public.global_shipments where id = p_shipment_id),
    'movement_id', v_mov_id
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."return_shipment_to_vendor"("p_shipment_id" bigint, "p_items_qty" "jsonb", "p_outcome" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_item jsonb;
  v_stock_id bigint;
  v_shipment_item_id bigint;
  v_qty numeric;
  v_mov_id bigint;
  v_amount numeric := 0;
  v_ledger jsonb;
  v_vendor_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before return';
  end if;

  if p_outcome not in ('cash_refund', 'store_credit') then
    raise exception 'outcome must be cash_refund or store_credit';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_vendor_id := v_ship.vendor_id;

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    v_ship.parent_tenant_id,
    public.next_stock_movement_number(v_ship.parent_tenant_id, 'vendor_return'),
    'return_inbound',
    'shipment_return',
    p_shipment_id::text,
    'Vendor return outcome: ' || p_outcome,
    public.current_user_email()
  )
  returning id into v_mov_id;

  for v_item in select value from jsonb_array_elements(coalesce(p_items_qty, '[]'::jsonb))
  loop
    v_stock_id := (v_item->>'global_stock_id')::bigint;
    v_shipment_item_id := (v_item->>'shipment_item_id')::bigint;
    v_qty := coalesce((v_item->>'quantity')::numeric, 0);

    if v_stock_id is null and v_shipment_item_id is not null then
      select gs.id into v_stock_id
      from public.global_stocks gs
      join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = v_shipment_item_id
        and gs.parent_tenant_id = v_ship.parent_tenant_id
        and gst.is_sellable = true
        and gs.availability = 'sellable'::public.stock_availability
      order by gs.quantity desc, gs.id
      limit 1;
    end if;

    if v_stock_id is null or v_qty <= 0 then
      continue;
    end if;

    insert into public.stock_movement_lines (
      movement_id, stock_id, quantity, from_availability, to_availability
    ) values (
      v_mov_id, v_stock_id, v_qty, 'sellable'::public.stock_availability, 'held'::public.stock_availability
    );

    v_amount := v_amount + (v_qty * coalesce(
      (select gsi.landed_cost_bdt from public.global_stocks gs
       join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gs.id = v_stock_id),
      0
    ));
  end loop;

  perform public.post_stock_movement(v_mov_id);

  if v_amount <= 0 then
    v_amount := coalesce((
      select sum(coalesce(e.amount, 0))
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id and e.cost_bucket = 'material'::public.global_shipment_cost_bucket
    ), 0);
  end if;

  if p_outcome = 'cash_refund' then
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_ship.parent_tenant_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
    );
    if v_vendor_id is not null then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
        p_entity_type => 'vendor',
        p_entity_id => v_vendor_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_source_type => 'shipment_return',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
      );
    end if;
  else
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
      p_entity_type => 'vendor',
      p_entity_id => v_vendor_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'store_credit', 'movement_id', v_mov_id)
    );
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'outcome', p_outcome,
    'movement_id', v_mov_id,
    'return_processed', true,
    'wallet_posted', true,
    'amount_bdt', v_amount
  );
end;
$$;


GRANT ALL ON TABLE public.document_number_configs TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.document_number_counters TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.next_document_number(bigint, text, text, timestamptz) TO authenticated, service_role;
GRANT ALL ON FUNCTION public.peek_document_number(bigint, text, text, timestamptz) TO authenticated, service_role;
GRANT ALL ON FUNCTION public.map_global_invoice_type_to_sub_type(public.global_invoice_type) TO authenticated, service_role;
GRANT ALL ON FUNCTION public.next_stock_movement_number(bigint, text) TO authenticated, service_role;
GRANT ALL ON FUNCTION public.backfill_document_number_counters_from_sales_invoice_counters() TO service_role;
GRANT ALL ON FUNCTION public.backfill_document_number_counters_from_tenant_shipments() TO service_role;
