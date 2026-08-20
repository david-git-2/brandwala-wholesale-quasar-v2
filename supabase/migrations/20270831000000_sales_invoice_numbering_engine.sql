-- Sales Invoice Numbering Engine (INV-{TYPE}-{YYYYMMDD}-{SEQ})
-- Supports atomic daily sequence counting per tenant and invoice type.

CREATE TABLE IF NOT EXISTS "public"."sales_invoice_counters" (
    "tenant_id" bigint NOT NULL,
    "invoice_type" "public"."global_invoice_type" NOT NULL,
    "date_key" "text" NOT NULL,
    "last_value" bigint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "sales_invoice_counters_pkey" PRIMARY KEY ("tenant_id", "invoice_type", "date_key"),
    CONSTRAINT "sales_invoice_counters_last_value_check" CHECK (("last_value" >= 0)),
    CONSTRAINT "sales_invoice_counters_date_key_check" CHECK (("date_key" ~ '^\d{8}$'::text)),
    CONSTRAINT "sales_invoice_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE
);

ALTER TABLE "public"."sales_invoice_counters" OWNER TO "postgres";

ALTER TABLE "public"."sales_invoice_counters" ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE TRIGGER "trg_sales_invoice_counters_set_updated_at"
BEFORE UPDATE ON "public"."sales_invoice_counters"
FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

-- Atomic generator RPC
CREATE OR REPLACE FUNCTION "public"."generate_sales_invoice_number"(
  "p_tenant_id" bigint,
  "p_invoice_type" "public"."global_invoice_type",
  "p_date" "date" DEFAULT CURRENT_DATE
) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_type_code text;
  v_date_key text;
  v_next bigint;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  IF p_invoice_type IS NULL THEN
    RAISE EXCEPTION 'invoice_type is required';
  END IF;

  v_type_code := CASE p_invoice_type
    WHEN 'wholesale'::public.global_invoice_type THEN 'WS'
    WHEN 'retail'::public.global_invoice_type THEN 'RT'
    WHEN 'dropship'::public.global_invoice_type THEN 'DS'
    ELSE 'INV'
  END;

  v_date_key := to_char(COALESCE(p_date, CURRENT_DATE), 'YYYYMMDD');

  INSERT INTO public.sales_invoice_counters (tenant_id, invoice_type, date_key, last_value)
  VALUES (p_tenant_id, p_invoice_type, v_date_key, 1)
  ON CONFLICT (tenant_id, invoice_type, date_key)
  DO UPDATE
    SET last_value = public.sales_invoice_counters.last_value + 1,
        updated_at = now()
  RETURNING last_value INTO v_next;

  RETURN 'INV-' || v_type_code || '-' || v_date_key || '-' || lpad(v_next::text, 4, '0');
END;
$$;

ALTER FUNCTION "public"."generate_sales_invoice_number"("p_tenant_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_date" "date") OWNER TO "postgres";

-- Permissions
GRANT SELECT ON TABLE "public"."sales_invoice_counters" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_invoice_counters" TO "service_role";
GRANT EXECUTE ON FUNCTION "public"."generate_sales_invoice_number"("p_tenant_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_date" "date") TO "authenticated", "service_role";

-- Update create_sales_invoice to auto-generate invoice_no if omitted or blank
CREATE OR REPLACE FUNCTION "public"."create_sales_invoice"(
  "p_tenant_id" bigint,
  "p_invoice_no" "text",
  "p_invoice_type" "public"."global_invoice_type",
  "p_billing_profile_id" bigint DEFAULT NULL::bigint,
  "p_recipient_profile_id" bigint DEFAULT NULL::bigint,
  "p_recipient_name" "text" DEFAULT NULL::"text",
  "p_recipient_phone" "text" DEFAULT NULL::"text",
  "p_recipient_address" "text" DEFAULT NULL::"text",
  "p_retail_billing_mode" "public"."retail_billing_mode" DEFAULT NULL::"public"."retail_billing_mode",
  "p_due_date" "date" DEFAULT NULL::"date",
  "p_note" "text" DEFAULT NULL::"text",
  "p_invoice_date" "date" DEFAULT NULL::"date"
) RETURNS "public"."sales_invoices"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
  v_issued_by bigint;
  v_rec_name text;
  v_rec_phone text;
  v_rec_address text;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_bill_name text;
  v_bill_phone text;
  v_bill_address text;
  v_collection_source public.collection_source_type;
  v_invoice_no text;
  v_invoice_date date;
