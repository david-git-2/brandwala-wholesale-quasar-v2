CREATE FUNCTION public.resolve_thrift_barcode (
  p_tenant_id     bigint,
  p_scanned_value text
)
  RETURNS TABLE (
    barcode_id text,
    status     text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_canonical text;
begin
  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  v_canonical := public.resolve_thrift_barcode_id_internal(p_tenant_id, p_scanned_value);
  if v_canonical is null then
    return;
  end if;

  return query
  select b.barcode_id, b.status
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.barcode_id = v_canonical
  limit 1;
end;
$function$;

GRANT ALL ON FUNCTION public.resolve_thrift_barcode(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.resolve_thrift_barcode(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_thrift_barcode(bigint, text) TO service_role;