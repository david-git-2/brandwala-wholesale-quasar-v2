-- PBC offer modes: landed cost + profit, or VAT then profit on GBP web price.

do $$ begin
  create type public.pbc_offer_pricing_mode as enum (
    'landed_cost_plus',
    'gbp_vat_then_profit'
  );
exception
  when duplicate_object then null;
end $$;

alter table public.product_based_costing_files
  add column if not exists vat_rate numeric(12,4) default 0;

alter table public.product_based_costing_files
  add column if not exists offer_pricing_mode public.pbc_offer_pricing_mode
    default 'landed_cost_plus'::public.pbc_offer_pricing_mode;

update public.product_based_costing_files
   set offer_pricing_mode = 'landed_cost_plus'
 where offer_pricing_mode is null;

alter table public.product_based_costing_files
  alter column offer_pricing_mode set default 'landed_cost_plus'::public.pbc_offer_pricing_mode,
  alter column offer_pricing_mode set not null;

create or replace function public.pbc_calculated_offer_price_bdt(
    p_price_gbp numeric,
    p_product_weight numeric,
    p_package_weight numeric,
    p_cargo_rate numeric,
    p_conversion_rate numeric,
    p_profit_rate numeric,
    p_vat_rate numeric,
    p_offer_pricing_mode text
) returns numeric
    language plpgsql immutable
    as $$
declare
  v_mode text := coalesce(p_offer_pricing_mode, 'landed_cost_plus');
  v_fx numeric := coalesce(p_conversion_rate, 140);
  v_profit numeric := coalesce(p_profit_rate, 0);
  v_vat numeric := coalesce(p_vat_rate, 0);
  v_unit_cost_bdt numeric;
  v_marked_gbp numeric;
begin
  if v_mode = 'gbp_vat_then_profit' then
    v_marked_gbp := round(
      coalesce(p_price_gbp, 0) * (1 + v_vat / 100.0) * (1 + v_profit / 100.0),
      2
    );
    return public.round_bdt_up_to_zero_or_five(ceil(v_marked_gbp * v_fx - 1e-9));
  end if;

  v_unit_cost_bdt := ceil(
    round(
      (coalesce(p_price_gbp, 0) + ((coalesce(p_product_weight, 0) + coalesce(p_package_weight, 0)) / 1000.0) * coalesce(p_cargo_rate, 0)),
      2
    ) * v_fx - 1e-9
  );
  return public.round_bdt_up_to_zero_or_five(v_unit_cost_bdt + (v_unit_cost_bdt * v_profit / 100.0));
end;
$$;

create or replace function public.recalculate_product_based_costing_file_offer_prices(p_file_id bigint) returns void
    language plpgsql security definer
    as $$
declare
  v_conversion_rate numeric;
  v_cargo_rate numeric;
  v_profit_rate numeric;
  v_vat_rate numeric;
  v_offer_pricing_mode text;
begin
  select conversion_rate, cargo_rate_kg_gbp, profit_rate, vat_rate, offer_pricing_mode::text
    into v_conversion_rate, v_cargo_rate, v_profit_rate, v_vat_rate, v_offer_pricing_mode
    from public.product_based_costing_files
   where id = p_file_id;

  update public.product_based_costing_items
     set offer_price = public.pbc_calculated_offer_price_bdt(
           coalesce(price_gbp, 0),
           coalesce(product_weight, 0),
           coalesce(package_weight, 0),
           coalesce(v_cargo_rate, 0),
           coalesce(v_conversion_rate, 140),
           coalesce(v_profit_rate, 25),
           coalesce(v_vat_rate, 0),
           coalesce(v_offer_pricing_mode, 'landed_cost_plus')
         ),
         is_offer_price_manual = false
   where product_based_costing_file_id = p_file_id
     and (is_offer_price_manual is not true);
end;
$$;

drop function if exists public.get_product_based_costing_file_summary(bigint, numeric, numeric, numeric);

