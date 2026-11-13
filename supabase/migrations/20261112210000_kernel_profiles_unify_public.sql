-- Unify money kernel party ids on public.profiles (drop money_kernel.profiles).

CREATE UNIQUE INDEX IF NOT EXISTS profiles_tenant_id_id_uidx
  ON public.profiles (tenant_id, id);

CREATE OR REPLACE FUNCTION public.money_kernel_assert_profile_in_tenant(
  p_books_tenant_id bigint,
  p_profile_id bigint
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_profile_id IS NULL THEN
    RAISE EXCEPTION 'not_found: profile required';
  END IF;
  PERFORM 1
  FROM public.profiles pr
  WHERE pr.id = p_profile_id
    AND pr.tenant_id = p_books_tenant_id
    AND pr.deleted_at IS NULL
    AND pr.is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: profile % in tenant %', p_profile_id, p_books_tenant_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_map_money_profile_id_to_public(
  p_books_tenant_id bigint,
  p_money_profile_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SET search_path = public, money_kernel, pg_temp
AS $$
DECLARE
  v_public bigint;
BEGIN
  IF p_books_tenant_id IS NULL OR p_money_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM money_kernel.profiles mk
    WHERE mk.tenant_id = p_books_tenant_id AND mk.id = p_money_profile_id
  ) THEN
    SELECT pr.id INTO v_public
    FROM public.profiles pr
    WHERE pr.id = p_money_profile_id
      AND pr.tenant_id = p_books_tenant_id
      AND pr.deleted_at IS NULL
    LIMIT 1;
    IF v_public IS NOT NULL THEN
      RETURN v_public;
    END IF;
  END IF;

  SELECT nullif(btrim(mk.meta->>'public_profile_id'), '')::bigint
  INTO v_public
  FROM money_kernel.profiles mk
  WHERE mk.tenant_id = p_books_tenant_id
    AND mk.id = p_money_profile_id
  LIMIT 1;
  IF v_public IS NOT NULL THEN
    RETURN v_public;
  END IF;

  SELECT pr.id INTO v_public
  FROM money_kernel.profiles mk
  JOIN public.profiles pr
    ON pr.tenant_id = p_books_tenant_id
   AND pr.deleted_at IS NULL
   AND pr.profile_type::text = mk.profile_type
   AND pr.subject_id = nullif(btrim(mk.meta->>'subject_id'), '')::bigint
  WHERE mk.tenant_id = p_books_tenant_id
    AND mk.id = p_money_profile_id
  LIMIT 1;

  RETURN v_public;
END;
$$;

ALTER TABLE money_kernel.bills DROP CONSTRAINT IF EXISTS fk_bills_from_profile;
ALTER TABLE money_kernel.bills DROP CONSTRAINT IF EXISTS fk_bills_to_profile;

DO $$
DECLARE
  v_bad bigint;
BEGIN
  IF to_regclass('money_kernel.profiles') IS NULL THEN
    RETURN;
  END IF;

  ALTER TABLE money_kernel.bills DISABLE TRIGGER trg_bills_guard_financial_spine;

  UPDATE money_kernel.bills b
  SET
    from_profile_id = coalesce(
      public._kernel_map_money_profile_id_to_public(b.tenant_id, b.from_profile_id),
      b.from_profile_id
    ),
    to_profile_id = coalesce(
      public._kernel_map_money_profile_id_to_public(b.tenant_id, b.to_profile_id),
      b.to_profile_id
    ),
    counterparty_profile_id = coalesce(
      public._kernel_map_money_profile_id_to_public(b.tenant_id, b.counterparty_profile_id),
      b.counterparty_profile_id
    )
  WHERE b.from_profile_id IS NOT NULL
     OR b.to_profile_id IS NOT NULL
     OR b.counterparty_profile_id IS NOT NULL;

  SELECT count(*) INTO v_bad
  FROM money_kernel.bills b
  WHERE (b.from_profile_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.profiles pr WHERE pr.id = b.from_profile_id AND pr.tenant_id = b.tenant_id
    ))
     OR (b.to_profile_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.profiles pr WHERE pr.id = b.to_profile_id AND pr.tenant_id = b.tenant_id
    ));
  IF v_bad > 0 THEN
    RAISE EXCEPTION 'kernel_profiles_unify: % bills reference unmappable profiles', v_bad;
  END IF;

  UPDATE money_kernel.cashbook_accounts ca
  SET
    entity_id = public._kernel_map_money_profile_id_to_public(ca.tenant_id, ca.entity_id),
    profile_id = public._kernel_map_money_profile_id_to_public(ca.tenant_id, ca.profile_id)
  WHERE ca.entity_type = 'profile';

  SELECT count(*) INTO v_bad
  FROM money_kernel.cashbook_accounts ca
  WHERE ca.entity_type = 'profile'
    AND ca.entity_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.profiles pr WHERE pr.id = ca.entity_id AND pr.tenant_id = ca.tenant_id
    );
  IF v_bad > 0 THEN
    RAISE EXCEPTION 'kernel_profiles_unify: % cashbook accounts reference unmappable profiles', v_bad;
  END IF;

  ALTER TABLE money_kernel.bills ENABLE TRIGGER trg_bills_guard_financial_spine;
