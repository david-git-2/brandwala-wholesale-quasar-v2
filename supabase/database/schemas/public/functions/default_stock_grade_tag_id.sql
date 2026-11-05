CREATE FUNCTION public.default_stock_grade_tag_id()
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select t.id
  from public.tags t
  join public.tag_categories tc on tc.id = t.category_id
  where tc.module_key = 'stock_grade' and tc.code = 'warehouse' and t.slug = 'standard'
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.default_stock_grade_tag_id() TO anon;

GRANT ALL ON FUNCTION public.default_stock_grade_tag_id() TO authenticated;

GRANT ALL ON FUNCTION public.default_stock_grade_tag_id() TO service_role;