CREATE FUNCTION public.validate_costing_file_customer_group()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
declare
  v_group_tenant_id bigint;
begin
  select cg.tenant_id
  into v_group_tenant_id
  from public.customer_groups cg
  where cg.id = new.customer_group_id;

  if v_group_tenant_id is null then
    raise exception 'customer_group_id % does not exist', new.customer_group_id;
  end if;

  if v_group_tenant_id <> new.tenant_id then
    raise exception 'customer_group_id % does not belong to tenant_id %', new.customer_group_id, new.tenant_id;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.validate_costing_file_customer_group() TO anon;

GRANT ALL ON FUNCTION public.validate_costing_file_customer_group() TO authenticated;

GRANT ALL ON FUNCTION public.validate_costing_file_customer_group() TO service_role;