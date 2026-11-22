-- delete_customer_group soft-deletes the group; AFTER triggers still referenced billing_profiles.

CREATE OR REPLACE FUNCTION public.trg_customer_groups_soft_delete_phone_unique()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO public
AS $$
BEGIN
  IF new.deleted_at IS NOT NULL AND old.deleted_at IS NULL THEN
    ALTER TABLE public.profiles DISABLE TRIGGER trg_customer_profiles_admin_email_unique_per_tenant;

    UPDATE public.profiles
    SET is_phone_unique = false
    WHERE customer_group_id = new.id
      AND profile_type = 'customer'::public.profile_party_type;

    ALTER TABLE public.profiles ENABLE TRIGGER trg_customer_profiles_admin_email_unique_per_tenant;
  ELSIF new.deleted_at IS NULL AND old.deleted_at IS NOT NULL THEN
    ALTER TABLE public.profiles DISABLE TRIGGER trg_customer_profiles_admin_email_unique_per_tenant;

    UPDATE public.profiles
    SET is_phone_unique = true
    WHERE customer_group_id = new.id
      AND profile_type = 'customer'::public.profile_party_type;

    ALTER TABLE public.profiles ENABLE TRIGGER trg_customer_profiles_admin_email_unique_per_tenant;
  END IF;
  RETURN new;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_sync_profile_from_customer_group()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
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
$$;