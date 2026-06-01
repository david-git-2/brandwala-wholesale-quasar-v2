-- ====================================================================
-- RPC: add_item_to_commerce_cart
-- Safely inserts or updates a commerce_cart row without relying on
-- upsert + .single() which triggers PGRST116 when no row is returned
-- on a no-op update.
-- ====================================================================
begin;

create or replace function public.add_item_to_commerce_cart(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_product_id bigint,
  p_quantity integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing public.commerce_cart;
  v_row      public.commerce_cart;
begin
  -- Check if an entry already exists
  select *
  into v_existing
  from public.commerce_cart
  where tenant_id        = p_tenant_id
    and customer_group_id = p_customer_group_id
    and product_id        = p_product_id
  limit 1;

  if v_existing.id is not null then
    -- Row exists: update quantity by adding the new amount
    update public.commerce_cart
    set quantity   = v_existing.quantity + greatest(p_quantity, 1),
        updated_at = now()
    where id = v_existing.id
    returning * into v_row;
  else
    -- Row does not exist: insert fresh
    insert into public.commerce_cart (
      tenant_id,
      customer_group_id,
      product_id,
      quantity
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      p_product_id,
      greatest(p_quantity, 1)
    )
    returning * into v_row;
  end if;

  return to_jsonb(v_row);
end;
$$;

grant execute on function public.add_item_to_commerce_cart(bigint, bigint, bigint, integer) to authenticated;

commit;
