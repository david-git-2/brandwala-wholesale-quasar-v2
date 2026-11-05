-- Phase 4a: drop parent_tenant_id on shops + shop_orders.
-- Rewrite RPCs that still read those columns, then drop triggers/indexes/FKs/columns.

CREATE OR REPLACE FUNCTION "public"."apply_dropship_payout_settlement_fifo"("p_tenant_id" bigint, "p_profile_id" bigint, "p_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_remaining numeric := greatest(coalesce(p_amount, 0), 0);
  v_parent_tenant_id bigint;
  r record;
  v_hold numeric;
  v_paid numeric;
  v_outstanding numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  for r in
    select o.id
    from public.shop_orders o
    where o.profile_id = p_profile_id
      and o.shop_type_snapshot = 'dropship'
      and o.global_invoice_id is not null
      and coalesce(o.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
      and (
        o.tenant_id = p_tenant_id
        or o.tenant_id = v_parent_tenant_id
      )
    order by o.created_at asc, o.id asc
  loop
    exit when v_remaining <= 0;

    select coalesce(sum(u.amount), 0)
    into v_hold
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = r.id::text
      and u.entity_type in ('middleman', 'customer')
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit';

    select coalesce(sum(u.amount), 0)
    into v_paid
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = p_profile_id
      and u.type = 'debit'
      and coalesce(u.metadata->>'transaction_type', '') = 'profit_paid_out'
      and coalesce(u.metadata->>'shop_order_id', u.metadata->>'order_id', '') = r.id::text;

    v_outstanding := greatest(v_hold - v_paid, 0);

    if v_outstanding <= 0 then
      continue;
    end if;

    if v_remaining >= v_outstanding then
      update public.shop_orders
      set payout_settlement_status = 'paid',
          updated_at = now()
      where id = r.id;
      v_remaining := v_remaining - v_outstanding;
    else
      update public.shop_orders
      set payout_settlement_status = 'partial',
          updated_at = now()
      where id = r.id;
      v_remaining := 0;
    end if;
  end loop;
end;
$$;


ALTER FUNCTION "public"."apply_dropship_payout_settlement_fifo"("p_tenant_id" bigint, "p_profile_id" bigint, "p_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assert_staff_can_place_dropship_order_on_behalf"("p_shop_id" bigint, "p_customer_group_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop public.shops%rowtype;
BEGIN
  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = p_shop_id
    AND is_active = true
    AND deleted_at IS NULL;

  IF v_shop.id IS NULL THEN
    RAISE EXCEPTION 'shop not found or inactive';
  END IF;

  IF v_shop.shop_type <> 'dropship' THEN
    RAISE EXCEPTION 'shop is not dropship';
  END IF;

  IF NOT public.membership_has_module_action(v_shop.tenant_id, 'shop_order_mgmt', 'edit')
     AND NOT public.membership_has_module_action(
       public.resolve_parent_tenant_id(v_shop.tenant_id), 'shop_order_mgmt', 'edit'
     )
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.customer_groups cg
    WHERE cg.id = p_customer_group_id
      AND cg.is_active = true
      AND cg.deleted_at IS NULL
      AND coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(v_shop.tenant_id)
  ) THEN
    RAISE EXCEPTION 'customer group not found';
  END IF;
END;
$$;


ALTER FUNCTION "public"."assert_staff_can_place_dropship_order_on_behalf"("p_shop_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_shop_order"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_item record;
  v_allocation_id bigint;
  v_stock_id bigint;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'Access denied';
  end if;

  if v_order.status = 'fulfilled' then
    raise exception 'Cannot delete a fulfilled order';
  end if;

  if exists (
    select 1
    from public.shop_orders o
    where o.replacement_of_order_id = p_order_id
  ) then
    raise exception 'Cannot delete order: a replacement order references it';
  end if;

  perform public.purge_shop_order_financial_artifacts(p_order_id);

  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    v_allocation_id := v_item.global_stock_allocation_id;
    v_stock_id := v_item.global_stock_id;

    if v_allocation_id is not null then
      update public.global_stock_allocations
      set
        allocated_quantity = greatest(0, allocated_quantity - v_item.quantity),
        updated_at = now()
      where id = v_allocation_id;
    end if;

    if v_stock_id is not null then
      update public.global_stocks
      set
        allocated_quantity = greatest(0, allocated_quantity - v_item.quantity),
        updated_at = now()
      where id = v_stock_id;
    end if;

    delete from public.shop_stock_reservations where cart_item_id = v_item.id;
  end loop;

  delete from public.shop_order_item_stock_picks where order_id = p_order_id;
  delete from public.shop_order_items where order_id = p_order_id;
  delete from public.shop_orders where id = p_order_id;
end;
$$;


ALTER FUNCTION "public"."delete_shop_order"("p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finalize_dropship_return"("p_order_id" bigint, "p_items" "jsonb", "p_actual_return_charge" numeric DEFAULT 0.00, "p_deduct_from_middle_man" boolean DEFAULT true, "p_override_reason" "text" DEFAULT NULL::"text", "p_return_ref" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  v_profile_id bigint;
  v_is_remitted boolean := false;
  v_existing_ref_order_id bigint;
  v_profit numeric(12,2) := 0;
  v_revenue numeric(12,2) := 0;
  v_billed numeric(12,2) := 0;
  v_remit_net numeric(12,2) := 0;
  v_courier_charge numeric(12,2) := 0;
  v_has_billed boolean := false;
  v_has_profit boolean := false;
  v_grade_tag_id bigint;
  v_to_availability public.stock_availability;
  v_to_availability_raw text;
  v_use_explicit_targets boolean := false;
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
    where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
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
    select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  end if;

  v_profile_id := v_order.profile_id;
  if v_profile_id is null and v_order.customer_group_id is not null then
    select id into v_profile_id
    from public.profiles
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and customer_group_id = v_order.customer_group_id
    order by is_default desc, created_at asc
    limit 1;
  end if;

  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item_elem in select * from jsonb_array_elements(p_items) loop
      v_order_item_id := (v_item_elem->>'order_item_id')::bigint;
      v_returned_qty := coalesce((v_item_elem->>'returned_qty')::numeric, 0);
      v_condition := coalesce(lower(trim(v_item_elem->>'condition')), 'perfect');
      v_grade_tag_id := nullif((v_item_elem->>'grade_tag_id')::bigint, 0);
      v_to_availability_raw := nullif(lower(trim(v_item_elem->>'to_availability')), '');
      v_use_explicit_targets := v_grade_tag_id is not null or v_to_availability_raw is not null;

      if v_returned_qty <= 0 then
        continue;
      end if;

      select * into v_order_item
      from public.shop_order_items
      where id = v_order_item_id and order_id = p_order_id for update;

      if v_order_item.id is null then
        raise exception 'Order item #% not found on order #%', v_order_item_id, p_order_id;
      end if;

      v_net_delivered := coalesce(v_order_item.confirmed_quantity, v_order_item.quantity) - coalesce(v_order_item.returned_quantity, 0);
      if v_returned_qty > v_net_delivered then
        raise exception 'Returned quantity % exceeds net delivered quantity % for item #%', v_returned_qty, v_net_delivered, v_order_item_id;
      end if;

      if v_use_explicit_targets then
        v_grade_tag_id := coalesce(
          v_grade_tag_id,
          v_order_item.grade_tag_id,
          public.default_stock_grade_tag_id()
        );
        v_to_availability := coalesce(
          v_to_availability_raw::public.stock_availability,
          'held'::public.stock_availability
        );
      else
        v_to_availability := case
          when v_condition = 'damaged' then 'unsellable'::public.stock_availability
          else 'held'::public.stock_availability
        end;
        v_grade_tag_id := public.stock_grade_tag_id_for_slug(
          case v_condition
            when 'open_box' then 'open_box'
            when 'damaged' then 'badly_damaged'
            else 'standard'
          end
        );
      end if;

      select * into v_stock from public.global_stocks where id = v_order_item.global_stock_id;

      if v_stock.id is not null then
        perform public.create_and_post_stock_movement(
          v_parent_tenant_id,
          v_stock.id,
          ceil(v_returned_qty)::integer,
          public.default_returns_stock_location_id(v_parent_tenant_id),
          v_to_availability,
          v_grade_tag_id,
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
            v_invoice.parent_tenant_id, v_invoice.parent_tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
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
    select 1 from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Resolve amounts from UWL (canonical after billing-profile unification)
  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_billed
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'customer'
    and entity_id = v_profile_id
    and metadata->>'transaction_type' in ('invoice_billed', 'return_reversal', 'invoice_collection');

  -- Net billed outstanding before clawback: invert so positive = amount still billed
  v_billed := greatest(-v_billed, 0);
  v_has_billed := v_billed > 0 or exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_profit
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type in ('customer', 'middleman')
    and entity_id = v_profile_id
    and metadata->>'section' = 'payout_earned';

  v_profit := greatest(v_profit, 0);
  v_has_profit := v_profit > 0;

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_revenue
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'tenant'
    and metadata->>'transaction_type' = 'revenue';

  if v_revenue <= 0 then
    v_revenue := coalesce(v_invoice.total_amount, 0.00);
  end if;

  select coalesce((metadata->>'net_remitted')::numeric, amount, 0)
  into v_remit_net
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce((metadata->>'courier_charge')::numeric, amount, 0)
  into v_courier_charge
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_courier_charge'
  limit 1;

  -- Leg 1: Reverse remaining invoice billed / collection net on customer
  if v_profile_id is not null and v_has_billed and v_billed > 0
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
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
  elsif v_profile_id is not null and v_has_billed and v_billed = 0
     and exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    -- Invoice fully collected already — reverse original billed amount then reverse collection net via billed lookup
    select coalesce(base_amount, 0) into v_billed
    from public.cashbook_entries
    where source_type = 'shop_order' and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
    limit 1;

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_profile_id,
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
        select 1 from public.cashbook_entries
        where source_type = 'shop_order' and source_id = p_order_id::text
          and metadata->>'transaction_type' = 'invoice_collection'
      ) then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_profile_id,
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
  elsif v_profile_id is not null
     and exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_collection'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_collection_reversal'
     )
  then
    select coalesce(sum(base_amount), 0) into v_billed
    from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and entity_type = 'customer'
      and entity_id = v_profile_id
      and type = 'credit'
      and metadata->>'transaction_type' = 'invoice_collection';

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_profile_id,
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
  if v_profile_id is not null and v_has_profit
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_profit_clawback'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
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
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_revenue_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
         select 1 from public.cashbook_entries
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'remittance_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
         select 1 from public.cashbook_entries
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'courier_charge_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
     and v_profile_id is not null
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order'
         and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_fee'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
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


ALTER FUNCTION "public"."finalize_dropship_return"("p_order_id" bigint, "p_items" "jsonb", "p_actual_return_charge" numeric, "p_deduct_from_middle_man" boolean, "p_override_reason" "text", "p_return_ref" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dropship_finance_hub_data"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_summary jsonb;
  v_orders jsonb;
  v_merchants jsonb;
  v_parent_tenant_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  v_summary := public.get_cashbook_dashboard_summary(p_tenant_id);

  with finance_orders as (
    select
      o.id,
      o.order_no,
      o.recipient_name,
      o.status,
      o.cod_collect_amount,
      o.delivery_charge_amount,
      o.cod_charge_amount,
      o.driver_notes,
      o.courier_name,
      o.courier_remittance_ref,
      o.courier_bank_trx_id,
      o.profile_id,
      o.created_at,
      o.collection_source,
      o.payout_settlement_status,
      o.is_prepaid_snapshot,
      o.global_invoice_id,
      s.name as shop_name,
      pr.name as billing_profile_name,
      inv.collection_source as invoice_collection_source,
      inv.total_amount as invoice_total_amount,
      inv.paid_amount as invoice_paid_amount
    from public.shop_orders o
    left join public.shops s on s.id = o.shop_id
    left join public.profiles pr on pr.id = o.profile_id
    left join public.bills inv on inv.id = o.global_invoice_id
    where o.tenant_id = p_tenant_id
      and o.shop_type_snapshot = 'dropship'
      and o.status in ('delivered', 'payment_received')
  ),
  ledger_flags as (
    select
      l.source_id,
      max(case when coalesce(l.metadata->>'purpose', '') in ('delivered_costing', 'courier_cod_receivable') then 1 else 0 end) as has_delivered_costing,
      max(case when coalesce(l.metadata->>'purpose', '') in ('courier_remittance', 'tenant_remittance_received') then 1 else 0 end) as has_remittance
    from public.cashbook_entries l
    where l.parent_tenant_id = v_parent_tenant_id
      and l.source_type = 'shop_order'
      and l.source_id in (select fo.id::text from finance_orders fo)
    group by l.source_id
  ),
  order_rows as (
    select
      fo.id,
      fo.order_no as "orderNo",
      fo.recipient_name as "customerName",
      fo.shop_name as "shopName",
      fo.courier_name as "courierName",
      fo.status::text as status,
      case
        when fo.global_invoice_id is not null then coalesce(fo.invoice_total_amount, 0)
        else coalesce(fo.cod_collect_amount, 0)
      end as "totalAmount",
      coalesce(fo.cod_collect_amount, 0) as "codCollectAmount",
      coalesce(fo.delivery_charge_amount, 0) as "deliveryChargeAmount",
      coalesce(fo.cod_charge_amount, 0) as "codChargeAmount",
      fo.driver_notes as "courierNotes",
      fo.courier_remittance_ref as "courierRemittanceRef",
      fo.courier_bank_trx_id as "courierBankTrxId",
      fo.profile_id as "billingProfileId",
      fo.billing_profile_name as "billingProfileName",
      fo.created_at as "createdAt",
      case
        when fo.status::text = 'delivered'
          and coalesce(lf.has_remittance, 0) = 0
          and fo.courier_remittance_ref is null
          and coalesce(fo.cod_collect_amount, 0) > 0
          and coalesce(
            fo.collection_source,
            fo.invoice_collection_source,
            case
              when fo.is_prepaid_snapshot then 'profile'::public.collection_source_type
              else 'recipient'::public.collection_source_type
            end
          ) <> 'profile'::public.collection_source_type
          then 'courier_remittance'
        when coalesce(lf.has_delivered_costing, 0) = 0 and fo.status::text = 'delivered' then 'delivered_costing'
        when fo.status::text = 'delivered'
          or (coalesce(lf.has_remittance, 0) = 0 and fo.status::text <> 'payment_received')
          then 'courier_remittance'
        when fo.status::text = 'payment_received'
          and coalesce(fo.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
          then 'middleman_payout'
        else 'completed'
      end as "nextStep",
      coalesce(
        fo.collection_source,
        fo.invoice_collection_source,
        case
          when fo.is_prepaid_snapshot then 'profile'::public.collection_source_type
          else null::public.collection_source_type
        end
      )::text as "collectionSource",
      coalesce(fo.payout_settlement_status, 'unpaid') as "payoutSettlementStatus",
      case
        when fo.global_invoice_id is not null then greatest(coalesce(fo.invoice_total_amount, 0) - coalesce(fo.invoice_paid_amount, 0), 0)
        else null
      end as "invoiceOutstanding"
    from finance_orders fo
    left join ledger_flags lf on lf.source_id = fo.id::text
    order by fo.created_at desc
  )
  select coalesce(jsonb_agg(to_jsonb(order_rows)), '[]'::jsonb)
  into v_orders
  from order_rows;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', pr.id,
        'name', pr.name,
        'payableBalance', coalesce(wa.available_balance, 0)
      )
      order by pr.name
    ),
    '[]'::jsonb
  )
  into v_merchants
  from public.profiles pr
  left join public.cashbook_accounts wa
    on wa.parent_tenant_id = v_parent_tenant_id
   and wa.entity_type = 'customer'
   and wa.entity_id = pr.id
   and wa.currency_code = 'BDT'
  where pr.operating_tenant_id = p_tenant_id
     or pr.operating_tenant_id = v_parent_tenant_id;

  return jsonb_build_object(
    'kpis', jsonb_build_object(
      'courierOwedTotal', coalesce((v_summary->>'courier_cod_holding_total')::numeric, 0),
      'tenantCashTotal', coalesce((v_summary->>'tenant_cash_total')::numeric, 0),
      'middlemanPayableTotal', coalesce((v_summary->>'merchant_available_total')::numeric, 0)
    ),
    'orders', coalesce(v_orders, '[]'::jsonb),
    'merchants', coalesce(v_merchants, '[]'::jsonb)
  );
end;
$$;


ALTER FUNCTION "public"."get_dropship_finance_hub_data"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dropship_management_order"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_detail jsonb;
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_charge_lines jsonb;
  v_reseller_purchase_cost numeric(15,2);
  v_reseller_unit_purchase_cost numeric(15,2);
  v_order_item_quantity integer;
  v_company_procurement_cost numeric(15,2);
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_courier_name text;
  v_has_settlement boolean := false;
  v_invoice jsonb;
  v_is_returned boolean := false;
  v_gift_cost_merchant_total numeric(15,2) := 0;
  v_gift_cost_tenant_total numeric(15,2) := 0;
  v_parent_tenant_id bigint;
  v_courier_ap_bill_id bigint;
  v_courier_ap_due numeric(15,2) := 0;
  v_dropship_profit_credited numeric(15,2) := 0;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
    and tenant_id = p_tenant_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select coalesce(sum(ce.amount), 0)
  into v_dropship_profit_credited
  from public.cashbook_entries ce
  where ce.parent_tenant_id = v_parent_tenant_id
    and ce.source_type = 'shop_order'
    and ce.source_id = p_order_id::text
    and ce.type = 'credit'
    and coalesce(ce.metadata->>'transaction_type', '') = 'dropship_profit';

  v_courier_ap_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_parent_tenant_id);
  if v_courier_ap_bill_id is not null then
    v_courier_ap_due := greatest(
      coalesce((public.get_bill_net_balances(v_courier_ap_bill_id)->>'due_amount')::numeric, 0),
      0
    );
  end if;

  select
    coalesce(sum(soi.gift_cost_amount) filter (
      where coalesce(soi.is_gift, false)
        and soi.gift_source = 'stock'
        and soi.gift_cost_charged_to = 'reseller'
        and coalesce(soi.gift_cost_amount, 0) > 0
    ), 0),
    coalesce(sum(soi.gift_cost_amount) filter (
      where coalesce(soi.is_gift, false)
        and soi.gift_source = 'stock'
        and soi.gift_cost_charged_to = 'tenant'
        and coalesce(soi.gift_cost_amount, 0) > 0
    ), 0)
  into v_gift_cost_merchant_total, v_gift_cost_tenant_total
  from public.shop_order_items soi
  where soi.order_id = p_order_id;

  v_is_returned := v_order.status = 'returned'::public.shop_order_status;

  if v_order.status not in ('shipped', 'delivered', 'payment_received', 'reseller_paid', 'returned') then
    raise exception 'order status % is not eligible for dropship management desk', v_order.status;
  end if;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);

  select coalesce(cs.name, v_order.courier_name)
  into v_courier_name
  from public.courier_services cs
  where cs.id::text = v_order.courier_service_id::text;

  select
    rp.reseller_unit_purchase_cost,
    rp.reseller_purchase_cost,
    rp.order_item_quantity
  into v_reseller_unit_purchase_cost, v_reseller_purchase_cost, v_order_item_quantity
  from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

  select coalesce(
    sum(public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount) * soi.quantity),
    0
  )
  into v_company_procurement_cost
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id
    and o.tenant_id = p_tenant_id;

  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  v_charge_lines := public.build_dropship_management_charge_lines(
    v_order,
    case when v_has_settlement then v_settlement.id else null end
  );

  if v_has_settlement then
    v_collected_cod := v_settlement.collected_cod_amount;
  else
    v_collected_cod := coalesce(v_order.cod_collect_amount, v_calculated_cod);
  end if;

  if v_order.global_invoice_id is null then
    v_invoice := null;
  else
    select jsonb_build_object(
      'id', i.id,
      'invoice_no', i.invoice_no,
      'invoice_status', i.invoice_status,
      'payment_status', i.payment_status,
      'total_amount', i.total_amount,
      'due_amount', i.due_amount
    )
    into v_invoice
    from public.bills i
    where i.id = v_order.global_invoice_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'order', (v_detail->'order') || jsonb_build_object(
      'courier_name', v_courier_name,
      'payout_settlement_status', v_order.payout_settlement_status,
      'returned_at', v_order.returned_at,
      'return_charge_amount', coalesce(v_order.return_charge_amount, 0),
      'deduct_return_charge_from_middle_man', coalesce(v_order.deduct_return_charge_from_middle_man, false),
      'return_override_reason', v_order.return_override_reason,
      'courier_ap_bill_id', v_courier_ap_bill_id
    ),
    'items', coalesce(v_detail->'items', '[]'::jsonb),
    'fulfillment', v_detail->'fulfillment',
    'computed', (v_detail->'computed') || jsonb_build_object(
      'order_item_quantity', v_order_item_quantity
    ),
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', coalesce(v_settlement.status::text, 'draft'),
      'calculated_cod_amount', coalesce(v_calculated_cod, v_settlement.calculated_cod_amount),
      'collected_cod_amount', coalesce(v_settlement.collected_cod_amount, v_collected_cod),
      'reseller_unit_purchase_cost', v_reseller_unit_purchase_cost,
      'reseller_purchase_cost', v_reseller_purchase_cost,
      'company_procurement_cost', v_company_procurement_cost,
      'discount_company_pay', coalesce(v_settlement.discount_company_pay, 0),
      'return_reason_note', coalesce(v_settlement.return_reason_note, ''),
      'charge_lines', v_charge_lines,
      'total_cost', v_settlement.total_cost,
      'reseller_profit', v_settlement.reseller_profit,
      'company_profit', v_settlement.company_profit,
      'courier_cod_booked_at', v_settlement.courier_cod_booked_at,
      'remittance_at', v_settlement.remittance_at,
      'merchant_payout_at', v_settlement.merchant_payout_at,
      'gift_cost_merchant_total', v_gift_cost_merchant_total,
      'gift_cost_tenant_total', v_gift_cost_tenant_total,
      'dropship_profit_credited', v_dropship_profit_credited,
      'courier_ap_due', v_courier_ap_due
    ),
    'invoice', v_invoice,
    'step_state', jsonb_build_object(
      'can_mark_returned',
        not v_is_returned
        and v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_mark_delivered',
        not v_is_returned
        and v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_issue_invoice',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and v_order.global_invoice_id is null,
      'can_record_bank_transfer',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.remittance_at is null),
      'can_transfer_to_reseller',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.status is distinct from 'confirmed')
        and (not v_has_settlement or v_settlement.merchant_payout_at is null)
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_dropship_management_order"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dropship_order_detail_v2"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_customer_group_name text;
  v_sell_symbol text;
  v_buy_currency_id bigint;
  v_items jsonb;
  v_courier_ap_bill_id bigint;
  v_items_resell_total numeric := 0;
  v_recipient_charge_total numeric := 0;
  v_recipient_grand_total numeric := 0;
  v_all_lines_resolved boolean := false;
  v_total_delivered_qty numeric := 0;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select o.*
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  select s.name, gc.symbol, s.buy_currency_id
  into v_shop_name, v_sell_symbol, v_buy_currency_id
  from public.shops s
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where s.id = v_order.shop_id;

  select cg.name
  into v_customer_group_name
  from public.customer_groups cg
  where cg.id = v_order.customer_group_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'product_id', soi.product_id,
        'global_stock_id', soi.global_stock_id,
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'cost_price_amount', public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount),
        'cost_price_currency_id', coalesce(soi.cost_price_currency_id, v_buy_currency_id, soi.unit_list_price_currency_id),
        'unit_list_price_amount', public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount),
        'unit_list_price_currency_id', coalesce(soi.cost_price_currency_id, v_buy_currency_id, soi.unit_list_price_currency_id),
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_sell_price_currency_id', soi.unit_sell_price_currency_id,
        'unit_minimum_sell_price_amount', soi.unit_minimum_sell_price_amount,
        'unit_minimum_sell_price_currency_id', soi.unit_minimum_sell_price_currency_id,
        'customer_sell_price_amount',
          coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount),
        'customer_sell_price_currency_id',
          coalesce(soi.customer_sell_price_currency_id, soi.final_price_currency_id, soi.unit_sell_price_currency_id),
        'final_price_amount', soi.final_price_amount,
        'final_price_currency_id', soi.final_price_currency_id,
        'returned_quantity', coalesce(soi.returned_quantity, 0),
        'confirmed_quantity', soi.confirmed_quantity,
        'is_fulfillment_unavailable', coalesce(soi.is_fulfillment_unavailable, false),
        'unavailable_reason', soi.unavailable_reason,
        'fulfillment_resolved', (
          coalesce(soi.is_fulfillment_unavailable, false)
          or coalesce(soi.confirmed_quantity, 0) > 0
          or (coalesce(soi.is_gift, false) and soi.gift_source = 'customer_stock' and coalesce(soi.confirmed_quantity, 0) >= soi.quantity)
          or (coalesce(soi.is_gift, false) and soi.gift_source = 'stock')
        ),
        'is_gift', coalesce(soi.is_gift, false),
        'gift_source', soi.gift_source,
        'gift_cost_amount', coalesce(soi.gift_cost_amount, 0),
        'gift_cost_charged_to', soi.gift_cost_charged_to,
        'gift_added_by', soi.gift_added_by,
        'shop_customer_stock_id', soi.shop_customer_stock_id,
        'sku', p.product_code,
        'barcode', p.barcode,
        'brand', p.brand,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount, 0)
      * soi.quantity
    ),
    0
  )
  into v_items_resell_total
  from public.shop_order_items soi
  where soi.order_id = v_order.id
    and not coalesce(soi.is_gift, false);

  v_recipient_charge_total :=
    case when not coalesce(v_order.deduct_delivery_from_margin, false)
      then coalesce(v_order.delivery_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_cod_from_margin, false)
      then coalesce(v_order.cod_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_print_from_margin, false)
      then coalesce(v_order.print_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_packing_from_margin, false)
      then coalesce(v_order.packing_charge_amount, 0) else 0 end;

  v_recipient_grand_total :=
    v_items_resell_total + v_recipient_charge_total - coalesce(v_order.discount_amount, 0);

  select coalesce(bool_and(
    coalesce(soi.is_fulfillment_unavailable, false)
    or coalesce(soi.confirmed_quantity, 0) > 0
    or (
      coalesce(soi.is_gift, false)
      and soi.gift_source = 'customer_stock'
      and coalesce(soi.confirmed_quantity, 0) >= soi.quantity
    )
    or (
      coalesce(soi.is_gift, false)
      and soi.gift_source = 'stock'
    )
  ), true)
  into v_all_lines_resolved
  from public.shop_order_items soi
  where soi.order_id = v_order.id and soi.quantity > 0;

  select coalesce(sum(coalesce(soi.confirmed_quantity, 0)), 0)
  into v_total_delivered_qty
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select b.id
  into v_courier_ap_bill_id
  from public.bills b
  where b.source_id = p_order_id::text
    and b.invoice_type = 'ap'
    and b.invoice_status is distinct from 'voided'
    and (
      b.source_type = 'dropship_courier'
      or (b.source_type = 'shop_order' and b.source_key = 'courier')
    )
  order by case when b.source_type = 'dropship_courier' then 0 else 1 end, b.id
  limit 1;

  return jsonb_build_object(
    'success', true,
    'order', (
      jsonb_build_object(
        'id', v_order.id,
        'tenant_id', v_order.tenant_id,
        'shop_id', v_order.shop_id,
        'shop_name', v_shop_name,
        'customer_group_id', v_order.customer_group_id,
        'customer_group_name', v_customer_group_name,
        'cart_id', v_order.cart_id,
        'order_no', v_order.order_no,
        'name', v_order.name,
        'shop_type_snapshot', v_order.shop_type_snapshot,
        'order_mode_snapshot', v_order.order_mode_snapshot,
        'is_negotiable_snapshot', v_order.is_negotiable_snapshot,
        'status', v_order.status,
        'negotiate_round', v_order.negotiate_round,
        'placed_at', v_order.placed_at,
        'fulfilled_at', v_order.fulfilled_at,
        'global_invoice_id', v_order.global_invoice_id,
        'created_by_email', v_order.created_by_email,
        'created_at', v_order.created_at,
        'updated_at', v_order.updated_at,
        'shop_sell_currency_symbol', v_sell_symbol,
        'recipient_name', v_order.recipient_name,
        'recipient_phone', v_order.recipient_phone,
        'recipient_phone_secondary', v_order.recipient_phone_secondary,
        'shipping_address', v_order.shipping_address,
        'shipping_thana', v_order.shipping_thana,
        'shipping_district', v_order.shipping_district,
        'shipping_post_code', null,
        'recipient_profile_id', v_order.recipient_profile_id,
        'profile_id', v_order.profile_id,
        'delivery_instructions', v_order.delivery_instructions,
        'is_prepaid_snapshot', v_order.is_prepaid_snapshot,
        'cod_charge_amount', v_order.cod_charge_amount,
        'delivery_charge_amount', v_order.delivery_charge_amount,
        'print_charge_amount', v_order.print_charge_amount,
        'packing_charge_amount', v_order.packing_charge_amount,
        'discount_amount', v_order.discount_amount,
        'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
        'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
        'deduct_print_from_margin', v_order.deduct_print_from_margin,
        'deduct_packing_from_margin', v_order.deduct_packing_from_margin
      ) || jsonb_build_object(
        'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total),
        'item_count', jsonb_array_length(v_items),
        'delivery_zone', v_order.delivery_zone,
        'courier_name', v_order.courier_name,
        'courier_awb_number', v_order.courier_awb_number,
        'tracking_url', v_order.tracking_url,
        'courier_ap_bill_id', v_courier_ap_bill_id,
        'recipient_call_attempt_count', coalesce(v_order.recipient_call_attempt_count, 0),
        'recipient_verified_at', v_order.recipient_verified_at,
        'cancel_reason', v_order.cancel_reason,
        'auto_gifts_applied_at', v_order.auto_gifts_applied_at,
        'auto_gifts_apply_result', v_order.auto_gifts_apply_result
      )
    ),
    'items', v_items,
    'summary', jsonb_build_object(
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'cod_charge_amount', v_order.cod_charge_amount,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'print_charge_amount', v_order.print_charge_amount,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'packing_charge_amount', v_order.packing_charge_amount,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'discount_amount', v_order.discount_amount,
      'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total)
    ),
    'computed', jsonb_build_object(
      'items_resell_total', v_items_resell_total,
      'recipient_charge_total', v_recipient_charge_total,
      'recipient_grand_total', v_recipient_grand_total,
      'all_lines_resolved', v_all_lines_resolved,
      'total_delivered_qty', v_total_delivered_qty,
      'delivery_zone_label',
        case v_order.delivery_zone
          when 'inside_dhaka' then 'Inside Dhaka'
          when 'outside_dhaka' then 'Outside Dhaka'
          else null
        end
    ),
    'fulfillment', jsonb_build_object(
      'pickup', jsonb_build_object(
        'merchant_id', null,
        'sender_name', coalesce(v_order.sender_name, v_order.default_sender_name),
        'pickup_phone', coalesce(v_order.pickup_phone, v_order.default_pickup_phone),
        'pickup_address', coalesce(v_order.pickup_address, v_order.default_pickup_address)
      ),
      'courier', jsonb_build_object(
        'courier_service_id', v_order.courier_service_id,
        'courier_awb_number', v_order.courier_awb_number,
        'tracking_url', v_order.tracking_url,
        'allow_open_box', coalesce(v_order.allow_open_box, false),
        'cod_charge', v_order.cod_charge_amount
      )
    ),
    'permissions', jsonb_build_object(
      'can_show_invoice_paper', v_order.status = 'confirmed',
      'can_start_processing', false,
      'can_confirm_recipient_call', v_order.status = 'confirmed' and v_order.recipient_verified_at is null,
      'can_mark_ready_for_pickup', v_order.status = 'processing',
      'can_mark_shipped', v_order.status = 'ready_for_pickup',
      'can_print_customer_invoice', v_order.status in ('ready_for_pickup', 'shipped', 'delivered')
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_dropship_order_detail_v2"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_customer_access_page"("p_shop_id" bigint, "p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop_tenant_id bigint;
  v_books_id bigint;
  v_groups jsonb := '[]'::jsonb;
  v_access jsonb := '[]'::jsonb;
BEGIN
  IF p_shop_id IS NULL OR p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop_id and tenant_id are required';
  END IF;

  SELECT s.tenant_id
  INTO v_shop_tenant_id
  FROM public.shops s
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL
    AND s.tenant_id = p_tenant_id;

  IF v_shop_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.user_can_access_tenant_fetch(v_shop_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(v_shop_tenant_id);

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', cg.id,
        'name', cg.name,
        'is_active', cg.is_active,
        'accent_color', cg.accent_color
      )
      ORDER BY cg.name
    ),
    '[]'::jsonb
  )
  INTO v_groups
  FROM public.customer_groups cg
  WHERE cg.parent_tenant_id = v_books_id
    AND cg.deleted_at IS NULL;

  SELECT coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb)
  INTO v_access
  FROM public.shop_customer_group_access a
  WHERE a.shop_id = p_shop_id;

  RETURN jsonb_build_object(
    'customer_groups', v_groups,
    'access_overrides', v_access
  );
