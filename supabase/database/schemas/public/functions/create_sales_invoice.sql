CREATE FUNCTION public.create_sales_invoice (
  p_tenant_id                bigint,
  p_invoice_no               text,
  p_profile_id               bigint,
  p_invoice_type             public.global_invoice_type  DEFAULT 'wholesale'::public.global_invoice_type,
  p_source_module            public.global_source_module DEFAULT 'wholesale'::public.global_source_module,
  p_recipient_name           text                        DEFAULT NULL::text,
  p_recipient_phone          text                        DEFAULT NULL::text,
  p_recipient_address        text                        DEFAULT NULL::text,
  p_recipient_party_id       bigint                      DEFAULT NULL::bigint,
  p_middle_man_payout_amount numeric                     DEFAULT NULL::numeric,
  p_note                     text                        DEFAULT NULL::text
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.bills;
  v_parent_id bigint;
  v_issued_by bigint;
  v_profile public.profiles;
  v_invoice_type public.global_invoice_type;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_collection_source text;
begin
  if p_profile_id is null then
    raise exception 'Customer profile is required.';
  end if;

  v_invoice_type := coalesce(p_invoice_type, 'wholesale');
  v_issued_by := p_tenant_id;
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

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

  select * into v_profile from public.profiles where id = p_profile_id;
  if v_profile.id is null then raise exception 'Customer profile not found.'; end if;
  if not public.profile_valid_for_issuer(p_profile_id, v_issued_by) then
    raise exception 'Customer profile does not belong to issuing tenant.';
  end if;

  if v_invoice_type = 'wholesale' then
    v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_profile.name);
    v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_profile.phone);
    v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_profile.address);
    v_collection_source := 'profile';
  elsif v_invoice_type = 'retail' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for retail.'; end if;
    v_collection_source := 'profile';
  elsif v_invoice_type = 'dropship' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for dropship.'; end if;
    v_collection_source := 'profile';
  else
    raise exception 'Invalid invoice type.';
  end if;

  insert into public.bills (
    parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type,
    profile_id,
    recipient_name, recipient_phone, recipient_address,
    collection_source, note, due_amount
  )
  values (
    v_parent_id, v_issued_by, trim(p_invoice_no), v_invoice_type,
    p_profile_id,
    v_recipient_name, v_recipient_phone, v_recipient_address,
    v_collection_source, nullif(trim(coalesce(p_note, '')), ''), 0
  )
  returning * into v_row;

  perform public.stamp_bill_kernel_fields(v_row.id);
  select * into v_row from public.bills where id = v_row.id;

  return v_row;
end;
$function$;

CREATE FUNCTION public.create_sales_invoice (
  p_tenant_id            bigint,
  p_invoice_no           text                       DEFAULT NULL::text,
  p_invoice_type         public.global_invoice_type DEFAULT 'wholesale'::public.global_invoice_type,
  p_profile_id           bigint                     DEFAULT NULL::bigint,
  p_recipient_profile_id bigint                     DEFAULT NULL::bigint,
  p_recipient_name       text                       DEFAULT NULL::text,
  p_recipient_phone      text                       DEFAULT NULL::text,
  p_recipient_address    text                       DEFAULT NULL::text,
  p_retail_billing_mode  public.retail_billing_mode DEFAULT NULL::public.retail_billing_mode,
  p_due_date             date                       DEFAULT NULL::date,
  p_note                 text                       DEFAULT NULL::text,
  p_invoice_date         date                       DEFAULT NULL::date
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.bills;
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
      where (m.tenant_id = p_tenant_id or m.tenant_id = v_parent_id)
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
    or public.is_superadmin()
  ) then
    raise exception 'not allowed';
  end if;

  if p_profile_id is not null then
    if not public.profile_valid_for_issuer(p_profile_id, v_issued_by) then
      raise exception 'billing profile not accessible for this tenant';
    end if;
  end if;

  if p_recipient_profile_id is not null then
    if not public.recipient_profile_valid_for_issuer(p_recipient_profile_id, v_issued_by) then
      raise exception 'recipient profile not accessible for this tenant';
    end if;
  end if;

  if p_invoice_type = 'wholesale'::public.global_invoice_type then
    if p_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for wholesale invoices';
    end if;
    v_collection_source := 'profile'::public.collection_source_type;

  elsif p_invoice_type = 'retail'::public.global_invoice_type then
    if p_retail_billing_mode is null then
      raise exception 'retail billing mode (account or direct) is required for retail invoices';
    end if;

    if p_retail_billing_mode = 'account'::public.retail_billing_mode then
      if p_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
      v_collection_source := 'profile'::public.collection_source_type;
    else
      if p_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
      v_collection_source := 'recipient'::public.collection_source_type;
    end if;

  elsif p_invoice_type = 'dropship'::public.global_invoice_type then
    if p_profile_id is null then
      raise exception 'billing profile (middle man) is required for dropship invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for dropship invoices';
    end if;
    v_collection_source := 'profile'::public.collection_source_type;
  elsif p_invoice_type = 'ap'::public.global_invoice_type then
    if p_profile_id is null then
      raise exception 'payee profile_id is required for AP bills';
    end if;
    v_collection_source := 'profile'::public.collection_source_type;
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

  if p_invoice_type = 'wholesale'::public.global_invoice_type and p_profile_id is not null then
    select name, phone, address
    into v_bill_name, v_bill_phone, v_bill_address
    from public.profiles
    where id = p_profile_id;

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

  insert into public.bills (
    parent_tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    retail_billing_mode,
    invoice_status,
    profile_id,
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
    v_issued_by,
    v_invoice_no,
    p_invoice_type,
    v_invoice_date,
    p_retail_billing_mode,
    'draft'::public.global_invoice_status,
    p_profile_id,
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

  perform public.stamp_bill_kernel_fields(v_row.id);
  select * into v_row from public.bills where id = v_row.id;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.create_sales_invoice(bigint, text, bigint, public.global_invoice_type, public.global_source_module, text, text, text, bigint, numeric, text) TO anon;

GRANT ALL ON FUNCTION public.create_sales_invoice(bigint, text, bigint, public.global_invoice_type, public.global_source_module, text, text, text, bigint, numeric, text) TO
  authenticated;

GRANT ALL ON FUNCTION public.create_sales_invoice(bigint, text, bigint, public.global_invoice_type, public.global_source_module, text, text, text, bigint, numeric, text) TO
  service_role;

GRANT ALL ON FUNCTION public.create_sales_invoice(bigint, text, public.global_invoice_type, bigint, bigint, text, text, text, public.retail_billing_mode, date, text, date) TO anon;

GRANT ALL ON FUNCTION public.create_sales_invoice(bigint, text, public.global_invoice_type, bigint, bigint, text, text, text, public.retail_billing_mode, date, text, date) TO
  authenticated;

GRANT ALL ON FUNCTION public.create_sales_invoice(bigint, text, public.global_invoice_type, bigint, bigint, text, text, text, public.retail_billing_mode, date, text, date) TO
  service_role;