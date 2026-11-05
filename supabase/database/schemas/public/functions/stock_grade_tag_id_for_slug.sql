CREATE FUNCTION public.stock_grade_tag_id_for_slug (
  p_slug text
)
  RETURNS bigint
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id bigint;
begin
  select tg.id into v_id
  from public.tags tg
  inner join public.tag_categories tc on tc.id = tg.category_id
  where tc.module_key = 'stock_grade'
    and tc.code = 'warehouse'
    and tg.slug = p_slug
    and tg.is_active = true
  order by tg.id
  limit 1;

  if v_id is null then
    return public.default_stock_grade_tag_id();
  end if;
  return v_id;
end;
$function$;

GRANT ALL ON FUNCTION public.stock_grade_tag_id_for_slug(text) TO anon;

GRANT ALL ON FUNCTION public.stock_grade_tag_id_for_slug(text) TO authenticated;

GRANT ALL ON FUNCTION public.stock_grade_tag_id_for_slug(text) TO service_role;