END;
$$;


ALTER FUNCTION "public"."get_shop_customer_access_page"("p_shop_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_order_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_code text;
  v_sell_symbol text;
  v_buy_code text;
  v_buy_symbol text;
  v_customer_group_name text;
  v_item_count bigint;
  v_total_amount numeric;
  v_collection_source public.collection_source_type;
  v_items jsonb;
  v_invoices jsonb;
  v_shipments jsonb;
  v_order_json jsonb;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  select
    s.name,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.code,
    sell_gc.symbol,
    buy_gc.code,
    buy_gc.symbol
  into
    v_shop_name,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_code,
    v_sell_symbol,
    v_buy_code,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  select cg.name
  into v_customer_group_name
  from public.customer_groups cg
  where cg.id = v_order.customer_group_id;

  v_collection_source := v_order.collection_source;
  if v_collection_source is null and v_order.global_invoice_id is not null then
    select inv.collection_source
    into v_collection_source
    from public.bills inv
    where inv.id = v_order.global_invoice_id;
  end if;
  if v_collection_source is null and v_order.is_prepaid_snapshot then
    v_collection_source := 'profile'::public.collection_source_type;
  end if;

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.staff_offer_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        soi.unit_list_price_amount
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  if v_order.global_invoice_id is not null then
    v_invoices := jsonb_build_array(jsonb_build_object('id', v_order.global_invoice_id));
  else
    v_invoices := '[]'::jsonb;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('id', x.shipment_id) order by x.shipment_id),
    '[]'::jsonb
  )
  into v_shipments
  from (
    select distinct gship.id as shipment_id
    from public.shop_order_items soi
    join public.global_stocks gs on gs.id = soi.global_stock_id
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    where soi.order_id = v_order.id
  ) x;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at,
        'product', jsonb_build_object(
          'id', soi.product_id,
          'sku', p.product_code,
          'brand', p.brand,
          'barcode', p.barcode,
          'weight_gm', p.product_weight,
          'package_weight_gm', p.package_weight,
          'minimum_order_quantity', coalesce(p.minimum_order_quantity, 1)
        ),
        'pricing', jsonb_build_object(
          'cost', jsonb_build_object(
            'amount', coalesce(soi.cost_price_amount, soi.unit_list_price_amount, p.reference_cost_amount),
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = coalesce(
                soi.cost_price_currency_id,
                soi.unit_list_price_currency_id
              )
              limit 1
            )
          ),
          'list', jsonb_build_object(
            'amount', soi.unit_list_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_list_price_currency_id
              limit 1
            )
          ),
          'sell', jsonb_build_object(
            'amount', soi.unit_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_sell_price_currency_id
              limit 1
            )
          ),
          'minimum_sell', jsonb_build_object(
            'amount', soi.unit_minimum_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_minimum_sell_price_currency_id
              limit 1
            )
          )
        ),
        'negotiation', jsonb_build_object(
          'status', soi.negotiation_status,
          'customer_decision', soi.customer_decision_status,
          'staff_offer', case
            when soi.staff_offer_amount is not null then jsonb_build_object(
              'amount', soi.staff_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.staff_offer_currency_id
                limit 1
              ),
              'at', soi.staff_offer_at,
              'is_manual', soi.is_first_offer_manual
            )
            else null
          end,
          'customer_offer', case
            when soi.customer_offer_amount is not null then jsonb_build_object(
              'amount', soi.customer_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.customer_offer_currency_id
                limit 1
              ),
              'at', soi.customer_counter_at
            )
            else null
          end,
          'final_offer', case
            when soi.final_price_amount is not null then jsonb_build_object(
              'amount', soi.final_price_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.final_price_currency_id
                limit 1
              ),
              'at', soi.final_offer_at,
              'is_manual', soi.is_final_offer_manual
            )
            else null
          end,
          'weight_kg', soi.weight_kg,
          'confirmed_quantity', soi.confirmed_quantity
        ),
        'fulfillment', jsonb_build_object(
          'returned', soi.returned_quantity,
          'procurement_pulled', soi.procurement_pulled
        ),
        'stock', case
          when soi.global_stock_id is not null then jsonb_build_object(
            'global_stock_id', soi.global_stock_id,
            'global_stock_allocation_id', soi.global_stock_allocation_id,
            'shipment_item_id', gsi.id,
            'shipment_id', gship.id
          )
          else null
        end
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  left join public.global_stocks gs on gs.id = soi.global_stock_id
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  where soi.order_id = v_order.id;

  v_order_json := jsonb_build_object(
    'id', v_order.id,
    'tenant_id', v_order.tenant_id,
    'order_no', v_order.order_no,
    'name', v_order.name,
    'cart_id', v_order.cart_id,
    'created_by_email', v_order.created_by_email,
    'created_at', v_order.created_at,
    'updated_at', v_order.updated_at,
    'placed_at', v_order.placed_at,
    'fulfilled_at', v_order.fulfilled_at,
    'global_invoice_id', v_order.global_invoice_id,
    'collection_source', v_collection_source,
    'shop', jsonb_build_object(
      'id', v_order.shop_id,
      'name', v_shop_name,
      'type', v_order.shop_type_snapshot,
      'order_mode', v_order.order_mode_snapshot,
      'is_negotiable', v_order.is_negotiable_snapshot,
      'sell_currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end,
      'buy_currency', case
        when v_buy_currency_id is not null then jsonb_build_object(
          'id', v_buy_currency_id,
          'code', v_buy_code,
          'symbol', v_buy_symbol
        )
        else null
      end
    ),
    'customer', jsonb_build_object(
      'group_id', v_order.customer_group_id,
      'group_name', v_customer_group_name,
      'profile_id', v_order.profile_id
    ),
    'status', jsonb_build_object(
      'value', v_order.status,
      'negotiate_round', v_order.negotiate_round
    ),
    'rates', jsonb_build_object(
      'cargo', v_order.cargo_rate,
      'conversion', v_order.conversion_rate,
      'profit', v_order.profit_rate,
      'first_offer', v_order.first_offer_rate,
      'final_offer', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg
    ),
    'recipient', jsonb_build_object(
      'name', v_order.recipient_name,
      'phone', v_order.recipient_phone,
      'phone_secondary', v_order.recipient_phone_secondary,
      'address', v_order.shipping_address,
      'district', v_order.shipping_district,
      'thana', v_order.shipping_thana,
      'profile_id', v_order.recipient_profile_id,
      'delivery_instructions', v_order.delivery_instructions,
      'is_prepaid', v_order.is_prepaid_snapshot
    ),
    'charges', jsonb_build_object(
      'cod', v_order.cod_charge_amount,
      'delivery', v_order.delivery_charge_amount,
      'print', v_order.print_charge_amount,
      'packing', v_order.packing_charge_amount,
      'discount', v_order.discount_amount,
      'deduct_from_margin', jsonb_build_object(
        'charges', v_order.deduct_charges_from_margin,
        'cod', v_order.deduct_cod_from_margin,
        'delivery', v_order.deduct_delivery_from_margin,
        'print', v_order.deduct_print_from_margin,
        'packing', v_order.deduct_packing_from_margin
      )
    ),
    'totals', jsonb_build_object(
      'item_count', v_item_count,
      'amount', v_total_amount,
      'currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end
    ),
    'courier', jsonb_build_object(
      'service_id', v_order.courier_service_id,
      'name', v_order.courier_name,
      'awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'order_ref', v_order.courier_order_ref,
      'tracking_number', v_order.courier_tracking_number,
      'consignment_id', v_order.courier_consignment_id,
      'cost_amount', v_order.courier_cost_amount,
      'delivered_at', v_order.delivered_at,
      'returned_at', v_order.returned_at
    ),
    'pickup', jsonb_build_object(
      'sender_name', v_order.sender_name,
      'phone', v_order.pickup_phone,
      'address', v_order.pickup_address,
      'default_sender_name', v_order.default_sender_name,
      'default_phone', v_order.default_pickup_phone,
      'default_address', v_order.default_pickup_address
    ),
    'payout', jsonb_build_object(
      'account_type', v_order.payout_account_type,
      'account_info', v_order.payout_account_info,
      'default_account_type', v_order.default_payout_account_type,
      'default_account_info', v_order.default_payout_account_info,
      'settlement_status', v_order.payout_settlement_status,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_remittance_ref', v_order.courier_remittance_ref,
      'courier_bank_trx_id', v_order.courier_bank_trx_id
    ),
    'parcel', jsonb_build_object(
      'weight_band', v_order.package_weight_band,
      'item_category', v_order.item_category,
      'description', v_order.parcel_description,
      'delivery_zone', v_order.delivery_zone,
      'allow_open_box', v_order.allow_open_box,
      'driver_notes', v_order.driver_notes,
      'delivery_instruction_notes', v_order.delivery_instruction_notes
    ),
    'return_info', jsonb_build_object(
      'sub_state', v_order.return_sub_state,
      'override_reason', v_order.return_override_reason,
      'ref', v_order.return_ref,
      'charge_amount', v_order.return_charge_amount,
      'deduct_charge_from_middle_man', v_order.deduct_return_charge_from_middle_man,
      'replacement_of_order_id', v_order.replacement_of_order_id,
      'middle_man_reference', v_order.middle_man_reference
    ),
    'links', jsonb_build_object(
      'invoices', v_invoices,
      'shipments', v_shipments
    )
  );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items
  );
