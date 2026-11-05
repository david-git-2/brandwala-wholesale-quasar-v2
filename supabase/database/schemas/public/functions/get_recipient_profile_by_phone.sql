CREATE FUNCTION public.get_recipient_profile_by_phone (
  p_tenant_id bigint,
  p_phone     text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_phone text;
  v_row public.recipient_profiles%rowtype;
  v_can_access boolean;
  v_parent_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_can_access := public.is_tenant_staff(p_tenant_id)
    or public.current_customer_group_id(p_tenant_id) is not null
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or public.has_active_tenant_membership(p_tenant_id);

  if not v_can_access then
    raise exception 'access denied';
  end if;

  begin
    v_phone := public.normalize_bd_mobile(p_phone);
  exception when others then
    return null;
  end;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_row
  from public.recipient_profiles
  where (parent_tenant_id = v_parent_id or (parent_tenant_id is null and tenant_id = v_parent_id) or tenant_id = p_tenant_id)
    and phone = v_phone
  order by (parent_tenant_id = v_parent_id) desc, updated_at desc
  limit 1;

  if v_row.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'name', v_row.name,
    'phone', v_row.phone,
    'secondary_phone', v_row.secondary_phone,
    'address', v_row.address,
    'district', v_row.district,
    'thana', v_row.thana,
    'addresses', v_row.addresses,
    'tenant_id', v_row.tenant_id,
    'parent_tenant_id', v_row.parent_tenant_id,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_recipient_profile_by_phone(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.get_recipient_profile_by_phone(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.get_recipient_profile_by_phone(bigint, text) TO service_role;