CREATE FUNCTION public.profile_valid_for_issuer (
  p_profile_id          bigint,
  p_issued_by_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.profiles pr
    where pr.id = p_profile_id
      and pr.deleted_at is null
      and (
        pr.parent_tenant_id = p_issued_by_tenant_id
        or pr.parent_tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or exists (
          select 1
          from public.tenants t
          where t.id = p_issued_by_tenant_id
            and t.parent_id = pr.parent_tenant_id
        )
      )
  );
$function$;

GRANT ALL ON FUNCTION public.profile_valid_for_issuer(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.profile_valid_for_issuer(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.profile_valid_for_issuer(bigint, bigint) TO service_role;