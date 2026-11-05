CREATE FUNCTION public.list_tag_categories (
  p_module_key text DEFAULT NULL::text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_res json;
begin
  select coalesce(json_agg(row_to_json(c)), '[]'::json)
  into v_res
  from (
    select
      tc.id,
      tc.module_key,
      tc.code,
      tc.name,
      tc.cardinality,
      tc.is_system,
      tc.tenant_id,
      tc.sort_order,
      tc.is_active,
      tc.created_at
    from public.tag_categories tc
    where tc.is_active = true
      and (p_module_key is null or tc.module_key = p_module_key)
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      )
    order by tc.sort_order asc nulls last, tc.id asc
  ) c;

  return v_res;
end;
$function$;

GRANT ALL ON FUNCTION public.list_tag_categories(text) TO anon;

GRANT ALL ON FUNCTION public.list_tag_categories(text) TO authenticated;

GRANT ALL ON FUNCTION public.list_tag_categories(text) TO service_role;