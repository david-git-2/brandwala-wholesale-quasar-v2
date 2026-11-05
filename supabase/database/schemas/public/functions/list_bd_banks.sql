CREATE FUNCTION public.list_bd_banks()
  RETURNS TABLE (
    id         bigint,
    code       text,
    name       text,
    swift_code text,
    sort_order integer
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select b.id, b.code, b.name, b.swift_code, b.sort_order
  from public.bd_banks b
  where b.is_active = true
  order by b.sort_order asc, b.name asc;
$function$;

GRANT ALL ON FUNCTION public.list_bd_banks() TO anon;

GRANT ALL ON FUNCTION public.list_bd_banks() TO authenticated;

GRANT ALL ON FUNCTION public.list_bd_banks() TO service_role;