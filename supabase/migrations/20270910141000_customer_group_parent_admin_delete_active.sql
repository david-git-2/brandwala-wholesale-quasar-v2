-- Only parent (books) tenant admins may delete customer groups or change is_active.

create or replace function public.can_administer_customer_group(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path to public
as $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(public.resolve_parent_tenant_id(p_tenant_id))
$$;

grant execute on function public.can_administer_customer_group(bigint) to authenticated;

create or replace function public.trg_customer_groups_guard_administer_active()
returns trigger
language plpgsql
security definer
set search_path to public
as $$
begin
  if old.is_active is distinct from new.is_active then
    if not public.can_administer_customer_group(old.tenant_id) then
      raise exception 'Only parent tenant admins can activate or deactivate customer groups';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_customer_groups_guard_administer_active on public.customer_groups;

create trigger trg_customer_groups_guard_administer_active
  before update on public.customer_groups
  for each row
  execute function public.trg_customer_groups_guard_administer_active();

drop policy if exists customer_groups_delete on public.customer_groups;

create policy customer_groups_delete on public.customer_groups
  for delete to authenticated
  using (public.can_administer_customer_group(tenant_id));

create or replace function public.delete_customer_group(p_id bigint)
returns void
language plpgsql
security definer
set search_path to public
as $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id into v_tenant_id
  from public.customer_groups cg
  where cg.id = p_id;

  if v_tenant_id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.can_administer_customer_group(v_tenant_id) then
    raise exception 'Only parent tenant admins can delete customer groups';
  end if;

  delete from public.wallet_accounts wa
  using public.billing_profiles bp
  where bp.customer_group_id = p_id
    and wa.entity_type = 'customer'
    and wa.entity_id = bp.id;

  delete from public.customer_groups where id = p_id;
end;
$$;
