CREATE FUNCTION public.pop_demand_bucket_item (
  p_bucket_item_id   bigint,
  p_popped_into_type text,
  p_popped_into_id   bigint
)
  RETURNS public.customer_demand_bucket_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.customer_demand_bucket_items;
begin
  if p_bucket_item_id is null then
    raise exception 'bucket_item_id is required';
  end if;
  if nullif(trim(coalesce(p_popped_into_type, '')), '') is null
     or p_popped_into_id is null then
    raise exception 'popped_into_type and popped_into_id are required';
  end if;

  select * into v_row
  from public.customer_demand_bucket_items
  where id = p_bucket_item_id;

  if not found then
    raise exception 'bucket item not found: %', p_bucket_item_id;
  end if;

  if v_row.status <> 'open' then
    raise exception 'bucket item % is not open', p_bucket_item_id;
  end if;

  if not public.can_access_demand_bucket_profile(v_row.tenant_id, v_row.profile_id, false) then
    raise exception 'access denied';
  end if;

  update public.customer_demand_bucket_items
  set
    status = 'popped',
    popped_at = now(),
    popped_into_type = trim(p_popped_into_type),
    popped_into_id = p_popped_into_id,
    updated_at = now()
  where id = p_bucket_item_id
  returning * into v_row;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.pop_demand_bucket_item(bigint, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.pop_demand_bucket_item(bigint, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.pop_demand_bucket_item(bigint, text, bigint) TO service_role;