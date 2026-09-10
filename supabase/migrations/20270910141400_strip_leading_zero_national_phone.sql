-- Strip a leading 0 from national numbers (country calling code is separate).

begin;

create or replace function public.normalize_customer_national_phone(p_phone text)
returns text
language sql
immutable
set search_path = public
as $$
  select nullif(
    regexp_replace(
      regexp_replace(trim(coalesce(p_phone, '')), '[^0-9]', '', 'g'),
      '^0+',
      ''
    ),
    ''
  );
$$;

create or replace function public.trg_billing_profiles_normalize_phone()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.phone := public.normalize_customer_national_phone(new.phone);
  return new;
end;
$$;

drop trigger if exists trg_billing_profiles_normalize_phone on public.billing_profiles;
create trigger trg_billing_profiles_normalize_phone
  before insert or update of phone
  on public.billing_profiles
  for each row
  execute function public.trg_billing_profiles_normalize_phone();

create or replace function public.find_customer_create_conflict(
  p_tenant_id bigint,
  p_phone text default null,
  p_phone_country_code text default null,
  p_group_name text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
  v_phone text;
  v_code text;
  v_name text;
  v_phone_group text;
  v_name_group text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_phone := public.normalize_customer_national_phone(p_phone);
  v_code := nullif(trim(coalesce(p_phone_country_code, '')), '');
  if v_code is not null and v_code not like '+%' then
    v_code := '+' || v_code;
  end if;
  v_name := nullif(trim(coalesce(p_group_name, '')), '');

  if v_phone is not null and v_code is not null then
    select cg.name
    into v_phone_group
    from public.billing_profiles bp
    left join public.customer_groups cg on cg.id = bp.customer_group_id
    where bp.parent_tenant_id = v_books_id
      and bp.phone_country_code = v_code
      and bp.phone = v_phone
      and (cg.id is null or cg.deleted_at is null)
    order by bp.id
    limit 1;
  end if;

  if v_name is not null then
    select cg.name
    into v_name_group
    from public.customer_groups cg
    where cg.parent_tenant_id = v_books_id
      and cg.deleted_at is null
      and lower(cg.name) = lower(v_name)
    order by cg.id
    limit 1;
  end if;

  return jsonb_build_object(
    'phone_group_name', v_phone_group,
    'name_group_name', v_name_group
  );
end;
$$;

grant all on function public.normalize_customer_national_phone(text) to authenticated;
grant all on function public.find_customer_create_conflict(bigint, text, text, text) to authenticated;

commit;
