-- Cashbook auto-provision: courier + books tenant on profile trigger; backfill Main/BDT

CREATE OR REPLACE FUNCTION public.profile_auto_provisions_cashbook(p_profile_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles pr
    WHERE pr.id = p_profile_id
      AND pr.is_active = true
      AND pr.deleted_at IS NULL
      AND pr.cashbook_enabled = true
      AND pr.profile_type IN (
        'tenant'::public.profile_party_type,
        'customer'::public.profile_party_type,
        'courier'::public.profile_party_type,
        'investor'::public.profile_party_type
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.trg_provision_kernel_cashbook_for_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
BEGIN
  PERFORM public.fn_provision_profile_cashbook_defaults(
    public.resolve_books_tenant_id(NEW.tenant_id),
    NEW.id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_provision_kernel_cashbook_for_profile ON public.profiles;
CREATE TRIGGER trg_provision_kernel_cashbook_for_profile
  AFTER INSERT OR UPDATE OF cashbook_enabled, is_active, deleted_at ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_provision_kernel_cashbook_for_profile();

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT
      pr.id,
      public.resolve_books_tenant_id(pr.tenant_id) AS books_tenant_id
    FROM public.profiles pr
    WHERE public.profile_auto_provisions_cashbook(pr.id)
  LOOP
    PERFORM public.fn_provision_profile_cashbook_defaults(r.books_tenant_id, r.id);
  END LOOP;
END $$;