begin
  v_issued_by := p_tenant_id;
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_invoice_date := coalesce(p_invoice_date, CURRENT_DATE);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'not allowed';
  end if;

  if p_billing_profile_id is not null then
    if not exists (
      select 1 from public.billing_profiles
      where id = p_billing_profile_id and tenant_id = v_issued_by
    ) then
      raise exception 'billing profile must belong to the issuing tenant';
    end if;
  end if;

  if p_recipient_profile_id is not null then
    if not exists (
      select 1 from public.recipient_profiles
      where id = p_recipient_profile_id and tenant_id = v_issued_by
    ) then
      raise exception 'recipient profile must belong to the issuing tenant';
    end if;
  end if;

  if p_invoice_type = 'wholesale'::public.global_invoice_type then
    if p_billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for wholesale invoices';
    end if;
    v_collection_source := 'billing_profile'::public.collection_source_type;

  elsif p_invoice_type = 'retail'::public.global_invoice_type then
    if p_retail_billing_mode is null then
      raise exception 'retail billing mode (account or direct) is required for retail invoices';
    end if;

    if p_retail_billing_mode = 'account'::public.retail_billing_mode then
      if p_billing_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
      v_collection_source := 'billing_profile'::public.collection_source_type;
    else
      if p_billing_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
      v_collection_source := 'recipient'::public.collection_source_type;
    end if;

  elsif p_invoice_type = 'dropship'::public.global_invoice_type then
    if p_billing_profile_id is null then
      raise exception 'billing profile (middle man) is required for dropship invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for dropship invoices';
    end if;
    v_collection_source := 'recipient'::public.collection_source_type;
  end if;

  if p_recipient_profile_id is not null then
    select name, phone, address
    into v_rec_name, v_rec_phone, v_rec_address
    from public.recipient_profiles
    where id = p_recipient_profile_id;
  end if;

  v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_rec_name);
  v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_rec_phone);
  v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_rec_address);

  if p_invoice_type = 'wholesale'::public.global_invoice_type and p_billing_profile_id is not null then
    select name, phone, address
    into v_bill_name, v_bill_phone, v_bill_address
    from public.billing_profiles
    where id = p_billing_profile_id;

    v_recipient_name := coalesce(v_recipient_name, v_bill_name);
    v_recipient_phone := coalesce(v_recipient_phone, v_bill_phone);
    v_recipient_address := coalesce(v_recipient_address, v_bill_address);
  end if;

  -- Resolve invoice_no: auto-generate if omitted or empty
  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := public.generate_sales_invoice_number(p_tenant_id, p_invoice_type, v_invoice_date);
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    retail_billing_mode,
    invoice_status,
    fulfillment_status,
    billing_profile_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    due_date,
    payment_status,
    note
  )
  values (
    v_parent_id,
    v_parent_id,
    v_issued_by,
    v_invoice_no,
    p_invoice_type,
    v_invoice_date,
    p_retail_billing_mode,
    'draft'::public.global_invoice_status,
    'pending'::public.global_fulfillment_status,
    p_billing_profile_id,
    p_recipient_profile_id,
    v_recipient_name,
    v_recipient_phone,
    v_recipient_address,
    v_collection_source,
    p_due_date,
    'due',
    nullif(trim(coalesce(p_note, '')), '')
  )
  returning * into v_row;

  return v_row;
end;
$$;
