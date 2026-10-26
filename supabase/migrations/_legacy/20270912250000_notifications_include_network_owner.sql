begin;

create or replace function public.resolve_notification_recipient_user_ids(
  p_parent_tenant_id bigint,
  p_operating_tenant_id bigint,
  p_audience public.notification_audience,
  p_recipient_user_ids uuid[] default null,
  p_module_key text default null,
  p_action text default 'view'
)
returns uuid[]
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_ids uuid[];
begin
  if p_audience = 'assignee_only' then
    if p_recipient_user_ids is null or cardinality(p_recipient_user_ids) = 0 then
      return array[]::uuid[];
    end if;

    select coalesce(array_agg(distinct u.user_id), array[]::uuid[])
    into v_user_ids
    from unnest(p_recipient_user_ids) as input(user_id)
    join auth.users u on u.id = input.user_id
    where input.user_id is not null;

    return coalesce(v_user_ids, array[]::uuid[]);
  end if;

  if p_audience = 'child_only' and p_operating_tenant_id is null then
    return array[]::uuid[];
  end if;

  with pools as (
    select distinct
      u.id as user_id,
      m.tenant_id as membership_tenant_id
    from public.memberships m
    join auth.users u on lower(trim(u.email)) = lower(trim(m.email))
    where m.is_active = true
      and (
        (
          p_audience in ('child_only', 'child_and_parent')
          and p_operating_tenant_id is not null
          and m.tenant_id = p_operating_tenant_id
        )
        or (
          p_audience in ('parent_only', 'child_and_parent')
          and m.tenant_id = p_parent_tenant_id
        )
        or (
          m.tenant_id = p_parent_tenant_id
          and m.role = 'owner'::public.app_role
        )
      )
  )
  select coalesce(array_agg(distinct p.user_id), array[]::uuid[])
  into v_user_ids
  from pools p
  where p_module_key is null
     or public.membership_has_module_action(p.membership_tenant_id, p_module_key, p_action);

  return coalesce(v_user_ids, array[]::uuid[]);
end;
$$;

commit;
