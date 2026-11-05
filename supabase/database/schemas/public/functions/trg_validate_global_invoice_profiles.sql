CREATE FUNCTION public.trg_validate_global_invoice_profiles()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if new.profile_id is not null then
    if not public.profile_valid_for_issuer(
      new.profile_id,
      new.issued_by_tenant_id
    ) then
      raise exception 'Profile books must match invoice issued_by_tenant_id';
    end if;
  end if;

  if new.recipient_profile_id is not null then
    if not public.recipient_profile_valid_for_issuer(
      new.recipient_profile_id,
      new.issued_by_tenant_id
    ) then
      raise exception 'Recipient profile tenant_id must match invoice issued_by_tenant_id';
    end if;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_validate_global_invoice_profiles() TO anon;

GRANT ALL ON FUNCTION public.trg_validate_global_invoice_profiles() TO authenticated;

GRANT ALL ON FUNCTION public.trg_validate_global_invoice_profiles() TO service_role;