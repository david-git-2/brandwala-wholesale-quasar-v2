-- =========================================================
-- Step 5: Backend tenant lookup helpers
-- Active-only, pre-login-safe tenant resolution helpers
-- =========================================================

drop function if exists public.find_active_tenant_by_slug(text);

create function public.find_active_tenant_by_slug(
  p_slug text
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain
  from public.tenants t
  where t.is_active = true
    and lower(trim(t.slug)) = nullif(lower(trim(coalesce(p_slug, ''))), '')
  limit 1;
$$;

grant execute on function public.find_active_tenant_by_slug(text)
to anon, authenticated;

drop function if exists public.find_active_tenant_by_public_domain(text);

create function public.find_active_tenant_by_public_domain(
  p_public_domain text
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain
  from public.tenants t
  where t.is_active = true
    and lower(trim(coalesce(t.public_domain, ''))) = nullif(
      regexp_replace(
        lower(
          trim(
            split_part(
              regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
              '/',
              1
            )
          )
        ),
        ':\d+$',
        ''
      ),
      ''
    )
  limit 1;
$$;

grant execute on function public.find_active_tenant_by_public_domain(text)
to anon, authenticated;

drop function if exists public.resolve_tenant_for_entry(text, text);

create function public.resolve_tenant_for_entry(
  p_slug text default null,
  p_hostname text default null
)
returns table(
  id bigint,
  name text,
  slug text,
  public_domain text
)
language sql
security definer
set search_path = public
stable
as $$
  with domain_match as (
    select *
    from public.find_active_tenant_by_public_domain(p_hostname)
  ),
  slug_match as (
    select *
    from public.find_active_tenant_by_slug(p_slug)
  )
  select *
  from domain_match
  union all
  select *
  from slug_match
  where not exists (select 1 from domain_match)
  limit 1;
$$;

grant execute on function public.resolve_tenant_for_entry(text, text)
to anon, authenticated;
