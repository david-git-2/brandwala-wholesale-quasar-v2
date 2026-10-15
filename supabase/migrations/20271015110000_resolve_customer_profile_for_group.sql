-- submit_dropship_order_from_cart (20271015100000) calls this; was in schemas only.

CREATE OR REPLACE FUNCTION "public"."resolve_customer_profile_for_group"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_profile_id bigint;
  v_books_id bigint;
begin
  if p_customer_group_id is null then
    return null;
  end if;

  select id into v_profile_id
  from public.profiles
  where operating_tenant_id = p_tenant_id
    and customer_group_id = p_customer_group_id
    and profile_type = 'customer'::public.profile_party_type
  order by id
  limit 1;

  if v_profile_id is not null then
    return v_profile_id;
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  select id into v_profile_id
  from public.profiles pr
  where pr.customer_group_id = p_customer_group_id
    and pr.profile_type = 'customer'::public.profile_party_type
    and (
      pr.operating_tenant_id = v_books_id
      or pr.operating_tenant_id in (
        select t.id from public.tenants t where t.parent_id = v_books_id
      )
    )
  order by
    case
      when pr.operating_tenant_id = p_tenant_id then 0
      when pr.operating_tenant_id = v_books_id then 1
      else 2
    end,
    pr.id
  limit 1;

  return v_profile_id;
end;
$$;

ALTER FUNCTION "public"."resolve_customer_profile_for_group"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."resolve_customer_profile_for_group"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "authenticated";
