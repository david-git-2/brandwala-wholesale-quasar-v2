CREATE FUNCTION public.sync_vendor_reference_fields()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
declare
  v_id bigint;
  v_code text;
begin
  if new.vendor_id is not null then
    select id, code
    into v_id, v_code
    from public.vendors
    where id = new.vendor_id
    limit 1;

    if v_id is null then
      raise exception 'invalid vendor_id: %', new.vendor_id;
    end if;

    new.vendor_id := v_id;
    new.vendor_code := v_code;
    return new;
  end if;

  if new.vendor_code is not null and length(trim(new.vendor_code)) > 0 then
    select id, code
    into v_id, v_code
    from public.vendors
    where upper(trim(code)) = upper(trim(new.vendor_code))
    order by id asc
    limit 1;

    if v_id is not null then
      new.vendor_id := v_id;
      new.vendor_code := v_code;
    else
      new.vendor_id := null;
      new.vendor_code := upper(trim(new.vendor_code));
    end if;

    return new;
  end if;

  new.vendor_id := null;
  new.vendor_code := null;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.sync_vendor_reference_fields() TO anon;

GRANT ALL ON FUNCTION public.sync_vendor_reference_fields() TO authenticated;

GRANT ALL ON FUNCTION public.sync_vendor_reference_fields() TO service_role;