-- Per cost-entry AP: staff issues one payable per line (no auto-sync on save).

CREATE OR REPLACE FUNCTION public._build_shipment_ap_cost_entry_paper(
  p_entry public.global_shipment_cost_entries,
  p_ship public.global_shipments
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO public
AS $$
declare
  v_currency_code text := 'BDT';
  v_currency_symbol text := '৳';
  v_amount numeric(12, 2);
  v_desc text;
  v_line jsonb;
begin
  select coalesce(c.code, 'BDT'), coalesce(c.symbol, c.code, '৳')
  into v_currency_code, v_currency_symbol
  from public.global_currencies c
  where c.id = coalesce(
    p_entry.currency_id,
    p_ship.shipment_cost_currency_id,
    p_ship.shipment_purchase_currency_id
  );

  v_amount := round(coalesce(p_entry.amount, 0), 2);
  v_desc := coalesce(
    nullif(trim(p_entry.description), ''),
    nullif(trim(p_entry.metadata->>'description'), ''),
    initcap(replace(p_entry.cost_component::text, '_', ' '))
  );

  v_line := jsonb_build_object(
    'description', v_desc,
    'amount', v_amount,
    'currency_code', v_currency_code,
    'currency_symbol', v_currency_symbol,
    'cost_entry_id', p_entry.id
  );

  return jsonb_build_object(
    'paper', p_entry.cost_bucket::text,
    'lines', jsonb_build_array(v_line),
    'currency_groups', jsonb_build_array(
      jsonb_build_object(
        'currency_code', v_currency_code,
        'currency_symbol', v_currency_symbol,
        'foreign_total', v_amount,
        'lines', jsonb_build_array(v_line)
      )
    ),
    'mixed_currencies', false,
    'foreign_total', v_amount,
    'currency_code', v_currency_code,
    'currency_symbol', v_currency_symbol,
    'bdt_amount', case
      when upper(coalesce(v_currency_code, 'BDT')) in ('', 'BDT') then v_amount
      else null
    end,
    'cost_entry_id', p_entry.id
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_cost_entry_ap(p_cost_entry_id bigint)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_entry public.global_shipment_cost_entries%rowtype;
  v_ship public.global_shipments%rowtype;
  v_parent bigint;
  v_issued_by bigint;
  v_vendor_profile bigint;
  v_cargo_profile bigint;
  v_local_profile bigint;
  v_tenant_name text;
  v_profile bigint;
  v_paper jsonb;
  v_plug_key text;
  v_amount numeric(12, 2);
  v_bill_id bigint;
  v_result public.bills;
begin
  if p_cost_entry_id is null then
    raise exception 'cost_entry_id is required';
  end if;

  select * into v_entry
  from public.global_shipment_cost_entries
  where id = p_cost_entry_id
  for update;

  if not found then
    raise exception 'cost entry not found';
  end if;

  select * into v_ship
  from public.global_shipments
  where id = v_entry.shipment_id
  for update;

  perform public._assert_shipment_cost_entry_mutable(p_cost_entry_id);

  if coalesce(v_entry.amount, 0) <= 0 then
    raise exception 'cost amount must be greater than zero';
  end if;

  v_parent := v_ship.tenant_id;
  v_issued_by := coalesce(v_ship.assigned_child_tenant_id, v_parent);

  if not public.user_can_manage_books_tenant(v_parent) then
    raise exception 'Permission denied';
  end if;

  if v_ship.vendor_id is not null then
    select pr.id into v_vendor_profile
    from public.profiles pr
    where pr.tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.tenant_id = v_parent
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

  v_profile := case v_entry.cost_bucket
    when 'material'::public.global_shipment_cost_bucket then v_vendor_profile
    when 'freight'::public.global_shipment_cost_bucket then v_cargo_profile
    when 'customs'::public.global_shipment_cost_bucket then v_cargo_profile
    else v_local_profile
  end;

  if v_profile is null then
    raise exception 'No vendor/cargo profile for this cost line; set shipment vendor or cargo first';
  end if;

  v_paper := public._build_shipment_ap_cost_entry_paper(v_entry, v_ship);
  if coalesce((v_paper->>'bdt_amount')::numeric, 0) <= 0
     and coalesce((v_paper->>'foreign_total')::numeric, 0) > 0 then
    v_paper := v_paper || jsonb_build_object(
      'bdt_amount', (v_paper->>'foreign_total')::numeric
    );
  end if;
  v_amount := round(coalesce((v_paper->>'foreign_total')::numeric, v_entry.amount), 2);
  v_plug_key := 'entry:' || p_cost_entry_id::text;

  v_bill_id := public._upsert_shipment_ap_bill(
    v_parent,
    v_issued_by,
    v_entry.shipment_id,
    v_ship.name,
    v_entry.cost_bucket::text,
    v_profile,
    v_amount,
    v_paper,
    true,
    v_plug_key
  );

  if v_bill_id is null then
    raise exception 'Could not create payable for cost entry %', p_cost_entry_id;
  end if;

  perform set_config('app.bill_desk_issue_shipment_ap', '1', true);
  perform set_config('app.shipment_ap_issue', '1', true);
  begin
    v_result := public.issue_bill(v_bill_id);
  exception
    when others then
      perform set_config('app.bill_desk_issue_shipment_ap', '0', true);
      perform set_config('app.shipment_ap_issue', '0', true);
      raise;
  end;
  perform set_config('app.bill_desk_issue_shipment_ap', '0', true);
  perform set_config('app.shipment_ap_issue', '0', true);

  update public.global_shipment_cost_entries
  set
    metadata = coalesce(metadata, '{}'::jsonb)
      || jsonb_build_object(
        'ap_bill_id', v_bill_id,
        'ap_bill_issued_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
      ),
    updated_at = now()
  where id = p_cost_entry_id;

  return v_result;
end;
$$;

GRANT EXECUTE ON FUNCTION public.issue_shipment_cost_entry_ap(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_shipment_cost_entry_ap(bigint) TO service_role;
