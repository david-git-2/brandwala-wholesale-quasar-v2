CREATE OR REPLACE FUNCTION public.get_shop_customer_shell_bundle(p_tenant_id bigint) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO public
    AS $$
declare
  v_group_id bigint;
  v_active_carts jsonb := '[]'::jsonb;
  v_customer_shops jsonb := '[]'::jsonb;
  v_login_groups jsonb := '[]'::jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    raise exception 'access denied';
  end if;

  select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb)
  into v_active_carts
  from public.list_customer_active_carts(p_tenant_id) c;

  select coalesce(jsonb_agg(to_jsonb(s)), '[]'::jsonb)
  into v_customer_shops
  from public.list_customer_shops(p_tenant_id) s;

  select coalesce(jsonb_agg(to_jsonb(g)), '[]'::jsonb)
  into v_login_groups
  from public.check_shop_login_access(public.current_user_email(), p_tenant_id) g
  where g.has_match is distinct from false;

  return jsonb_build_object(
    'active_carts', v_active_carts,
    'customer_shops', v_customer_shops,
    'login_groups', v_login_groups
  );
end;
$$;

ALTER FUNCTION public.get_shop_customer_shell_bundle(p_tenant_id bigint) OWNER TO postgres;

GRANT ALL ON FUNCTION public.get_shop_customer_shell_bundle(p_tenant_id bigint) TO authenticated;
