CREATE FUNCTION public.update_costing_file_item_offer (
  p_id                       bigint,
  p_auxiliary_price_gbp      numeric DEFAULT NULL::numeric,
  p_item_price_gbp           numeric DEFAULT NULL::numeric,
  p_cargo_rate               numeric DEFAULT NULL::numeric,
  p_costing_price_gbp        numeric DEFAULT NULL::numeric,
  p_costing_price_bdt        integer DEFAULT NULL::integer,
  p_offer_price_override_bdt integer DEFAULT NULL::integer
)
  RETURNS TABLE (
    id                       bigint,
    auxiliary_price_gbp      numeric,
    item_price_gbp           numeric,
    cargo_rate               numeric,
    costing_price_gbp        numeric,
    costing_price_bdt        integer,
    offer_price_override_bdt integer,
    offer_price_bdt          integer,
    updated_at               timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with updated as (
    update public.costing_file_items cfi
    set
      auxiliary_price_gbp = coalesce(p_auxiliary_price_gbp, cfi.auxiliary_price_gbp),
      item_price_gbp = coalesce(p_item_price_gbp, cfi.item_price_gbp),
      cargo_rate = coalesce(p_cargo_rate, cfi.cargo_rate),
      costing_price_gbp = coalesce(p_costing_price_gbp, cfi.costing_price_gbp),
      costing_price_bdt = coalesce(p_costing_price_bdt, cfi.costing_price_bdt),
      offer_price_override_bdt = p_offer_price_override_bdt
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cfi.id,
      cfi.auxiliary_price_gbp,
      cfi.item_price_gbp,
      cfi.cargo_rate,
      cfi.costing_price_gbp,
      cfi.costing_price_bdt,
      cfi.offer_price_override_bdt,
      cfi.offer_price_bdt,
      cfi.updated_at
  )
  select *
  from updated;
$function$;

GRANT ALL ON FUNCTION public.update_costing_file_item_offer(bigint, numeric, numeric, numeric, numeric, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.update_costing_file_item_offer(bigint, numeric, numeric, numeric, numeric, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.update_costing_file_item_offer(bigint, numeric, numeric, numeric, numeric, integer, integer) TO service_role;