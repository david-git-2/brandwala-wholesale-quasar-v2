-- W9: customer/shop return_inbound adds qty at held @ returns + chosen grade.
-- Do not increment the original sellable row. Vendor shipment_return keeps decrement.

begin;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.default_returns_stock_location_id(p_tenant_id bigint)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant public.tenants%rowtype;
  v_loc bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant from public.tenants where id = p_tenant_id;
  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    return public.default_returns_stock_location_id(v_tenant.parent_id);
  end if;

  select sl.id into v_loc
  from public.stock_locations sl
  where sl.parent_tenant_id = p_tenant_id
    and sl.is_active = true
    and sl.kind = 'returns'::public.stock_location_kind
  order by sl.sort_order, sl.id
  limit 1;

  if v_loc is not null then
    return v_loc;
  end if;

  insert into public.stock_locations (
    parent_tenant_id, parent_location_id, code, name, kind,
    is_default, is_pickable, sort_order, is_active
  ) values (
    p_tenant_id, null, 'RETURNS', 'Returns', 'returns',
    false, false, 100, true
  )
  on conflict (parent_tenant_id, code) do update
    set kind = 'returns'::public.stock_location_kind,
        is_active = true,
        is_pickable = false
  returning id into v_loc;

  return v_loc;
end;
$$;

revoke all on function public.default_returns_stock_location_id(bigint) from public;
grant execute on function public.default_returns_stock_location_id(bigint) to authenticated;
grant execute on function public.default_returns_stock_location_id(bigint) to service_role;

create or replace function public.stock_grade_tag_id_for_slug(p_slug text)
returns bigint
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id bigint;
begin
  select tg.id into v_id
  from public.tags tg
  inner join public.tag_categories tc on tc.id = tg.category_id
  where tc.module_key = 'stock_grade'
    and tc.code = 'warehouse'
    and tg.slug = p_slug
    and tg.is_active = true
  order by tg.id
  limit 1;

  if v_id is null then
    return public.default_stock_grade_tag_id();
  end if;
  return v_id;
end;
$$;

revoke all on function public.stock_grade_tag_id_for_slug(text) from public;
grant execute on function public.stock_grade_tag_id_for_slug(text) to authenticated;
grant execute on function public.stock_grade_tag_id_for_slug(text) to service_role;

-- ---------------------------------------------------------------------------
-- post_stock_movement: return_inbound adds to target grain (except vendor shipment_return)
-- ---------------------------------------------------------------------------
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
     and not public.is_superadmin()
     and not exists (
       select 1
       from public.memberships m
       inner join public.tenants t on t.id = m.tenant_id
       where t.parent_id = v_mov.tenant_id
         and lower(trim(m.email)) = public.current_user_email()
         and m.is_active = true
     ) then
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

        if v_target_avail = v_stock.availability
           and v_target_loc = v_stock.location_id
           and v_target_grade = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id()) then
          update public.global_stocks
          set updated_at = now()
          where id = v_stock.id;
        else
          select * into v_target_stock
          from public.global_stocks
          where shipment_item_id = v_stock.shipment_item_id
            and availability = v_target_avail
            and location_id = v_target_loc
            and grade_tag_id = v_target_grade
          for update;

          if found then
            update public.global_stocks
            set quantity = quantity + v_move_qty, updated_at = now()
            where id = v_target_stock.id;

            if v_stock.quantity = v_move_qty then
              delete from public.global_stocks where id = v_stock.id;
              update public.stock_movement_lines
              set stock_id = v_target_stock.id
              where id = v_line.id;
            else
              update public.global_stocks
              set quantity = quantity - v_move_qty, updated_at = now()
              where id = v_stock.id;
            end if;
          else
            if v_stock.quantity = v_move_qty then
              update public.global_stocks
              set
                availability = v_target_avail,
                location_id = v_target_loc,
                grade_tag_id = v_target_grade,
                updated_at = now()
              where id = v_stock.id;
            else
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

      when 'return_inbound' then
        if v_mov.reference_type = 'shipment_return' then
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
          v_target_avail := coalesce(v_line.to_availability, 'held'::public.stock_availability);
          v_target_loc := coalesce(
            v_line.to_location_id,
            public.default_returns_stock_location_id(v_stock.parent_tenant_id)
          );
          v_target_grade := coalesce(
            v_line.to_grade_tag_id,
            public.default_stock_grade_tag_id()
          );

          select * into v_target_stock
          from public.global_stocks
          where shipment_item_id = v_stock.shipment_item_id
            and availability = v_target_avail
            and location_id = v_target_loc
            and grade_tag_id = v_target_grade
          for update;

          if found then
            update public.global_stocks
            set quantity = quantity + v_move_qty, updated_at = now()
            where id = v_target_stock.id;
          else
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
          end if;
        end if;

      when 'receive_rollback' then
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

