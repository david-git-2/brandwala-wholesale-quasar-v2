-- Shipment AP bucket bills: draft while costs open, issued on lock.

update public.bills b
set invoice_status = 'draft'::public.global_invoice_status,
    updated_at = now()
from public.global_shipments gs
where b.ap_shipment_id = gs.id
  and b.invoice_type = 'ap'::public.global_invoice_type
  and b.invoice_status = 'issued'::public.global_invoice_status
  and coalesce(b.paid_amount, 0) = 0
  and coalesce(gs.costs_locked, false) = false;

-- Functions copied from supabase/schemas (bills_pays + procurement lock).

CREATE OR REPLACE FUNCTION "public"."_upsert_shipment_ap_bill"("p_parent_tenant_id" bigint, "p_issued_by_tenant_id" bigint, "p_shipment_id" bigint, "p_shipment_name" "text", "p_ap_kind" "text", "p_profile_id" bigint, "p_amount" numeric, "p_ap_paper" "jsonb" DEFAULT NULL::"jsonb", "p_keep_as_draft" boolean DEFAULT false) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bill public.bills;
  v_target numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_kind_label text;
  v_meta_base jsonb;
  v_paper_status public.global_invoice_status;
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select * into v_bill
  from public.bills b
  where b.parent_tenant_id = p_parent_tenant_id
    and b.ap_shipment_id = p_shipment_id
    and b.ap_kind = p_ap_kind
    and b.invoice_type = 'ap'::public.global_invoice_type
  for update;

  if p_profile_id is null or coalesce(p_amount, 0) <= 0 then
    if v_bill.id is not null and coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_status in (
         'issued'::public.global_invoice_status,
         'draft'::public.global_invoice_status
       ) then
      update public.bills
      set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
      where id = v_bill.id;
    end if;
    return null;
  end if;

  v_target := round(p_amount, 2);
  v_kind_label := initcap(replace(p_ap_kind, '_', ' '));
  v_meta_base := jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id);
  if p_ap_paper is not null then
    v_meta_base := v_meta_base || jsonb_build_object('ap_paper', p_ap_paper);
  end if;

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(p_issued_by_tenant_id, 'ap'::public.global_invoice_type, current_date);
    insert into public.bills (
      parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, note, channel_meta
    ) values (
      p_parent_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, p_profile_id, 'billing_profile'::public.collection_source_type, 'due',
      v_target, v_target, v_target, 0,
      p_shipment_id, p_ap_kind,
      format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
      v_meta_base
    )
    returning id into v_bill.id;
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return v_bill.id;
    end if;

    update public.bills
    set
      invoice_status = v_paper_status,
      profile_id = p_profile_id,
      subtotal_amount = v_target,
      total_amount = v_target,
      due_amount = v_target,
      payment_status = 'due',
      note = format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
      channel_meta = coalesce(channel_meta, '{}'::jsonb)
        || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
        || case
          when p_ap_paper is not null then jsonb_build_object('ap_paper', p_ap_paper)
          else '{}'::jsonb
        end,
      updated_at = now()
    where id = v_bill.id;

    return v_bill.id;
  end if;

  v_target := greatest(v_target, coalesce(v_bill.paid_amount, 0));
  v_due := greatest(v_target - coalesce(v_bill.paid_amount, 0), 0);
  v_status := case
    when v_due <= 0 then 'paid'
    when coalesce(v_bill.paid_amount, 0) > 0 then 'partially_paid'
    else 'due'
  end;

  update public.bills
  set
    profile_id = p_profile_id,
    subtotal_amount = v_target,
    total_amount = v_target,
    due_amount = v_due,
    payment_status = v_status,
    note = format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
    channel_meta = coalesce(channel_meta, '{}'::jsonb)
      || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
      || case
        when p_ap_paper is not null and coalesce(v_bill.paid_amount, 0) = 0
        then jsonb_build_object('ap_paper', p_ap_paper)
        else '{}'::jsonb
      end,
    updated_at = now()
  where id = v_bill.id;

  return v_bill.id;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."issue_shipment_ap_bills"("p_shipment_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent bigint;
  v_count integer := 0;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
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

  update public.bills b
  set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
  where b.parent_tenant_id = v_parent
    and b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."sync_shipment_ap_bills"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments;
  v_parent bigint;
  v_issued_by bigint;
  v_vendor_profile bigint;
  v_cargo_profile bigint;
  v_local_profile bigint;
  v_tenant_name text;
  v_bucket public.global_shipment_cost_bucket;
  v_bucket_text text;
  v_paper jsonb;
  v_amt numeric(12, 2);
  v_profile bigint;
  v_bill_id bigint;
  v_bills jsonb := '{}'::jsonb;
  v_keep_as_draft boolean := false;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  v_parent := v_ship.parent_tenant_id;
  v_issued_by := coalesce(v_ship.assigned_child_tenant_id, v_parent);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  if v_ship.vendor_id is not null then
    select pr.id into v_vendor_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'cargo'::public.profile_party_type
      and pr.subject_id = v_ship.cargo_company_id;
  end if;

  select t.name into v_tenant_name from public.tenants t where t.id = v_parent;

  v_local_profile := public.upsert_profile_for_party(
    v_parent,
    'company'::public.profile_party_type,
    v_parent,
    coalesce(v_tenant_name, 'Local opex'),
    null, null, '+880', null, false, null, true, null
  );

  v_keep_as_draft := not coalesce(v_ship.costs_locked, false);

  if v_ship.status = 'cancelled' then
    update public.bills
    set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
    where parent_tenant_id = v_parent
      and ap_shipment_id = p_shipment_id
      and invoice_type = 'ap'::public.global_invoice_type
      and invoice_status in (
        'issued'::public.global_invoice_status,
        'draft'::public.global_invoice_status
      )
      and coalesce(paid_amount, 0) = 0;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  foreach v_bucket_text in array enum_range(null::public.global_shipment_cost_bucket)::text[]
  loop
    v_bucket := v_bucket_text::public.global_shipment_cost_bucket;
    v_paper := public._build_shipment_ap_bucket_paper(p_shipment_id, v_ship, v_bucket);
    v_amt := coalesce((v_paper->>'bdt_amount')::numeric, 0);

    v_profile := case v_bucket
      when 'material'::public.global_shipment_cost_bucket then v_vendor_profile
      when 'freight'::public.global_shipment_cost_bucket then v_cargo_profile
      when 'customs'::public.global_shipment_cost_bucket then v_cargo_profile
      else v_local_profile
    end;

    v_bill_id := public._upsert_shipment_ap_bill(
      v_parent,
      v_issued_by,
      p_shipment_id,
      v_ship.name,
      v_bucket::text,
      v_profile,
      v_amt,
      v_paper,
      v_keep_as_draft
    );

    if v_bill_id is not null then
      v_bills := v_bills || jsonb_build_object(v_bucket::text, v_bill_id);
    end if;
  end loop;

  update public.bills
  set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
  where parent_tenant_id = v_parent
    and ap_shipment_id = p_shipment_id
    and invoice_type = 'ap'::public.global_invoice_type
    and ap_kind in ('vendor', 'cargo', 'local')
    and invoice_status = 'issued'::public.global_invoice_status
    and coalesce(paid_amount, 0) = 0;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."lock_global_shipment_costs"("p_shipment_id" bigint) RETURNS "public"."global_shipments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment stock is not posted; receive before locking costs';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are already locked';
  end if;

  perform set_config('app.allow_costs_lock', '1', true);

  update public.global_shipments
  set costs_locked = true,
      costs_locked_at = now(),
      costs_locked_by = auth.uid(),
      updated_at = now()
  where id = p_shipment_id
  returning * into v_ship;

  perform public.sync_shipment_ap_bills(p_shipment_id);
  perform public.issue_shipment_ap_bills(p_shipment_id);

  return v_ship;
end;
$$;

GRANT ALL ON FUNCTION public.issue_shipment_ap_bills(bigint) TO authenticated;
GRANT ALL ON FUNCTION public.issue_shipment_ap_bills(bigint) TO service_role;
