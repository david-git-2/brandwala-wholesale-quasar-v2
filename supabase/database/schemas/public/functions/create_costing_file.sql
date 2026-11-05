CREATE FUNCTION public.create_costing_file (
  p_tenant_id         bigint,
  p_customer_group_id bigint,
  p_name              text,
  p_market            text
)
  RETURNS TABLE (
    id                bigint,
    name              text,
    market            text,
    status            public.costing_file_status,
    customer_group_id bigint,
    tenant_id         bigint,
    created_by_email  text,
    created_at        timestamp with time zone,
    updated_at        timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Costing file name is required.';
  end if;

  if not exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and cg.tenant_id = p_tenant_id
  ) then
    raise exception 'Customer group does not belong to this tenant.';
  end if;

  if not (
    public.can_admin_manage_costing_file(p_tenant_id)
    or public.can_staff_access_costing_file(p_tenant_id)
    or public.can_customer_access_costing_file(p_customer_group_id)
  ) then
    raise exception 'You do not have permission to create this costing file.';
  end if;

  return query
    insert into public.costing_files (
      tenant_id,
      customer_group_id,
      name,
      market
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      nullif(trim(coalesce(p_market, '')), '')
    )
    returning
      id,
      name,
      market,
      status,
      customer_group_id,
      tenant_id,
      created_by_email,
      created_at,
      updated_at;
end;
$function$;

CREATE FUNCTION public.create_costing_file (
  p_customer_group_id bigint,
  p_market            text,
  p_name              text,
  p_status            public.costing_file_status DEFAULT 'draft'::public.costing_file_status,
  p_tenant_id         bigint                     DEFAULT NULL::bigint
)
  RETURNS TABLE (
    id                  bigint,
    name                text,
    market              text,
    status              public.costing_file_status,
    customer_group_id   bigint,
    tenant_id           bigint,
    created_by_email    text,
    default_shipment_id bigint,
    created_at          timestamp with time zone,
    updated_at          timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;

  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Costing file name is required.';
  end if;

  if not exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and cg.tenant_id = p_tenant_id
  ) then
    raise exception 'Customer group does not belong to this tenant.';
  end if;

  if not (
    public.can_admin_manage_costing_file(p_tenant_id)
    or public.can_staff_access_costing_file(p_tenant_id)
    or public.can_customer_access_costing_file(p_customer_group_id)
  ) then
    raise exception 'You do not have permission to create this costing file.';
  end if;

  return query
    insert into public.costing_files as cf (
      tenant_id,
      customer_group_id,
      name,
      market,
      status
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      nullif(trim(coalesce(p_market, '')), ''),
      coalesce(p_status, 'draft')
    )
    returning
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at;
end;
$function$;

GRANT ALL ON FUNCTION public.create_costing_file(bigint, bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.create_costing_file(bigint, bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.create_costing_file(bigint, bigint, text, text) TO service_role;

GRANT ALL ON FUNCTION public.create_costing_file(bigint, text, text, public.costing_file_status, bigint) TO anon;

GRANT ALL ON FUNCTION public.create_costing_file(bigint, text, text, public.costing_file_status, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.create_costing_file(bigint, text, text, public.costing_file_status, bigint) TO service_role;