-- ---------------------------------------------------------------------------
-- create_and_post_stock_movement: skip on-hand check for customer return_inbound
-- ---------------------------------------------------------------------------
drop function if exists public.create_and_post_stock_movement(
  bigint, bigint, integer, bigint, public.stock_availability, bigint, public.stock_movement_type, text
);

create function public.create_and_post_stock_movement(
  p_tenant_id bigint,
  p_stock_id bigint,
  p_quantity integer,
  p_to_location_id bigint default null,
  p_to_availability public.stock_availability default null,
  p_to_grade_tag_id bigint default null,
  p_movement_type public.stock_movement_type default 'grade_change',
  p_notes text default null,
  p_reference_type text default null,
  p_reference_id text default null
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
  v_is_customer_return boolean;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin()
     and not exists (
       select 1
       from public.memberships m
       inner join public.tenants t on t.id = m.tenant_id
       where t.parent_id = p_tenant_id
         and lower(trim(m.email)) = public.current_user_email()
         and m.is_active = true
     ) then
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

  v_is_customer_return := (
    p_movement_type = 'return_inbound'::public.stock_movement_type
    and coalesce(p_reference_type, '') is distinct from 'shipment_return'
  );

  if not v_is_customer_return and v_stock.quantity < p_quantity then
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
    coalesce(p_reference_type, 'global_stock'),
    coalesce(p_reference_id, p_stock_id::text),
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
    case
      when v_is_customer_return then coalesce(
        p_to_location_id,
        public.default_returns_stock_location_id(p_tenant_id)
      )
      else coalesce(p_to_location_id, v_stock.location_id)
    end,
    v_stock.availability,
    case
      when v_is_customer_return then coalesce(p_to_availability, 'held'::public.stock_availability)
      else coalesce(p_to_availability, v_stock.availability)
    end,
    v_stock.grade_tag_id,
    coalesce(p_to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  );

  perform public.post_stock_movement(v_mov_id);

  return jsonb_build_object(
    'success', true,
    'movement_id', v_mov_id,
    'movement_no', v_mov_no
  );
end;
$$;

grant execute on function public.create_and_post_stock_movement(
  bigint, bigint, integer, bigint, public.stock_availability, bigint, public.stock_movement_type, text, text, text
) to authenticated;
grant execute on function public.create_and_post_stock_movement(
  bigint, bigint, integer, bigint, public.stock_availability, bigint, public.stock_movement_type, text, text, text
) to service_role;

-- ---------------------------------------------------------------------------
-- add_stock_movement_line: optional grade columns
-- ---------------------------------------------------------------------------
drop function if exists public.add_stock_movement_line(
  bigint, bigint, numeric, bigint, bigint, public.stock_availability, public.stock_availability
);

create function public.add_stock_movement_line(
  p_movement_id bigint,
  p_stock_id bigint,
  p_quantity numeric,
  p_from_location_id bigint default null,
  p_to_location_id bigint default null,
  p_from_availability public.stock_availability default null,
  p_to_availability public.stock_availability default null,
  p_from_grade_tag_id bigint default null,
  p_to_grade_tag_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mov public.stock_movements%rowtype;
  v_line public.stock_movement_lines%rowtype;
begin
  select * into v_mov from public.stock_movements where id = p_movement_id for update;
  if not found then
    raise exception 'movement not found';
  end if;
  if v_mov.is_posted then
    raise exception 'movement already posted';
  end if;
  if not public.has_active_tenant_membership(v_mov.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be positive';
  end if;

  insert into public.stock_movement_lines (
    movement_id, stock_id, from_location_id, to_location_id,
    from_availability, to_availability, from_grade_tag_id, to_grade_tag_id, quantity
  ) values (
    p_movement_id, p_stock_id, p_from_location_id, p_to_location_id,
    p_from_availability, p_to_availability, p_from_grade_tag_id, p_to_grade_tag_id, p_quantity
  )
  returning * into v_line;

  return jsonb_build_object('line', to_jsonb(v_line));
end;
$$;

grant execute on function public.add_stock_movement_line(
  bigint, bigint, numeric, bigint, bigint, public.stock_availability, public.stock_availability, bigint, bigint
) to authenticated;

-- ---------------------------------------------------------------------------
-- add_global_return_item: post return_inbound instead of restocking sellable / dropped tables
-- ---------------------------------------------------------------------------
drop function if exists public.add_global_return_item(
  bigint, bigint, numeric, numeric, numeric, numeric, text
);

create function public.add_global_return_item(
  p_invoice_id bigint,
  p_invoice_item_id bigint,
  p_quantity numeric,
  p_return_face_amount numeric,
  p_return_accounting_amount numeric,
  p_return_charge_amount numeric default 0,
  p_note text default null,
  p_to_grade_tag_id bigint default null,
  p_to_availability public.stock_availability default 'held'
)
returns public.global_return_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items;
  v_row public.global_return_items;
  v_parent bigint;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'cannot return items on a non-posted invoice';
  end if;

  select * into v_item from public.global_invoice_items where id = p_invoice_item_id for update;
  if v_item.id is null then raise exception 'invoice item not found'; end if;
  if v_item.invoice_id <> p_invoice_id then
    raise exception 'invoice item does not belong to the selected invoice';
  end if;

  if v_item.return_quantity + p_quantity > v_item.quantity then
    raise exception 'return quantity exceeds available item quantity';
  end if;

  insert into public.global_return_items (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    invoice_item_id,
    global_stock_id,
    quantity,
    return_charge_amount,
    note
  )
  values (
    v_invoice.tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_invoice_item_id,
    v_item.global_stock_id,
    p_quantity,
    coalesce(p_return_charge_amount, 0.00),
    nullif(trim(p_note), '')
  )
  returning * into v_row;

  update public.global_invoice_items
  set return_quantity = return_quantity + p_quantity
  where id = p_invoice_item_id;

  v_parent := coalesce(v_invoice.parent_tenant_id, public.resolve_parent_tenant_id(v_invoice.tenant_id));

  if v_item.global_stock_id is not null then
    perform public.create_and_post_stock_movement(
      v_parent,
      v_item.global_stock_id,
      ceil(p_quantity)::integer,
      public.default_returns_stock_location_id(v_parent),
      coalesce(p_to_availability, 'held'::public.stock_availability),
      coalesce(p_to_grade_tag_id, public.default_stock_grade_tag_id()),
      'return_inbound'::public.stock_movement_type,
      coalesce(nullif(trim(p_note), ''), 'Invoice return'),
      'sales_invoice',
      p_invoice_id::text
    );
  end if;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

grant execute on function public.add_global_return_item(
  bigint, bigint, numeric, numeric, numeric, numeric, text, bigint, public.stock_availability
) to authenticated;

create or replace function public.add_global_return_item(
  p_invoice_id bigint,
  p_invoice_item_id bigint,
  p_quantity numeric,
  p_return_charge_amount numeric default 0,
  p_note text default null
)
returns public.global_return_items
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.add_global_return_item(
    p_invoice_id,
    p_invoice_item_id,
    p_quantity,
    0::numeric,
    0::numeric,
    p_return_charge_amount,
    p_note,
    null::bigint,
    'held'::public.stock_availability
  );
end;
$$;

grant execute on function public.add_global_return_item(bigint, bigint, numeric, numeric, text) to authenticated;


-- ---------------------------------------------------------------------------
-- finalize_dropship_return: restock via return_inbound movement
-- ---------------------------------------------------------------------------
create or replace function public.finalize_dropship_return(
  p_order_id bigint,
  p_items jsonb,
  p_actual_return_charge numeric default 0.00,
  p_deduct_from_middle_man boolean default true,
  p_override_reason text default null,
  p_return_ref text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_invoice record;
  v_parent_tenant_id bigint;
  v_ref text;
  v_item_elem jsonb;
  v_order_item_id bigint;
  v_returned_qty numeric;
  v_condition text;
  v_order_item record;
  v_invoice_item record;
  v_stock record;
  v_target_stock_type_id bigint;
  v_target_stock_id bigint;
  v_net_delivered numeric;
  v_currency text;
  v_billing_profile_id bigint;
  v_is_remitted boolean := false;
  v_existing_ref_order_id bigint;
  v_profit numeric(12,2) := 0;
  v_revenue numeric(12,2) := 0;
  v_billed numeric(12,2) := 0;
  v_remit_net numeric(12,2) := 0;
  v_courier_charge numeric(12,2) := 0;
  v_has_billed boolean := false;
  v_has_profit boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order #% is not a dropship order', p_order_id;
  end if;

  v_currency := 'BDT';
  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  v_ref := nullif(trim(coalesce(p_return_ref, '')), '');
  if v_ref is not null then
    select id into v_existing_ref_order_id
    from public.shop_orders
    where tenant_id = v_order.tenant_id
      and return_ref = v_ref;

    if v_existing_ref_order_id is not null then
      if v_existing_ref_order_id = p_order_id and v_order.return_sub_state = 'return_finalized' then
        return jsonb_build_object(
          'success', true,
          'idempotent', true,
          'message', 'Return already finalized with reference ' || v_ref,
          'order_id', p_order_id
        );
      else
        raise exception 'Duplicate return reference % already used for another return', v_ref;
      end if;
    end if;
  end if;

  if v_order.return_sub_state = 'return_finalized' then
    return jsonb_build_object(
      'success', true,
      'idempotent', true,
      'message', 'Order return is already finalized',
      'order_id', p_order_id
    );
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  end if;

  v_billing_profile_id := v_order.billing_profile_id;
  if v_billing_profile_id is null and v_order.customer_group_id is not null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = v_order.tenant_id
      and customer_group_id = v_order.customer_group_id
    order by is_default desc, created_at asc
    limit 1;
  end if;

  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item_elem in select * from jsonb_array_elements(p_items) loop
      v_order_item_id := (v_item_elem->>'order_item_id')::bigint;
      v_returned_qty := coalesce((v_item_elem->>'returned_qty')::numeric, 0);
      v_condition := coalesce(lower(trim(v_item_elem->>'condition')), 'perfect');

      if v_returned_qty <= 0 then
        continue;
      end if;

      select * into v_order_item
      from public.shop_order_items
      where id = v_order_item_id and order_id = p_order_id for update;

      if v_order_item.id is null then
        raise exception 'Order item #% not found on order #%', v_order_item_id, p_order_id;
      end if;

      v_net_delivered := coalesce(v_order_item.delivered_quantity, v_order_item.quantity) - coalesce(v_order_item.returned_quantity, 0);
      if v_returned_qty > v_net_delivered then
        raise exception 'Returned quantity % exceeds net delivered quantity % for item #%', v_returned_qty, v_net_delivered, v_order_item_id;
      end if;

      select * into v_stock from public.global_stocks where id = v_order_item.global_stock_id;

      if v_stock.id is not null then
        perform public.create_and_post_stock_movement(
          v_parent_tenant_id,
          v_stock.id,
          ceil(v_returned_qty)::integer,
          public.default_returns_stock_location_id(v_parent_tenant_id),
          case
            when v_condition = 'damaged' then 'unsellable'::public.stock_availability
            else 'held'::public.stock_availability
          end,
          public.stock_grade_tag_id_for_slug(
            case v_condition
              when 'open_box' then 'open_box'
              when 'damaged' then 'badly_damaged'
              else 'standard'
            end
          ),
          'return_inbound'::public.stock_movement_type,
          coalesce(p_override_reason, 'Dropship return'),
          'shop_order',
          p_order_id::text
        );
      end if;

      update public.shop_order_items
      set returned_quantity = coalesce(returned_quantity, 0) + v_returned_qty, updated_at = now()
      where id = v_order_item_id;

      if v_invoice.id is not null then
        select * into v_invoice_item
        from public.global_invoice_items
        where invoice_id = v_invoice.id
          and (global_stock_id = v_order_item.global_stock_id or product_id = v_order_item.product_id)
        limit 1;

        if v_invoice_item.id is not null then
          -- global_return_items schema: quantity + return_charge_amount only (no return_amount / face / accounting)
          insert into public.global_return_items (
            tenant_id, parent_tenant_id, invoice_id, invoice_item_id, global_stock_id,
            quantity, return_charge_amount, note
          )
          values (
            v_invoice.tenant_id, v_invoice.parent_tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
            v_returned_qty, 0.00, coalesce(p_override_reason, 'Dropship return finalization')
          );

          update public.global_invoice_items
          set return_quantity = coalesce(return_quantity, 0) + v_returned_qty, updated_at = now()
          where id = v_invoice_item.id;
        end if;
      end if;
    end loop;
  end if;

  if v_invoice.id is not null then
    perform public.recompute_global_invoice_totals(v_invoice.id);
  end if;

  select exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Resolve amounts from UWL (canonical after billing-profile unification)
  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_billed
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'customer'
    and entity_id = v_billing_profile_id
    and metadata->>'transaction_type' in ('invoice_billed', 'return_reversal', 'invoice_collection');

  -- Net billed outstanding before clawback: invert so positive = amount still billed
  v_billed := greatest(-v_billed, 0);
  v_has_billed := v_billed > 0 or exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_profit
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type in ('customer', 'middleman')
    and entity_id = v_billing_profile_id
    and metadata->>'section' = 'payout_earned';

  v_profit := greatest(v_profit, 0);
  v_has_profit := v_profit > 0;

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_revenue
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'tenant'
    and metadata->>'transaction_type' = 'revenue';

  if v_revenue <= 0 then
    v_revenue := coalesce(v_invoice.total_amount, 0.00);
  end if;

  select coalesce((metadata->>'net_remitted')::numeric, amount, 0)
  into v_remit_net
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce((metadata->>'courier_charge')::numeric, amount, 0)
  into v_courier_charge
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_courier_charge'
  limit 1;

  -- Leg 1: Reverse remaining invoice billed / collection net on customer
  if v_billing_profile_id is not null and v_has_billed and v_billed > 0
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'credit',
      p_amount => v_billed,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'receivable',
        'transaction_type', 'return_reversal',
        'label', 'Return Billed Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  elsif v_billing_profile_id is not null and v_has_billed and v_billed = 0
     and exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    -- Invoice fully collected already — reverse original billed amount then reverse collection net via billed lookup
    select coalesce(base_amount, 0) into v_billed
    from public.universal_wallet_ledger
    where source_type = 'shop_order' and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
    limit 1;

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_billing_profile_id,
        p_type => 'credit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_reversal',
          'label', 'Return Billed Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );

      if exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order' and source_id = p_order_id::text
          and metadata->>'transaction_type' = 'invoice_collection'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_billing_profile_id,
          p_type => 'debit',
          p_amount => v_billed,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'receivable',
            'transaction_type', 'return_collection_reversal',
            'label', 'Return Collection Reversal',
            'order_no', v_order.order_no,
            'return_ref', v_ref
          )
        );
      end if;
    end if;

  -- Historical remittance path: invoice_collection posted without invoice_billed.
  -- Unwind collection only (no synthetic return_reversal credit).
  elsif v_billing_profile_id is not null
     and exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_collection'
     )
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_collection_reversal'
     )
  then
    select coalesce(sum(base_amount), 0) into v_billed
    from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and entity_type = 'customer'
      and entity_id = v_billing_profile_id
      and type = 'credit'
      and metadata->>'transaction_type' = 'invoice_collection';

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_billing_profile_id,
        p_type => 'debit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_collection_reversal',
          'label', 'Return Collection Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Leg 2: Claw back profit on customer (unified billing-profile wallet)
  if v_billing_profile_id is not null and v_has_profit
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_profit_clawback'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'debit',
      p_amount => v_profit,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_profit_clawback',
        'label', 'Return Profit Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 3: Reverse tenant revenue
  if v_revenue > 0
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_revenue_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_order.tenant_id,
      p_type => 'debit',
      p_amount => v_revenue,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'revenue',
        'transaction_type', 'return_revenue_reversal',
        'label', 'Return Revenue Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 4: Reverse remittance cash + courier fee if remitted
  if v_is_remitted then
    if coalesce(v_remit_net, 0) > 0
       and not exists (
         select 1 from public.universal_wallet_ledger
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'remittance_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_order.tenant_id,
        p_type => 'debit',
        p_amount => v_remit_net,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'payment_received',
          'purpose', 'remittance_return_reversal',
          'transaction_type', 'remittance_return_reversal',
          'label', 'Remittance Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;

    if coalesce(v_courier_charge, 0) > 0
       and not exists (
         select 1 from public.universal_wallet_ledger
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'courier_charge_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_order.tenant_id,
        p_type => 'credit',
        p_amount => v_courier_charge,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'delivery_fee',
          'purpose', 'courier_charge_return_reversal',
          'transaction_type', 'courier_charge_return_reversal',
          'label', 'Courier Fee Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Return fee: UWL only (legacy middle_man_payout_ledger was dropped)
  if p_deduct_from_middle_man
     and p_actual_return_charge > 0
     and v_billing_profile_id is not null
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order'
         and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_fee'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'debit',
      p_amount => p_actual_return_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_fee',
        'label', 'Return Fee',
        'order_no', v_order.order_no,
        'return_ref', v_ref,
        'invoice_id', v_order.global_invoice_id
      )
    );
  end if;

  update public.shop_orders
  set
    status = 'returned'::public.shop_order_status,
    return_sub_state = 'return_finalized',
    returned_at = coalesce(returned_at, now()),
    return_charge_amount = p_actual_return_charge,
    deduct_return_charge_from_middle_man = p_deduct_from_middle_man,
    return_override_reason = coalesce(p_override_reason, return_override_reason),
    return_ref = v_ref,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', 'returned',
    'return_sub_state', 'return_finalized',
    'return_ref', v_ref
  );
end;
$$;

grant execute on function public.finalize_dropship_return(bigint, jsonb, numeric, boolean, text, text) to authenticated;
grant execute on function public.finalize_dropship_return(bigint, jsonb, numeric, boolean, text, text) to service_role;

commit;
