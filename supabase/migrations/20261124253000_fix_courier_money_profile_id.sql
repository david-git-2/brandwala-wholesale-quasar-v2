-- Courier remittance ledger uses entity_type=courier + wallet_entity_id.
-- Resolve to profiles.id (courier/subject_id), not treat wallet_entity_id as profile id.

CREATE OR REPLACE FUNCTION public._kernel_cashbook_money_profile_id(
  p_books_id bigint,
  p_entity_type text,
  p_entity_id bigint
) RETURNS bigint
LANGUAGE sql
STABLE
SET search_path TO public
AS $$
  SELECT CASE p_entity_type
    WHEN 'tenant' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'tenant'::public.profile_party_type
        AND pr.subject_id = p_books_id
      LIMIT 1
    )
    WHEN 'customer' THEN p_entity_id
    WHEN 'vendor' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'vendor'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
    WHEN 'cargo_company' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'cargo'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
    WHEN 'courier' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'courier'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
    WHEN 'investor' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'investor'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
  ELSE p_entity_id
  END;
$$;
