begin;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'stock_movement_type') then
    create type public.stock_movement_type as enum (
      'adjustment',
      'location_transfer',
      'availability_transfer',
      'receive_putaway',
      'return_inbound',
      'receive_rollback',
      'vendor_return'
    );
  end if;
end;
$$;

create table if not exists public.stock_movements (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  movement_no text not null,
  movement_type public.stock_movement_type not null,
  reference_type text,
  reference_id text,
  notes text,
  created_by_email text,
  is_posted boolean not null default false,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.stock_movement_lines (
  id bigserial primary key,
  movement_id bigint not null references public.stock_movements(id) on delete cascade,
  stock_id bigint references public.global_stocks(id) on delete set null,
  from_location_id bigint references public.stock_locations(id) on delete set null,
  to_location_id bigint references public.stock_locations(id) on delete set null,
  from_availability public.stock_availability,
  to_availability public.stock_availability,
  quantity numeric not null check (quantity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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
  v_new_qty numeric;
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

    case v_mov.movement_type
      when 'adjustment' then
        if v_line.to_availability is not null and v_line.from_availability is null then
          v_new_qty := v_stock.quantity + v_line.quantity;
        else
          v_new_qty := v_stock.quantity - v_line.quantity;
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
        update public.global_stocks
        set
          location_id = coalesce(v_line.to_location_id, location_id),
          availability = coalesce(v_line.to_availability, availability),
          updated_at = now()
        where id = v_line.stock_id;

      when 'return_inbound', 'receive_rollback' then
        v_new_qty := v_stock.quantity - v_line.quantity;
        if v_new_qty < 0 then
          raise exception 'return would make stock % negative', v_line.stock_id;
        end if;
        update public.global_stocks
        set quantity = v_new_qty, updated_at = now()
        where id = v_line.stock_id;

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

create or replace function public.create_stock_movement(
  p_tenant_id bigint,
  p_movement_type public.stock_movement_type,
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
  v_mov public.stock_movements%rowtype;
  v_no text;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_no := 'SM-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    p_tenant_id,
    v_no,
    p_movement_type,
    p_reference_type,
    p_reference_id,
    p_notes,
    public.current_user_email()
  )
  returning * into v_mov;

  return jsonb_build_object('movement', to_jsonb(v_mov));
end;
$$;

create or replace function public.add_stock_movement_line(
  p_movement_id bigint,
  p_stock_id bigint,
  p_quantity numeric,
  p_from_location_id bigint default null,
  p_to_location_id bigint default null,
  p_from_availability public.stock_availability default null,
  p_to_availability public.stock_availability default null
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
    from_availability, to_availability, quantity
  ) values (
    p_movement_id, p_stock_id, p_from_location_id, p_to_location_id,
    p_from_availability, p_to_availability, p_quantity
  )
  returning * into v_line;

  return jsonb_build_object('line', to_jsonb(v_line));
end;
$$;

create or replace function public.list_stock_movements(
  p_tenant_id bigint,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_data jsonb;
  v_total bigint;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select count(*) into v_total
  from public.stock_movements m
  where m.tenant_id = p_tenant_id;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.id desc), '[]'::jsonb)
  into v_data
  from (
    select * from public.stock_movements
    where tenant_id = p_tenant_id
    order by id desc
    limit p_limit offset p_offset
  ) m;

  return jsonb_build_object('data', v_data, 'total', v_total);
end;
$$;

grant execute on function public.post_stock_movement(bigint) to authenticated;
grant execute on function public.create_stock_movement(bigint, public.stock_movement_type, text, text, text) to authenticated;
grant execute on function public.add_stock_movement_line(bigint, bigint, numeric, bigint, bigint, public.stock_availability, public.stock_availability) to authenticated;
grant execute on function public.list_stock_movements(bigint, integer, integer) to authenticated;

commit;
