CREATE FUNCTION public.trg_sync_profile_from_courier_service()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_books_id bigint;
begin
  if new.tenant_id is null then
    return new;
  end if;

  v_books_id := public.resolve_parent_tenant_id(new.tenant_id);

  perform public.upsert_profile_for_party(
    v_books_id,
    'courier'::public.profile_party_type,
    new.wallet_entity_id,
    new.name,
    null,
    null,
    '+880',
    null,
    false,
    null,
    coalesce(new.is_active, true),
    null
  );

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_courier_service() TO anon;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_courier_service() TO authenticated;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_courier_service() TO service_role;