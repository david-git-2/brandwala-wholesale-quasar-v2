CREATE FUNCTION public.ap_bill_channel_foreign_face (
  p_channel_meta jsonb
)
  RETURNS numeric
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  select coalesce(
    nullif((p_channel_meta->'ap_paper'->>'foreign_total')::numeric, 0),
    nullif((p_channel_meta->'ap_paper'->'currency_groups'->0->>'foreign_total')::numeric, 0)
  );
$function$;

GRANT ALL ON FUNCTION public.ap_bill_channel_foreign_face(jsonb) TO anon;

GRANT ALL ON FUNCTION public.ap_bill_channel_foreign_face(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.ap_bill_channel_foreign_face(jsonb) TO service_role;