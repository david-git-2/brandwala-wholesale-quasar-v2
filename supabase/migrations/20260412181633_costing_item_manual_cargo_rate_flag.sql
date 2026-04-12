alter table public.costing_file_items
  add column if not exists cargo_rate_is_manual boolean not null default false;

create or replace function public.apply_costing_item_calculations()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cargo_rate_1kg numeric(12,2);
  v_cargo_rate_2kg numeric(12,2);
  v_conversion_rate numeric(12,2);
  v_admin_profit_rate numeric(12,2);
  v_total_weight integer;
  v_auxiliary_price_gbp numeric(12,2);
  v_item_price_gbp numeric(12,2);
  v_cargo_rate numeric(12,2);
  v_costing_price_gbp numeric(12,2);
  v_costing_price_bdt integer;
  v_calculated_offer_price_bdt integer;
begin
  select
    cf.cargo_rate_1kg,
    cf.cargo_rate_2kg,
    cf.conversion_rate,
    cf.admin_profit_rate
  into
    v_cargo_rate_1kg,
    v_cargo_rate_2kg,
    v_conversion_rate,
    v_admin_profit_rate
  from public.costing_files cf
  where cf.id = new.costing_file_id;

  v_total_weight := coalesce(new.product_weight, 0) + coalesce(new.package_weight, 0);
  v_auxiliary_price_gbp := public.calculate_costing_auxiliary_price_gbp(
    new.price_in_web_gbp,
    new.delivery_price_gbp
  )::numeric(12,2);

  v_item_price_gbp := round(
    (
      coalesce(new.price_in_web_gbp, 0)
      + coalesce(new.delivery_price_gbp, 0)
      + coalesce(v_auxiliary_price_gbp, 0)
    )::numeric,
    2
  );

  if coalesce(new.cargo_rate_is_manual, false) and new.cargo_rate is not null then
    v_cargo_rate := round(new.cargo_rate::numeric, 2);
  elsif v_item_price_gbp > 10 then
    v_cargo_rate := coalesce(v_cargo_rate_2kg, 0);
  else
    v_cargo_rate := coalesce(v_cargo_rate_1kg, 0);
  end if;

  v_cargo_rate := round(v_cargo_rate::numeric, 2);

  v_costing_price_gbp := round(
    (
      coalesce(v_item_price_gbp, 0)
      + (coalesce(v_total_weight, 0) / 1000.0) * coalesce(v_cargo_rate, 0)
    )::numeric,
    2
  );

  v_costing_price_bdt := public.round_bdt_up_to_zero_or_five(
    coalesce(v_costing_price_gbp, 0) * coalesce(v_conversion_rate, 0)
  );

  v_calculated_offer_price_bdt := public.round_bdt_up_to_zero_or_five(
    v_costing_price_bdt + (v_costing_price_bdt * coalesce(v_admin_profit_rate, 0) / 100.0)
  );

  new.auxiliary_price_gbp := v_auxiliary_price_gbp;
  new.item_price_gbp := v_item_price_gbp;
  new.cargo_rate := v_cargo_rate;
  new.costing_price_gbp := v_costing_price_gbp;
  new.costing_price_bdt := v_costing_price_bdt;
  new.offer_price_bdt := coalesce(new.offer_price_override_bdt, v_calculated_offer_price_bdt);

  return new;
end;
$$;