end;
$$;


ALTER FUNCTION "public"."get_shop_order_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_setup_bundle"("p_shop_id" bigint, "p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop jsonb;
  v_shop_tenant_id bigint;
  v_scope_tenant_id bigint;
  v_categories jsonb := '[]'::jsonb;
  v_vendors jsonb := '[]'::jsonb;
  v_brands_by_vendor jsonb := '{}'::jsonb;
BEGIN
  IF p_shop_id IS NULL OR p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop_id and tenant_id are required';
  END IF;

  SELECT
    to_jsonb(s) || jsonb_build_object('tenant_slug', coalesce(t.slug, '')),
    s.tenant_id
  INTO v_shop, v_shop_tenant_id
  FROM public.shops s
  LEFT JOIN public.tenants t ON t.id = s.tenant_id
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL
    AND s.tenant_id = p_tenant_id;

  IF v_shop IS NULL OR v_shop_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.user_can_access_tenant_fetch(v_shop_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_scope_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);

  SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.name), '[]'::jsonb)
  INTO v_categories
  FROM public.shop_categories c
  WHERE c.tenant_id = v_shop_tenant_id;

  SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY v.id), '[]'::jsonb)
  INTO v_vendors
  FROM public.list_vendors_for_tenant(v_shop_tenant_id) v;

  SELECT coalesce(
    jsonb_object_agg(upper(trim(x.vendor_code)), x.brand_names),
    '{}'::jsonb
  )
  INTO v_brands_by_vendor
  FROM (
    SELECT
      pb.vendor_code,
      jsonb_agg(trim(pb.name) ORDER BY trim(pb.name))
        FILTER (WHERE pb.name IS NOT NULL AND trim(pb.name) <> '') AS brand_names
    FROM public.product_brands pb
    WHERE pb.parent_tenant_id = v_scope_tenant_id
      AND pb.vendor_code IS NOT NULL
      AND trim(pb.vendor_code) <> ''
    GROUP BY pb.vendor_code
  ) x
  WHERE x.brand_names IS NOT NULL;

  RETURN jsonb_build_object(
    'shop', v_shop,
    'categories', v_categories,
    'vendors', v_vendors,
    'brands_by_vendor', v_brands_by_vendor
  );
END;
$$;


