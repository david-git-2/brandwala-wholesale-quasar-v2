-- Fix resolve_billing_profile_for_customer_group: fall back to any profile under books network

begin;

create or replace function public.resolve_billing_profile_for_customer_group(
  p_tenant_id bigint,
  p_customer_group_id bigint
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_billing_profile_id bigint;
  v_books_id bigint;
begin
  if p_customer_group_id is null then
    return null;
  end if;

  select id into v_billing_profile_id
  from public.billing_profiles
  where tenant_id = p_tenant_id
    and customer_group_id = p_customer_group_id
  order by id
  limit 1;

  if v_billing_profile_id is not null then
    return v_billing_profile_id;
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  select id into v_billing_profile_id
  from public.billing_profiles bp
  where bp.customer_group_id = p_customer_group_id
    and (
      bp.tenant_id = v_books_id
      or bp.tenant_id in (
        select t.id from public.tenants t where t.parent_id = v_books_id
      )
    )
  order by
    case
      when bp.tenant_id = p_tenant_id then 0
      when bp.tenant_id = v_books_id then 1
      else 2
    end,
    bp.id
  limit 1;

  return v_billing_profile_id;
end;
$$;

commit;
