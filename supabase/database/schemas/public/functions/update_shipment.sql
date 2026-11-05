CREATE FUNCTION public.update_shipment (
  p_id    bigint,
  p_field text,
  p_value text
)
  RETURNS public.shipments
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.shipments;
  v_field text;
  v_value text;
  v_type text;
begin
  select *
  into v_row
  from public.shipments
  where id = p_id;

  if v_row.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_row.tenant_id) then
    raise exception 'not allowed';
  end if;

  v_field := lower(trim(coalesce(p_field, '')));
  v_value := trim(coalesce(p_value, ''));

  if v_field = 'name' then
    update public.shipments set name = v_value where id = p_id returning * into v_row;
  elsif v_field = 'shipment_type' then
    v_type := lower(v_value);
    if v_type not in ('local', 'international') then
      raise exception 'invalid shipment_type: %', v_value;
    end if;
    update public.shipments set shipment_type = v_type where id = p_id returning * into v_row;
  elsif v_field = 'status' then
    update public.shipments set status = v_value where id = p_id returning * into v_row;
  elsif v_field = 'inventory_added' then
    update public.shipments
    set inventory_added = coalesce(nullif(v_value, '')::boolean, false)
    where id = p_id returning * into v_row;
  elsif v_field = 'product_conversion_rate' then
    update public.shipments
    set product_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'cargo_conversion_rate' then
    update public.shipments
    set cargo_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'cargo_rate' then
    update public.shipments
    set cargo_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'weight' then
    update public.shipments
    set weight = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'received_weight' then
    update public.shipments
    set received_weight = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'transaction_rate' then
    update public.shipments
    set transaction_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  else
    raise exception 'unsupported shipment field: %', p_field;
  end if;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.update_shipment(bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.update_shipment(bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.update_shipment(bigint, text, text) TO service_role;