CREATE FUNCTION public.get_tag_by_slug (
  p_category_id bigint DEFAULT NULL::bigint,
  p_module_key  text   DEFAULT NULL::text,
  p_code        text   DEFAULT NULL::text,
  p_slug        text   DEFAULT NULL::text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_category_id bigint;
  v_res json;
begin
  if p_slug is null then
    return null;
  end if;

  if p_category_id is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.id = p_category_id
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      );
  elsif p_module_key is not null and p_code is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.module_key = p_module_key
      and tc.code = p_code
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      )
    order by tc.is_system desc, tc.id asc
    limit 1;
  end if;

  if v_category_id is null then
    return null;
  end if;

  select row_to_json(t)
  into v_res
  from (
    select
      tg.id,
      tg.category_id,
      tg.slug,
      tg.name,
      tg.color,
      tg.metadata,
      tg.sort_order,
      tg.is_system,
      tg.is_active,
      tg.tenant_id,
      tg.group_name,
      tg.type
    from public.tags tg
    where tg.category_id = v_category_id
      and tg.slug = p_slug
      and tg.is_active = true
    limit 1
  ) t;

  return v_res;
end;
$function$;

GRANT ALL ON FUNCTION public.get_tag_by_slug(bigint, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.get_tag_by_slug(bigint, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.get_tag_by_slug(bigint, text, text, text) TO service_role;