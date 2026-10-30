-- Shipment AP lifecycle: upsert fix, lock/issue/pay guards
-- Shipment AP draft upsert (sync adapter). Called from sync_shipment_ap_bills / upsert_draft_bill adapter.

CREATE OR REPLACE FUNCTION public._upsert_shipment_ap_bill(
  p_parent_tenant_id bigint,
  p_issued_by_tenant_id bigint,
  p_shipment_id bigint,
  p_shipment_name text,
  p_ap_kind text,
  p_profile_id bigint,
  p_amount numeric,
  p_ap_paper jsonb DEFAULT NULL,
  p_keep_as_draft boolean DEFAULT false,
  p_source_key text DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_target numeric(12, 2);
  v_old_total numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_kind_label text;
  v_meta_base jsonb;
  v_paper_status public.global_invoice_status;
  v_plug_key text;
  v_face_currency text;
  v_base_note text;
  v_note text;
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  v_plug_key := coalesce(nullif(btrim(p_source_key), ''), p_ap_kind);
  v_face_currency := upper(trim(coalesce(p_ap_paper->>'currency_code', 'BDT')));

  select * into v_bill
  from public.bills b
  where b.parent_tenant_id = p_parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.source_type = 'shipment_cost'
    and b.source_id = p_shipment_id::text
    and b.source_key = v_plug_key
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

  v_base_note := format(
    'Shipment %s — %s AP%s',
    coalesce(p_shipment_name, p_shipment_id::text),
    v_kind_label,
    case when v_plug_key <> p_ap_kind then ' (' || v_plug_key || ')' else '' end
  );

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(
      p_issued_by_tenant_id,
      'ap'::public.global_invoice_type,
      current_date
    );
    insert into public.bills (
      parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind
    ) values (
      p_parent_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, p_profile_id, 'profile'::public.collection_source_type, 'due',
      v_target, v_target, v_target, 0,
      p_shipment_id, p_ap_kind, 'shipment_cost', p_shipment_id::text, v_plug_key, v_face_currency,
      v_base_note,
      v_meta_base,
      'standard'::public.bill_document_kind
    )
    returning id into v_bill.id;
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'issued'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) = 0
       and not exists (
         select 1 from public.bill_settlements bs where bs.bill_id = v_bill.id
       )
       and p_ap_paper is not null then
      update public.bills
      set
        channel_meta = coalesce(channel_meta, '{}'::jsonb)
          || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
          || jsonb_build_object('ap_paper', p_ap_paper),
        updated_at = now()
      where id = v_bill.id;
    end if;
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
      source_type = coalesce(source_type, 'shipment_cost'),
      source_id = coalesce(source_id, p_shipment_id::text),
      source_key = coalesce(source_key, v_plug_key),
      currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
      note = v_base_note,
      channel_meta = coalesce(channel_meta, '{}'::jsonb)
        || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
        || case
          when p_ap_paper is not null then jsonb_build_object('ap_paper', p_ap_paper)
          else '{}'::jsonb
        end,
      updated_at = now()
    where id = v_bill.id;

    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  v_old_total := round(coalesce(v_bill.total_amount, 0), 2);
  v_note := coalesce(nullif(trim(v_bill.note), ''), v_base_note);
  if v_old_total is distinct from v_target then
    v_note := v_note || format(
      E'\nCost sync %s: %s → %s %s',
      to_char(current_date, 'YYYY-MM-DD'),
      v_old_total,
      v_target,
      v_face_currency
    );
  end if;

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
    source_type = coalesce(source_type, 'shipment_cost'),
    source_id = coalesce(source_id, p_shipment_id::text),
    source_key = coalesce(source_key, v_plug_key),
    currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
    note = v_note,
    channel_meta = coalesce(channel_meta, '{}'::jsonb)
      || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
      || case
        when p_ap_paper is not null and coalesce(v_bill.paid_amount, 0) = 0
        then jsonb_build_object('ap_paper', p_ap_paper)
        else '{}'::jsonb
      end,
    updated_at = now()
  where id = v_bill.id;

  perform public.stamp_bill_kernel_fields(v_bill.id);
  return v_bill.id;
end;
$$;

-- Procurement: lock shipment costs → sync AP → issue AP (calls bills_pays adapters).

CREATE OR REPLACE FUNCTION public.lock_global_shipment_costs(p_shipment_id bigint)
RETURNS public.global_shipments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
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

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Set shipment to in transit or received before locking costs';
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

  perform set_config('app.shipment_ap_issue', '1', true);
  perform public.issue_shipment_ap_bills(p_shipment_id);
  perform set_config('app.shipment_ap_issue', '0', true);

  return v_ship;
