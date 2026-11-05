CREATE FUNCTION public.ap_bill_channel_currency (
  p_channel_meta jsonb
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  select upper(coalesce(
    nullif(trim(p_channel_meta->'ap_paper'->>'currency_code'), ''),
    nullif(trim(p_channel_meta->'ap_paper'->'currency_groups'->0->>'currency_code'), ''),
    'BDT'
  ));
$function$;

GRANT ALL ON FUNCTION public.ap_bill_channel_currency(jsonb) TO anon;

GRANT ALL ON FUNCTION public.ap_bill_channel_currency(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.ap_bill_channel_currency(jsonb) TO service_role;