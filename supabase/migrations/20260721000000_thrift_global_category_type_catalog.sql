begin;

-- =========================================================
-- Global + tenant-scoped thrift categories and types
-- =========================================================

alter table public.thrift_categories
  add column if not exists is_global boolean not null default false;

alter table public.thrift_types
  add column if not exists is_global boolean not null default false;

alter table public.thrift_categories
  alter column tenant_id drop not null;

alter table public.thrift_types
  alter column tenant_id drop not null;

alter table public.thrift_categories
  drop constraint if exists thrift_categories_name_tenant_unique;

alter table public.thrift_types
  drop constraint if exists thrift_types_name_tenant_unique;

alter table public.thrift_categories
  add constraint thrift_categories_scope_check
  check (
    (is_global = true and tenant_id is null)
    or (is_global = false and tenant_id is not null)
  );

alter table public.thrift_types
  add constraint thrift_types_scope_check
  check (
    (is_global = true and tenant_id is null)
    or (is_global = false and tenant_id is not null)
  );

create unique index if not exists thrift_categories_global_name_unique
  on public.thrift_categories (name)
  where is_global = true;

create unique index if not exists thrift_categories_tenant_name_unique
  on public.thrift_categories (tenant_id, name)
  where is_global = false;

create unique index if not exists thrift_types_global_name_unique
  on public.thrift_types (name)
  where is_global = true;

create unique index if not exists thrift_types_tenant_name_unique
  on public.thrift_types (tenant_id, name)
  where is_global = false;

-- RLS: categories
drop policy if exists select_thrift_categories on public.thrift_categories;
drop policy if exists write_thrift_categories on public.thrift_categories;

create policy select_thrift_categories on public.thrift_categories for select to authenticated
  using (
    is_global = true
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = thrift_categories.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

create policy write_thrift_categories on public.thrift_categories for all to authenticated
  using (
    is_global = false
    and exists (
      select 1 from public.memberships m
      where m.tenant_id = thrift_categories.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  );

-- RLS: types
drop policy if exists select_thrift_types on public.thrift_types;
drop policy if exists write_thrift_types on public.thrift_types;

create policy select_thrift_types on public.thrift_types for select to authenticated
  using (
    is_global = true
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = thrift_types.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

create policy write_thrift_types on public.thrift_types for all to authenticated
  using (
    is_global = false
    and exists (
      select 1 from public.memberships m
      where m.tenant_id = thrift_types.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  );

-- Global category
insert into public.thrift_categories (tenant_id, is_global, name, description, inserted_by)
select null, true, 'Women Clothing', 'Women''s clothing and dresses', 'system'
where not exists (
  select 1 from public.thrift_categories
  where is_global = true and name = 'Women Clothing'
);

-- Global dress types (UK retail)
insert into public.thrift_types (tenant_id, is_global, name, description, inserted_by)
select null, true, v.name, v.description, 'system'
from (
  values
    ('Mini Dress', 'Above-knee length'),
    ('Midi Dress', 'Mid-calf length'),
    ('Maxi Dress', 'Ankle or floor length'),
    ('Midaxi Dress', 'Between midi and maxi'),
    ('Shift Dress', 'Straight boxy silhouette'),
    ('Wrap Dress', 'Front wrap tie at waist'),
    ('Bodycon Dress', 'Form-fitting stretch silhouette'),
    ('A-Line Dress', 'Fitted top, flared skirt'),
    ('Fit and Flare Dress', 'Cinched waist, flared hem'),
    ('Shirt Dress', 'Shirt-style button front'),
    ('Skater Dress', 'Fitted bodice, flared skirt'),
    ('Slip Dress', 'Strappy satin or silk minimalist'),
    ('Tea Dress', 'Fifties-inspired below-knee'),
    ('Smock Dress', 'Loose tiered easy fit'),
    ('Jumper Dress', 'Knitted sweater dress'),
    ('T-Shirt Dress', 'Casual tee-style dress'),
    ('Cocktail Dress', 'Semi-formal occasion'),
    ('Evening Dress', 'Formal long dress'),
    ('Party Dress', 'Short dressy going-out style'),
    ('Strappy Dress', 'Thin or thick shoulder straps'),
    ('Denim Dress', 'Denim fabric dress'),
    ('Blazer Dress', 'Tailored blazer-style'),
    ('Swing Dress', 'Loose knee-length flared'),
    ('Off Shoulder Dress', 'Bardot neckline')
) as v(name, description)
where not exists (
  select 1 from public.thrift_types t
  where t.is_global = true and t.name = v.name
);

commit;
