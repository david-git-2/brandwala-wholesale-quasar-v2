-- P3/P4: kernel landed FX, retire cost entries table
-- Landed FX: capitalizable totals from kernel shipment AP bill lines (Option A).

CREATE OR REPLACE FUNCTION public._global_shipment_landed_fx_inputs(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_mat jsonb;
  v_fre jsonb;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_product_foreign numeric := 0;
  v_cargo_foreign numeric := 0;
  v_goods_bdt numeric := 0;
  v_freight_bdt numeric := 0;
  v_blended numeric := 1;
  v_kg numeric := 0;
  v_cargo_per_kg numeric := 0;
  v_mat_count integer := 0;
  v_fre_count integer := 0;
  v_entry_material numeric := 0;
  v_entry_freight numeric := 0;
BEGIN
  v_mat := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'material');
  v_fre := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'freight');

  v_mat_count := coalesce((v_mat ->> 'payment_count')::integer, 0);
  v_fre_count := coalesce((v_fre ->> 'payment_count')::integer, 0);

  IF v_mat_count > 0 THEN
    v_prod_rate := coalesce((v_mat ->> 'conversion_rate')::numeric, 1);
  END IF;
  IF v_fre_count > 0 THEN
    v_cargo_fx := coalesce((v_fre ->> 'conversion_rate')::numeric, 1);
  END IF;

  v_entry_material := public._shipment_kernel_capitalizable_bucket_total(p_shipment_id, 'material');
  v_entry_freight := public._shipment_kernel_capitalizable_bucket_total(p_shipment_id, 'freight');

  IF v_entry_material <= 0 AND to_regclass('public.global_shipment_cost_entries') IS NOT NULL THEN
    SELECT coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'material'), 0)
      INTO v_entry_material
      FROM public.global_shipment_cost_entries gce
     WHERE gce.shipment_id = p_shipment_id;
  END IF;

  IF v_entry_freight <= 0 AND to_regclass('public.global_shipment_cost_entries') IS NOT NULL THEN
    SELECT coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'freight'), 0)
      INTO v_entry_freight
      FROM public.global_shipment_cost_entries gce
     WHERE gce.shipment_id = p_shipment_id;
  END IF;

  v_product_foreign := coalesce((v_mat ->> 'foreign_paid')::numeric, 0);
  IF v_product_foreign <= 0 THEN
    v_product_foreign := v_entry_material;
  END IF;

  v_cargo_foreign := coalesce((v_fre ->> 'foreign_paid')::numeric, 0);
  IF v_cargo_foreign <= 0 THEN
    v_cargo_foreign := v_entry_freight;
  END IF;

  v_goods_bdt := round(v_product_foreign * v_prod_rate, 2);
  v_freight_bdt := round(v_cargo_foreign * v_cargo_fx, 2);

  IF (v_product_foreign + v_cargo_foreign) > 0 THEN
    v_blended := round((v_goods_bdt + v_freight_bdt) / (v_product_foreign + v_cargo_foreign), 6);
  ELSE
    v_blended := 1;
  END IF;

  SELECT coalesce(gs.total_weight_kg, gs.received_weight, 0)
    INTO v_kg
    FROM public.global_shipments gs
   WHERE gs.id = p_shipment_id;

  IF coalesce(v_kg, 0) > 0 AND v_cargo_foreign > 0 THEN
    v_cargo_per_kg := round(v_cargo_foreign / v_kg, 6);
  END IF;

  RETURN jsonb_build_object(
    'material', v_mat,
    'freight', v_fre,
    'goods_bdt', v_goods_bdt,
    'freight_bdt', v_freight_bdt,
    'product_foreign', v_product_foreign,
    'cargo_foreign', v_cargo_foreign,
    'product_conversion_rate', v_prod_rate,
    'cargo_conversion_rate', v_cargo_fx,
    'cargo_rate', v_cargo_per_kg,
    'transaction_rate', v_blended,
    'blended_rate', v_blended
  );
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
        'net_balances', v_elem->'net_balances'
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

CREATE OR REPLACE FUNCTION public.stamp_global_shipment_landed_costs(p_shipment_id bigint)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_cargo_foreign numeric := 0;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_fx jsonb;
  v_pack_kg numeric := 0;
  v_updated integer := 0;
  r record;
  v_line_gross numeric;
  v_line_cargo_share numeric;
  v_unit_product numeric;
  v_unit_cargo numeric;
  v_landed numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_cargo_foreign := coalesce((v_fx ->> 'cargo_foreign')::numeric, 0);
  v_prod_rate := coalesce((v_fx ->> 'product_conversion_rate')::numeric, 1);
  v_cargo_fx := coalesce((v_fx ->> 'cargo_conversion_rate')::numeric, 1);

  select coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
  into v_pack_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  perform set_config('app.allow_landed_cost_stamp', '1', true);

  for r in
    select *
    from public.global_shipment_items
    where shipment_id = p_shipment_id
  loop
    v_line_gross := (
      (coalesce(r.product_weight, 0) + coalesce(r.package_weight, 0)) * r.ordered_quantity
    ) / 1000.0;

    if v_pack_kg > 0 then
      v_line_cargo_share := (v_line_gross / v_pack_kg) * v_cargo_foreign;
    elsif (select coalesce(sum(ordered_quantity), 0) from public.global_shipment_items where shipment_id = p_shipment_id) > 0 then
      v_line_cargo_share := (r.ordered_quantity::numeric
        / (select sum(ordered_quantity) from public.global_shipment_items where shipment_id = p_shipment_id)
      ) * v_cargo_foreign;
    else
      v_line_cargo_share := 0;
    end if;

    if r.ordered_quantity > 0 then
      v_unit_product := coalesce(r.purchase_price, 0);
      v_unit_cargo := v_line_cargo_share / r.ordered_quantity;
    else
      v_unit_product := coalesce(r.purchase_price, 0);
      v_unit_cargo := 0;
    end if;

    if v_ship.type::text in ('local', 'domestic') then
      v_landed := v_unit_product + v_unit_cargo;
    else
      v_landed := (v_unit_product * v_prod_rate) + (v_unit_cargo * v_cargo_fx);
    end if;

    update public.global_shipment_items
    set landed_cost_bdt = round(v_landed::numeric, 4)
    where id = r.id;

    v_updated := v_updated + 1;
  end loop;

  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

  return v_updated;
end;
$$;

DROP FUNCTION IF EXISTS public.issue_shipment_cost_entry_ap_v2(bigint);
DROP FUNCTION IF EXISTS public.ensure_global_shipment_cost_entries_from_header(bigint);
DROP FUNCTION IF EXISTS public.save_global_shipment_cost_entries_batch(jsonb);
DROP TABLE IF EXISTS public.global_shipment_cost_entries CASCADE;