create or replace function public.get_product_based_costing_file_summary(
    p_file_id bigint,
    p_conversion_rate numeric default null::numeric,
    p_cargo_rate_kg_gbp numeric default null::numeric,
    p_profit_rate numeric default null::numeric,
    p_vat_rate numeric default null::numeric,
    p_offer_pricing_mode text default null::text
) returns jsonb
    language sql stable security definer
    set search_path to 'public'
    as $$
  with file_ctx as (
    select
      f.id,
      coalesce(p_conversion_rate, f.conversion_rate, 140)::numeric as conversion_rate,
      coalesce(p_cargo_rate_kg_gbp, f.cargo_rate_kg_gbp, 0)::numeric as cargo_rate,
      coalesce(p_profit_rate, f.profit_rate, 25)::numeric as profit_rate,
      coalesce(p_vat_rate, f.vat_rate, 0)::numeric as vat_rate,
      coalesce(p_offer_pricing_mode, f.offer_pricing_mode::text, 'landed_cost_plus') as offer_pricing_mode
    from public.product_based_costing_files f
    where f.id = p_file_id
      and public.can_view_costing_item(p_file_id)
  ),
  lines as (
    select
      i.id,
      greatest(coalesce(i.quantity, 0), 0)::numeric as qty,
      coalesce(i.price_gbp, 0)::numeric as price_gbp_n,
      coalesce(i.product_weight, 0)::numeric as product_weight_n,
      coalesce(i.package_weight, 0)::numeric as package_weight_n,
      coalesce(i.product_weight, 0) + coalesce(i.package_weight, 0) as weight_g,
      coalesce(i.is_offer_price_manual, false) as is_offer_price_manual,
      i.offer_price,
      fc.conversion_rate,
      fc.cargo_rate,
      fc.profit_rate,
      fc.vat_rate,
      fc.offer_pricing_mode
    from public.product_based_costing_items i
    inner join file_ctx fc on true
    where i.product_based_costing_file_id = p_file_id
  ),
  line_metrics as (
    select
      l.*,
      round((l.price_gbp_n + (l.weight_g / 1000.0) * l.cargo_rate)::numeric, 2) as unit_cost_gbp,
      ceil(
        round((l.price_gbp_n + (l.weight_g / 1000.0) * l.cargo_rate)::numeric, 2) * l.conversion_rate - 1e-9
      )::numeric as unit_cost_bdt,
      public.pbc_calculated_offer_price_bdt(
        l.price_gbp_n,
        l.product_weight_n,
        l.package_weight_n,
        l.cargo_rate,
        l.conversion_rate,
        l.profit_rate,
        l.vat_rate,
        l.offer_pricing_mode
      )::numeric as calculated_offer_bdt
    from lines l
  ),
  line_final as (
    select
      lm.*,
      case
        when lm.is_offer_price_manual and coalesce(lm.offer_price, 0) > 0 then
          public.round_bdt_up_to_zero_or_five(lm.offer_price)::numeric
        when coalesce(lm.offer_price, 0) > 0
          and public.round_bdt_up_to_zero_or_five(lm.offer_price) is distinct from lm.calculated_offer_bdt then
          public.round_bdt_up_to_zero_or_five(lm.offer_price)::numeric
        else lm.calculated_offer_bdt
      end as effective_offer_bdt,
      (
        lm.qty > 0
        and (
          lm.price_gbp_n <= 0
          or (lm.product_weight_n <= 0 and lm.package_weight_n <= 0)
        )
      ) as is_incomplete
    from line_metrics lm
  ),
  agg as (
    select
      (select count(*)::int from lines) as line_count,
      coalesce(sum(lf.qty) filter (where lf.qty > 0), 0)::numeric as total_quantity,
      coalesce(sum(lf.price_gbp_n * lf.qty) filter (where lf.qty > 0), 0)::numeric as goods_cost_gbp,
      coalesce(sum((lf.weight_g / 1000.0) * lf.cargo_rate * lf.qty) filter (where lf.qty > 0), 0)::numeric as cargo_cost_gbp,
      coalesce(sum(lf.weight_g * lf.qty) filter (where lf.qty > 0), 0)::numeric as cargo_weight_grams,
      coalesce(sum(lf.unit_cost_bdt * lf.qty) filter (where lf.qty > 0), 0)::numeric as total_cost_bdt,
      coalesce(sum(lf.effective_offer_bdt * lf.qty) filter (where lf.qty > 0), 0)::numeric as total_offer_price_bdt,
      count(*) filter (where lf.is_incomplete)::int as incomplete_line_count,
      (select conversion_rate from file_ctx limit 1) as conversion_rate
    from line_final lf
  )
  select coalesce(
    jsonb_build_object(
      'line_count', a.line_count,
      'total_quantity', a.total_quantity,
      'goods_cost_gbp', a.goods_cost_gbp,
      'goods_cost_bdt', a.goods_cost_gbp * a.conversion_rate,
      'cargo_weight_kg', a.cargo_weight_grams / 1000.0,
      'cargo_cost_gbp', a.cargo_cost_gbp,
      'cargo_cost_bdt', a.cargo_cost_gbp * a.conversion_rate,
      'total_cost_gbp', a.goods_cost_gbp + a.cargo_cost_gbp,
      'total_cost_bdt', a.total_cost_bdt,
      'total_offer_price_bdt', a.total_offer_price_bdt,
      'total_profit_bdt', a.total_offer_price_bdt - a.total_cost_bdt,
      'profit_margin_percent',
        case
          when a.total_offer_price_bdt > 0 then
            ((a.total_offer_price_bdt - a.total_cost_bdt) / a.total_offer_price_bdt) * 100.0
          else 0
        end,
      'avg_offer_per_unit_bdt',
        case
          when a.total_quantity > 0 then a.total_offer_price_bdt / a.total_quantity
          else 0
        end,
      'avg_cost_per_unit_bdt',
        case
          when a.total_quantity > 0 then a.total_cost_bdt / a.total_quantity
          else 0
        end,
      'incomplete_line_count', a.incomplete_line_count
    ),
    jsonb_build_object(
      'line_count', 0,
      'total_quantity', 0,
      'goods_cost_gbp', 0,
      'goods_cost_bdt', 0,
      'cargo_weight_kg', 0,
      'cargo_cost_gbp', 0,
      'cargo_cost_bdt', 0,
      'total_cost_gbp', 0,
      'total_cost_bdt', 0,
      'total_offer_price_bdt', 0,
      'total_profit_bdt', 0,
      'profit_margin_percent', 0,
      'avg_offer_per_unit_bdt', 0,
      'avg_cost_per_unit_bdt', 0,
      'incomplete_line_count', 0
    )
  )
  from agg a;
$$;

grant execute on function public.pbc_calculated_offer_price_bdt(numeric, numeric, numeric, numeric, numeric, numeric, numeric, text) to authenticated;
grant execute on function public.pbc_calculated_offer_price_bdt(numeric, numeric, numeric, numeric, numeric, numeric, numeric, text) to service_role;
grant execute on function public.get_product_based_costing_file_summary(bigint, numeric, numeric, numeric, numeric, text) to authenticated;
grant execute on function public.get_product_based_costing_file_summary(bigint, numeric, numeric, numeric, numeric, text) to service_role;
