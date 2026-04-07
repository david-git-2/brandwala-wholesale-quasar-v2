# Costing Backend Architecture

SQL reference for the costing file backend.

## Tables

### `costing_files`

- `id`
- `name`
- `market`
- `status`
- `customer_group_id`
- `tenant_id`
- `created_by_email`
- `cargo_rate_1kg`
- `cargo_rate_2kg`
- `conversion_rate`
- `admin_profit_rate`
- `created_at`
- `updated_at`

### `costing_file_items`

- `id`
- `costing_file_id`
- `website_url`
- `quantity`
- `name`
- `size`
- `color`
- `extra_information_1`
- `extra_information_2`
- `image_url`
- `product_weight`
- `package_weight`
- `price_in_web_gbp`
- `delivery_price_gbp`
- `auxiliary_price_gbp`
- `item_price_gbp`
- `cargo_rate`
- `costing_price_gbp`
- `costing_price_bdt`
- `offer_price_override_bdt`
- `offer_price_bdt`
- `customer_profit_rate`
- `status`
- `created_by_email`
- `created_at`
- `updated_at`

## Statuses

- file: `draft`, `customer_submitted`, `in_review`, `priced`, `offered`, `completed`, `cancelled`
- item: `pending`, `accepted`, `rejected`

## Helpers

```sql
public.is_tenant_staff(tenant_id)
public.is_customer_group_member(customer_group_id)
public.can_admin_manage_costing_file(tenant_id)
public.can_staff_access_costing_file(tenant_id)
public.can_customer_access_costing_file(customer_group_id)
public.can_view_costing_file(costing_file_id)
public.current_costing_item_actor_role(costing_file_id)
```

## RLS

```sql
create policy "costing_files_select"
on public.costing_files
for select
to authenticated
using (
  public.can_view_costing_file(id)
);
```

```sql
create policy "costing_files_insert"
on public.costing_files
for insert
to authenticated
with check (
  public.can_admin_manage_costing_file(tenant_id)
);
```

```sql
create policy "costing_files_update"
on public.costing_files
for update
to authenticated
using (
  public.can_admin_manage_costing_file(tenant_id)
);
```

```sql
create policy "costing_files_delete"
on public.costing_files
for delete
to authenticated
using (
  public.can_admin_manage_costing_file(tenant_id)
);
```

```sql
create policy "costing_file_items_select"
on public.costing_file_items
for select
to authenticated
using (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and public.can_view_costing_file(cf.id)
  )
);
```

```sql
create policy "costing_file_items_insert"
on public.costing_file_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
        )
      )
  )
);
```

## Trigger

```sql
create or replace function public.enforce_costing_file_item_update_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- admin can edit all
  -- staff can edit enrichment fields only
  -- customer can edit draft or offered fields as allowed
  return new;
end;
$$;
```

## RPCs

- `public.list_costing_files_for_actor(...)`
- `public.get_costing_file_by_id(...)`
- `public.list_costing_file_items(...)`
- `public.create_costing_file_item_request(...)`
- `public.update_costing_file_item_enrichment(...)`
- `public.update_costing_file_item_customer_profit(...)`
- `public.update_costing_file_items_customer_profit(...)`
- `public.update_costing_file_item_status(...)`
- `public.update_costing_file_item_offer(...)`
- `public.update_costing_file_item(...)`
