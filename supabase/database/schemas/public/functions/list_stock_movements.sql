CREATE FUNCTION public.list_stock_movements (
  p_tenant_id bigint,
  p_limit     integer DEFAULT 50,
  p_offset    integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_data jsonb;
  v_total bigint;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select count(*) into v_total
  from public.stock_movements m
  where m.tenant_id = p_tenant_id;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.id desc), '[]'::jsonb)
  into v_data
  from (
    select * from public.stock_movements
    where tenant_id = p_tenant_id
    order by id desc
    limit p_limit offset p_offset
  ) m;

  return jsonb_build_object('data', v_data, 'total', v_total);
end;
$function$;

GRANT ALL ON FUNCTION public.list_stock_movements(bigint, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_stock_movements(bigint, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_stock_movements(bigint, integer, integer) TO service_role;