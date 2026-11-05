CREATE FUNCTION public.check_shop_login_access (
  p_email     text,
  p_tenant_id bigint DEFAULT NULL::bigint
)
  RETURNS TABLE (
    has_match                boolean,
    matched_role             public.customer_group_role,
    member_id                bigint,
    member_name              text,
    member_email             text,
    member_tenant_id         bigint,
    customer_group_id        bigint,
    customer_group_name      text,
    member_is_active         boolean,
    customer_group_is_active boolean,
    member_created_at        timestamp with time zone,
    member_updated_at        timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email text;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  return query
  select
    true,
    cgm.role,
    cgm.id,
    coalesce(
      nullif(trim(cgm.name), ''),
      (select coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') from auth.users u where u.email = v_email limit 1)
    ),
    lower(trim(cgm.email)),
    cg.tenant_id,
    cg.id,
    cg.name,
    cgm.is_active,
    cg.is_active,
    cgm.created_at,
    cgm.updated_at
  from public.customer_group_members cgm
  inner join public.customer_groups cg
    on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and cg.deleted_at is null
    and (
      p_tenant_id is null
      or exists (
        select 1
        from public.shop_customer_group_access scga
        inner join public.shops s on s.id = scga.shop_id
        where scga.customer_group_id = cg.id
          and scga.status = true
          and s.tenant_id = p_tenant_id
          and s.is_active = true
          and s.deleted_at is null
          and coalesce(cg.parent_tenant_id, cg.tenant_id)
            = public.resolve_parent_tenant_id(p_tenant_id)
      )
    )
  order by
    cg.name asc,
    cg.id asc,
    case cgm.role
      when 'admin' then 1
      when 'manager' then 2
      when 'staff' then 3
      else 99
    end asc,
    cgm.id asc;
end;
$function$;

GRANT ALL ON FUNCTION public.check_shop_login_access(text, bigint) TO anon;

GRANT ALL ON FUNCTION public.check_shop_login_access(text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.check_shop_login_access(text, bigint) TO service_role;