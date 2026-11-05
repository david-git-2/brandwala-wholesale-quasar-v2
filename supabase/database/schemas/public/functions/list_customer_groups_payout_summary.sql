CREATE FUNCTION public.list_customer_groups_payout_summary (
  p_tenant_id         bigint,
  p_search            text    DEFAULT NULL::text,
  p_limit             integer DEFAULT 50,
  p_customer_group_id bigint  DEFAULT NULL::bigint,
  p_only_with_payable boolean DEFAULT true
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_id bigint;
  v_result jsonb;
  v_search text;
begin
  if p_tenant_id is null then
    return '[]'::jsonb;
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_search := nullif(trim(p_search), '');

  if not (
    public.is_superadmin()
    or public.is_tenant_staff(p_tenant_id)
    or public.membership_has_module_action(v_parent_id, 'payments', 'view')
    or public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      cg.id as customer_group_id,
      cg.name,
      ('CUST-GRP-' || lpad(cg.id::text, 4, '0')) as account_code,
      coalesce(sum(wa.available_balance), 0.00)::numeric(12, 2) as payable_balance,
      (
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'profile_id', pr2.id,
              'name', pr2.name,
              'payable_balance', coalesce(wa2.available_balance, 0.00)
            )
            order by coalesce(wa2.available_balance, 0.00) desc, pr2.name
          ),
          '[]'::jsonb
        )
        from public.profiles pr2
        left join public.cashbook_accounts wa2
          on wa2.parent_tenant_id = v_parent_id
         and wa2.entity_type = 'customer'
         and wa2.entity_id = pr2.id
         and wa2.currency_code = 'BDT'
        where pr2.customer_group_id = cg.id
          and pr2.profile_type = 'customer'::public.profile_party_type
          and (pr2.operating_tenant_id = v_parent_id or pr2.operating_tenant_id = p_tenant_id)
      ) as profiles
    from public.customer_groups cg
    inner join public.profiles pr
      on pr.customer_group_id = cg.id
     and (pr.operating_tenant_id = v_parent_id or pr.operating_tenant_id = p_tenant_id)
    left join public.cashbook_accounts wa
      on wa.parent_tenant_id = v_parent_id
     and wa.entity_type = 'customer'
     and wa.entity_id = pr.id
     and wa.currency_code = 'BDT'
    where (cg.parent_tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or pr.name ilike '%' || v_search || '%'
        or coalesce(pr.phone, '') ilike '%' || v_search || '%'
        or coalesce(pr.email, '') ilike '%' || v_search || '%'
      )
    group by cg.id, cg.name
    having (
      not coalesce(p_only_with_payable, false)
      or coalesce(sum(wa.available_balance), 0.00) > 0.00
    )
    order by payable_balance desc nulls last, cg.name asc
    limit greatest(least(coalesce(p_limit, 50), 200), 1)
  ) r;

  return v_result;
end;
$function$;

GRANT ALL ON FUNCTION public.list_customer_groups_payout_summary(bigint, text, integer, bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.list_customer_groups_payout_summary(bigint, text, integer, bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.list_customer_groups_payout_summary(bigint, text, integer, bigint, boolean) TO service_role;