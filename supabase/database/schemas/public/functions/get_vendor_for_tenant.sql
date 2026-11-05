CREATE FUNCTION public.get_vendor_for_tenant (
  p_id        bigint,
  p_tenant_id bigint
)
  RETURNS public.vendors
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.vendors;
  v_books_id bigint;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    select * into v_row
    from public.vendors
    where id = p_id
      and parent_tenant_id is null;

    return v_row;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_row
  from public.vendors
  where id = p_id
    and parent_tenant_id = v_books_id;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.get_vendor_for_tenant(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_vendor_for_tenant(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_vendor_for_tenant(bigint, bigint) TO service_role;