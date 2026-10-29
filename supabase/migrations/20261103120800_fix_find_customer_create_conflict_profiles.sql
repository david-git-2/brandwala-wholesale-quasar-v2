-- find_customer_create_conflict: billing_profiles removed; phone uniqueness lives on profiles.
CREATE OR REPLACE FUNCTION public.find_customer_create_conflict(
  p_tenant_id bigint,
  p_phone text DEFAULT NULL,
  p_phone_country_code text DEFAULT NULL,
  p_group_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_phone text;
  v_code text;
  v_name text;
  v_phone_group text;
  v_name_group text;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_phone := public.normalize_customer_national_phone(p_phone);
  v_code := nullif(trim(coalesce(p_phone_country_code, '')), '');
  IF v_code IS NOT NULL AND v_code NOT LIKE '+%' THEN
    v_code := '+' || v_code;
  END IF;
  v_name := nullif(trim(coalesce(p_group_name, '')), '');

  IF v_phone IS NOT NULL AND v_code IS NOT NULL THEN
    SELECT cg.name
    INTO v_phone_group
    FROM public.profiles pr
    LEFT JOIN public.customer_groups cg ON cg.id = pr.customer_group_id
    WHERE pr.profile_type = 'customer'::public.profile_party_type
      AND pr.parent_tenant_id = v_books_id
      AND pr.phone_country_code = v_code
      AND pr.phone = v_phone
      AND pr.is_phone_unique
      AND (cg.id IS NULL OR cg.deleted_at IS NULL)
    ORDER BY pr.id
    LIMIT 1;
  END IF;

  IF v_name IS NOT NULL THEN
    SELECT cg.name
    INTO v_name_group
    FROM public.customer_groups cg
    WHERE cg.parent_tenant_id = v_books_id
      AND cg.deleted_at IS NULL
      AND lower(cg.name) = lower(v_name)
    ORDER BY cg.id
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'phone_group_name', v_phone_group,
    'name_group_name', v_name_group
  );
END;
$$;
