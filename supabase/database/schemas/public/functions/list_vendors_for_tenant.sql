CREATE FUNCTION public.list_vendors_for_tenant (
  p_tenant_id bigint
)
  RETURNS SETOF public.vendors
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_books_id bigint;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    return query
    select v.*
    from public.vendors v
    where v.parent_tenant_id is null
    order by v.id asc;

    return;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select v.*
  from public.vendors v
  where v.parent_tenant_id = v_books_id
  order by v.id asc;
end;
$function$;

GRANT ALL ON FUNCTION public.list_vendors_for_tenant(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_vendors_for_tenant(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_vendors_for_tenant(bigint) TO service_role;