CREATE FUNCTION public.upsert_investor_profile (
  p_id            bigint,
  p_tenant_id     bigint,
  p_name          text,
  p_phone         text,
  p_email         text,
  p_address       text,
  p_is_active     boolean,
  p_currency_code text,
  p_notes         text
)
  RETURNS public.investors
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.investors;
  v_action text;
begin
  v_action := case when p_id is null then 'create' else 'edit' end;
  if not public.membership_has_module_action(p_tenant_id, 'investor_profiles', v_action) then
    raise exception 'not allowed';
  end if;

  if p_id is not null then
    update public.investors
    set
      name = p_name,
      phone = p_phone,
      email = p_email,
      address = p_address,
      is_active = p_is_active,
      currency_code = p_currency_code,
      notes = p_notes,
      updated_at = now()
    where id = p_id and tenant_id = p_tenant_id
    returning * into v_row;

    if v_row.id is null then
      raise exception 'investor not found';
    end if;
  else
    insert into public.investors (
      tenant_id, name, phone, email, address, is_active, currency_code, notes
    ) values (
      p_tenant_id, p_name, p_phone, p_email, p_address, p_is_active, p_currency_code, p_notes
    )
    returning * into v_row;
  end if;

  perform public.sync_investor_profile_membership(
    p_tenant_id,
    v_row.id,
    v_row.email,
    v_row.is_active
  );

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_investor_profile(bigint, bigint, text, text, text, text, boolean, text, text) TO anon;

GRANT ALL ON FUNCTION public.upsert_investor_profile(bigint, bigint, text, text, text, text, boolean, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_investor_profile(bigint, bigint, text, text, text, text, boolean, text, text) TO service_role;