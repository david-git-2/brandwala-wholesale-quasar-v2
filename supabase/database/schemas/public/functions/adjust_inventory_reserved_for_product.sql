CREATE FUNCTION public.adjust_inventory_reserved_for_product (
  p_tenant_id  bigint,
  p_product_id bigint,
  p_delta      integer
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_remaining integer := coalesce(p_delta, 0);
  v_rec record;
  v_take integer;
  v_slack integer;
begin
  if v_remaining = 0 or p_product_id is null then
    return;
  end if;

  if v_remaining > 0 then
    for v_rec in
      select
        st.id,
        st.available_quantity,
        st.reserved_quantity,
        st.damaged_quantity,
        st.stolen_quantity,
        st.expired_quantity,
        st.open_box_quantity
      from public.inventory_stocks st
      join public.inventory_items ii on ii.id = st.inventory_item_id
      where ii.tenant_id = p_tenant_id
        and ii.product_id = p_product_id
        and ii.status = 'active'
      order by st.id asc
      for update of st
    loop
      v_slack := greatest(
        0,
        coalesce(v_rec.available_quantity, 0)
        - coalesce(v_rec.reserved_quantity, 0)
        - coalesce(v_rec.damaged_quantity, 0)
        - coalesce(v_rec.stolen_quantity, 0)
        - coalesce(v_rec.expired_quantity, 0)
        - coalesce(v_rec.open_box_quantity, 0)
      );

      if v_slack <= 0 then
        continue;
      end if;

      v_take := least(v_remaining, v_slack);

      update public.inventory_stocks
      set reserved_quantity = coalesce(reserved_quantity, 0) + v_take
      where id = v_rec.id;

      v_remaining := v_remaining - v_take;
      exit when v_remaining = 0;
    end loop;

    if v_remaining > 0 then
      raise exception 'Not enough stock to reserve for product %.', p_product_id;
    end if;
  else
    v_remaining := abs(v_remaining);

    for v_rec in
      select
        st.id,
        st.reserved_quantity
      from public.inventory_stocks st
      join public.inventory_items ii on ii.id = st.inventory_item_id
      where ii.tenant_id = p_tenant_id
        and ii.product_id = p_product_id
        and ii.status = 'active'
        and coalesce(st.reserved_quantity, 0) > 0
      order by st.id desc
      for update of st
    loop
      v_take := least(v_remaining, coalesce(v_rec.reserved_quantity, 0));

      update public.inventory_stocks
      set reserved_quantity = greatest(0, coalesce(reserved_quantity, 0) - v_take)
      where id = v_rec.id;

      v_remaining := v_remaining - v_take;
      exit when v_remaining = 0;
    end loop;
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.adjust_inventory_reserved_for_product(bigint, bigint, integer) TO anon;

GRANT ALL ON FUNCTION public.adjust_inventory_reserved_for_product(bigint, bigint, integer) TO authenticated;

GRANT ALL ON FUNCTION public.adjust_inventory_reserved_for_product(bigint, bigint, integer) TO service_role;