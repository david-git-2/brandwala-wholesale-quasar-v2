CREATE FUNCTION public.trg_sync_profile_from_cargo_company()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_books_id bigint;
begin
  v_books_id := new.parent_tenant_id;

  if v_books_id is null then
    return new;
  end if;

  perform public.upsert_profile_for_party(
    v_books_id,
    'cargo'::public.profile_party_type,
    new.id,
    new.name,
    new.email,
    new.phone,
    '+880',
    new.address,
    case when new.phone is null or btrim(new.phone) = '' then false else true end,
    null,
    true,
    null
  );

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_cargo_company() TO anon;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_cargo_company() TO authenticated;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_cargo_company() TO service_role;