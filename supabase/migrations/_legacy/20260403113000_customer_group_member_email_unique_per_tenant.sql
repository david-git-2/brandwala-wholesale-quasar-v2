create or replace function public.enforce_customer_group_member_email_unique_per_tenant()
returns trigger
language plpgsql
as $$
declare
  v_tenant_id bigint;
  v_normalized_email text;
begin
  select cg.tenant_id
  into v_tenant_id
  from public.customer_groups cg
  where cg.id = new.customer_group_id;

  if v_tenant_id is null then
    raise exception 'customer group tenant could not be resolved';
  end if;

  v_normalized_email := lower(trim(new.email));
  new.email := v_normalized_email;

  if exists (
    select 1
    from public.customer_group_members cgm
    join public.customer_groups cg
      on cg.id = cgm.customer_group_id
    where cg.tenant_id = v_tenant_id
      and lower(trim(cgm.email)) = v_normalized_email
      and cgm.id <> coalesce(new.id, -1)
  ) then
    raise exception 'This email already belongs to another customer user in the same tenant';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_customer_group_members_email_unique_per_tenant
on public.customer_group_members;

create trigger trg_customer_group_members_email_unique_per_tenant
before insert or update on public.customer_group_members
for each row
execute function public.enforce_customer_group_member_email_unique_per_tenant();
