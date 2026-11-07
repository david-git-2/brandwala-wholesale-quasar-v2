CREATE FUNCTION public.delete_shop_orders_for_staff (
  p_tenant_id bigint,
  p_order_ids bigint[]
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ids bigint[];
  v_id bigint;
  v_deleted bigint[] := '{}'::bigint[];
  v_max_batch constant integer := 100;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'Access denied';
  end if;

  if p_order_ids is null or cardinality(p_order_ids) = 0 then
    raise exception 'No orders specified';
  end if;

  select coalesce(array_agg(x order by x), '{}'::bigint[])
  into v_ids
  from (
    select distinct unnest(coalesce(p_order_ids, array[]::bigint[])) as x
  ) s
  where x is not null;

  if v_ids is null or cardinality(v_ids) = 0 then
    raise exception 'No orders specified';
  end if;

  if cardinality(v_ids) > v_max_batch then
    raise exception 'Cannot delete more than % orders at once', v_max_batch;
  end if;

  foreach v_id in array v_ids loop
    if not exists (
      select 1
      from public.shop_orders o
      where o.id = v_id
        and o.status = 'cancelled'::public.shop_order_status
        and (
          o.tenant_id = p_tenant_id
          or o.tenant_id in (select public.list_child_tenant_ids(p_tenant_id))
        )
    ) then
      raise exception 'Order % is not cancelled, not in scope, or does not exist', v_id;
    end if;
  end loop;

  foreach v_id in array v_ids loop
    perform public.delete_shop_order(v_id);
    v_deleted := array_append(v_deleted, v_id);
  end loop;

  return jsonb_build_object(
    'deleted_count', cardinality(v_deleted),
    'deleted_ids', to_jsonb(v_deleted)
  );
end;
$function$;

GRANT ALL ON FUNCTION public.delete_shop_orders_for_staff(bigint, bigint[]) TO anon;

GRANT ALL ON FUNCTION public.delete_shop_orders_for_staff(bigint, bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public.delete_shop_orders_for_staff(bigint, bigint[]) TO service_role;
