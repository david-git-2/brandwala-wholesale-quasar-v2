CREATE FUNCTION public.delete_customer_group (
  p_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_books_id bigint;
  v_deleted_at timestamptz;
begin
  select coalesce(cg.parent_tenant_id, cg.tenant_id), cg.deleted_at
  into v_books_id, v_deleted_at
  from public.customer_groups cg
  where cg.id = p_id;

  if v_books_id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.can_administer_customer_group(v_books_id) then
    raise exception 'Only parent tenant admins can delete customer groups';
  end if;

  if v_deleted_at is not null then
    return;
  end if;

  update public.customer_groups
  set
    deleted_at = now(),
    is_active = false,
    updated_at = now()
  where id = p_id
    and deleted_at is null;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_customer_group(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_customer_group(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_customer_group(bigint) TO service_role;