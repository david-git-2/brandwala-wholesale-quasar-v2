-- Cash out desk: customer groups with aggregated merchant wallet payable (parent books).

begin;

create or replace function public.list_customer_groups_payout_summary(
  p_tenant_id bigint,
  p_search text default null,
  p_limit integer default 50,
  p_customer_group_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
              'billing_profile_id', bp2.id,
              'name', bp2.name,
              'payable_balance', coalesce(wa2.available_balance, 0.00)
            )
            order by coalesce(wa2.available_balance, 0.00) desc, bp2.name
          ),
          '[]'::jsonb
        )
        from public.billing_profiles bp2
        left join public.wallet_accounts wa2
          on wa2.parent_tenant_id = v_parent_id
         and wa2.entity_type = 'customer'
         and wa2.entity_id = bp2.id
         and wa2.currency_code = 'BDT'
        where bp2.customer_group_id = cg.id
          and (bp2.tenant_id = v_parent_id or bp2.tenant_id = p_tenant_id)
      ) as billing_profiles
    from public.customer_groups cg
    inner join public.billing_profiles bp
      on bp.customer_group_id = cg.id
     and (bp.tenant_id = v_parent_id or bp.tenant_id = p_tenant_id)
    left join public.wallet_accounts wa
      on wa.parent_tenant_id = v_parent_id
     and wa.entity_type = 'customer'
     and wa.entity_id = bp.id
     and wa.currency_code = 'BDT'
    where (cg.parent_tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or bp.name ilike '%' || v_search || '%'
        or coalesce(bp.phone, '') ilike '%' || v_search || '%'
        or coalesce(bp.email, '') ilike '%' || v_search || '%'
      )
    group by cg.id, cg.name
    order by payable_balance desc nulls last, cg.name asc
    limit greatest(least(coalesce(p_limit, 50), 200), 1)
  ) r;

  return v_result;
end;
$$;

grant execute on function public.list_customer_groups_payout_summary(bigint, text, integer, bigint) to authenticated;
grant execute on function public.list_customer_groups_payout_summary(bigint, text, integer, bigint) to service_role;

commit;
