-- Credit/debit notes on bills (kernel). No separate notes table.

DO $$
BEGIN
  CREATE TYPE public.bill_document_kind AS ENUM (
    'standard',
    'credit_note',
    'debit_note'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

ALTER TABLE public.bills
  ADD COLUMN IF NOT EXISTS document_kind public.bill_document_kind
    DEFAULT 'standard'::public.bill_document_kind NOT NULL,
  ADD COLUMN IF NOT EXISTS parent_bill_id bigint;

UPDATE public.bills
SET document_kind = 'standard'::public.bill_document_kind
WHERE document_kind IS NULL;

ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_document_parent_check;
ALTER TABLE public.bills
  ADD CONSTRAINT bills_document_parent_check CHECK (
    (
      (document_kind = 'standard'::public.bill_document_kind AND parent_bill_id IS NULL)
      OR (document_kind <> 'standard'::public.bill_document_kind AND parent_bill_id IS NOT NULL)
    )
  );

ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_parent_bill_id_fkey;
ALTER TABLE public.bills
  ADD CONSTRAINT bills_parent_bill_id_fkey
  FOREIGN KEY (parent_bill_id) REFERENCES public.bills(id) ON DELETE RESTRICT;

DROP INDEX IF EXISTS public.bills_ap_shipment_kind_uidx;
CREATE UNIQUE INDEX bills_ap_shipment_kind_uidx
  ON public.bills USING btree (parent_tenant_id, ap_shipment_id, ap_kind)
  WHERE (
    invoice_type = 'ap'::public.global_invoice_type
    AND document_kind = 'standard'::public.bill_document_kind
    AND ap_shipment_id IS NOT NULL
    AND ap_kind IS NOT NULL
  );

CREATE INDEX IF NOT EXISTS bills_parent_bill_id_idx
  ON public.bills USING btree (parent_bill_id)
  WHERE (parent_bill_id IS NOT NULL);

CREATE OR REPLACE FUNCTION public.recompute_global_invoice_payment_status(p_global_invoice_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_bill public.bills;
  v_root_id bigint;
  v_total numeric(12,2);
  v_paid numeric(12,2);
  v_written_off numeric(12,2);
  v_credits numeric(12,2);
  v_debits numeric(12,2);
  v_due numeric(12,2);
  v_parent_remaining numeric(12,2);
  v_credit_pool numeric(12,2);
  v_child record;
  v_child_paid numeric(12,2);
  v_applied numeric(12,2);
  v_child_due numeric(12,2);
begin
  select * into v_bill from public.bills where id = p_global_invoice_id;
  if not found then return; end if;

  v_root_id := coalesce(v_bill.parent_bill_id, v_bill.id);

  select * into v_bill from public.bills where id = v_root_id for update;
  if not found then return; end if;

  select coalesce(sum(amount), 0.00) into v_paid
  from public.pay_allocations where global_invoice_id = v_root_id;

  select coalesce(sum(amount), 0.00) into v_written_off
  from public.invoice_write_offs where invoice_id = v_root_id;

  select coalesce(sum(total_amount), 0.00) into v_credits
  from public.bills
  where parent_bill_id = v_root_id
    and document_kind = 'credit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(total_amount), 0.00) into v_debits
  from public.bills
  where parent_bill_id = v_root_id
    and document_kind = 'debit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  v_total := coalesce(v_bill.total_amount, 0.00);
  v_parent_remaining := greatest(v_total - v_paid - v_written_off, 0.00);
  v_due := greatest(v_parent_remaining - v_credits + v_debits, 0.00);

  update public.bills
  set
    paid_amount = v_paid,
    written_off_amount = v_written_off,
    due_amount = v_due,
    payment_status = case
      when v_due = 0.00 and v_written_off > 0.00 then 'settled_with_write_off'
      when v_due = 0.00 and v_paid > 0.00 then 'paid'
      when v_paid > 0.00 or v_written_off > 0.00 then 'partially_paid'
      else 'due'
    end,
    updated_at = now()
  where id = v_root_id;

  v_credit_pool := least(v_credits, v_parent_remaining);

  for v_child in
    select id, document_kind, total_amount, invoice_status
    from public.bills
    where parent_bill_id = v_root_id
    order by id
  loop
    select coalesce(sum(amount), 0.00) into v_child_paid
    from public.pay_allocations where global_invoice_id = v_child.id;

    if v_child.invoice_status <> 'issued'::public.global_invoice_status then
      v_child_due := 0.00;
    elsif v_child.document_kind = 'credit_note'::public.bill_document_kind then
      v_applied := least(coalesce(v_child.total_amount, 0.00), v_credit_pool);
      v_credit_pool := v_credit_pool - v_applied;
      v_child_due := greatest(coalesce(v_child.total_amount, 0.00) - v_applied - v_child_paid, 0.00);
    else
      v_child_due := 0.00;
    end if;

    update public.bills
    set
      paid_amount = v_child_paid,
      due_amount = v_child_due,
      payment_status = case
        when v_child.invoice_status = 'voided'::public.global_invoice_status then 'due'
        when v_child_due = 0.00 and v_child_paid > 0.00 then 'paid'
        when v_child_due = 0.00 then 'paid'
        when v_child_paid > 0.00 then 'partially_paid'
        else 'due'
      end,
      updated_at = now()
    where id = v_child.id;
  end loop;
end;
$$;

CREATE OR REPLACE FUNCTION public.create_bill_adjustment(
  p_parent_bill_id bigint,
  p_kind text,
  p_amount numeric,
  p_reason text,
  p_issue boolean DEFAULT true
) RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_parent public.bills;
  v_kind public.bill_document_kind;
  v_row public.bills;
  v_no text;
  v_reason text;
  v_amount numeric(12,2);
  v_status public.global_invoice_status;
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

  v_amount := round(coalesce(p_amount, 0), 2);
  if v_amount <= 0 then
    raise exception 'amount must be greater than zero';
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

  v_no := public.generate_sales_invoice_number(
    v_parent.issued_by_tenant_id,
    v_parent.invoice_type,
    current_date
  );
  if v_kind = 'credit_note'::public.bill_document_kind then
    v_no := replace(v_no, 'INV-', 'INV-CN-');
  else
    v_no := replace(v_no, 'INV-', 'INV-DN-');
  end if;

  v_status := case when coalesce(p_issue, true)
    then 'issued'::public.global_invoice_status
    else 'draft'::public.global_invoice_status
  end;

  insert into public.bills (
    parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
    invoice_status, profile_id, collection_source, payment_status,
    subtotal_amount, total_amount, due_amount, paid_amount, note,
    document_kind, parent_bill_id, ap_shipment_id, ap_kind, channel_meta
  ) values (
    v_parent.parent_tenant_id, v_parent.issued_by_tenant_id, v_no, v_parent.invoice_type, current_date,
    v_status, v_parent.profile_id, v_parent.collection_source, 'due',
    v_amount, v_amount, v_amount, 0, v_reason,
    v_kind, v_parent.id, v_parent.ap_shipment_id, v_parent.ap_kind,
    jsonb_build_object(
      'adjustment', jsonb_build_object(
        'kind', v_kind::text,
        'reason', v_reason,
        'parent_invoice_no', v_parent.invoice_no
      )
    )
  )
  returning * into v_row;

  if v_status = 'issued'::public.global_invoice_status then
    perform public.recompute_global_invoice_payment_status(v_parent.id);
    select * into v_row from public.bills where id = v_row.id;
  end if;

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_bill_adjustment(p_adjustment_id bigint)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_row public.bills;
begin
  select * into v_row from public.bills where id = p_adjustment_id for update;
  if v_row.id is null then
    raise exception 'adjustment not found';
  end if;
  if v_row.document_kind = 'standard'::public.bill_document_kind then
    raise exception 'not an adjustment bill';
  end if;
  if v_row.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'only draft adjustments can be issued';
  end if;
  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_row.parent_tenant_id)
    or public.membership_has_module_action(v_row.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  update public.bills
  set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
  where id = p_adjustment_id
  returning * into v_row;

  perform public.recompute_global_invoice_payment_status(v_row.parent_bill_id);
  select * into v_row from public.bills where id = p_adjustment_id;
  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION public.list_bill_adjustments(p_parent_bill_id bigint)
RETURNS SETOF public.bills
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  select b.*
  from public.bills b
  where b.parent_bill_id = p_parent_bill_id
  order by b.id;
$$;

CREATE OR REPLACE FUNCTION public.get_bill_net_balances(p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_bill public.bills;
  v_root public.bills;
  v_credits numeric(12,2);
  v_debits numeric(12,2);
  v_credit_due numeric(12,2);
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;

  select * into v_root
  from public.bills
  where id = coalesce(v_bill.parent_bill_id, v_bill.id);

  select coalesce(sum(total_amount), 0.00), coalesce(sum(due_amount), 0.00)
  into v_credits, v_credit_due
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'credit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(total_amount), 0.00) into v_debits
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'debit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  return jsonb_build_object(
    'bill_id', v_root.id,
    'invoice_no', v_root.invoice_no,
    'original_total', v_root.total_amount,
    'paid_amount', v_root.paid_amount,
    'credits_issued', v_credits,
    'debits_issued', v_debits,
    'due_amount', v_root.due_amount,
    'credit_open', v_credit_due,
    'document_kind', v_bill.document_kind
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.void_sales_invoice(p_invoice_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_invoice public.bills;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'only issued invoices can be voided';
  end if;
  if v_invoice.paid_amount > 0 then
    raise exception 'cannot void a paid or partially paid invoice; reverse collections/payments first';
  end if;

  if v_invoice.document_kind = 'standard'::public.bill_document_kind
     and exists (
       select 1 from public.bills n
       where n.parent_bill_id = p_invoice_id
         and n.invoice_status <> 'voided'::public.global_invoice_status
     ) then
    raise exception 'void or issue credit on child notes before voiding this bill';
  end if;

  update public.bills
  set
    invoice_status = 'voided'::public.global_invoice_status,
    due_amount = 0.00
  where id = p_invoice_id;

  if v_invoice.parent_bill_id is not null then
    perform public.recompute_global_invoice_payment_status(v_invoice.parent_bill_id);
  end if;
end;
$$;

-- AP lookups ignore credit/debit children (unique bucket stays on standard paper).
CREATE OR REPLACE FUNCTION public._upsert_shipment_ap_bill(
  p_parent_tenant_id bigint,
  p_issued_by_tenant_id bigint,
  p_shipment_id bigint,
  p_shipment_name text,
  p_ap_kind text,
  p_profile_id bigint,
  p_amount numeric,
  p_ap_paper jsonb DEFAULT NULL,
  p_keep_as_draft boolean DEFAULT false
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
    and b.document_kind = 'standard'::public.bill_document_kind
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
      ap_shipment_id, ap_kind, note, channel_meta, document_kind
    ) values (
      p_parent_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, p_profile_id, 'billing_profile'::public.collection_source_type, 'due',
      v_target, v_target, v_target, 0,
      p_shipment_id, p_ap_kind,
      format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
      v_meta_base,
      'standard'::public.bill_document_kind
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

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bills(p_shipment_id bigint)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bill_for_kind(p_shipment_id bigint, p_ap_kind text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_parent bigint;
  v_bill_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  if p_ap_kind is null or trim(p_ap_kind) = '' then
    raise exception 'ap_kind is required';
  end if;

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

  update public.bills b
  set
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(b.payment_status, ''), 'due'),
    updated_at = now()
  where b.parent_tenant_id = v_parent
    and b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.ap_kind = p_ap_kind
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0
  returning b.id into v_bill_id;

  if v_bill_id is null then
    raise exception 'No draft AP bill to issue for bucket %', p_ap_kind;
  end if;

  return v_bill_id;
end;
$$;

CREATE OR REPLACE FUNCTION public.sync_shipment_ap_bills(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
      and document_kind = 'standard'::public.bill_document_kind
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
    v_amt := coalesce(
      (v_paper->>'foreign_total')::numeric,
      (v_paper->>'bdt_amount')::numeric,
      0
    );

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
    and document_kind = 'standard'::public.bill_document_kind
    and ap_kind in ('vendor', 'cargo', 'local')
    and invoice_status = 'issued'::public.global_invoice_status
    and coalesce(paid_amount, 0) = 0;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$$;

CREATE OR REPLACE FUNCTION public.shipment_ap_bucket_paid_totals(p_shipment_id bigint, p_ap_kind text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_bdt numeric := 0;
  v_foreign numeric := 0;
  v_count integer := 0;
  v_rate numeric := 1;
begin
  if p_shipment_id is null or nullif(trim(coalesce(p_ap_kind, '')), '') is null then
    return jsonb_build_object(
      'bdt_paid', 0,
      'foreign_paid', 0,
      'conversion_rate', 1,
      'payment_count', 0
    );
  end if;

  select
    coalesce(sum(
      round(
        case
          when coalesce(p.foreign_amount, 0) > 0 and coalesce(p.exchange_rate, 0) > 0 then
            pa.amount * p.exchange_rate
          else pa.amount
        end,
        2
      )
    ), 0),
    coalesce(sum(
      round(
        case
          when coalesce(p.foreign_amount, 0) > 0 then pa.amount
          else pa.amount
        end,
        2
      )
    ), 0),
    count(distinct p.id)::integer
  into v_bdt, v_foreign, v_count
  from public.bills b
  inner join public.pay_allocations pa on pa.global_invoice_id = b.id
  inner join public.pays p on p.id = pa.payment_id
  where b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.ap_kind = p_ap_kind
    and p.voided_at is null;

  if v_foreign > 0 then
    v_rate := round(v_bdt / v_foreign, 6);
  end if;

  return jsonb_build_object(
    'bdt_paid', v_bdt,
    'foreign_paid', v_foreign,
    'conversion_rate', v_rate,
    'payment_count', v_count
  );
end;
$$;

GRANT ALL ON FUNCTION public.create_bill_adjustment(bigint, text, numeric, text, boolean) TO authenticated;
GRANT ALL ON FUNCTION public.create_bill_adjustment(bigint, text, numeric, text, boolean) TO service_role;
GRANT ALL ON FUNCTION public.issue_bill_adjustment(bigint) TO authenticated;
GRANT ALL ON FUNCTION public.issue_bill_adjustment(bigint) TO service_role;
GRANT ALL ON FUNCTION public.list_bill_adjustments(bigint) TO authenticated;
GRANT ALL ON FUNCTION public.list_bill_adjustments(bigint) TO service_role;
GRANT ALL ON FUNCTION public.get_bill_net_balances(bigint) TO authenticated;
GRANT ALL ON FUNCTION public.get_bill_net_balances(bigint) TO service_role;