ALTER FUNCTION "public"."get_shop_setup_bundle"("p_shop_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."issue_dropship_tenant_b2b_invoice"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_build jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_created boolean := false;
  v_courier_cod_booked boolean := false;
  v_orphan_invoice_id bigint;
  v_parent_tenant_id bigint;
  v_merchant_profile_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    return jsonb_build_object('success', false, 'error', 'tenant mismatch');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in (
    'ready_for_pickup'::public.shop_order_status,
    'shipped'::public.shop_order_status,
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'tenant B2B invoice requires ready_for_pickup, shipped, or delivered (current: %s)',
        v_order.status
      )
    );
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  v_merchant_profile_id := null;
  if v_order.profile_id is not null then
    select p.id into v_merchant_profile_id
    from public.profiles p
    where p.id = v_order.profile_id
      and p.profile_type = 'customer'::public.profile_party_type
      and p.deleted_at is null;
  end if;

  if v_merchant_profile_id is null then
    v_merchant_profile_id := public.resolve_customer_profile_for_group(
      v_order.tenant_id,
      v_order.customer_group_id
    );
  end if;

  if v_merchant_profile_id is null then
    return jsonb_build_object(
      'success', false,
      'error', 'dropshipper customer profile is required; do not bill the tenant'
    );
  end if;

  if v_order.profile_id is distinct from v_merchant_profile_id then
    update public.shop_orders
    set profile_id = v_merchant_profile_id, updated_at = now()
    where id = p_order_id;
    v_order.profile_id := v_merchant_profile_id;
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.id is not null
       and v_invoice.invoice_status = 'draft'::public.global_invoice_status then
      if v_invoice.profile_id is distinct from v_merchant_profile_id then
        update public.bills
        set profile_id = v_merchant_profile_id, updated_at = now()
        where id = v_invoice.id;
        perform public.stamp_bill_kernel_fields(v_invoice.id);
      end if;
      perform public.post_sales_invoice(v_invoice.id);
      perform public.sync_sales_invoice_charges_from_header(v_invoice.id);
      select * into v_invoice from public.bills where id = v_invoice.id;
    end if;
    return jsonb_build_object(
      'success', true,
      'already_issued', true,
      'created', false,
      'order_id', p_order_id,
      'invoice', jsonb_build_object(
        'id', v_invoice.id,
        'invoice_no', v_invoice.invoice_no,
        'invoice_type', v_invoice.invoice_type,
        'invoice_status', v_invoice.invoice_status,
        'payment_status', v_invoice.payment_status,
        'subtotal_amount', v_invoice.subtotal_amount,
        'print_charge', v_invoice.print_charge,
        'wrapping_charge', v_invoice.wrapping_charge,
        'discount_amount', v_invoice.discount_amount,
        'total_amount', v_invoice.total_amount,
        'paid_amount', v_invoice.paid_amount,
        'due_amount', v_invoice.due_amount,
        'profile_id', v_invoice.profile_id,
        'collection_source', v_invoice.collection_source
      )
    );
  end if;

  v_build := public.build_dropship_tenant_b2b_invoice_payload(p_order_id);
  if coalesce(v_build->>'success', 'false') <> 'true' then
    return v_build;
  end if;

  v_payload := v_build->'payload';
  v_payload := v_payload || jsonb_build_object(
    'issue', true,
    'shop_order_id', p_order_id
  );

  select i.id into v_orphan_invoice_id
  from public.bills i
  where i.invoice_no = v_payload->'invoice'->>'invoice_no'
    and i.invoice_type = 'dropship'::public.global_invoice_type
    and (
      i.issued_by_tenant_id = v_order.tenant_id
      or i.parent_tenant_id = v_parent_tenant_id
    )
    and not exists (
      select 1 from public.shop_orders o2 where o2.global_invoice_id = i.id
    )
  limit 1;

  if v_orphan_invoice_id is not null then
    delete from public.global_return_items where invoice_id = v_orphan_invoice_id;
    delete from public.bill_lines where invoice_id = v_orphan_invoice_id;
    delete from public.bills where id = v_orphan_invoice_id;
  end if;

  v_result := public.create_sales_invoice_from_payload(v_order.tenant_id, v_payload);
  v_created := true;

  if coalesce(v_result->>'success', 'false') <> 'true' then
    return coalesce(
      v_result,
      jsonb_build_object('success', false, 'error', 'failed to upsert tenant B2B invoice')
    );
  end if;

  update public.shop_orders
  set
    global_invoice_id = (v_result->>'invoice_id')::bigint,
    updated_at = now()
  where id = p_order_id
    and global_invoice_id is null;

  select * into v_order from public.shop_orders where id = p_order_id;
  select * into v_invoice from public.bills where id = v_order.global_invoice_id;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice was not created');
  end if;

  perform public.sync_sales_invoice_charges_from_header(v_invoice.id);

  update public.bills
  set
    shop_order_id = p_order_id,
    channel_meta = coalesce(v_payload->'invoice'->'channel_meta', '{}'::jsonb),
    updated_at = now()
  where id = v_invoice.id;

  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  v_courier_cod_booked := exists (
    select 1 from public.cashbook_entries
    where tenant_id = v_order.tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'delivered_costing'
  );

  return jsonb_build_object(
    'success', true,
    'created', v_created,
    'already_issued', false,
    'order_id', p_order_id,
    'invoice', jsonb_build_object(
      'id', v_invoice.id,
      'invoice_no', v_invoice.invoice_no,
      'invoice_type', v_invoice.invoice_type,
      'invoice_status', v_invoice.invoice_status,
      'payment_status', v_invoice.payment_status,
      'subtotal_amount', v_invoice.subtotal_amount,
      'print_charge', v_invoice.print_charge,
      'wrapping_charge', v_invoice.wrapping_charge,
      'discount_amount', v_invoice.discount_amount,
      'total_amount', v_invoice.total_amount,
      'paid_amount', v_invoice.paid_amount,
      'due_amount', v_invoice.due_amount,
      'profile_id', v_invoice.profile_id,
      'collection_source', v_invoice.collection_source
    ),
    'wallet', jsonb_build_object(
      'courier_cod_booked', v_courier_cod_booked,
      'source_type', 'shop_order',
      'source_id', p_order_id::text
    )
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;


ALTER FUNCTION "public"."issue_dropship_tenant_b2b_invoice"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_status" "text" DEFAULT NULL::"text", "p_search" "text" DEFAULT NULL::"text", "p_statuses" "text"[] DEFAULT NULL::"text"[]) RETURNS TABLE("id" bigint, "order_no" "text", "status" "public"."shop_order_status", "created_at" timestamp with time zone, "customer_group_name" "text", "created_by_email" "text", "recipient_name" "text", "recipient_phone" "text", "courier_name" "text", "courier_awb_number" "text", "cod_collect_amount" numeric, "total_amount" numeric, "global_invoice_id" bigint, "courier_remittance_ref" "text", "collection_source" "public"."collection_source_type", "payout_settlement_status" "text", "tenant_id" bigint, "tenant_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    o.id,
    o.order_no,
    o.status,
    o.created_at,
    cg.name as customer_group_name,
    o.created_by_email,
    o.recipient_name,
    o.recipient_phone,
    coalesce(cs.name, o.courier_name) as courier_name,
    o.courier_awb_number,
    o.cod_collect_amount,
    coalesce(
      (
        select sum(
          coalesce(
            final_price_amount,
            staff_offer_amount,
            customer_offer_amount,
            unit_sell_price_amount,
            unit_list_price_amount
          ) * quantity
        )
        from public.shop_order_items
        where order_id = o.id
      ),
      0
    )::numeric as total_amount,
    o.global_invoice_id,
    o.courier_remittance_ref,
    o.collection_source,
    o.payout_settlement_status,
    o.tenant_id,
    coalesce(t.name, '')::text as tenant_name
  from public.shop_orders o
  join public.customer_groups cg on cg.id = o.customer_group_id
  left join public.courier_services cs on cs.id::text = o.courier_service_id::text
  left join public.tenants t on t.id = o.tenant_id
  where o.tenant_id = p_tenant_id
    and o.shop_type_snapshot = 'dropship'
    and (
      case
        when p_statuses is not null and cardinality(p_statuses) > 0 then
          o.status::text = any(p_statuses)
        when p_status is not null then
          o.status::text = p_status
        else
          o.status::text in (
            'submitted',
            'confirmed',
            'placed',
            'processing',
            'ready_for_pickup',
            'shipped',
            'delivered',
            'returned',
            'payment_received'
          )
      end
    )
    and (
      p_search is null
      or o.order_no ilike ('%' || p_search || '%')
      or o.recipient_name ilike ('%' || p_search || '%')
      or o.recipient_phone ilike ('%' || p_search || '%')
      or o.courier_awb_number ilike ('%' || p_search || '%')
      or o.courier_name ilike ('%' || p_search || '%')
      or cs.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
      or o.created_by_email ilike ('%' || p_search || '%')
      or t.name ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;


ALTER FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status" "text", "p_search" "text", "p_statuses" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_shop_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "shop_id" bigint, "shop_name" "text", "customer_group_id" bigint, "customer_group_name" "text", "order_no" "text", "name" "text", "shop_type_snapshot" "public"."shop_type_enum", "is_negotiable_snapshot" boolean, "status" "public"."shop_order_status", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "item_count" bigint, "tenant_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    o.id,
    o.tenant_id,
    o.shop_id,
    s.name as shop_name,
    o.customer_group_id,
    cg.name as customer_group_name,
    o.order_no,
    o.name,
    o.shop_type_snapshot,
    o.is_negotiable_snapshot,
    o.status,
    o.created_at,
    o.updated_at,
    (select count(*)::bigint from public.shop_order_items where order_id = o.id) as item_count,
    coalesce(t.name, '')::text as tenant_name
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  join public.customer_groups cg on cg.id = o.customer_group_id
  left join public.tenants t on t.id = o.tenant_id
  where o.tenant_id = p_tenant_id
    and (p_status is null or o.status::text = p_status)
    and (p_shop_id is null or o.shop_id = p_shop_id)
    and (
      p_search is null
      or o.order_no ilike ('%' || p_search || '%')
      or o.name ilike ('%' || p_search || '%')
      or s.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
      or t.name ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;


ALTER FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shop_orders_staff_page"("p_tenant_id" bigint, "p_parent_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 30, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_shop_id" bigint DEFAULT NULL::bigint, "p_shop_type" "text" DEFAULT NULL::"text", "p_cursor_created_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_cursor_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_limit, 30), 100));
  v_fetch integer := v_limit + 1;
  v_shops jsonb := '[]'::jsonb;
  v_orders jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF p_cursor_created_at IS NULL AND p_cursor_id IS NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.memberships m
      WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    ) THEN
      RAISE EXCEPTION 'not allowed';
    END IF;

    SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name), '[]'::jsonb)
    INTO v_shops
    FROM (
      SELECT
        s.id,
        s.tenant_id,
        s.name,
        s.slug,
        s.shop_type,
        coalesce(t.name, '')::text AS tenant_name
      FROM public.shops s
      LEFT JOIN public.tenants t ON t.id = s.tenant_id
      WHERE s.tenant_id = p_tenant_id
        AND s.deleted_at IS NULL
      ORDER BY s.name
      LIMIT 500
    ) x;
  END IF;

  WITH base AS (
    SELECT
      o.id,
      o.tenant_id,
      o.shop_id,
      s.name AS shop_name,
      o.customer_group_id,
      cg.name AS customer_group_name,
      o.order_no,
      o.name,
      o.shop_type_snapshot,
      o.is_negotiable_snapshot,
      o.status,
      o.created_at,
      o.updated_at,
      (SELECT count(*)::bigint FROM public.shop_order_items WHERE order_id = o.id) AS item_count,
      coalesce(t.name, '')::text AS tenant_name
    FROM public.shop_orders o
    JOIN public.shops s ON s.id = o.shop_id
    JOIN public.customer_groups cg ON cg.id = o.customer_group_id
    LEFT JOIN public.tenants t ON t.id = o.tenant_id
    WHERE o.tenant_id = p_tenant_id
      AND (p_status IS NULL OR o.status::text = p_status)
      AND (p_shop_id IS NULL OR o.shop_id = p_shop_id)
      AND (p_shop_type IS NULL OR s.shop_type::text = p_shop_type)
      AND (
        p_search IS NULL
        OR o.order_no ILIKE ('%' || p_search || '%')
        OR o.name ILIKE ('%' || p_search || '%')
        OR s.name ILIKE ('%' || p_search || '%')
        OR cg.name ILIKE ('%' || p_search || '%')
        OR t.name ILIKE ('%' || p_search || '%')
      )
      AND (
        p_cursor_created_at IS NULL
        OR (o.created_at, o.id) < (p_cursor_created_at, p_cursor_id)
      )
    ORDER BY o.created_at DESC, o.id DESC
    LIMIT v_fetch
  ),
  page AS (
    SELECT * FROM base ORDER BY created_at DESC, id DESC LIMIT v_limit
  ),
  tail AS (
    SELECT created_at, id FROM page ORDER BY created_at ASC, id ASC LIMIT 1
  )
  SELECT
    coalesce(
      (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC, p.id DESC) FROM page p),
      '[]'::jsonb
    ),
    (SELECT count(*) > v_limit FROM base),
    CASE
      WHEN (SELECT count(*) FROM base) > v_limit THEN
        (SELECT jsonb_build_object('created_at', created_at, 'id', id) FROM tail)
      ELSE NULL
    END
  INTO v_orders, v_has_more, v_next_cursor;

  RETURN jsonb_build_object(
    'shops', v_shops,
    'orders', v_orders,
    'meta', jsonb_build_object(
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
END;
$$;


ALTER FUNCTION "public"."list_shop_orders_staff_page"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint, "p_shop_type" "text", "p_cursor_created_at" timestamp with time zone, "p_cursor_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_parent_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 200, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_active" boolean DEFAULT NULL::boolean) RETURNS TABLE("id" bigint, "tenant_id" bigint, "name" "text", "slug" "text", "shop_type" "public"."shop_type_enum", "vendor_code" "text", "order_mode" "public"."shop_order_mode_enum", "is_negotiable" boolean, "show_stock_quantity" boolean, "default_currency_id" bigint, "global_stock_type_id" bigint, "is_active" boolean, "allow_delivery" boolean, "buy_currency_id" bigint, "sell_currency_id" bigint, "pricing_method" "text", "markup_percentage" numeric, "quantity_display_mode" "text", "display_quantity_add" integer, "default_print_charge_amount" numeric, "default_packing_charge_amount" numeric, "deduct_charges_from_margin" boolean, "vendor_filters" "jsonb", "deduct_print_from_margin" boolean, "deduct_packing_from_margin" boolean, "description" "text", "category_ids" bigint[], "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "total_count" bigint, "tenant_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total bigint;
begin
  if not exists (
    select 1 from public.memberships m
    where (m.tenant_id = p_tenant_id or m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  select count(*)
  into v_total
  from public.shops s
  left join public.tenants t on t.id = s.tenant_id
  where s.tenant_id = p_tenant_id
    and s.deleted_at is null
    and (p_active is null or s.is_active = p_active)
    and (
      p_search is null
      or s.name ilike '%' || p_search || '%'
      or s.slug ilike '%' || p_search || '%'
      or t.name ilike '%' || p_search || '%'
    );

  return query
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.vendor_code,
    s.order_mode,
    s.is_negotiable,
    s.show_stock_quantity,
    s.default_currency_id,
    s.global_stock_type_id,
    s.is_active,
    s.allow_delivery,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage,
    s.quantity_display_mode,
    s.display_quantity_add,
    s.default_print_charge_amount,
    s.default_packing_charge_amount,
    s.deduct_charges_from_margin,
    s.vendor_filters,
    s.deduct_print_from_margin,
    s.deduct_packing_from_margin,
    s.description,
    s.category_ids,
    s.created_at,
    s.updated_at,
    v_total,
    coalesce(t.name, '')::text as tenant_name
  from public.shops s
  left join public.tenants t on t.id = s.tenant_id
  where s.tenant_id = p_tenant_id
    and s.deleted_at is null
    and (p_active is null or s.is_active = p_active)
    and (
      p_search is null
      or s.name ilike '%' || p_search || '%'
      or s.slug ilike '%' || p_search || '%'
      or t.name ilike '%' || p_search || '%'
    );
end;
$$;


ALTER FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shops_app_page"("p_tenant_id" bigint, "p_parent_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_active" boolean DEFAULT NULL::boolean, "p_catalog_parent_tenant_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_total bigint;
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_shops jsonb := '[]'::jsonb;
  v_catalog jsonb := '[]'::jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  SELECT count(*)
  INTO v_total
  FROM public.shops s
  LEFT JOIN public.tenants t ON t.id = s.tenant_id
  WHERE s.tenant_id = p_tenant_id
    AND s.deleted_at IS NULL
    AND (p_active IS NULL OR s.is_active = p_active)
    AND (
      p_search IS NULL
      OR s.name ILIKE '%' || p_search || '%'
      OR s.slug ILIKE '%' || p_search || '%'
      OR t.name ILIKE '%' || p_search || '%'
    );

  SELECT coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  INTO v_shops
  FROM (
    SELECT
      s.id,
      s.tenant_id,
      s.name,
      s.slug,
      s.shop_type,
      s.vendor_code,
      s.order_mode,
      s.is_negotiable,
      s.show_stock_quantity,
      s.default_currency_id,
      s.global_stock_type_id,
      s.is_active,
      s.allow_delivery,
      s.buy_currency_id,
      s.sell_currency_id,
      s.pricing_method,
      s.markup_percentage,
      s.quantity_display_mode,
      s.display_quantity_add,
      s.default_print_charge_amount,
      s.default_packing_charge_amount,
      s.deduct_charges_from_margin,
      s.vendor_filters,
      s.deduct_print_from_margin,
      s.deduct_packing_from_margin,
      s.description,
      s.category_ids,
      s.created_at,
      s.updated_at,
      v_total AS total_count,
      coalesce(t.name, '')::text AS tenant_name
    FROM public.shops s
    LEFT JOIN public.tenants t ON t.id = s.tenant_id
    WHERE s.tenant_id = p_tenant_id
      AND s.deleted_at IS NULL
      AND (p_active IS NULL OR s.is_active = p_active)
      AND (
        p_search IS NULL
        OR s.name ILIKE '%' || p_search || '%'
        OR s.slug ILIKE '%' || p_search || '%'
        OR t.name ILIKE '%' || p_search || '%'
      )
    ORDER BY s.name
    LIMIT v_limit
    OFFSET v_offset
  ) x;

  IF v_offset = 0
    AND p_catalog_parent_tenant_id IS NOT NULL
    AND public.can_view_products_for_parent(p_catalog_parent_tenant_id)
  THEN
    SELECT coalesce(jsonb_agg(to_jsonb(l)), '[]'::jsonb)
    INTO v_catalog
    FROM (
      SELECT
        l.id,
        l.parent_tenant_id,
        l.source,
        l.event_kind,
        l.source_url,
        l.file_name,
        l.ran_at,
        l.products_updated,
        l.duration_seconds
      FROM public.catalog_refresh_log l
      WHERE l.parent_tenant_id = p_catalog_parent_tenant_id
      ORDER BY l.ran_at DESC
      LIMIT 200
    ) l;
  END IF;

  RETURN jsonb_build_object(
    'shops', v_shops,
    'total_count', v_total,
    'catalog_refresh_log', v_catalog
  );
END;
$$;


ALTER FUNCTION "public"."list_shops_app_page"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean, "p_catalog_parent_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_dropship_order_delivered"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_save jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.status <> 'shipped'::public.shop_order_status then
    raise exception 'mark as delivered requires shipped status (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'customer invoice is required before deliver';
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id;
  if v_invoice.id is null then
    raise exception 'linked customer invoice not found';
  end if;

  if v_invoice.invoice_status not in (
    'draft'::public.global_invoice_status,
    'issued'::public.global_invoice_status
  ) then
    raise exception 'customer invoice must be draft or issued before deliver (current: %)', v_invoice.invoice_status;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  v_save := public.finalize_dropship_order_bills_at_delivered(p_order_id);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  update public.shop_orders
  set
    status = 'delivered'::public.shop_order_status,
    delivered_at = coalesce(delivered_at, now()),
    updated_at = now()
  where id = p_order_id;

  perform public.ensure_dropship_courier_cod_receivable(p_order_id);

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as delivered',
    'order_id', p_order_id,
    'invoice_id', v_order.global_invoice_id
  );
end;
$$;


ALTER FUNCTION "public"."mark_dropship_order_delivered"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_dropship_order_returned_from_settlement"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_save jsonb;
  v_finalize jsonb;
  v_return_items jsonb;
  v_return_fee numeric(15,2) := 0;
  v_line jsonb;
  v_deduct boolean := false;
  v_return_ref text;
  v_reason text;
  v_has_return_qty boolean := false;
  v_elem jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  if v_order.status <> 'shipped'::public.shop_order_status then
    raise exception 'mark as returned requires shipped status (current: %)', v_order.status;
  end if;

  v_return_items := coalesce(p_payload->'return_items', '[]'::jsonb);
  if jsonb_typeof(v_return_items) <> 'array' then
    raise exception 'return_items must be a JSON array';
  end if;

  for v_elem in select * from jsonb_array_elements(v_return_items) loop
    if coalesce((v_elem->>'returned_qty')::numeric, 0) > 0 then
      v_has_return_qty := true;
      exit;
    end if;
  end loop;

  if not v_has_return_qty then
    raise exception 'at least one return line with quantity > 0 is required';
  end if;

  v_deduct := coalesce((p_payload->>'deduct_from_middle_man')::boolean, false);
  v_return_ref := nullif(trim(coalesce(p_payload->>'return_ref', '')), '');
  if v_return_ref is null then
    v_return_ref := 'RET-' || p_order_id::text || '-' || extract(epoch from now())::bigint::text;
  end if;
  v_reason := nullif(trim(coalesce(p_payload->>'return_reason_note', '')), '');

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  for v_line in select * from jsonb_array_elements(coalesce(p_payload->'charge_lines', '[]'::jsonb)) loop
    if v_line->>'charge_type' = 'return' then
      v_return_fee := coalesce((v_line->>'amount')::numeric, 0);
      exit;
    end if;
  end loop;

  v_finalize := public.finalize_dropship_return(
    p_order_id => p_order_id,
    p_items => v_return_items,
    p_actual_return_charge => v_return_fee,
    p_deduct_from_middle_man => v_deduct,
    p_override_reason => v_reason,
    p_return_ref => v_return_ref
  );

  if coalesce(v_finalize->>'success', 'false') <> 'true' then
    return v_finalize;
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as returned',
    'order_id', p_order_id,
    'status', 'returned',
    'return_ref', v_return_ref
  );
end;
$$;


ALTER FUNCTION "public"."mark_dropship_order_returned_from_settlement"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  return public.preview_dropship_issued_bill_notes_at_deliver(p_order_id);
end;
$$;


ALTER FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_dropship_courier_bank_transfer"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_remit jsonb;
  v_net_amount numeric(15,2);
  v_courier_charge numeric(15,2);
  v_collected_cod numeric(15,2);
  v_remittance_ref text;
  v_bank_trx_id text;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement is required before recording courier bank transfer';
  end if;

  if v_settlement.remittance_at is not null then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Courier bank transfer already recorded',
      'order_id', p_order_id,
      'remittance', null
    );
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'bank transfer requires delivered or payment_received status (current: %)', v_order.status;
  end if;

  v_remittance_ref := nullif(trim(coalesce(p_payload->>'remittance_ref', '')), '');
  v_bank_trx_id := nullif(trim(coalesce(p_payload->>'bank_trx_id', '')), '');

  if v_remittance_ref is null then
    raise exception 'remittance_ref is required';
  end if;

  v_collected_cod := coalesce(
    v_settlement.collected_cod_amount,
    v_order.cod_collect_amount,
    0
  );

  v_net_amount := coalesce((p_payload->>'net_amount')::numeric, 0);

  if v_net_amount <= 0 then
    raise exception 'net_amount must be positive';
  end if;

  if v_collected_cod > 0 and v_net_amount > (v_collected_cod + 0.01) then
    raise exception 'Net remittance (%) exceeds collected COD (%)', v_net_amount, v_collected_cod;
  end if;

  v_courier_charge := greatest(v_collected_cod - v_net_amount, 0);

  v_remit := public.record_dropship_courier_remittance(
    p_order_id,
    v_net_amount,
    v_remittance_ref,
    v_bank_trx_id,
    null,
    'bank_transfer',
    null,
    v_courier_charge
  );

  if coalesce(v_remit->>'success', 'false') <> 'true' then
    return v_remit;
  end if;

  update public.dropship_order_settlements
  set remittance_at = now(), updated_at = now()
  where shop_order_id = p_order_id;

  update public.shop_orders
  set
    courier_remittance_ref = coalesce(v_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(v_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Courier bank transfer recorded; invoice paid and merchant wallet credited from remittance remainder',
    'order_id', p_order_id,
    'net_amount', v_net_amount,
    'courier_charge', v_courier_charge,
    'collected_cod', v_collected_cod,
    'remittance', v_remit
  );
end;
$$;


ALTER FUNCTION "public"."record_dropship_courier_bank_transfer"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_dropship_settlement_draft"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_detail jsonb;
  v_settlement public.dropship_order_settlements;
  v_has_settlement boolean := false;
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_items_resell_total numeric(15,2);
  v_order_discount_amount numeric(15,2);
  v_reseller_purchase_cost numeric(15,2);
  v_reseller_unit_purchase_cost numeric(15,2);
  v_company_procurement_cost numeric(15,2);
  v_discount_company_pay numeric(15,2);
  v_return_reason_note text;
  v_charge_lines jsonb;
  v_line jsonb;
  v_totals record;
  v_currency_id bigint;
  v_payload_unit numeric(15,2);
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  v_collected_cod := coalesce((p_payload->>'collected_cod_amount')::numeric, 0);
  v_discount_company_pay := coalesce((p_payload->>'discount_company_pay')::numeric, 0);
  v_return_reason_note := nullif(trim(coalesce(p_payload->>'return_reason_note', '')), '');
  v_charge_lines := coalesce(p_payload->'charge_lines', '[]'::jsonb);

  if jsonb_typeof(v_charge_lines) <> 'array' then
    raise exception 'charge_lines must be a JSON array';
  end if;

  perform public.apply_dropship_order_charge_lines(p_order_id, v_charge_lines);

  v_payload_unit := (p_payload->>'reseller_unit_purchase_cost')::numeric;
  if v_payload_unit is not null then
    perform public.apply_dropship_reseller_unit_purchase(p_order_id, v_payload_unit);
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);
  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );
  v_items_resell_total := coalesce((v_detail->'computed'->>'items_resell_total')::numeric, 0);
  v_order_discount_amount := coalesce(
    (v_detail->'order'->>'discount_amount')::numeric,
    v_order.discount_amount,
    0
  );

  select s.sell_currency_id into v_currency_id
  from public.shops s where s.id = v_order.shop_id;

  select
    rp.reseller_unit_purchase_cost,
    rp.reseller_purchase_cost
  into v_reseller_unit_purchase_cost, v_reseller_purchase_cost
  from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

  select coalesce(
    sum(public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount) * soi.quantity),
    0
  )
  into v_company_procurement_cost
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  if v_has_settlement and v_settlement.status = 'confirmed' then
    raise exception 'settlement is confirmed and cannot be edited';
  end if;

  select * into v_totals
  from public.compute_dropship_settlement_totals(
    v_items_resell_total,
    v_order_discount_amount,
    v_reseller_purchase_cost,
    v_company_procurement_cost,
    v_discount_company_pay,
    v_charge_lines
  );

  if not v_has_settlement then
    insert into public.dropship_order_settlements (
      tenant_id,
      shop_order_id,
      profile_id,
      currency_id,
      calculated_cod_amount,
      collected_cod_amount,
      reseller_unit_purchase_cost,
      reseller_purchase_cost,
      discount_company_pay,
      return_reason_note,
      total_cost,
      reseller_profit,
      company_profit,
      status
    ) values (
      v_order.tenant_id,
      p_order_id,
      v_order.profile_id,
      v_currency_id,
      v_calculated_cod,
      v_collected_cod,
      v_reseller_unit_purchase_cost,
      v_reseller_purchase_cost,
      v_discount_company_pay,
      v_return_reason_note,
      v_totals.total_cost,
      v_totals.reseller_profit,
      v_totals.company_profit,
      'draft'
    )
    returning * into v_settlement;
  else
    update public.dropship_order_settlements
    set
      profile_id = coalesce(v_order.profile_id, profile_id),
      currency_id = coalesce(v_currency_id, currency_id),
      calculated_cod_amount = v_calculated_cod,
      collected_cod_amount = v_collected_cod,
      reseller_unit_purchase_cost = v_reseller_unit_purchase_cost,
      reseller_purchase_cost = v_reseller_purchase_cost,
      discount_company_pay = v_discount_company_pay,
      return_reason_note = v_return_reason_note,
      total_cost = v_totals.total_cost,
      reseller_profit = v_totals.reseller_profit,
      company_profit = v_totals.company_profit,
      updated_at = now()
    where id = v_settlement.id
    returning * into v_settlement;
  end if;

  if v_settlement.id is null then
    raise exception 'settlement row missing after upsert';
  end if;

  delete from public.dropship_settlement_charge_lines
  where settlement_id = v_settlement.id;

  for v_line in select value from jsonb_array_elements(v_charge_lines)
  loop
    insert into public.dropship_settlement_charge_lines (
      settlement_id,
      charge_type,
      amount,
      payer
    ) values (
      v_settlement.id,
      (v_line->>'charge_type')::public.dropship_settlement_charge_type,
      coalesce((v_line->>'amount')::numeric, 0),
      (v_line->>'payer')::public.dropship_settlement_charge_payer
    );
  end loop;

  return jsonb_build_object(
    'success', true,
    'settlement_id', v_settlement.id,
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', v_settlement.status,
      'calculated_cod_amount', v_calculated_cod,
      'collected_cod_amount', v_settlement.collected_cod_amount,
      'reseller_unit_purchase_cost', v_reseller_unit_purchase_cost,
      'reseller_purchase_cost', v_reseller_purchase_cost,
      'company_procurement_cost', v_company_procurement_cost,
      'discount_company_pay', v_settlement.discount_company_pay,
      'return_reason_note', v_settlement.return_reason_note,
      'total_cost', v_settlement.total_cost,
      'reseller_profit', v_settlement.reseller_profit,
      'company_profit', v_settlement.company_profit,
      'courier_cod_booked_at', v_settlement.courier_cod_booked_at,
      'remittance_at', v_settlement.remittance_at,
      'merchant_payout_at', v_settlement.merchant_payout_at
    )
  );
