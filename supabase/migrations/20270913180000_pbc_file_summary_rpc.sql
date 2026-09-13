-- Aggregate PBC file summary across all line items (not paginated client slice)

create or replace function public.get_product_based_costing_file_summary(
  p_file_id bigint,
  p_conversion_rate numeric default null,
  p_cargo_rate_kg_gbp numeric default null,
  p_profit_rate numeric default null
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with file_ctx as (
    select
      f.id,
      coalesce(p_conversion_rate, f.conversion_rate, 140)::numeric as conversion_rate,
      coalesce(p_cargo_rate_kg_gbp, f.cargo_rate_kg_gbp, 0)::numeric as cargo_rate,
      coalesce(p_profit_rate, f.profit_rate, 25)::numeric as profit_rate
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
      fc.profit_rate
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
      public.round_bdt_up_to_zero_or_five(
        ceil(
          round((l.price_gbp_n + (l.weight_g / 1000.0) * l.cargo_rate)::numeric, 2) * l.conversion_rate - 1e-9
        )
        + (
          ceil(
            round((l.price_gbp_n + (l.weight_g / 1000.0) * l.cargo_rate)::numeric, 2) * l.conversion_rate - 1e-9
          ) * l.profit_rate / 100.0
        )
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

grant execute on function public.get_product_based_costing_file_summary(
  bigint,
  numeric,
  numeric,
  numeric
) to authenticated;
