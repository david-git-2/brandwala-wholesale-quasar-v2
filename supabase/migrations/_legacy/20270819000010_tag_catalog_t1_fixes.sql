-- Fix tag catalog T1: is_system default, backfill, write RLS, slug uniqueness, RPC hardening
begin;

-- 1. is_system default false; backfill non-catalog tags; keep catalog seeds as system
alter table public.tags
  alter column is_system set default false;

update public.tags
set is_system = false
where category_id is null
   or tenant_id is not null;

update public.tags
set
  is_system = true,
  created_by_email = 'system@platform'
where category_id is not null
  and tenant_id is null;

-- 2. Replace legacy unique (tenant_id, slug, created_by_email) so system tags
--    can share slugs across categories (uniqueness is category_id + slug).
alter table public.tags
  drop constraint if exists tags_tenant_id_slug_created_by_email_key;

drop index if exists tags_tenant_id_slug_created_by_email_key;

create unique index if not exists tags_tenant_slug_email_unique
  on public.tags (tenant_id, slug, created_by_email)
  where tenant_id is not null;

-- 3. Block writes on system tags (keep owner/admin writes for non-system)
drop policy if exists tags_all on public.tags;
drop policy if exists tags_insert on public.tags;
drop policy if exists tags_update on public.tags;
drop policy if exists tags_delete on public.tags;

create policy tags_insert on public.tags
  for insert to authenticated
  with check (
    coalesce(is_system, false) = false
    and (
      created_by_email = public.current_user_email()
      or (tenant_id is not null and public.is_tenant_admin(tenant_id))
    )
  );

create policy tags_update on public.tags
  for update to authenticated
  using (
    coalesce(is_system, false) = false
    and (
      created_by_email = public.current_user_email()
      or (tenant_id is not null and public.is_tenant_admin(tenant_id))
    )
  )
  with check (
    coalesce(is_system, false) = false
  );

create policy tags_delete on public.tags
  for delete to authenticated
  using (
    coalesce(is_system, false) = false
    and (
      created_by_email = public.current_user_email()
      or (tenant_id is not null and public.is_tenant_admin(tenant_id))
    )
  );

-- 4. Harden list RPCs: system rows only (+ caller's tenant custom later);
--    revoke anon; set search_path
create or replace function public.list_tag_categories(
  p_module_key text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_res json;
begin
  select coalesce(json_agg(row_to_json(c)), '[]'::json)
  into v_res
  from (
    select
      tc.id,
      tc.module_key,
      tc.code,
      tc.name,
      tc.cardinality,
      tc.is_system,
      tc.tenant_id,
      tc.sort_order,
      tc.is_active,
      tc.created_at
    from public.tag_categories tc
    where tc.is_active = true
      and (p_module_key is null or tc.module_key = p_module_key)
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      )
    order by tc.sort_order asc nulls last, tc.id asc
  ) c;

  return v_res;
end;
$$;

create or replace function public.list_tags_for_category(
  p_category_id bigint default null,
  p_module_key text default null,
  p_code text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category_id bigint;
  v_res json;
begin
  if p_category_id is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.id = p_category_id
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      );
  elsif p_module_key is not null and p_code is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.module_key = p_module_key
      and tc.code = p_code
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      )
    order by tc.is_system desc, tc.id asc
    limit 1;
  end if;

  if v_category_id is null then
    return '[]'::json;
  end if;

  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  into v_res
  from (
    select
      tg.id,
      tg.category_id,
      tg.slug,
      tg.name,
      tg.color,
      tg.metadata,
      tg.sort_order,
      tg.is_system,
      tg.is_active,
      tg.tenant_id,
      tg.group_name,
      tg.type
    from public.tags tg
    where tg.category_id = v_category_id
      and tg.is_active = true
    order by tg.sort_order asc nulls last, tg.id asc
  ) t;

  return v_res;
end;
$$;

create or replace function public.get_tag_by_slug(
  p_category_id bigint default null,
  p_module_key text default null,
  p_code text default null,
  p_slug text default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category_id bigint;
  v_res json;
begin
  if p_slug is null then
    return null;
  end if;

  if p_category_id is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.id = p_category_id
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      );
  elsif p_module_key is not null and p_code is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.module_key = p_module_key
      and tc.code = p_code
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      )
    order by tc.is_system desc, tc.id asc
    limit 1;
  end if;

  if v_category_id is null then
    return null;
  end if;

  select row_to_json(t)
  into v_res
  from (
    select
      tg.id,
      tg.category_id,
      tg.slug,
      tg.name,
      tg.color,
      tg.metadata,
      tg.sort_order,
      tg.is_system,
      tg.is_active,
      tg.tenant_id,
      tg.group_name,
      tg.type
    from public.tags tg
    where tg.category_id = v_category_id
      and tg.slug = p_slug
      and tg.is_active = true
    limit 1
  ) t;

  return v_res;
end;
$$;

revoke all on function public.list_tag_categories(text) from public, anon;
revoke all on function public.list_tags_for_category(bigint, text, text) from public, anon;
revoke all on function public.get_tag_by_slug(bigint, text, text, text) from public, anon;

grant execute on function public.list_tag_categories(text) to authenticated;
grant execute on function public.list_tags_for_category(bigint, text, text) to authenticated;
grant execute on function public.get_tag_by_slug(bigint, text, text, text) to authenticated;

-- Also tighten category table select: no anon
drop policy if exists tag_categories_select on public.tag_categories;
create policy tag_categories_select on public.tag_categories
  for select to authenticated
  using (
    is_system = true
    or tenant_id is null
    or (tenant_id is not null and public.has_active_tenant_membership(tenant_id))
  );

drop policy if exists tags_select on public.tags;
create policy tags_select on public.tags
  for select to authenticated
  using (
    is_system = true
    or tenant_id is null
    or (tenant_id is not null and public.has_active_tenant_membership(tenant_id))
    or created_by_email = public.current_user_email()
  );

commit;