end;
$$;


ALTER FUNCTION "public"."save_dropship_settlement_draft"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ship_dropship_order_and_issue_merchant_bill"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_issue jsonb;
  v_ap jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    return jsonb_build_object('success', false, 'error', 'tenant mismatch');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status <> 'ready_for_pickup'::public.shop_order_status then
    return jsonb_build_object(
      'success', false,
      'error', format('ship requires ready_for_pickup (current: %s)', v_order.status)
    );
  end if;

  if v_order.profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required before ship');
  end if;

  if v_order.courier_service_id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required before ship');
  end if;

  if nullif(trim(coalesce(v_order.sender_name, '')), '') is null
     or nullif(trim(coalesce(v_order.pickup_phone, '')), '') is null
     or nullif(trim(coalesce(v_order.pickup_address, '')), '') is null then
    return jsonb_build_object('success', false, 'error', 'pickup location name, phone, and address are required before ship');
  end if;

  if exists (
    select 1
    from public.shop_order_items soi
    where soi.order_id = p_order_id
      and soi.quantity > 0
      and coalesce(soi.is_fulfillment_unavailable, false) = false
      and coalesce(soi.confirmed_quantity, 0) <= 0
      and not (
        coalesce(soi.is_gift, false)
        and soi.gift_source = 'stock'
      )
      and not (
        coalesce(soi.is_gift, false)
        and soi.gift_source = 'customer_stock'
        and coalesce(soi.confirmed_quantity, 0) >= soi.quantity
      )
      and not exists (
        select 1
        from public.shop_order_item_stock_picks sp
        where sp.order_item_id = soi.id
          and sp.quantity > 0
      )
  ) then
    return jsonb_build_object('success', false, 'error', 'every line must be picked or marked unavailable before ship');
  end if;

  v_issue := public.issue_dropship_tenant_b2b_invoice(p_tenant_id, p_order_id);
  if coalesce(v_issue->>'success', 'false') <> 'true' then
    return v_issue;
  end if;

  v_ap := public.upsert_dropship_courier_ap_bill(p_order_id, false);
  if coalesce(v_ap->>'success', 'false') <> 'true' then
    return v_ap;
  end if;
  if nullif(v_ap->>'bill_id', '') is null then
    return jsonb_build_object('success', false, 'error', 'courier bill was not created');
  end if;

  update public.shop_orders
  set
    status = 'shipped'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'shipped',
    'invoice', v_issue->'invoice',
    'courier_ap', v_ap,
    'created', coalesce(v_issue->>'created', 'false')::boolean,
    'already_issued', coalesce(v_issue->>'already_issued', 'false')::boolean
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;


ALTER FUNCTION "public"."ship_dropship_order_and_issue_merchant_bill"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_create_dropship_order"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_items" "jsonb", "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_shipping_post_code" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_is_prepaid" boolean DEFAULT false, "p_delivery_instructions" "text" DEFAULT NULL::"text", "p_cod_charge_amount" numeric DEFAULT 0, "p_delivery_charge_amount" numeric DEFAULT 0, "p_print_charge_amount" numeric DEFAULT 0, "p_packing_charge_amount" numeric DEFAULT 0, "p_discount_amount" numeric DEFAULT 0, "p_recipient_pays_delivery" boolean DEFAULT true, "p_recipient_pays_cod" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_result jsonb;
  v_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci public.shop_order_items%rowtype;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
  v_billing_profile_warning boolean := false;
  v_elem jsonb;
  v_product_id bigint;
  v_global_stock_id bigint;
  v_qty integer;
  v_prod_name text;
  v_prod_image text;
  v_listing_id_new bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
  v_landed_cost numeric;
  v_can_set_dropship_price boolean;
  v_order_tenant_id bigint;
