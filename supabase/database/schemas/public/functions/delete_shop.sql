CREATE FUNCTION public.delete_shop (
  p_shop_id   bigint,
  p_tenant_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  update public.shops
  set
    deleted_at = now(),
    deleted_by = public.current_user_email(),
    is_active = false
  where id = p_shop_id
    and (tenant_id = p_tenant_id or parent_tenant_id = p_tenant_id)
    and deleted_at is null;

  if not found then
    raise exception 'shop not found or already deleted';
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_shop(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_shop(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_shop(bigint, bigint) TO service_role;