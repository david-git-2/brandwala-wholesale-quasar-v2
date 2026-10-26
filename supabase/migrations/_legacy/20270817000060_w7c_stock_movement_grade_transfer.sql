-- Migration W7c: Stock Movements Grade & Location Transfer RPC support
-- Extend stock_movement_lines, update post_stock_movement, add create_and_post_stock_movement RPC.

begin;

-- 1. Extend stock_movement_lines
alter table public.stock_movement_lines
  add column if not exists from_grade_tag_id bigint null references public.tags(id),
  add column if not exists to_grade_tag_id bigint null references public.tags(id);

-- 2. Update post_stock_movement RPC for grade_tag_id grain & grade_change movement type
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
  v_target_grade bigint;
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
          grade_tag_id = coalesce(v_line.to_grade_tag_id, grade_tag_id, public.default_stock_grade_tag_id()),
          updated_at = now()
        where id = v_line.stock_id;

      when 'location_transfer', 'availability_transfer', 'grade_change', 'receive_putaway' then
        v_target_avail := coalesce(v_line.to_availability, v_stock.availability);
        v_target_loc := coalesce(v_line.to_location_id, v_stock.location_id);
        v_target_grade := coalesce(v_line.to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id());

        if v_stock.quantity < v_move_qty then
          raise exception 'insufficient stock quantity on stock % (requested %, available %)',
            v_line.stock_id, v_move_qty, v_stock.quantity;
        end if;

        -- If target grain matches source grain, update in place
        if v_target_avail = v_stock.availability
           and v_target_loc = v_stock.location_id
           and v_target_grade = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id()) then
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
            and grade_tag_id = v_target_grade
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
                grade_tag_id = v_target_grade,
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
                location_id,
                grade_tag_id
              ) values (
                v_stock.parent_tenant_id,
                v_stock.shipment_item_id,
                v_stock.stock_type_id,
                v_move_qty,
                (v_target_avail = 'sellable'::public.stock_availability),
                v_target_avail,
                v_target_loc,
                v_target_grade
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

-- 3. Atomic create_and_post_stock_movement RPC
create or replace function public.create_and_post_stock_movement(
  p_tenant_id bigint,
  p_stock_id bigint,
  p_quantity integer,
  p_to_location_id bigint default null,
  p_to_availability public.stock_availability default null,
  p_to_grade_tag_id bigint default null,
  p_movement_type public.stock_movement_type default 'grade_change',
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stock public.global_stocks%rowtype;
  v_mov_id bigint;
  v_mov_no text;
  v_res jsonb;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select * into v_stock
  from public.global_stocks
  where id = p_stock_id
    and parent_tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'stock % not found', p_stock_id;
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be > 0';
  end if;

  if v_stock.quantity < p_quantity then
    raise exception 'insufficient stock quantity (requested %, available %)', p_quantity, v_stock.quantity;
  end if;

  v_mov_no := 'MOV-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    p_tenant_id,
    v_mov_no,
    p_movement_type,
    'global_stock',
    p_stock_id::text,
    p_notes,
    public.current_user_email(),
    false,
    null
  )
  returning id into v_mov_id;

  insert into public.stock_movement_lines (
    movement_id,
    stock_id,
    quantity,
    from_location_id,
    to_location_id,
    from_availability,
    to_availability,
    from_grade_tag_id,
    to_grade_tag_id
  ) values (
    v_mov_id,
    p_stock_id,
    p_quantity,
    v_stock.location_id,
    coalesce(p_to_location_id, v_stock.location_id),
    v_stock.availability,
    coalesce(p_to_availability, v_stock.availability),
    v_stock.grade_tag_id,
    coalesce(p_to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  );

  v_res := public.post_stock_movement(v_mov_id);

  return jsonb_build_object(
    'success', true,
    'movement_id', v_mov_id,
    'movement_no', v_mov_no
  );
end;
$$;

grant execute on function public.create_and_post_stock_movement(
  bigint, bigint, integer, bigint, public.stock_availability, bigint, public.stock_movement_type, text
) to authenticated;

commit;