BEGIN
  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  SELECT * INTO v_shop FROM public.shops WHERE id = p_shop_id AND is_active = true;
  IF v_shop.id IS NULL THEN RAISE EXCEPTION 'shop not found or inactive'; END IF;
  IF v_shop.shop_type <> 'dropship' THEN RAISE EXCEPTION 'shop is not dropship'; END IF;
  v_order_tenant_id := public.resolve_parent_tenant_id(v_shop.tenant_id);

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'order must include at least one item';
  END IF;

  IF nullif(trim(coalesce(p_recipient_name, '')), '') IS NULL THEN RAISE EXCEPTION 'recipient name is required'; END IF;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  IF v_phone IS NULL THEN RAISE EXCEPTION 'recipient phone is required'; END IF;
  IF nullif(trim(coalesce(p_shipping_address, '')), '') IS NULL THEN RAISE EXCEPTION 'shipping address is required'; END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT
        nullif((e->>'listing_id')::bigint, 0) AS listing_id,
        (e->>'product_id')::bigint AS product_id,
        sum(greatest(1, coalesce((e->>'quantity')::int, 1))) AS qty
      FROM jsonb_array_elements(p_items) AS e
      GROUP BY 1, 2
    ) agg
    JOIN public.shop_product_listings l ON l.id = agg.listing_id AND l.shop_id = p_shop_id
    LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
    WHERE agg.listing_id IS NOT NULL
      AND agg.qty > coalesce(
        l.display_quantity_override,
        public.shop_product_grade_available_units(
          v_shop.tenant_id,
          agg.product_id,
          coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
        )
      )
  ) THEN
    RAISE EXCEPTION 'insufficient stock for one or more items';
  END IF;

  SELECT can_set_dropship_price INTO v_can_set_dropship_price
  FROM public.get_shop_permissions_for_customer_group(p_shop_id, p_customer_group_id)
  LIMIT 1;
  v_can_set_dropship_price := coalesce(v_can_set_dropship_price, true);

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_listing_id_new := nullif((v_elem->>'listing_id')::bigint, 0);
    v_global_stock_id := nullif((v_elem->>'global_stock_id')::bigint, 0);
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));
    IF v_product_id IS NULL OR (v_listing_id_new IS NULL AND v_global_stock_id IS NULL) THEN
      RAISE EXCEPTION 'each item requires product_id and listing_id';
    END IF;

    IF v_listing_id_new IS NOT NULL THEN
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id
      FROM public.shop_product_listings l
      WHERE l.id = v_listing_id_new
        AND l.shop_id = p_shop_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    ELSE
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id
      FROM public.shop_product_listings l
      WHERE l.shop_id = p_shop_id
        AND l.global_stock_id = v_global_stock_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    END IF;

    IF v_listing_id_new IS NULL THEN
      RAISE EXCEPTION 'active product listing not found on this shop';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.shop_listing_group_hides h
      WHERE h.listing_id = v_listing_id_new AND h.customer_group_id = p_customer_group_id
    ) THEN
      RAISE EXCEPTION 'product not available for this customer';
    END IF;

    IF nullif(v_elem->>'customer_sell_price_amount', '') IS NOT NULL THEN
      v_customer_sell_price_amount := (v_elem->>'customer_sell_price_amount')::numeric;
      v_customer_sell_price_currency_id := coalesce((v_elem->>'customer_sell_price_currency_id')::bigint, v_sell_price_currency_id);
    ELSIF v_can_set_dropship_price AND v_sell_price_currency_id = v_min_sell_price_currency_id THEN
      v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    ELSE
      v_customer_sell_price_amount := v_sell_price_amount;
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    END IF;

    IF coalesce(v_min_sell_price_amount, 0) > 0
       AND v_customer_sell_price_currency_id = v_min_sell_price_currency_id
       AND v_customer_sell_price_amount < v_min_sell_price_amount THEN
      RAISE EXCEPTION 'price floor violation: item priced below minimum sell price';
    END IF;
  END LOOP;

  v_profile_id := p_profile_id;
  IF v_profile_id IS NULL THEN
    v_profile_id := public.resolve_customer_profile_for_group(v_shop.tenant_id, p_customer_group_id);
  END IF;
  IF v_profile_id IS NULL THEN
    v_billing_profile_warning := true;
  END IF;

  IF v_shop.order_mode = 'checkout_fixed' THEN v_order_status := 'confirmed';
  ELSE v_order_status := 'submitted'; END IF;

  v_deduct_delivery_from_margin := NOT coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := NOT coalesce(p_recipient_pays_cod, true);

  SELECT public.generate_shop_order_number(v_order_tenant_id, v_shop.id) INTO v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_shop.tenant_id, p_name => p_recipient_name, p_phone => v_phone,
    p_phone_secondary => p_recipient_phone_secondary, p_address => p_shipping_address,
    p_district => p_shipping_district, p_thana => p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;

  INSERT INTO public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id, order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot, status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, profile_id, created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  ) VALUES (
    v_order_tenant_id, v_shop.id, p_customer_group_id, NULL, v_order_no,
    'Order for ' || nullif(trim(coalesce(p_recipient_name, '')), ''),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable, v_order_status, 0,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone,
    nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    nullif(trim(coalesce(p_shipping_district, '')), ''),
    nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_profile_id, public.current_user_email(),
    coalesce(p_cod_charge_amount, 0), coalesce(p_delivery_charge_amount, 0),
    coalesce(p_print_charge_amount, 0), coalesce(p_packing_charge_amount, 0), coalesce(p_discount_amount, 0),
    coalesce(p_is_prepaid, false), nullif(trim(coalesce(p_delivery_instructions, '')), ''),
    v_shop.deduct_charges_from_margin, v_deduct_cod_from_margin, v_deduct_delivery_from_margin,
    v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  ) RETURNING id INTO v_order_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_listing_id_new := nullif((v_elem->>'listing_id')::bigint, 0);
    v_global_stock_id := nullif((v_elem->>'global_stock_id')::bigint, 0);
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));

    SELECT name, image_url INTO v_prod_name, v_prod_image FROM public.products WHERE id = v_product_id;

    IF v_listing_id_new IS NOT NULL THEN
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id,
        coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
        l.global_stock_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id,
        v_grade_tag_id, v_global_stock_id
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.id = v_listing_id_new
        AND l.shop_id = p_shop_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    ELSE
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id,
        coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
        l.global_stock_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id,
        v_grade_tag_id, v_global_stock_id
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.shop_id = p_shop_id
        AND l.global_stock_id = v_global_stock_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    END IF;

    IF v_global_stock_id IS NOT NULL THEN
      SELECT coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gs.shipment_item_id))
      INTO v_landed_cost
      FROM public.global_stocks gs
      JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
      WHERE gs.id = v_global_stock_id;
    ELSE
      v_landed_cost := public.shop_product_grade_avg_landed_cost(
        v_shop.tenant_id, v_product_id, v_grade_tag_id
      );
    END IF;

    IF nullif(v_elem->>'customer_sell_price_amount', '') IS NOT NULL THEN
      v_customer_sell_price_amount := (v_elem->>'customer_sell_price_amount')::numeric;
      v_customer_sell_price_currency_id := coalesce((v_elem->>'customer_sell_price_currency_id')::bigint, v_sell_price_currency_id);
    ELSIF v_can_set_dropship_price AND v_sell_price_currency_id = v_min_sell_price_currency_id THEN
      v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    ELSE
      v_customer_sell_price_amount := v_sell_price_amount;
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    END IF;

    INSERT INTO public.shop_order_items (
      order_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
      name, image_url, quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      customer_offer_amount, customer_offer_currency_id,
      final_price_amount, final_price_currency_id,
      cost_price_amount, cost_price_currency_id, confirmed_quantity
    ) VALUES (
      v_order_id, v_product_id, v_listing_id_new,
      coalesce(v_grade_tag_id, public.default_stock_grade_tag_id()),
      v_global_stock_id, NULL, v_prod_name, v_prod_image, v_qty,
      coalesce(v_landed_cost, 0), v_shop.buy_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      CASE WHEN v_order_status = 'confirmed' THEN v_customer_sell_price_amount ELSE NULL END,
      CASE WHEN v_order_status = 'confirmed' THEN v_customer_sell_price_currency_id ELSE NULL END,
      coalesce(v_landed_cost, public.shop_product_grade_avg_landed_cost(
        v_shop.tenant_id, v_product_id, coalesce(v_grade_tag_id, public.default_stock_grade_tag_id())
      )),
      v_shop.buy_currency_id, 0
    );
  END LOOP;

  FOR v_ci IN SELECT * FROM public.shop_order_items WHERE order_id = v_order_id LOOP
    v_grade_tag_id := coalesce(
      v_ci.grade_tag_id,
      (SELECT l.grade_tag_id FROM public.shop_product_listings l WHERE l.id = v_ci.listing_id),
      (SELECT gs.grade_tag_id FROM public.global_stocks gs WHERE gs.id = v_ci.global_stock_id),
      public.default_stock_grade_tag_id()
    );
    v_listing_id := coalesce(
      v_ci.listing_id,
      (SELECT l.id FROM public.shop_product_listings l WHERE l.shop_id = v_shop.id AND l.product_id = v_ci.product_id
        AND coalesce(l.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id ORDER BY l.id ASC LIMIT 1),
      (SELECT l.id FROM public.shop_product_listings l WHERE l.shop_id = v_shop.id AND l.product_id = v_ci.product_id
        AND l.global_stock_id = v_ci.global_stock_id LIMIT 1)
    );

    IF v_listing_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE id = v_listing_id AND display_quantity_override IS NOT NULL;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE shop_id = v_shop.id
        AND product_id = v_ci.product_id
        AND global_stock_id = v_ci.global_stock_id
        AND display_quantity_override IS NOT NULL;
    END IF;

    IF v_ci.global_stock_id IS NOT NULL THEN
      UPDATE public.global_stocks
      SET quantity = greatest(0, quantity - v_ci.quantity)
      WHERE id = v_ci.global_stock_id;
    END IF;

    UPDATE public.shop_order_items
    SET listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
    WHERE id = v_ci.id;

    IF v_listing_id IS NOT NULL THEN
      v_available_after := public.shop_product_grade_available_units(v_shop.tenant_id, v_ci.product_id, v_grade_tag_id);
      IF coalesce((SELECT display_quantity_override FROM public.shop_product_listings WHERE id = v_listing_id), v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false WHERE id = v_listing_id;
      END IF;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      SELECT coalesce(sum(gs.quantity), 0) INTO v_available_after
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = (SELECT shipment_item_id FROM public.global_stocks WHERE id = v_ci.global_stock_id)
        AND gs.availability = 'sellable'::public.stock_availability;
      IF coalesce(
        (SELECT display_quantity_override FROM public.shop_product_listings
         WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id),
        v_available_after,
        0
      ) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false
        WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id;
      END IF;
    END IF;
  END LOOP;

  PERFORM public.recompute_dropship_cod_collect_amount(v_order_id);

  SELECT jsonb_build_object(
    'order_id', v_order_id, 'order_no', v_order_no, 'status', v_order_status,
    'shop_id', v_shop.id, 'billing_profile_warning', v_billing_profile_warning
  ) INTO v_result;
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."staff_create_dropship_order"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_items" "jsonb", "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_shipping_post_code" "text", "p_profile_id" bigint, "p_is_prepaid" boolean, "p_delivery_instructions" "text", "p_cod_charge_amount" numeric, "p_delivery_charge_amount" numeric, "p_print_charge_amount" numeric, "p_packing_charge_amount" numeric, "p_discount_amount" numeric, "p_recipient_pays_delivery" boolean, "p_recipient_pays_cod" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_finalize_catalog_prices"("p_order_id" bigint, "p_items" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_desk_tenant_id bigint;
  v_elem jsonb;
  v_item_id bigint;
  v_final_amount numeric;
  v_final_currency_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := v_order.tenant_id;

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_finalize_catalog_prices is only valid for vendor_catalog orders.';
  end if;

  if v_order.status <> 'countered'::public.shop_order_status then
    raise exception 'Order % cannot send final offer from status %', p_order_id, v_order.status;
  end if;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_elem->>'id')::bigint;
    v_final_amount := (v_elem->>'final_offer_amount')::numeric;
    v_final_currency_id := (v_elem->>'final_offer_currency_id')::bigint;

    update public.shop_order_items
    set
      final_price_amount = v_final_amount,
      final_price_currency_id = v_final_currency_id,
      is_final_offer_manual = coalesce((v_elem->>'is_final_offer_manual')::boolean, is_final_offer_manual),
      negotiation_status = 'final_offered',
      final_offer_at = now(),
      updated_at = now()
    where id = v_item_id and order_id = p_order_id;
  end loop;

  update public.shop_orders
  set
    status = 'final_offered'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.offer.final',
    p_title := format('Confirm %s', v_order.order_no),
    p_body := 'Check price and quantity, then confirm.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."staff_finalize_catalog_prices"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_set_catalog_delivered_qty"("p_order_id" bigint, "p_items" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_desk_tenant_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := v_order.tenant_id;

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_delivered_qty is only valid for vendor_catalog orders.';
  end if;

  update public.shop_orders
  set
    status = 'delivered'::public.shop_order_status,
    fulfilled_at = coalesce(fulfilled_at, now()),
    updated_at = now()
  where id = p_order_id;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.delivered',
    p_title := format('Order %s delivered', v_order.order_no),
    p_body := 'Open the order for details.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."staff_set_catalog_delivered_qty"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_desk_tenant_id bigint;
  v_item_row record;
  v_target_qty integer;
  v_allocated integer;
  v_shortfall integer;
  v_product record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := v_order.tenant_id;

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  end if;

  if public.normalize_shop_order_procurement_status(v_order.status) <> 'procuring' then
    raise exception 'order must be procuring to mark packed';
  end if;

  update public.shop_orders
  set
    status = 'packed'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  where id = p_order_id;

  for v_item_row in
    select oi.*
    from public.shop_order_items oi
    where oi.order_id = p_order_id
  loop
    v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);

    select coalesce(pd.delivered_quantity, 0)
    into v_allocated
    from public.preorder_demand pd
    where pd.source_type = 'shop_order_item'
      and pd.source_id = v_item_row.id;

    v_shortfall := greatest(v_target_qty - coalesce(v_allocated, 0), 0);

    if v_shortfall > 0 and v_order.profile_id is not null then
        select p.barcode, p.product_code
        into v_product
        from public.products p
        where p.id = v_item_row.product_id;

        perform public.add_demand_bucket_item_internal(
          p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_profile_id => v_order.profile_id,
          p_product_id => v_item_row.product_id,
          p_source_type => 'shop_order_item',
          p_source_id => v_item_row.id,
          p_snapshot => jsonb_build_object(
            'name', coalesce(v_item_row.name, ''),
            'image_url', v_item_row.image_url,
            'barcode', v_product.barcode,
            'product_code', v_product.product_code,
            'note', null
          ),
          p_quantity => v_shortfall
        );

        insert into public.customer_order_backlog_items (
          tenant_id,
          profile_id,
          product_id,
          order_id,
          order_item_id,
          requested_quantity,
          fulfilled_quantity,
          backlog_status
        ) values (
          v_order.tenant_id,
          v_order.profile_id,
          v_item_row.product_id,
          p_order_id,
          v_item_row.id,
          v_shortfall,
          0,
          'open'
        )
        on conflict (tenant_id, profile_id, product_id)
        do update set
          requested_quantity = customer_order_backlog_items.requested_quantity + excluded.requested_quantity,
          backlog_status = 'open',
          updated_at = now();
    end if;
  end loop;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.packed',
    p_title := format('%s is packing', v_order.order_no),
    p_body := 'We will mark it on the way when it ships.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_start_catalog_procurement"("p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_desk_tenant_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := v_order.tenant_id;

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_start_catalog_procurement is only valid for vendor_catalog orders.';
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'Order % cannot start procurement from status %', p_order_id, v_order.status;
  end if;

  update public.shop_order_items
  set
    confirmed_quantity = coalesce(confirmed_quantity, quantity),
    updated_at = now()
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'procuring'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."staff_start_catalog_procurement"("p_order_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_submit_dropship_order_from_cart"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_shipping_post_code" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_is_prepaid" boolean DEFAULT false, "p_delivery_instructions" "text" DEFAULT NULL::"text", "p_cod_charge_amount" numeric DEFAULT 0, "p_delivery_charge_amount" numeric DEFAULT 0, "p_print_charge_amount" numeric DEFAULT 0, "p_packing_charge_amount" numeric DEFAULT 0, "p_discount_amount" numeric DEFAULT 0, "p_recipient_pays_delivery" boolean DEFAULT true, "p_recipient_pays_cod" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop public.shops%rowtype;
  v_cart public.shop_carts%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_item_count integer;
  v_result jsonb;
  v_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
  v_billing_profile_warning boolean := false;
  v_order_tenant_id bigint;
BEGIN
  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  SELECT * INTO v_shop FROM public.shops WHERE id = p_shop_id AND is_active = true;
  IF v_shop.id IS NULL THEN RAISE EXCEPTION 'shop not found or inactive'; END IF;
  IF v_shop.shop_type <> 'dropship' THEN RAISE EXCEPTION 'shop is not dropship'; END IF;

  SELECT * INTO v_cart
  FROM public.shop_carts c
  WHERE c.shop_id = p_shop_id
    AND c.customer_group_id = p_customer_group_id
    AND c.status = 'active'
  ORDER BY c.id DESC
  LIMIT 1;

  IF v_cart.id IS NULL THEN RAISE EXCEPTION 'active cart not found'; END IF;
  v_order_tenant_id := public.resolve_parent_tenant_id(v_cart.tenant_id);

  SELECT count(*) INTO v_item_count FROM public.shop_cart_items WHERE cart_id = v_cart.id;
  IF v_item_count = 0 THEN RAISE EXCEPTION 'cart is empty'; END IF;

  IF nullif(trim(coalesce(p_recipient_name, '')), '') IS NULL THEN RAISE EXCEPTION 'recipient name is required'; END IF;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  IF v_phone IS NULL THEN RAISE EXCEPTION 'recipient phone is required'; END IF;
  IF nullif(trim(coalesce(p_shipping_address, '')), '') IS NULL THEN RAISE EXCEPTION 'shipping address is required'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.shop_cart_items ci
    WHERE ci.cart_id = v_cart.id
      AND coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
      AND coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0) < ci.unit_minimum_sell_price_amount
  ) THEN
    RAISE EXCEPTION 'price floor violation: some items are priced below the minimum sell price';
  END IF;

  v_profile_id := p_profile_id;
  IF v_profile_id IS NULL THEN
    v_profile_id := public.resolve_customer_profile_for_group(v_cart.tenant_id, v_cart.customer_group_id);
  END IF;

  IF v_profile_id IS NULL THEN
    v_billing_profile_warning := true;
  END IF;

  IF v_shop.order_mode = 'checkout_fixed' THEN v_order_status := 'confirmed';
  ELSE v_order_status := 'submitted'; END IF;

  v_deduct_delivery_from_margin := NOT coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := NOT coalesce(p_recipient_pays_cod, true);

  SELECT public.generate_shop_order_number(v_order_tenant_id, v_cart.shop_id) INTO v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_cart.tenant_id, p_name => p_recipient_name, p_phone => v_phone,
    p_phone_secondary => p_recipient_phone_secondary, p_address => p_shipping_address,
    p_district => p_shipping_district, p_thana => p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;

  INSERT INTO public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id, order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot, status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, profile_id, created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  ) VALUES (
    v_order_tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id, v_order_no,
    'Order for ' || nullif(trim(coalesce(p_recipient_name, '')), ''),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable, v_order_status, 0,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone,
    nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    nullif(trim(coalesce(p_shipping_district, '')), ''),
    nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_profile_id, public.current_user_email(),
    coalesce(p_cod_charge_amount, 0), coalesce(p_delivery_charge_amount, 0),
    coalesce(p_print_charge_amount, 0), coalesce(p_packing_charge_amount, 0), coalesce(p_discount_amount, 0),
    coalesce(p_is_prepaid, false), nullif(trim(coalesce(p_delivery_instructions, '')), ''),
    v_shop.deduct_charges_from_margin, v_deduct_cod_from_margin, v_deduct_delivery_from_margin,
    v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  ) RETURNING id INTO v_order_id;

  INSERT INTO public.shop_order_items (
    order_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id, confirmed_quantity
  )
  SELECT
    v_order_id, ci.product_id, ci.listing_id,
    coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
    NULL, NULL, ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    CASE WHEN v_order_status = 'confirmed' THEN coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount) ELSE NULL END,
    CASE WHEN v_order_status = 'confirmed' THEN coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id) ELSE NULL END,
    coalesce(ci.unit_list_price_amount, public.shop_product_grade_avg_landed_cost(
      v_cart.tenant_id, ci.product_id,
      coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
    )),
    v_shop.buy_currency_id, 0
  FROM public.shop_cart_items ci
  LEFT JOIN public.shop_product_listings l ON l.id = ci.listing_id
  LEFT JOIN public.global_stocks gs ON gs.id = ci.global_stock_id
  WHERE ci.cart_id = v_cart.id;

  FOR v_ci IN SELECT * FROM public.shop_cart_items WHERE cart_id = v_cart.id LOOP
    v_grade_tag_id := coalesce(
      v_ci.grade_tag_id,
      (SELECT l.grade_tag_id FROM public.shop_product_listings l WHERE l.id = v_ci.listing_id),
      (SELECT gs.grade_tag_id FROM public.global_stocks gs WHERE gs.id = v_ci.global_stock_id),
      public.default_stock_grade_tag_id()
    );
    v_listing_id := coalesce(
      v_ci.listing_id,
      (SELECT l.id FROM public.shop_product_listings l WHERE l.shop_id = v_shop.id AND l.product_id = v_ci.product_id
        AND coalesce(l.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id ORDER BY l.id ASC LIMIT 1),
      (SELECT l.id FROM public.shop_product_listings l WHERE l.shop_id = v_shop.id AND l.product_id = v_ci.product_id
        AND l.global_stock_id = v_ci.global_stock_id LIMIT 1)
    );

    IF v_listing_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE id = v_listing_id AND display_quantity_override IS NOT NULL;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id
        AND display_quantity_override IS NOT NULL;
    END IF;

    SELECT soi.id INTO v_order_item_id FROM public.shop_order_items soi
    WHERE soi.order_id = v_order_id AND soi.product_id = v_ci.product_id
      AND soi.listing_id IS NOT DISTINCT FROM v_ci.listing_id ORDER BY soi.id ASC LIMIT 1;
    IF v_order_item_id IS NULL THEN
      SELECT soi.id INTO v_order_item_id FROM public.shop_order_items soi
      WHERE soi.order_id = v_order_id AND soi.product_id = v_ci.product_id ORDER BY soi.id ASC LIMIT 1;
    END IF;
    IF v_order_item_id IS NOT NULL THEN
      UPDATE public.shop_order_items
      SET listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
      WHERE id = v_order_item_id;
    END IF;

    IF v_listing_id IS NOT NULL THEN
      v_available_after := public.shop_product_grade_available_units(v_cart.tenant_id, v_ci.product_id, v_grade_tag_id);
      IF coalesce((SELECT display_quantity_override FROM public.shop_product_listings WHERE id = v_listing_id), v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false WHERE id = v_listing_id;
      END IF;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      SELECT coalesce(sum(gs.quantity), 0) INTO v_available_after FROM public.global_stocks gs
      WHERE gs.shipment_item_id = (SELECT shipment_item_id FROM public.global_stocks WHERE id = v_ci.global_stock_id)
        AND gs.availability = 'sellable'::public.stock_availability;
      IF coalesce((SELECT display_quantity_override FROM public.shop_product_listings
        WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id),
        v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false
        WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id;
      END IF;
    END IF;
  END LOOP;

  DELETE FROM public.shop_stock_reservations
  WHERE cart_item_id IN (SELECT id FROM public.shop_cart_items WHERE cart_id = v_cart.id);
  UPDATE public.shop_carts SET status = 'converted', updated_at = now() WHERE id = v_cart.id;

  PERFORM public.recompute_dropship_cod_collect_amount(v_order_id);

  SELECT jsonb_build_object(
    'order_id', v_order_id, 'order_no', v_order_no, 'status', v_order_status,
    'cart_id', v_cart.id, 'shop_id', v_shop.id,
    'billing_profile_warning', v_billing_profile_warning
  ) INTO v_result;
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."staff_submit_dropship_order_from_cart"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_shipping_post_code" "text", "p_profile_id" bigint, "p_is_prepaid" boolean, "p_delivery_instructions" "text", "p_cod_charge_amount" numeric, "p_delivery_charge_amount" numeric, "p_print_charge_amount" numeric, "p_packing_charge_amount" numeric, "p_discount_amount" numeric, "p_recipient_pays_delivery" boolean, "p_recipient_pays_cod" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_dropship_order_from_cart"("p_shop_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_shipping_post_code" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_is_prepaid" boolean DEFAULT false, "p_delivery_instructions" "text" DEFAULT NULL::"text", "p_cod_charge_amount" numeric DEFAULT 0, "p_delivery_charge_amount" numeric DEFAULT 0, "p_print_charge_amount" numeric DEFAULT 0, "p_packing_charge_amount" numeric DEFAULT 0, "p_discount_amount" numeric DEFAULT 0, "p_recipient_pays_delivery" boolean DEFAULT true, "p_recipient_pays_cod" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop public.shops%rowtype;
  v_cart public.shop_carts%rowtype;
  v_customer_group_id bigint;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_item_count integer;
  v_result jsonb;
  v_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
  v_order_tenant_id bigint;
begin
  select * into v_shop from public.shops where id = p_shop_id and is_active = true;
  if v_shop.id is null then raise exception 'shop not found or inactive'; end if;
  if v_shop.shop_type <> 'dropship' then raise exception 'shop is not dropship'; end if;
  if not public.can_customer_access_shop(p_shop_id) then raise exception 'access denied'; end if;

  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id and access.status = true and cg.is_active = true
    and cgm.is_active = true and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc limit 1;

  if v_customer_group_id is null then raise exception 'no customer group access found'; end if;

  select * into v_cart from public.shop_carts c
  where c.shop_id = p_shop_id
    and c.customer_group_id = v_customer_group_id and c.status = 'active'
  order by c.id desc limit 1;

  if v_cart.id is null then raise exception 'active cart not found'; end if;
  v_order_tenant_id := public.resolve_parent_tenant_id(v_cart.tenant_id);
  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then raise exception 'access denied'; end if;

  select can_place_order into v_can_place_order from public.get_shop_permissions_for_customer(p_shop_id);
  if coalesce(v_can_place_order, false) is not true then raise exception 'checkout not allowed for this customer group'; end if;

  select count(*) into v_item_count from public.shop_cart_items where cart_id = v_cart.id;
  if v_item_count = 0 then raise exception 'cart is empty'; end if;

  if nullif(trim(coalesce(p_recipient_name, '')), '') is null then raise exception 'recipient name is required'; end if;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  if v_phone is null then raise exception 'recipient phone is required'; end if;
  if nullif(trim(coalesce(p_shipping_address, '')), '') is null then raise exception 'shipping address is required'; end if;

  if exists (
    select 1 from public.shop_cart_items ci
    where ci.cart_id = v_cart.id
      and coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
      and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0) < ci.unit_minimum_sell_price_amount
  ) then
    raise exception 'price floor violation: some items are priced below the minimum sell price';
  end if;

  v_profile_id := p_profile_id;
  if v_profile_id is null then
    v_profile_id := public.resolve_customer_profile_for_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.order_mode = 'checkout_fixed' then v_order_status := 'confirmed';
  else v_order_status := 'submitted'; end if;

  v_deduct_delivery_from_margin := not coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := not coalesce(p_recipient_pays_cod, true);

  select public.generate_shop_order_number(v_order_tenant_id, v_cart.shop_id) into v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_cart.tenant_id, p_name => p_recipient_name, p_phone => v_phone,
    p_phone_secondary => p_recipient_phone_secondary, p_address => p_shipping_address,
    p_district => p_shipping_district, p_thana => p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;

  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id, order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot, status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, profile_id, created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  ) values (
    v_order_tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id, v_order_no,
    'Order for ' || nullif(trim(coalesce(p_recipient_name, '')), ''),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable, v_order_status, 0,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone,
    nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    nullif(trim(coalesce(p_shipping_district, '')), ''),
    nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_profile_id, public.current_user_email(),
    coalesce(p_cod_charge_amount, 0), coalesce(p_delivery_charge_amount, 0),
    coalesce(p_print_charge_amount, 0), coalesce(p_packing_charge_amount, 0), coalesce(p_discount_amount, 0),
    coalesce(p_is_prepaid, false), nullif(trim(coalesce(p_delivery_instructions, '')), ''),
    v_shop.deduct_charges_from_margin, v_deduct_cod_from_margin, v_deduct_delivery_from_margin,
    v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  ) returning id into v_order_id;

  insert into public.shop_order_items (
    order_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id, confirmed_quantity
  )
  select
    v_order_id, ci.product_id, ci.listing_id,
    coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
    null, null, ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount) else null end,
    case when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id) else null end,
    coalesce(ci.unit_list_price_amount, public.shop_product_grade_avg_landed_cost(
      v_cart.tenant_id, ci.product_id,
      coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
    )),
    v_shop.buy_currency_id, 0
  from public.shop_cart_items ci
  left join public.shop_product_listings l on l.id = ci.listing_id
  left join public.global_stocks gs on gs.id = ci.global_stock_id
  where ci.cart_id = v_cart.id;

  for v_ci in select * from public.shop_cart_items where cart_id = v_cart.id loop
    v_grade_tag_id := coalesce(
      v_ci.grade_tag_id,
      (select l.grade_tag_id from public.shop_product_listings l where l.id = v_ci.listing_id),
      (select gs.grade_tag_id from public.global_stocks gs where gs.id = v_ci.global_stock_id),
      public.default_stock_grade_tag_id()
    );
    v_listing_id := coalesce(
      v_ci.listing_id,
      (select l.id from public.shop_product_listings l where l.shop_id = v_shop.id and l.product_id = v_ci.product_id
        and coalesce(l.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id order by l.id asc limit 1),
      (select l.id from public.shop_product_listings l where l.shop_id = v_shop.id and l.product_id = v_ci.product_id
        and l.global_stock_id = v_ci.global_stock_id limit 1)
    );

    if v_listing_id is not null then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      where id = v_listing_id and display_quantity_override is not null;
    elsif v_ci.global_stock_id is not null then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id
        and display_quantity_override is not null;
    end if;

    select soi.id into v_order_item_id from public.shop_order_items soi
    where soi.order_id = v_order_id and soi.product_id = v_ci.product_id
      and soi.listing_id is not distinct from v_ci.listing_id order by soi.id asc limit 1;
    if v_order_item_id is null then
      select soi.id into v_order_item_id from public.shop_order_items soi
      where soi.order_id = v_order_id and soi.product_id = v_ci.product_id order by soi.id asc limit 1;
    end if;
    if v_order_item_id is not null then
      update public.shop_order_items
      set listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
      where id = v_order_item_id;
    end if;

    if v_listing_id is not null then
      v_available_after := public.shop_product_grade_available_units(v_cart.tenant_id, v_ci.product_id, v_grade_tag_id);
      if coalesce((select display_quantity_override from public.shop_product_listings where id = v_listing_id), v_available_after, 0) <= 0 then
        update public.shop_product_listings set is_active = false where id = v_listing_id;
      end if;
    elsif v_ci.global_stock_id is not null then
      select coalesce(sum(gs.quantity), 0) into v_available_after from public.global_stocks gs
      where gs.shipment_item_id = (select shipment_item_id from public.global_stocks where id = v_ci.global_stock_id)
        and gs.availability = 'sellable'::public.stock_availability;
      if coalesce((select display_quantity_override from public.shop_product_listings
        where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id),
        v_available_after, 0) <= 0 then
        update public.shop_product_listings set is_active = false
        where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id;
      end if;
    end if;
  end loop;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = v_cart.id);
  update public.shop_carts set status = 'converted', updated_at = now() where id = v_cart.id;

  perform public.recompute_dropship_cod_collect_amount(v_order_id);

  select jsonb_build_object(
    'order_id', v_order_id, 'order_no', v_order_no, 'status', v_order_status,
    'cart_id', v_cart.id, 'shop_id', v_shop.id
  ) into v_result;
  return v_result;