END;
$$;

ALTER TABLE money_kernel.bills DROP CONSTRAINT IF EXISTS fk_bills_from_profile;
ALTER TABLE money_kernel.bills DROP CONSTRAINT IF EXISTS fk_bills_to_profile;

DROP TRIGGER IF EXISTS trg_provision_profile_cashbook ON money_kernel.profiles;
DROP TRIGGER IF EXISTS trg_tenant_id_immutable_profiles ON money_kernel.profiles;

DROP VIEW IF EXISTS public.v_pot_balances;

DROP TABLE IF EXISTS money_kernel.profiles;

ALTER TABLE money_kernel.bills
  DROP CONSTRAINT IF EXISTS fk_bills_from_profile;
ALTER TABLE money_kernel.bills
  ADD CONSTRAINT fk_bills_from_profile
  FOREIGN KEY (tenant_id, from_profile_id)
  REFERENCES public.profiles (tenant_id, id);

ALTER TABLE money_kernel.bills
  DROP CONSTRAINT IF EXISTS fk_bills_to_profile;
ALTER TABLE money_kernel.bills
  ADD CONSTRAINT fk_bills_to_profile
  FOREIGN KEY (tenant_id, to_profile_id)
  REFERENCES public.profiles (tenant_id, id);

CREATE OR REPLACE FUNCTION money_kernel.ensure_profile_for_public_party(
  p_books_tenant_id bigint,
  p_public_profile_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
BEGIN
  PERFORM public.money_kernel_assert_profile_in_tenant(p_books_tenant_id, p_public_profile_id);
  PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_public_profile_id);
  RETURN p_public_profile_id;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.profile_spend_allowed(
  p_uid       uuid,
  p_tenant_id bigint,
  p_profile_id bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
      FROM public.profiles pr
     WHERE pr.id = p_profile_id
       AND pr.tenant_id = p_tenant_id
       AND pr.deleted_at IS NULL
       AND pr.is_active = true
  );
$$;

CREATE OR REPLACE FUNCTION public.fn_provision_kernel_cashbook_for_profile_row(
  p_books_tenant_id bigint,
  p_profile_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_account_id bigint;
  v_point_id   bigint;
  v_pot_id     bigint;
BEGIN
  IF p_books_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT ca.id INTO v_account_id
  FROM money_kernel.cashbook_accounts ca
  WHERE ca.tenant_id = p_books_tenant_id
    AND ca.entity_type = 'profile'
    AND ca.entity_id = p_profile_id
  LIMIT 1;

  IF v_account_id IS NULL THEN
    INSERT INTO money_kernel.cashbook_accounts
      (tenant_id, entity_type, entity_id, profile_id)
    VALUES
      (p_books_tenant_id, 'profile', p_profile_id, p_profile_id)
    RETURNING id INTO v_account_id;
  END IF;

  SELECT cp.id INTO v_point_id
  FROM money_kernel.cashbook_points cp
  WHERE cp.cashbook_account_id = v_account_id
    AND cp.code = 'main'
  LIMIT 1;

  IF v_point_id IS NULL THEN
    INSERT INTO money_kernel.cashbook_points
      (tenant_id, cashbook_account_id, code, name)
    VALUES
      (p_books_tenant_id, v_account_id, 'main', 'Main')
    RETURNING id INTO v_point_id;
  END IF;

  SELECT pp.id INTO v_pot_id
  FROM money_kernel.cashbook_point_pots pp
  WHERE pp.cashbook_point_id = v_point_id
    AND pp.currency_code = 'BDT'
  LIMIT 1;

  IF v_pot_id IS NULL THEN
    INSERT INTO money_kernel.cashbook_point_pots
      (tenant_id, cashbook_point_id, currency_code)
    VALUES
      (p_books_tenant_id, v_point_id, 'BDT')
    RETURNING id INTO v_pot_id;
  END IF;

  UPDATE money_kernel.cashbook_accounts
     SET default_cashbook_point_pot_id = coalesce(default_cashbook_point_pot_id, v_pot_id)
   WHERE id = v_account_id;

  RETURN v_account_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_provision_kernel_cashbook_for_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
BEGIN
  IF NEW.is_active IS DISTINCT FROM true OR NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;
  PERFORM public.fn_provision_kernel_cashbook_for_profile_row(NEW.tenant_id, NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_provision_kernel_cashbook_for_profile ON public.profiles;
CREATE TRIGGER trg_provision_kernel_cashbook_for_profile
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_provision_kernel_cashbook_for_profile();

GRANT EXECUTE ON FUNCTION public.money_kernel_assert_profile_in_tenant(bigint, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_provision_kernel_cashbook_for_profile_row(bigint, bigint) TO authenticated, service_role;
