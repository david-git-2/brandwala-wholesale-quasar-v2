CREATE FUNCTION public.recipient_profile_valid_for_issuer (
  p_recipient_profile_id bigint,
  p_issued_by_tenant_id  bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.recipient_profiles rp
    where rp.id = p_recipient_profile_id
      and (
        rp.tenant_id = p_issued_by_tenant_id
        or rp.tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or coalesce(rp.parent_tenant_id, rp.tenant_id)
          = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or exists (
          select 1
          from public.tenants t
          where t.id = rp.tenant_id
            and t.parent_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        )
      )
  );
$function$;

GRANT ALL ON FUNCTION public.recipient_profile_valid_for_issuer(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.recipient_profile_valid_for_issuer(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.recipient_profile_valid_for_issuer(bigint, bigint) TO service_role;