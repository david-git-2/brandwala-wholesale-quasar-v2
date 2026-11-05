CREATE FUNCTION public.sync_investor_profile_membership (
  p_tenant_id   bigint,
  p_investor_id bigint,
  p_email       text,
  p_is_active   boolean
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email text;
  v_linked public.memberships;
  v_by_email public.memberships;
begin
  perform set_config('app.sync_investor_profile_membership', '1', true);

  v_email := lower(trim(coalesce(p_email, '')));

  if v_email = '' then
    update public.memberships
    set
      investor_id = null,
      updated_at = now()
    where tenant_id = p_tenant_id
      and investor_id = p_investor_id;
    perform set_config('app.sync_investor_profile_membership', '0', true);
    return;
  end if;

  select * into v_linked
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and m.investor_id = p_investor_id
  limit 1;

  if v_linked.id is not null then
    update public.memberships
    set
      email = v_email,
      investor_id = p_investor_id,
      is_active = case
        when role = 'investor'::public.app_role then coalesce(p_is_active, true)
        else is_active
      end,
      updated_at = now()
    where id = v_linked.id;
    perform set_config('app.sync_investor_profile_membership', '0', true);
    return;
  end if;

  select * into v_by_email
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = v_email
  limit 1;

  if v_by_email.id is not null then
    update public.memberships
    set
      investor_id = p_investor_id,
      is_active = case
        when v_by_email.role = 'investor'::public.app_role then coalesce(p_is_active, true)
        else is_active
      end,
      updated_at = now()
    where id = v_by_email.id;
    perform set_config('app.sync_investor_profile_membership', '0', true);
    return;
  end if;

  insert into public.memberships (tenant_id, email, role, is_active, investor_id)
  values (
    p_tenant_id,
    v_email,
    'investor'::public.app_role,
    coalesce(p_is_active, true),
    p_investor_id
  );

  perform set_config('app.sync_investor_profile_membership', '0', true);
end;
$function$;

GRANT ALL ON FUNCTION public.sync_investor_profile_membership(bigint, bigint, text, boolean) TO anon;

GRANT ALL ON FUNCTION public.sync_investor_profile_membership(bigint, bigint, text, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.sync_investor_profile_membership(bigint, bigint, text, boolean) TO service_role;