end;
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_issue_allowed(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Shipment % must be in transit or received before issuing AP bills', p_shipment_id;
  end if;

  if not coalesce(v_ship.costs_locked, false) then
    raise exception 'Shipment % costs are not locked; use Lock costs on the shipment first', p_shipment_id;
  end if;

  if current_setting('app.shipment_ap_issue', true) is distinct from '1'
     and coalesce(auth.role(), '') is distinct from 'service_role' then
    raise exception 'Issue shipment AP only via lock_global_shipment_costs on the shipment';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_payable(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if v_ship.status in ('draft', 'cancelled') then
    raise exception 'Shipment % must be in transit or received before AP payout', p_shipment_id;
  end if;

  if not coalesce(v_ship.costs_locked, false) then
    raise exception 'Shipment % costs are not locked; lock and issue AP before payout', p_shipment_id;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_allocations_payable(p_allocations jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_elem jsonb;
  v_bill_id bigint;
  v_bill public.bills;
begin
  if p_allocations is null or jsonb_typeof(p_allocations) <> 'array' then
    return;
  end if;

  for v_elem in select value from jsonb_array_elements(p_allocations)
  loop
    v_bill_id := nullif(v_elem->>'bill_id', '')::bigint;
    if v_bill_id is null then
      continue;
    end if;

    select * into v_bill from public.bills where id = v_bill_id;
    if v_bill.id is null then
      raise exception 'Allocation bill % not found', v_bill_id;
    end if;

    if v_bill.invoice_type = 'ap'::public.global_invoice_type
       and v_bill.source_type = 'shipment_cost'
       and v_bill.invoice_status <> 'issued'::public.global_invoice_status then
      raise exception 'Bill % must be issued before shipment AP payout', v_bill_id;
    end if;

    if v_bill.ap_shipment_id is not null then
      perform public._assert_shipment_ap_payable(v_bill.ap_shipment_id);
    elsif v_bill.source_type = 'shipment_cost' and nullif(trim(v_bill.source_id), '') is not null then
      perform public._assert_shipment_ap_payable(nullif(trim(v_bill.source_id), '')::bigint);
    end if;
  end loop;
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
        'issue_rpc', 'issue_bill'
      )
    );
end;
$$;

CREATE OR REPLACE FUNCTION public.post_shipment_ap_money_out(
  p_shipment_ids bigint[],
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_source text DEFAULT 'ap_payout',
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_type text DEFAULT 'shipment_cost',
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_sid text;
  v_primary bigint;
  v_sid_loop bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  for v_sid_loop in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
  loop
    perform public._assert_shipment_ap_payable(v_sid_loop);
  end loop;

  perform public._assert_shipment_ap_allocations_payable(p_allocations);

  select min(x.id) into v_primary from unnest(p_shipment_ids) as x(id) where x.id is not null;
  v_sid := coalesce(nullif(trim(p_source_id), ''), v_primary::text);

  v_pay := public.post_money_out(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_amount,
    p_source,
    p_note,
    p_reference,
    p_cashbook_point_id,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    coalesce(nullif(trim(p_source_type), ''), 'shipment_cost'),
    v_sid,
    p_idempotency_key
  );

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION public.post_shipment_ap_money_out_snapshot(
  p_shipment_ids bigint[],
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_cashbook_point_id bigint,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_sid_loop bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  for v_sid_loop in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
  loop
    perform public._assert_shipment_ap_payable(v_sid_loop);
  end loop;

  perform public._assert_shipment_ap_allocations_payable(p_allocations);

  return public.post_ap_payout_with_allocations_snapshot(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_cashbook_point_id,
    p_note,
    p_reference,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    p_source_currency_code,
    p_transaction_rate,
    p_cashbook_point_pot_id,
    p_idempotency_key
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bills(p_shipment_id bigint)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_bill_id bigint;
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

  perform public._assert_shipment_ap_issue_allowed(p_shipment_id);
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
        (b.source_type = 'shipment_cost' and b.source_id = p_shipment_id::text)
        or b.ap_shipment_id = p_shipment_id
      )
    order by b.id asc
  loop
    perform public.issue_bill(v_bill_id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bill_for_kind(
  p_shipment_id bigint,
  p_ap_kind text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  raise exception 'issue_shipment_ap_bill_for_kind is retired. Use lock_global_shipment_costs on shipment % to sync and issue all AP bills.',
    p_shipment_id;
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_bill(p_bill_id bigint)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;
  if v_bill.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'only draft bills can be issued';
  end if;

  if v_bill.ap_shipment_id is not null
     and v_bill.invoice_type = 'ap'::public.global_invoice_type then
    perform public._assert_shipment_ap_issue_allowed(v_bill.ap_shipment_id);
  elsif v_bill.invoice_type = 'ap'::public.global_invoice_type
    and v_bill.source_type = 'shipment_cost'
    and nullif(trim(v_bill.source_id), '') is not null then
    perform public._assert_shipment_ap_issue_allowed(nullif(trim(v_bill.source_id), '')::bigint);
  end if;

  update public.bills
  set
    invoice_status = 'issued'::public.global_invoice_status,
    due_amount = total_amount,
    paid_amount = 0,
    payment_status = 'due',
    updated_at = now()
  where id = p_bill_id
  returning * into v_bill;

  perform public._kernel_freeze_bill_txn_face(p_bill_id);
  select * into v_bill from public.bills where id = p_bill_id;

  return v_bill;
end;
$$;
