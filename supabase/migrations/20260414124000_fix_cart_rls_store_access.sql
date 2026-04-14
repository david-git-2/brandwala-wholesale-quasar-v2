-- =========================================================
-- Fix cart RLS insert/access checks for customer store flow
-- =========================================================

create or replace function public.can_access_cart(
  p_cart_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.carts c
    where c.id = p_cart_id
      and (
        public.has_active_tenant_membership(c.tenant_id)
        or (
          c.store_id is not null
          and public.can_customer_access_store(c.store_id)
        )
        or (
          c.customer_group_id is not null
          and exists (
            select 1
            from public.customer_group_members cgm
            where cgm.customer_group_id = c.customer_group_id
              and lower(trim(cgm.email)) = public.current_user_email()
              and cgm.is_active = true
          )
        )
      )
  );
$$;

create or replace function public.can_insert_cart(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_store_id bigint default null
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.has_active_tenant_membership(p_tenant_id)
    or (
      p_store_id is not null
      and exists (
        select 1
        from public.stores s
        where s.id = p_store_id
          and s.tenant_id = p_tenant_id
          and public.can_customer_access_store(s.id)
      )
    )
    or (
      p_customer_group_id is not null
      and exists (
        select 1
        from public.customer_groups cg
        join public.customer_group_members cgm
          on cgm.customer_group_id = cg.id
        where cg.id = p_customer_group_id
          and cg.tenant_id = p_tenant_id
          and lower(trim(cgm.email)) = public.current_user_email()
          and cgm.is_active = true
      )
    );
$$;

create or replace function public.can_access_cart_item(
  p_cart_item_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.cart_items ci
    join public.carts c on c.id = ci.cart_id
    where ci.id = p_cart_item_id
      and (
        public.has_active_tenant_membership(c.tenant_id)
        or (
          c.store_id is not null
          and public.can_customer_access_store(c.store_id)
        )
        or (
          c.customer_group_id is not null
          and exists (
            select 1
            from public.customer_group_members cgm
            where cgm.customer_group_id = c.customer_group_id
              and lower(trim(cgm.email)) = public.current_user_email()
              and cgm.is_active = true
          )
        )
      )
  );
$$;

drop policy if exists carts_insert on public.carts;
create policy carts_insert
on public.carts
for insert
to authenticated
with check (
  public.can_insert_cart(tenant_id, customer_group_id, store_id)
);

drop policy if exists carts_update on public.carts;
create policy carts_update
on public.carts
for update
to authenticated
using (
  public.can_access_cart(id)
)
with check (
  public.can_insert_cart(tenant_id, customer_group_id, store_id)
);

grant execute on function public.can_insert_cart(bigint, bigint, bigint)
to authenticated;
