CREATE FUNCTION public.update_costing_file_pricing (
  p_id                bigint,
  p_cargo_rate_1kg    numeric DEFAULT NULL::numeric,
  p_cargo_rate_2kg    numeric DEFAULT NULL::numeric,
  p_conversion_rate   numeric DEFAULT NULL::numeric,
  p_admin_profit_rate numeric DEFAULT NULL::numeric
)
  RETURNS TABLE (
    id                bigint,
    cargo_rate_1kg    numeric,
    cargo_rate_2kg    numeric,
    conversion_rate   numeric,
    admin_profit_rate numeric,
    updated_at        timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with updated as (
    update public.costing_files cf
    set
      cargo_rate_1kg = coalesce(p_cargo_rate_1kg, cf.cargo_rate_1kg),
      cargo_rate_2kg = coalesce(p_cargo_rate_2kg, cf.cargo_rate_2kg),
      conversion_rate = coalesce(p_conversion_rate, cf.conversion_rate),
      admin_profit_rate = coalesce(p_admin_profit_rate, cf.admin_profit_rate)
    where cf.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cf.id,
      cf.cargo_rate_1kg,
      cf.cargo_rate_2kg,
      cf.conversion_rate,
      cf.admin_profit_rate,
      cf.updated_at
  )
  select *
  from updated;
$function$;

GRANT ALL ON FUNCTION public.update_costing_file_pricing(bigint, numeric, numeric, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.update_costing_file_pricing(bigint, numeric, numeric, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.update_costing_file_pricing(bigint, numeric, numeric, numeric, numeric) TO service_role;