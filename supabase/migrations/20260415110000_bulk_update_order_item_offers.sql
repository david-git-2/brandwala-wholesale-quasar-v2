-- =========================================================
-- Bulk update order item offer fields in one RPC call
-- Supports first/customer/final offer updates together.
-- =========================================================

create or replace function public.bulk_update_order_item_offers(
  p_items jsonb
)
returns setof public.order_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_id bigint;
  v_first numeric;
  v_customer numeric;
  v_final numeric;
  v_updated public.order_items;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a JSON array';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_id := nullif(v_item->>'id', '')::bigint;

    if v_id is null then
      continue;
    end if;

    v_first := case
      when v_item ? 'first_offer_bdt' and v_item->>'first_offer_bdt' is not null
        then (v_item->>'first_offer_bdt')::numeric
      else null
    end;

    v_customer := case
      when v_item ? 'customer_offer_bdt' and v_item->>'customer_offer_bdt' is not null
        then (v_item->>'customer_offer_bdt')::numeric
      else null
    end;

    v_final := case
      when v_item ? 'final_offer_bdt' and v_item->>'final_offer_bdt' is not null
        then (v_item->>'final_offer_bdt')::numeric
      else null
    end;

    update public.order_items oi
    set
      first_offer_bdt = case
        when v_item ? 'first_offer_bdt' then v_first
        else oi.first_offer_bdt
      end,
      customer_offer_bdt = case
        when v_item ? 'customer_offer_bdt' then v_customer
        else oi.customer_offer_bdt
      end,
      final_offer_bdt = case
        when v_item ? 'final_offer_bdt' then v_final
        else oi.final_offer_bdt
      end
    where oi.id = v_id
    returning oi.* into v_updated;

    if v_updated.id is not null then
      return next v_updated;
    end if;
  end loop;

  return;
end;
$$;

grant execute on function public.bulk_update_order_item_offers(jsonb)
to authenticated;
