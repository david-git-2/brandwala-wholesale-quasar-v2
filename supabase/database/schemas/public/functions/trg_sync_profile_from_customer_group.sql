CREATE FUNCTION public.trg_sync_profile_from_customer_group()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  UPDATE public.profiles p
  SET
    accent_color = new.accent_color,
    is_active = new.is_active,
    deleted_at = new.deleted_at,
    updated_at = now()
  WHERE p.customer_group_id = new.id
    AND p.profile_type = 'customer'::public.profile_party_type;

  RETURN new;
END;
$function$;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_customer_group() TO anon;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_customer_group() TO authenticated;

GRANT ALL ON FUNCTION public.trg_sync_profile_from_customer_group() TO service_role;