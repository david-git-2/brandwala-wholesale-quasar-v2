CREATE FUNCTION public.is_vendor_code_available (
  p_code       text,
  p_exclude_id bigint DEFAULT NULL::bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select not exists (
    select 1
    from public.vendors v
    where upper(trim(v.code)) = upper(trim(p_code))
      and (p_exclude_id is null or v.id <> p_exclude_id)
  );
$function$;

GRANT ALL ON FUNCTION public.is_vendor_code_available(text, bigint) TO anon;

GRANT ALL ON FUNCTION public.is_vendor_code_available(text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_vendor_code_available(text, bigint) TO service_role;