end;
$$;


ALTER FUNCTION "public"."submit_dropship_order_from_cart"("p_shop_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_shipping_post_code" "text", "p_profile_id" bigint, "p_is_prepaid" boolean, "p_delivery_instructions" "text", "p_cod_charge_amount" numeric, "p_delivery_charge_amount" numeric, "p_print_charge_amount" numeric, "p_packing_charge_amount" numeric, "p_discount_amount" numeric, "p_recipient_pays_delivery" boolean, "p_recipient_pays_cod" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_shop_order_from_cart"("p_cart_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_is_prepaid" boolean DEFAULT false, "p_delivery_instructions" "text" DEFAULT NULL::"text", "p_cod_charge_amount" numeric DEFAULT 0, "p_delivery_charge_amount" numeric DEFAULT 0, "p_print_charge_amount" numeric DEFAULT 0, "p_packing_charge_amount" numeric DEFAULT 0, "p_discount_amount" numeric DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cart public.shop_carts%rowtype;
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_item_count integer;
  v_result jsonb;
  v_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_rem_alloc_qty integer;
  v_rem_override_qty integer;
  v_order_tenant_id bigint;
begin
  select * into v_cart from public.shop_carts where id = p_cart_id and status = 'active';
  if v_cart.id is null then
    raise exception 'active cart not found';
  end if;

  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_shop from public.shops where id = v_cart.shop_id;
  if v_shop.id is null or not v_shop.is_active then
    raise exception 'shop not found or inactive';
  end if;
  v_order_tenant_id := public.resolve_parent_tenant_id(v_cart.tenant_id);

  select can_place_order, can_negotiate
  into v_can_place_order, v_can_negotiate
  from public.get_shop_permissions_for_customer(v_shop.id);

  if coalesce(v_can_place_order, false) is not true then
    raise exception 'checkout not allowed for this customer group';
  end if;

  select count(*) into v_item_count from public.shop_cart_items where cart_id = p_cart_id;
  if v_item_count = 0 then
    raise exception 'cart is empty';
  end if;

  if v_shop.shop_type = 'dropship' then
    if exists (
      select 1 from public.shop_cart_items ci
      where ci.cart_id = p_cart_id
        and ci.customer_sell_price_currency_id = ci.unit_minimum_sell_price_currency_id
        and ci.customer_sell_price_amount < ci.unit_minimum_sell_price_amount
    ) then
      raise exception 'price floor violation: some items are priced below the minimum sell price';
    end if;
  end if;

  v_profile_id := p_profile_id;
  if v_profile_id is null then
    v_profile_id := public.resolve_customer_profile_for_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.shop_type = 'vendor_catalog' then
    if v_shop.order_mode <> 'procurement_intent' then
      raise exception 'invalid order mode for vendor catalog shop';
    end if;
    -- Catalog orders always start at submitted (CATALOG_NEGOTIATION.md §2.1); negotiation begins at priced.
    v_order_status := 'submitted';
  else
    if v_shop.order_mode = 'checkout_fixed' then
      v_order_status := 'confirmed';
    else
      v_order_status := 'submitted';
    end if;
  end if;

  select public.generate_shop_order_number(v_order_tenant_id, v_cart.shop_id) into v_order_no;

  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  if v_phone is not null then
    v_profile := public.upsert_recipient_profile_and_address(
      p_tenant_id => v_cart.tenant_id,
      p_name => p_recipient_name,
      p_phone => v_phone,
      p_phone_secondary => p_recipient_phone_secondary,
      p_address => p_shipping_address,
      p_district => p_shipping_district,
      p_thana => p_shipping_thana
    );
    v_recipient_profile_id := (v_profile->>'id')::bigint;
  end if;

  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, profile_id,
    created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  )
  values (
    v_order_tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), 'customer'),
    v_shop.shop_type, v_shop.order_mode,
    coalesce(v_shop.is_negotiable, false) and coalesce(v_can_negotiate, false),
    v_order_status, case when v_order_status = 'negotiating' then 1 else 0 end,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone, nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''), nullif(trim(coalesce(p_shipping_district, '')), ''), nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_profile_id,
    public.current_user_email(),
    p_cod_charge_amount, p_delivery_charge_amount, p_print_charge_amount, p_packing_charge_amount, p_discount_amount,
    p_is_prepaid, p_delivery_instructions, v_shop.deduct_charges_from_margin,
    false, false, v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  )
  returning id into v_order_id;

  insert into public.shop_order_items (
    order_id, product_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id
  )
  select
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_amount else null end,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_currency_id else null end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      else null
    end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      else null
    end,
    case when v_shop.shop_type = 'dropship' then public.resolve_shop_order_item_landed_cost(ci.global_stock_id, null, ci.unit_list_price_amount) else null end,
    case when v_shop.shop_type = 'dropship' then v_shop.buy_currency_id else null end
  from public.shop_cart_items ci
  where ci.cart_id = p_cart_id;

  if v_shop.shop_type = 'dropship' then
    for v_ci in select * from public.shop_cart_items where cart_id = p_cart_id loop
      if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
        update public.shop_product_listings
        set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id
          and display_quantity_override is not null;
      end if;

      if v_ci.global_stock_allocation_id is not null then
        update public.global_stock_allocations
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_allocation_id;
      end if;

      if v_ci.global_stock_id is not null then
        update public.global_stocks
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_id;
      end if;

      if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
        select gsa.quantity into v_rem_alloc_qty
        from public.global_stock_allocations gsa
        where gsa.id = v_ci.global_stock_allocation_id;

        select display_quantity_override into v_rem_override_qty
        from public.shop_product_listings
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id;

        if coalesce(v_rem_override_qty, v_rem_alloc_qty, 0) <= 0 then
          update public.shop_product_listings
          set is_active = false
          where shop_id = v_shop.id
            and product_id = v_ci.product_id
            and global_stock_allocation_id = v_ci.global_stock_allocation_id;
        end if;
      end if;
    end loop;
  end if;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = p_cart_id);

  update public.shop_carts
  set status = 'converted', updated_at = now()
  where id = p_cart_id;

  if v_shop.shop_type = 'vendor_catalog' then
    perform public.notify_catalog_shop_order(
      p_order_id := v_order_id,
      p_notify_staff := true,
      p_notify_customer := false,
      p_event_type := 'catalog.order.created',
      p_title := format('New order %s', v_order_no),
      p_body := format('%s items to price', v_item_count)
    );
  end if;

  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."submit_shop_order_from_cart"("p_cart_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_profile_id" bigint, "p_is_prepaid" boolean, "p_delivery_instructions" "text", "p_cod_charge_amount" numeric, "p_delivery_charge_amount" numeric, "p_print_charge_amount" numeric, "p_packing_charge_amount" numeric, "p_discount_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_dropship_reseller_profit"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_save jsonb;
  v_profile_id bigint;
  v_amount numeric(15,2);
  v_parent_tenant_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement draft is required before crediting reseller profit';
  end if;

  if v_order.status = 'reseller_paid'::public.shop_order_status
     or v_settlement.merchant_payout_at is not null
     or v_settlement.status = 'confirmed' then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already credited to merchant wallet',
      'order_id', p_order_id,
      'status', coalesce(v_order.status::text, 'reseller_paid')
    );
  end if;

  if v_order.courier_remittance_ref is null
     and v_settlement.remittance_at is null
     and v_order.status <> 'payment_received'::public.shop_order_status then
    raise exception 'Courier remittance must be recorded before crediting reseller profit (current: %)', v_order.status;
  end if;

  if p_payload is not null and p_payload <> '{}'::jsonb then
    v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
    if coalesce(v_save->>'success', 'false') <> 'true' then
      return v_save;
    end if;

    select * into v_settlement
    from public.dropship_order_settlements
    where shop_order_id = p_order_id;
  end if;

  v_profile_id := coalesce(v_order.profile_id, v_settlement.profile_id);
  if v_profile_id is null then
    raise exception 'billing profile is required for reseller profit credit';
  end if;

  v_amount := coalesce(v_settlement.reseller_profit, 0);
  if v_amount <= 0 then
    return jsonb_build_object(
      'success', true,
      'skipped', true,
      'message', 'No reseller profit to credit',
      'order_id', p_order_id,
      'amount', 0
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if exists (
    select 1
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = p_order_id::text
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = v_profile_id
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit'
  ) then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already credited to merchant wallet',
      'order_id', p_order_id,
      'amount', v_amount
    );
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => v_order.tenant_id,
    p_entity_type => 'customer',
    p_entity_id => v_profile_id,
    p_type => 'credit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'transaction_type', 'dropship_profit',
      'label', 'Dropship profit earned',
      'order_no', v_order.order_no,
      'order_id', p_order_id,
      'shop_order_id', p_order_id::text,
      'invoice_id', v_order.global_invoice_id,
      'notes', coalesce(
        nullif(trim(p_payload->>'reference_notes'), ''),
        'Dropship reseller profit for order #' || v_order.order_no
      )
    )
  );

  update public.dropship_order_settlements
  set
    status = 'confirmed',
    confirmed_at = now(),
    confirmed_by = auth.uid(),
    merchant_payout_at = now(),
    updated_at = now()
  where id = v_settlement.id;

  update public.shop_orders
  set
    status = 'reseller_paid'::public.shop_order_status,
    payout_settlement_status = 'paid',
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Reseller profit credited to merchant wallet',
    'order_id', p_order_id,
    'amount', v_amount,
    'status', 'reseller_paid',
    'profile_id', v_profile_id
  );
