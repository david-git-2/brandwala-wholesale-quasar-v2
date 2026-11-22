-- Prod has no trg_customer_profiles_admin_email_unique_per_tenant on public.profiles.

CREATE OR REPLACE FUNCTION public.trg_customer_groups_soft_delete_phone_unique()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO public
AS $$
BEGIN
  IF new.deleted_at IS NOT NULL AND old.deleted_at IS NULL THEN
    UPDATE public.profiles
    SET is_phone_unique = false
    WHERE customer_group_id = new.id
      AND profile_type = 'customer'::public.profile_party_type;
  ELSIF new.deleted_at IS NULL AND old.deleted_at IS NOT NULL THEN
    UPDATE public.profiles
    SET is_phone_unique = true
    WHERE customer_group_id = new.id
      AND profile_type = 'customer'::public.profile_party_type;
  END IF;
  RETURN new;
END;
$$;