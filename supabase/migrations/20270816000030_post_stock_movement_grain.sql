-- Phase 1 (W4 Step 1.3): RPC post_stock_movement with grain split/merge

begin;

create or replace function public.post_stock_movement(p_movement_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mov public.stock_movements%rowtype;
  v_line public.stock_movement_lines%rowtype;
  v_stock public.global_stocks%rowtype;
  v_target_stock public.global_stocks%rowtype;
  v_target_avail public.stock_availability;
  v_target_loc bigint;
  v_move_qty int;
  v_new_qty int;
begin
  select * into v_mov
  from public.stock_movements
  where id = p_movement_id
  for update;

  if not found then
    raise exception 'stock movement not found';
  end if;

  if v_mov.is_posted then
    raise exception 'stock movement already posted';
  end if;

  if not public.has_active_tenant_membership(v_mov.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_line in
    select * from public.stock_movement_lines where movement_id = p_movement_id
  loop
    if v_line.stock_id is null then
      continue;
    end if;

    select * into v_stock
    from public.global_stocks
    where id = v_line.stock_id
    for update;

    if not found then
      raise exception 'stock % not found for movement line', v_line.stock_id;
    end if;

    v_move_qty := coalesce(v_line.quantity::int, 0);
    if v_move_qty <= 0 then
      continue;
    end if;

    case v_mov.movement_type
      when 'adjustment' then
        if v_line.to_availability is not null and v_line.from_availability is null then
          v_new_qty := v_stock.quantity + v_move_qty;
        else
          v_new_qty := v_stock.quantity - v_move_qty;
        end if;

        if v_new_qty < 0 then
          raise exception 'adjustment would make stock % negative', v_line.stock_id;
        end if;

        update public.global_stocks
        set
          quantity = v_new_qty,
          location_id = coalesce(v_line.to_location_id, location_id),
          availability = coalesce(v_line.to_availability, availability),
          updated_at = now()
        where id = v_line.stock_id;

      when 'location_transfer', 'availability_transfer', 'receive_putaway' then
        v_target_avail := coalesce(v_line.to_availability, v_stock.availability);
        v_target_loc := coalesce(v_line.to_location_id, v_stock.location_id);

        if v_stock.quantity < v_move_qty then
          raise exception 'insufficient stock quantity on stock % (requested %, available %)',
            v_line.stock_id, v_move_qty, v_stock.quantity;
        end if;

        -- If target grain matches source grain, update in place
        if v_target_avail = v_stock.availability and v_target_loc = v_stock.location_id then
          update public.global_stocks
          set updated_at = now()
          where id = v_stock.id;
        else
          -- Check if target grain row exists
          select * into v_target_stock
          from public.global_stocks
          where shipment_item_id = v_stock.shipment_item_id
            and availability = v_target_avail
            and location_id = v_target_loc
          for update;

          if found then
            -- Target grain row exists -> merge qty into target, decrement source
            update public.global_stocks
            set quantity = quantity + v_move_qty, updated_at = now()
            where id = v_target_stock.id;

            if v_stock.quantity = v_move_qty then
              -- Full move to existing target -> delete source row & repoint line
              delete from public.global_stocks where id = v_stock.id;

              update public.stock_movement_lines
              set stock_id = v_target_stock.id
              where id = v_line.id;
            else
              -- Partial move -> decrement source
              update public.global_stocks
              set quantity = quantity - v_move_qty, updated_at = now()
              where id = v_stock.id;
            end if;

          else
            -- Target grain row does NOT exist
            if v_stock.quantity = v_move_qty then
              -- Full move -> update source row attributes
              update public.global_stocks
              set
                availability = v_target_avail,
                location_id = v_target_loc,
                updated_at = now()
              where id = v_stock.id;
            else
              -- Partial move -> create target row and decrement source
              insert into public.global_stocks (
                parent_tenant_id,
                shipment_item_id,
                stock_type_id,
                quantity,
                is_usable,
                availability,
                location_id
              ) values (
                v_stock.parent_tenant_id,
                v_stock.shipment_item_id,
                v_stock.stock_type_id,
                v_move_qty,
                (v_target_avail = 'sellable'::public.stock_availability),
                v_target_avail,
                v_target_loc
              );

              update public.global_stocks
              set quantity = quantity - v_move_qty, updated_at = now()
              where id = v_stock.id;
            end if;
          end if;
        end if;

      when 'return_inbound', 'receive_rollback' then
        v_new_qty := v_stock.quantity - v_move_qty;
        if v_new_qty < 0 then
          raise exception 'return would make stock % negative', v_line.stock_id;
        end if;

        if v_new_qty = 0 then
          delete from public.global_stocks where id = v_stock.id;
        else
          update public.global_stocks
          set quantity = v_new_qty, updated_at = now()
          where id = v_stock.id;
        end if;

      else
        raise exception 'unsupported movement type %', v_mov.movement_type;
    end case;
  end loop;

  update public.stock_movements
  set is_posted = true, posted_at = now(), updated_at = now()
  where id = p_movement_id;

  return jsonb_build_object(
    'movement_id', p_movement_id,
    'is_posted', true,
    'posted_at', now()
  );
end;
$$;

grant execute on function public.post_stock_movement(bigint) to authenticated;

commit;