end;
$$;


ALTER FUNCTION "public"."transfer_dropship_reseller_profit"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_catalog_order_item_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_item_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_product_id bigint;
  v_product_weight_gm numeric;
  v_package_weight_gm numeric;
begin
  if p_tenant_id is null or p_order_id is null or p_item_id is null then
    raise exception 'tenant, order, and item required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found
     or (v_order.tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_order_items soi
  set
    weight_kg = case when p_payload ? 'weight_kg' then (p_payload->>'weight_kg')::numeric else soi.weight_kg end,
    cost_price_amount = case when p_payload ? 'cost_price_amount' then (p_payload->>'cost_price_amount')::numeric else soi.cost_price_amount end,
    staff_offer_amount = case when p_payload ? 'staff_offer_amount' then (p_payload->>'staff_offer_amount')::numeric else soi.staff_offer_amount end,
    is_first_offer_manual = case when p_payload ? 'is_first_offer_manual' then coalesce((p_payload->>'is_first_offer_manual')::boolean, false) else soi.is_first_offer_manual end,
    customer_offer_amount = case when p_payload ? 'customer_offer_amount' then (p_payload->>'customer_offer_amount')::numeric else soi.customer_offer_amount end,
    customer_offer_currency_id = case when p_payload ? 'customer_offer_currency_id' then nullif(p_payload->>'customer_offer_currency_id', '')::bigint else soi.customer_offer_currency_id end,
    final_price_amount = case when p_payload ? 'final_price_amount' then (p_payload->>'final_price_amount')::numeric else soi.final_price_amount end,
    is_final_offer_manual = case when p_payload ? 'is_final_offer_manual' then coalesce((p_payload->>'is_final_offer_manual')::boolean, false) else soi.is_final_offer_manual end,
    confirmed_quantity = case when p_payload ? 'confirmed_quantity' then (p_payload->>'confirmed_quantity')::integer else soi.confirmed_quantity end,
    quantity = case when p_payload ? 'quantity' then (p_payload->>'quantity')::integer else soi.quantity end,
    updated_at = now()
  where soi.id = p_item_id and soi.order_id = p_order_id;

  select soi.product_id into v_product_id
  from public.shop_order_items soi
  where soi.id = p_item_id and soi.order_id = p_order_id;

  v_product_weight_gm := nullif(p_payload->>'product_weight_gm', '')::numeric;
  v_package_weight_gm := nullif(p_payload->>'package_weight_gm', '')::numeric;

  if v_product_id is not null
     and (
       (v_product_weight_gm is not null and v_product_weight_gm > 0)
       or (v_package_weight_gm is not null and v_package_weight_gm > 0)
     ) then
    update public.products p
    set
      product_weight = case
        when v_product_weight_gm is not null and v_product_weight_gm > 0 then v_product_weight_gm
        else p.product_weight
      end,
      package_weight = case
        when v_package_weight_gm is not null and v_package_weight_gm > 0 then v_package_weight_gm
        else p.package_weight
      end,
      updated_at = now()
    where p.id = v_product_id;
  end if;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."update_catalog_order_item_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_item_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_catalog_order_rates_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant and order required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found
     or (v_order.tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    conversion_rate = case when p_payload ? 'conversion_rate' then (p_payload->>'conversion_rate')::numeric else o.conversion_rate end,
    cargo_rate = case when p_payload ? 'cargo_rate' then (p_payload->>'cargo_rate')::numeric else o.cargo_rate end,
    profit_rate = case when p_payload ? 'profit_rate' then (p_payload->>'profit_rate')::numeric else o.profit_rate end,
    first_offer_rate = case when p_payload ? 'first_offer_rate' then (p_payload->>'first_offer_rate')::numeric else o.first_offer_rate end,
    final_offer_rate = case when p_payload ? 'final_offer_rate' then (p_payload->>'final_offer_rate')::numeric else o.final_offer_rate end,
    profit_basis = case when p_payload ? 'profit_basis' then nullif(p_payload->>'profit_basis', '') else o.profit_basis end,
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."update_catalog_order_rates_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_shop_order_charges_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant and order required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found or (v_order.tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    delivery_charge_amount = coalesce((p_payload->>'delivery_charge_amount')::numeric, o.delivery_charge_amount),
    deduct_delivery_from_margin = coalesce((p_payload->>'deduct_delivery_from_margin')::boolean, o.deduct_delivery_from_margin),
    cod_charge_amount = coalesce((p_payload->>'cod_charge_amount')::numeric, o.cod_charge_amount),
    deduct_cod_from_margin = coalesce((p_payload->>'deduct_cod_from_margin')::boolean, o.deduct_cod_from_margin),
    print_charge_amount = coalesce((p_payload->>'print_charge_amount')::numeric, o.print_charge_amount),
    deduct_print_from_margin = coalesce((p_payload->>'deduct_print_from_margin')::boolean, o.deduct_print_from_margin),
    packing_charge_amount = coalesce((p_payload->>'packing_charge_amount')::numeric, o.packing_charge_amount),
    deduct_packing_from_margin = coalesce((p_payload->>'deduct_packing_from_margin')::boolean, o.deduct_packing_from_margin),
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."update_shop_order_charges_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_shop_order_status_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_status" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null or p_status is null then
    raise exception 'tenant, order, and status required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found or (v_order.tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    status = p_status::public.shop_order_status,
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."update_shop_order_status_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_status" "text") OWNER TO "postgres";


DROP TRIGGER IF EXISTS trg_shop_orders_set_parent_tenant_id ON public.shop_orders;
DROP TRIGGER IF EXISTS trg_shops_set_parent_tenant_id ON public.shops;
DROP FUNCTION IF EXISTS public.set_shop_parent_tenant_id();

DROP INDEX IF EXISTS public.idx_shop_orders_parent_tenant_created_at;
DROP INDEX IF EXISTS public.idx_shop_orders_parent_tenant_id;
DROP INDEX IF EXISTS public.idx_shops_parent_tenant_id;

ALTER TABLE public.shop_orders DROP CONSTRAINT IF EXISTS shop_orders_parent_tenant_id_fkey;
ALTER TABLE public.shops DROP CONSTRAINT IF EXISTS shops_parent_tenant_id_fkey;

ALTER TABLE public.shop_orders DROP COLUMN IF EXISTS parent_tenant_id;
ALTER TABLE public.shops DROP COLUMN IF EXISTS parent_tenant_id;
