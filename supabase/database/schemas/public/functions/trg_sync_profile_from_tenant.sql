CREATE FUNCTION public.trg_sync_profile_from_tenant()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_books_id bigint;
begin
  v_books_id := coalesce(new.parent_id, new.id);

  perform public.upsert_profile_for_party(
    v_books_id,
    'tenant'::public.profile_party_type,
    new.id,
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

  perform public.ensure_tenant_default_money_profiles(v_books_id);

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_tenant() TO anon;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_tenant() TO authenticated;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_tenant() TO service_role;