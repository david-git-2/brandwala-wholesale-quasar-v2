


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';


CREATE TYPE "public"."app_role" AS ENUM (
    'superadmin',
    'admin',
    'staff',
    'viewer',
    'investor',
    'manager',
    'cashier'
);


ALTER TYPE "public"."app_role" OWNER TO "postgres";


CREATE TYPE "public"."commerce_order_status" AS ENUM (
    'placed',
    'reviewing',
    'shipping',
    'delivered',
    'cancelled'
);


ALTER TYPE "public"."commerce_order_status" OWNER TO "postgres";


CREATE TYPE "public"."customer_group_role" AS ENUM (
    'admin',
    'negotiator',
    'staff'
);


ALTER TYPE "public"."customer_group_role" OWNER TO "postgres";


CREATE TYPE "public"."investor_payment_method" AS ENUM (
    'cash',
    'bank',
    'mobile_banking',
    'other'
);


ALTER TYPE "public"."investor_payment_method" OWNER TO "postgres";


CREATE TYPE "public"."investor_transaction_type" AS ENUM (
    'deposit',
    'withdrawal',
    'profit_payout',
    'capital_in',
    'capital_adjustment',
    'withdrawal_paid',
    'profit_reinvest',
    'manual_adjustment'
);


ALTER TYPE "public"."investor_transaction_type" OWNER TO "postgres";


CREATE TYPE "public"."koba_order_status" AS ENUM (
    'pending',
    'confirmed',
    'processing',
    'shipped',
    'delivered',
    'cancelled'
);


ALTER TYPE "public"."koba_order_status" OWNER TO "postgres";


CREATE TYPE "public"."order_status" AS ENUM (
    'customer_submit',
    'direct_priced',
    'priced',
    'negotiate',
    'final_offered',
    'ordered',
    'processing',
    'invoicing',
    'invoiced'
);


ALTER TYPE "public"."order_status" OWNER TO "postgres";


    'NEW_WITH_TAGS',
    'EXCELLENT',
    'GOOD',
    'FAIR'
);


ALTER TYPE "public"."thrift_condition" OWNER TO "postgres";


CREATE TYPE "public"."thrift_delivery_status" AS ENUM (
    'PENDING',
    'SHIPPED',
    'DELIVERED',
    'RETURNED',
    'PARTIALLY_RETURNED'
);


ALTER TYPE "public"."thrift_delivery_status" OWNER TO "postgres";


CREATE TYPE "public"."thrift_item_status" AS ENUM (
    'SOLD',
    'RETURNED'
);


ALTER TYPE "public"."thrift_item_status" OWNER TO "postgres";


CREATE TYPE "public"."thrift_ledger_source" AS ENUM (
    'INVOICE',
    'SHIPMENT',
    'OPERATIONAL'
);


ALTER TYPE "public"."thrift_ledger_source" OWNER TO "postgres";


CREATE TYPE "public"."thrift_ledger_type" AS ENUM (
    'REVENUE',
    'EXPENSE',
    'REFUND',
    'LOSS'
);


ALTER TYPE "public"."thrift_ledger_type" OWNER TO "postgres";


CREATE TYPE "public"."thrift_payment_status" AS ENUM (
    'UNPAID',
    'PAID',
    'REFUNDED'
);


ALTER TYPE "public"."thrift_payment_status" OWNER TO "postgres";


CREATE TYPE "public"."thrift_return_action" AS ENUM (
    'RESTOCK',
    'WRITE_OFF'
);


ALTER TYPE "public"."thrift_return_action" OWNER TO "postgres";


CREATE TYPE "public"."thrift_section" AS ENUM (
    'MALE',
    'FEMALE',
    'UNISEX',
    'KIDS',
    'HOME'
);


ALTER TYPE "public"."thrift_section" OWNER TO "postgres";


CREATE TYPE "public"."thrift_stock_status" AS ENUM (
    'AVAILABLE',
    'OUT_OF_STOCK',
    'DAMAGED',
    'STOLEN',
    'SOLD',
    'RESERVED'
);


ALTER TYPE "public"."thrift_stock_status" OWNER TO "postgres";


CREATE TYPE "public"."thrift_stock_type" AS ENUM (
    'SINGLE',
    'BULK'
);


ALTER TYPE "public"."thrift_stock_type" OWNER TO "postgres";


CREATE TYPE "public"."thrift_transaction_method" AS ENUM (
    'CASH',
    'CARD',
    'MOBILE_BANKING',
    'COD'
);


ALTER TYPE "public"."thrift_transaction_method" OWNER TO "postgres";


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE OR REPLACE FUNCTION "public"."add_item_to_cart"("p_tenant_id" bigint, "p_store_id" bigint DEFAULT NULL::bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_can_see_price" boolean DEFAULT false, "p_product_id" bigint DEFAULT NULL::bigint, "p_name" "text" DEFAULT NULL::"text", "p_image_url" "text" DEFAULT NULL::"text", "p_price_bdt" numeric DEFAULT NULL::numeric, "p_minimum_sell_price_bdt" numeric DEFAULT NULL::numeric, "p_quantity" integer DEFAULT 1, "p_minimum_quantity" integer DEFAULT 1) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cart public.carts;
  v_item public.cart_items;
  v_existing_item public.cart_items;
  v_min_qty integer;
  v_name text;
  v_effective_price_bdt numeric;
  v_effective_min_sell_bdt numeric;
begin
  v_qty := greatest(coalesce(p_quantity, 1), 1);
  v_min_qty := greatest(coalesce(p_minimum_quantity, 1), 1);
  v_name := coalesce(nullif(trim(p_name), ''), 'Unnamed product');

  v_effective_price_bdt := p_price_bdt;
  v_effective_min_sell_bdt := p_minimum_sell_price_bdt;

  if p_product_id is not null and p_store_id is not null then
    select
      spp.price_bdt,
      spp.minimum_sell_price_bdt
    into
      v_effective_price_bdt,
      v_effective_min_sell_bdt
    from public.store_product_prices spp
    where spp.tenant_id = p_tenant_id
      and spp.store_id = p_store_id
      and spp.product_id = p_product_id
      and spp.is_active = true
    limit 1;
  -- Removed contradictory check:
  -- (v_effective_price_bdt < v_effective_min_sell_bdt) is natural and correct 
  -- now that price_bdt is wholesale and minimum_sell_price_bdt is retail threshold.

  select *
  into v_cart
  from public.carts c
  where c.tenant_id = p_tenant_id
    and c.store_id is not distinct from p_store_id
    and c.customer_group_id is not distinct from p_customer_group_id
  order by c.id desc
  limit 1;

  if v_cart.id is null then
    insert into public.carts (
      tenant_id,
      store_id,
      customer_group_id,
      can_see_price
    )
    values (
      p_tenant_id,
      p_store_id,
      p_customer_group_id,
      coalesce(p_can_see_price, false)
    )
    returning * into v_cart;
  if p_product_id is not null then
    select *
    into v_existing_item
    from public.cart_items ci
    where ci.cart_id = v_cart.id
      and ci.product_id = p_product_id
    limit 1;
  if v_existing_item.id is not null then
    update public.cart_items
    set
      quantity = v_existing_item.quantity + v_qty,
      minimum_quantity = v_min_qty,
      name = v_name,
      image_url = coalesce(p_image_url, v_existing_item.image_url),
      price_bdt = coalesce(v_effective_price_bdt, v_existing_item.price_bdt),
      minimum_sell_price_bdt = coalesce(v_effective_min_sell_bdt, v_existing_item.minimum_sell_price_bdt),
      price_gbp = coalesce(v_effective_price_bdt, v_existing_item.price_bdt, v_existing_item.price_gbp)
    where id = v_existing_item.id
    returning * into v_item;
  else
    insert into public.cart_items (
      cart_id,
      product_id,
      name,
      image_url,
      price_bdt,
      minimum_sell_price_bdt,
      price_gbp,
      quantity,
      minimum_quantity
    )
    values (
      v_cart.id,
      p_product_id,
      v_name,
      p_image_url,
      v_effective_price_bdt,
      v_effective_min_sell_bdt,
      v_effective_price_bdt,
      v_qty,
      v_min_qty
    )
    returning * into v_item;
  return jsonb_build_object(
    'cart', to_jsonb(v_cart),
    'item', to_jsonb(v_item)
  );
ALTER FUNCTION "public"."add_item_to_cart"("p_tenant_id" bigint, "p_store_id" bigint, "p_customer_group_id" bigint, "p_can_see_price" boolean, "p_product_id" bigint, "p_name" "text", "p_image_url" "text", "p_price_bdt" numeric, "p_minimum_sell_price_bdt" numeric, "p_quantity" integer, "p_minimum_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_item_to_commerce_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_global_stock_id" bigint, "p_quantity" integer DEFAULT 1) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_existing public.commerce_cart;
  v_row public.commerce_cart;
  select product_id into v_product_id
  from public.global_stocks
  where id = p_global_stock_id
    and parent_tenant_id = v_parent_id;

  if v_product_id is null and not exists (
    select 1 from public.global_stocks where id = p_global_stock_id and parent_tenant_id = v_parent_id
  ) then
    raise exception 'global stock not found for tenant parent';
  select *
  into v_existing
  from public.commerce_cart
  where tenant_id = p_tenant_id
    and customer_group_id = p_customer_group_id
    and global_stock_id = p_global_stock_id
  limit 1;

  if v_existing.id is not null then
    update public.commerce_cart
    set quantity = v_existing.quantity + greatest(p_quantity, 1),
        updated_at = now()
    where id = v_existing.id
    returning * into v_row;
  else
    insert into public.commerce_cart (
      tenant_id,
      customer_group_id,
      global_stock_id,
      inventory_item_id,
      product_id,
      quantity
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      p_global_stock_id,
      null,
      v_product_id,
      greatest(p_quantity, 1)
    )
    returning * into v_row;
  return to_jsonb(v_row);
ALTER FUNCTION "public"."add_item_to_commerce_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_global_stock_id" bigint, "p_quantity" integer) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invoice_payments" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "payment_id" bigint NOT NULL,
    "invoice_id" bigint,
    "amount" numeric(12,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "global_invoice_id" bigint,
    "commerce_invoice_id" bigint,
    CONSTRAINT "payment_allocations_amount_check" CHECK (("amount" > (0)::numeric))
);


ALTER TABLE "public"."invoice_payments" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_payment_allocation"("p_tenant_id" bigint, "p_payment_id" bigint, "p_invoice_id" bigint, "p_amount" numeric) RETURNS "public"."invoice_payments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_payment public.payments;
  v_invoice public.invoices;
  v_allocated_total numeric(12,2);
  v_remaining numeric(12,2);
  v_due numeric(12,2);
  v_row public.payment_allocations;
begin
  if p_tenant_id is null or p_payment_id is null or p_invoice_id is null then
    raise exception 'Tenant, payment and invoice are required.';
  select *
  into v_payment
  from public.payments
  where id = p_payment_id
  for update;

  if v_payment.tenant_id <> p_tenant_id then
    raise exception 'Payment does not belong to tenant.';
  select *
  into v_invoice
  from public.invoices
  where id = p_invoice_id
  for update;

  if v_invoice.tenant_id <> p_tenant_id then
    raise exception 'Invoice does not belong to tenant.';
  select coalesce(sum(amount), 0)
  into v_allocated_total
  from public.payment_allocations
  where payment_id = p_payment_id;

  v_remaining := coalesce(v_payment.amount, 0) - coalesce(v_allocated_total, 0);
  if p_amount > v_remaining then
    raise exception 'Allocation amount exceeds payment remaining amount.';
  v_due := coalesce(v_invoice.total_amount, 0) - coalesce(v_invoice.paid_amount, 0);
  if p_amount > v_due then
    raise exception 'Allocation amount exceeds invoice due amount.';
  insert into public.payment_allocations (
    tenant_id,
    payment_id,
    invoice_id,
    amount
  )
  values (
    p_tenant_id,
    p_payment_id,
    p_invoice_id,
    p_amount
  )
  returning * into v_row;

  update public.invoices
  set paid_amount = coalesce(paid_amount, 0) + p_amount,
      updated_at = now()
  where id = p_invoice_id;

  perform public.recompute_invoice_payment_status(p_invoice_id);

  ALTER FUNCTION "public"."add_payment_allocation"("p_tenant_id" bigint, "p_payment_id" bigint, "p_invoice_id" bigint, "p_amount" numeric) OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_remaining integer := coalesce(p_delta, 0);
  v_rec record;
  v_take integer;
  v_slack integer;
begin
  if v_remaining = 0 or p_product_id is null then
    return;
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
      v_take := least(v_remaining, v_slack);

      update public.inventory_stocks
      set reserved_quantity = coalesce(reserved_quantity, 0) + v_take
      where id = v_rec.id;

      v_remaining := v_remaining - v_take;
      exit when v_remaining = 0;
    if v_remaining > 0 then
      raise exception 'Not enough stock to reserve for product %.', p_product_id;
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
    ALTER FUNCTION "public"."adjust_inventory_reserved_for_product"("p_tenant_id" bigint, "p_product_id" bigint, "p_delta" integer) OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'INSERT' then
    if new.product_id is null then
      return new;
    select tenant_id into v_tenant_id from public.carts where id = new.cart_id;
    perform public.adjust_inventory_reserved_for_product(v_tenant_id, new.product_id, new.quantity);
    if tg_op = 'UPDATE' then
    select tenant_id into v_tenant_id from public.carts where id = new.cart_id;

    if old.product_id is not null then
      perform public.adjust_inventory_reserved_for_product(v_tenant_id, old.product_id, -old.quantity);
    if new.product_id is not null then
      perform public.adjust_inventory_reserved_for_product(v_tenant_id, new.product_id, new.quantity);
    if tg_op = 'DELETE' then
    if old.product_id is null then
      return old;
    select tenant_id into v_tenant_id from public.carts where id = old.cart_id;
    perform public.adjust_inventory_reserved_for_product(v_tenant_id, old.product_id, -old.quantity);
    return old;
  ALTER FUNCTION "public"."apply_cart_item_inventory_reservation"() OWNER TO "postgres";


    LANGUAGE "sql" STABLE
    AS $$
  select lower(trim(coalesce(auth.jwt() ->> 'email', '')))
$$;


ALTER FUNCTION "public"."current_user_email"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tags" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "color" "text" DEFAULT '#6366f1'::"text" NOT NULL,
    "type" "text" DEFAULT 'general'::"text" NOT NULL,
    "created_by_email" "text" DEFAULT "public"."current_user_email"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "group_name" "text",
    "sort_order" integer,
    "category_id" bigint,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "is_system" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."tags" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customer_group_members" (
    "id" bigint NOT NULL,
    "customer_group_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "email" "text" NOT NULL,
    "role" "public"."customer_group_role" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "added_by" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tenant_role_id" bigint
);


ALTER TABLE "public"."customer_group_members" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_customer_group_member_role"("p_cgm_id" bigint, "p_tenant_role_id" bigint) RETURNS "public"."customer_group_members"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_member public.customer_group_members;
  v_group public.customer_groups;
  v_role public.tenant_roles;
begin
  select * into v_member from public.customer_group_members where id = p_cgm_id;
  if v_member.id is null then
    raise exception 'Customer group member not found';
  select * into v_group from public.customer_groups where id = v_member.customer_group_id;
  if v_group.id is null then
    raise exception 'Customer group not found';
  if not public.user_is_tenant_admin(v_group.tenant_id) then
    raise exception 'Unauthorized';
  select * into v_role from public.tenant_roles where id = p_tenant_role_id;
  if v_role.id is null then
    raise exception 'Role not found';
  if v_role.tenant_id <> v_group.tenant_id then
    raise exception 'Role and Customer group member must belong to the same tenant';
  if v_role.scope <> 'shop' then
    raise exception 'Role scope must be shop for customer group members';
  update public.customer_group_members
  set
    tenant_role_id = p_tenant_role_id,
    updated_at = now()
  where id = p_cgm_id
  returning * into v_member;

  return v_member;
ALTER FUNCTION "public"."assign_customer_group_member_role"("p_cgm_id" bigint, "p_tenant_role_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."memberships" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "role" "public"."app_role" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "email" "text" NOT NULL,
    "accent_color" "text",
    "preference" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "investor_id" bigint,
    "tenant_role_id" bigint,
    CONSTRAINT "memberships_role_tenant_check" CHECK (((("role" = 'superadmin'::"public"."app_role") AND ("tenant_id" IS NULL)) OR (("role" <> 'superadmin'::"public"."app_role") AND ("tenant_id" IS NOT NULL))))
);


ALTER TABLE "public"."memberships" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_membership_role"("p_membership_id" bigint, "p_tenant_role_id" bigint) RETURNS "public"."memberships"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_member public.memberships;
  v_role public.tenant_roles;
begin
  select * into v_member from public.memberships where id = p_membership_id;
  if v_member.id is null then
    raise exception 'Membership not found';
  if not public.user_is_tenant_admin(v_member.tenant_id) then
    raise exception 'Unauthorized';
  select * into v_role from public.tenant_roles where id = p_tenant_role_id;
  if v_role.id is null then
    raise exception 'Role not found';
  if v_role.tenant_id <> v_member.tenant_id then
    raise exception 'Role and Membership must belong to the same tenant';
  if v_role.scope <> 'app' then
    raise exception 'Role scope must be app for internal memberships';
  update public.memberships
  set
    tenant_role_id = p_tenant_role_id,
    updated_at = now()
  where id = p_membership_id
  returning * into v_member;

  return v_member;
ALTER FUNCTION "public"."assign_membership_role"("p_membership_id" bigint, "p_tenant_role_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_order_tenant_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id
  into v_tenant_id
  from public.customer_groups cg
  where cg.id = new.customer_group_id;

  if v_tenant_id is null then
    raise exception 'customer_group_id % is invalid or has no tenant', new.customer_group_id;
  if tg_op = 'UPDATE' and old.tenant_id is not null and old.tenant_id <> v_tenant_id then
    raise exception 'changing order across tenants is not allowed';
  new.tenant_id := v_tenant_id;

  if new.tenant_order_id is null then
    new.tenant_order_id := public.next_tenant_scoped_counter(new.tenant_id, 'order');
  ALTER FUNCTION "public"."assign_order_tenant_fields"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auth_investor_id"() RETURNS bigint
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_investor_id bigint;
begin
  select investor_id into v_investor_id
  from public.memberships
  where lower(trim(email)) = public.current_user_email()
    and is_active = true
    and role = 'investor'::public.app_role
  limit 1;

  return v_investor_id;
ALTER FUNCTION "public"."auth_investor_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_enable_universal_wallet_for_new_tenant"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.tenant_modules (tenant_id, module_key, is_active)
  values (NEW.id, 'universal_wallet', true)
  on conflict (tenant_id, module_key) do update set is_active = true;
  return NEW;
ALTER FUNCTION "public"."auto_enable_universal_wallet_for_new_tenant"() OWNER TO "postgres";


    "id" bigint NOT NULL,
    "order_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "image_url" "text",
    "price_gbp" numeric(12,2),
    "cost_gbp" numeric(12,2),
    "cost_bdt" numeric(12,2),
    "first_offer_bdt" numeric(12,2),
    "customer_offer_bdt" numeric(12,2),
    "final_offer_bdt" numeric(12,2),
    "product_weight" numeric(12,3),
    "package_weight" numeric(12,3),
    "minimum_quantity" integer DEFAULT 1 NOT NULL,
    "product_id" bigint,
    "ordered_quantity" integer DEFAULT 0 NOT NULL,
    "delivered_quantity" integer DEFAULT 0 NOT NULL,
    "returned_quantity" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "barcode" "text",
    "product_code" "text",
    "shipment_id" bigint,
    CONSTRAINT "order_items_delivered_quantity_check" CHECK (("delivered_quantity" >= 0)),
    CONSTRAINT "order_items_minimum_quantity_check" CHECK (("minimum_quantity" > 0)),
    CONSTRAINT "order_items_ordered_quantity_check" CHECK (("ordered_quantity" >= 0)),
    CONSTRAINT "order_items_returned_quantity_check" CHECK (("returned_quantity" >= 0))
);


ALTER TABLE "public"."order_items" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_update_order_item_offers"("p_items" "jsonb") RETURNS SETOF "public"."order_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  for v_item in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_id := nullif(v_item->>'id', '')::bigint;

    if v_id is null then
      continue;
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
    return;
ALTER FUNCTION "public"."bulk_update_order_item_offers"("p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_update_order_items"("p_items" "jsonb") RETURNS SETOF "public"."order_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item jsonb;
  v_id bigint;
  v_patch jsonb;
  v_updated public.order_items;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a JSON array';
  for v_item in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_id := nullif(v_item->>'id', '')::bigint;

    if v_id is null then
      continue;
    v_patch := v_item
      - 'id'
      - 'created_at'
      - 'updated_at';

    update public.order_items oi
    set (
      order_id,
      shipment_id,
      name,
      image_url,
      price_gbp,
      cost_gbp,
      cost_bdt,
      first_offer_bdt,
      customer_offer_bdt,
      final_offer_bdt,
      product_weight,
      package_weight,
      minimum_quantity,
      product_id,
      ordered_quantity,
      delivered_quantity,
      returned_quantity
    ) = (
      select
        r.order_id,
        r.shipment_id,
        r.name,
        r.image_url,
        r.price_gbp,
        r.cost_gbp,
        r.cost_bdt,
        r.first_offer_bdt,
        r.customer_offer_bdt,
        r.final_offer_bdt,
        r.product_weight,
        r.package_weight,
        r.minimum_quantity,
        r.product_id,
        r.ordered_quantity,
        r.delivered_quantity,
        r.returned_quantity
      from jsonb_populate_record(oi, v_patch) as r
    )
    where oi.id = v_id
    returning oi.* into v_updated;

    if v_updated.id is not null then
      return next v_updated;
    return;
ALTER FUNCTION "public"."bulk_update_order_items"("p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_update_thrift_stock_locations"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_shelf_id" bigint DEFAULT NULL::bigint, "p_box_id" bigint DEFAULT NULL::bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE thrift_stocks
  SET shelf_id = p_shelf_id, box_id = p_box_id, updated_at = now()
  WHERE tenant_id = p_tenant_id AND id = ANY(p_stock_ids);
END; ALTER FUNCTION "public"."bulk_update_thrift_stock_locations"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_shelf_id" bigint, "p_box_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_update_thrift_stock_statuses"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_status" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF upper(trim(coalesce(p_status, ''))) = 'RESERVED' THEN
    RAISE EXCEPTION 'Use hold_thrift_stock to place holds (RESERVED)';
  END IF;

  UPDATE public.thrift_stocks
  SET status = p_status::public.thrift_stock_status,
      updated_at = now()
  WHERE tenant_id = p_tenant_id
    AND id = ANY(p_stock_ids);
END;
ALTER FUNCTION "public"."bulk_update_thrift_stock_statuses"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bump_tenant_permission_version"("p_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.tenant_permission_versions (tenant_id, version, updated_at)
  values (p_tenant_id, 1, now())
  on conflict (tenant_id) do update set
    version = tenant_permission_versions.version + 1,
    updated_at = now();
ALTER FUNCTION "public"."bump_tenant_permission_version"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_thrift_invoice_total"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_invoice_id bigint;
begin
  if tg_op = 'DELETE' then
    v_invoice_id := old.invoice_id;
  else
    v_invoice_id := new.invoice_id;
  update public.thrift_invoices
  set total_invoice_amount = coalesce((
    select sum(sold_price * quantity)
    from public.thrift_invoice_items
    where invoice_id = v_invoice_id
  ), 0.00) 
  + cod_charge 
  + packing_charge 
  + invoice_print_charge 
  + shipping_charge_customer
  where id = v_invoice_id;

  ALTER FUNCTION "public"."calculate_thrift_invoice_total"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_thrift_item_net_profit"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_landed numeric(12, 2);
begin
  if tg_op = 'INSERT' or new.landed_unit_cost_at_sale is null or new.landed_unit_cost_at_sale = 0 then
    v_landed := coalesce(public.compute_thrift_landed_unit_cost(new.stock_id), 0.00);
    new.landed_unit_cost_at_sale := v_landed;
  else
    v_landed := new.landed_unit_cost_at_sale;
  new.net_profit := (new.sold_price - v_landed) * new.quantity
                    - new.platform_fees
                    - new.shipping_cost_paid_by_shop;

  ALTER FUNCTION "public"."calculate_thrift_item_net_profit"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_access_cart"("p_cart_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
ALTER FUNCTION "public"."can_access_cart"("p_cart_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_access_cart_item"("p_cart_item_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
ALTER FUNCTION "public"."can_access_cart_item"("p_cart_item_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_assign_membership_role"("p_target_tenant_id" bigint, "p_target_role" "public"."app_role") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_target_tenant_id)
      and p_target_role in ('staff', 'viewer', 'investor')
    )
$$;


ALTER FUNCTION "public"."can_assign_membership_role"("p_target_tenant_id" bigint, "p_target_role" "public"."app_role") OWNER TO "postgres";


    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.store_access sa
    join public.customer_group_members cgm
      on cgm.customer_group_id = sa.customer_group_id
    where sa.store_id = p_store_id
      and sa.status = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
  )
$$;


ALTER FUNCTION "public"."can_customer_access_store"("p_store_id" bigint) OWNER TO "postgres";


    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.store_access sa
    join public.customer_group_members cgm
      on cgm.customer_group_id = sa.customer_group_id
    where sa.store_id = p_store_id
      and sa.status = true
      and sa.see_price = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
  )
$$;


ALTER FUNCTION "public"."can_customer_see_store_price"("p_store_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_insert_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_store_id" bigint DEFAULT NULL::bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
ALTER FUNCTION "public"."can_insert_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_store_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_insert_cart_item"("p_cart_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.can_access_cart(p_cart_id);
ALTER FUNCTION "public"."can_insert_cart_item"("p_cart_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_customer_group"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
$$;


ALTER FUNCTION "public"."can_manage_customer_group"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_customer_group_member"("p_customer_group_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and public.can_manage_customer_group(cg.tenant_id)
  )
$$;


ALTER FUNCTION "public"."can_manage_customer_group_member"("p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_membership"("p_target_tenant_id" bigint, "p_target_role" "public"."app_role") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.can_assign_membership_role(p_target_tenant_id, p_target_role)
$$;


ALTER FUNCTION "public"."can_manage_membership"("p_target_tenant_id" bigint, "p_target_role" "public"."app_role") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_products"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or public.membership_has_module_action(p_tenant_id, 'products', 'edit');
ALTER FUNCTION "public"."can_manage_products"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_store"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
$$;


ALTER FUNCTION "public"."can_manage_store"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_update_membership_row"("p_existing_tenant_id" bigint, "p_existing_role" "public"."app_role") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_existing_tenant_id)
      and p_existing_role in ('staff', 'viewer', 'investor')
    )
$$;


ALTER FUNCTION "public"."can_update_membership_row"("p_existing_tenant_id" bigint, "p_existing_role" "public"."app_role") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_products_customer"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.customer_group_members cgm
    join public.customer_groups cg
      on cg.id = cgm.customer_group_id
    where cg.tenant_id = p_tenant_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
      and cg.is_active = true
  )
$$;


ALTER FUNCTION "public"."can_view_products_customer"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_products_internal"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or public.membership_has_module_action(p_tenant_id, 'products', 'view');
ALTER FUNCTION "public"."can_view_products_internal"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_tenant_modules"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or exists (
      select 1
      from public.customer_group_members cgm
      inner join public.customer_groups cg
        on cg.id = cgm.customer_group_id
      where cg.tenant_id = p_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cg.is_active = true
        and cgm.is_active = true
    )
$$;


ALTER FUNCTION "public"."can_view_tenant_modules"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cart_exists"("p_cart_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.carts c
    where c.id = p_cart_id
  );
ALTER FUNCTION "public"."cart_exists"("p_cart_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ceil_thrift_retail_price"("p_price" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE PARALLEL SAFE
    AS $$
DECLARE
  n numeric;
  century numeric;
  ending numeric;
  candidate numeric;
BEGIN
  IF p_price IS NULL OR p_price <= 0 THEN
    RETURN 50;
  END IF;

  n := ceil(p_price);
  century := floor(n / 100) * 100;

  LOOP
    FOREACH ending IN ARRAY ARRAY[50, 90]::numeric[] LOOP
      candidate := century + ending;
      IF candidate >= n THEN
        RETURN candidate;
      END IF;
    END LOOP;
    century := century + 100;
  END LOOP;
END;
ALTER FUNCTION "public"."ceil_thrift_retail_price"("p_price" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."ceil_thrift_retail_price"("p_price" numeric) IS 'Ceil to next thrift retail ending (.50 / .90); matches web ceilThriftRetailPrice.';


CREATE OR REPLACE FUNCTION "public"."check_login_membership"("p_email" "text", "p_scope" "text") RETURNS TABLE("has_match" boolean, "matched_role" "public"."app_role", "member_id" bigint, "member_email" "text", "member_tenant_id" bigint, "member_is_active" boolean, "member_created_at" timestamp with time zone, "member_updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_roles public.app_role[];
  v_email text;
begin
  case lower(coalesce(p_scope, ''))
    when 'platform' then
      v_roles := array['superadmin'::public.app_role];
    when 'app' then
      v_roles := array['admin'::public.app_role, 'staff'::public.app_role, 'viewer'::public.app_role];
    else
      v_roles := array[]::public.app_role[];
  end case;

  v_email := lower(trim(coalesce(p_email, auth.jwt() ->> 'email', '')));

  select m.role,
         m.id,
         m.email,
         m.tenant_id,
         m.is_active,
         m.created_at,
         m.updated_at
  into matched_role,
       member_id,
       member_email,
       member_tenant_id,
       member_is_active,
       member_created_at,
       member_updated_at
  from public.memberships m
  where lower(trim(m.email)) = v_email
    and m.is_active = true
    and m.role = any(v_roles)
  order by case m.role
    when 'superadmin' then 1
    when 'admin' then 2
    when 'staff' then 3
    when 'viewer' then 4
    else 99
  end
  limit 1;

  has_match := matched_role is not null;
  return next;
ALTER FUNCTION "public"."check_login_membership"("p_email" "text", "p_scope" "text") OWNER TO "postgres";


    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.can_customer_access_store(p_store_id)
$$;


ALTER FUNCTION "public"."check_store_access"("p_store_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_store_price_access"("p_store_id" bigint) RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_has_internal_access boolean;
begin
  select s.tenant_id
  into v_tenant_id
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    return false;
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id = v_tenant_id
      and m.role in ('admin', 'staff')
  ) into v_has_internal_access;

  if v_has_internal_access then
    return true;
  return public.can_customer_see_store_price(p_store_id);
ALTER FUNCTION "public"."check_store_price_access"("p_store_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_thrift_landed_unit_cost"("p_stock_id" bigint) RETURNS numeric
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_stock public.thrift_stocks%ROWTYPE;
  v_shipment public.thrift_shipments%ROWTYPE;
  v_settings public.thrift_settings%ROWTYPE;
  v_sum_qty numeric;
  v_u numeric;
  v_total_weight_kg numeric;
  v_line_weight_kg numeric;
  v_costing_qty numeric;
  v_product_unit_cost numeric;
  v_shipment_cargo_cost numeric;
  v_shipment_ops_cost numeric;
  v_cargo_share_per_unit numeric;
  v_ops_share_per_unit numeric;
  v_landed_unit_cost numeric;
BEGIN
  SELECT * INTO v_stock
  FROM public.thrift_stocks
  WHERE id = p_stock_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  SELECT * INTO v_shipment
  FROM public.thrift_shipments
  WHERE id = v_stock.shipment_id;

  SELECT * INTO v_settings
  FROM public.thrift_settings
  WHERE tenant_id = v_stock.tenant_id;

  -- Costing qty: SOLD with remaining 0 still counts as 1 unit for allocation.
  v_costing_qty := CASE
    WHEN v_stock.status = 'SOLD'::public.thrift_stock_status
         AND COALESCE(v_stock.quantity, 0) = 0 THEN 1::numeric
    ELSE GREATEST(COALESCE(v_stock.quantity, 0), 0)::numeric
  END;

  SELECT COALESCE(SUM(
    CASE
      WHEN s.status = 'SOLD'::public.thrift_stock_status
           AND COALESCE(s.quantity, 0) = 0 THEN 1::numeric
      ELSE GREATEST(COALESCE(s.quantity, 0), 0)::numeric
    END
  ), 0) INTO v_sum_qty
  FROM public.thrift_stocks s
  WHERE s.shipment_id = v_stock.shipment_id;

  v_u := GREATEST(v_sum_qty, 1.0);

  SELECT COALESCE(SUM(
    (
      (COALESCE(s.product_weight, 0.0) + COALESCE(s.extra_weight, 0.0))
      / 1000.0
    ) * CASE
      WHEN s.status = 'SOLD'::public.thrift_stock_status
           AND COALESCE(s.quantity, 0) = 0 THEN 1::numeric
      ELSE GREATEST(COALESCE(s.quantity, 0), 0)::numeric
    END
  ), 0.0) INTO v_total_weight_kg
  FROM public.thrift_stocks s
  WHERE s.shipment_id = v_stock.shipment_id;

  v_line_weight_kg :=
    (COALESCE(v_stock.product_weight, 0.0) + COALESCE(v_stock.extra_weight, 0.0))
    / 1000.0
    * v_costing_qty;

  v_product_unit_cost :=
    (COALESCE(v_stock.origin_unit_price, 0.0) + COALESCE(v_stock.extra_origin_unit_price, 0.0))
    * COALESCE(v_shipment.product_conversion_rate, 1.0);

  v_shipment_cargo_cost :=
    COALESCE(v_shipment.total_cargo_weight_kg, 0.0)
    * COALESCE(v_shipment.cargo_rate, 0.0)
    * COALESCE(v_shipment.cargo_conversion_rate, 0.0);

  v_shipment_ops_cost :=
    (COALESCE(v_settings.hand_tag_unit_cost, 0.0) * v_u)
    + (COALESCE(v_settings.sticker_unit_cost, 0.0) * v_u)
    + COALESCE(v_shipment.labor_total_cost, 0.0)
    + COALESCE(v_shipment.transportation_total_cost, 0.0)
    + COALESCE(v_shipment.washing_total_cost, 0.0);

  IF v_total_weight_kg > 0 AND v_costing_qty > 0 THEN
    v_cargo_share_per_unit :=
      ((v_line_weight_kg / v_total_weight_kg) * v_shipment_cargo_cost)
      / v_costing_qty;
  ELSE
    v_cargo_share_per_unit := v_shipment_cargo_cost / v_u;
  END IF;

  v_ops_share_per_unit := v_shipment_ops_cost / v_u;

  v_landed_unit_cost :=
    v_product_unit_cost
    + v_cargo_share_per_unit
    + v_ops_share_per_unit
    + COALESCE(v_stock.additional_charges_cost, 0.0);

  RETURN COALESCE(v_landed_unit_cost, 0.0);
END;
ALTER FUNCTION "public"."compute_thrift_landed_unit_cost"("p_stock_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."confirm_courier_remittance_to_tenant"("p_order_id" bigint, "p_courier_charge" numeric DEFAULT 0.00, "p_remittance_ref" "text" DEFAULT NULL::"text", "p_bank_trx_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net_remitted numeric(12,2) := 0.00;
  v_ref text;
if v_order.id is null then
    return jsonb_build_object('success', false, 'error', format('Shop order #%s not found', p_order_id));
  if v_order.status <> 'delivered' then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be "delivered" to remit)', v_order.order_no, v_order.status)
    );
  if v_order.global_invoice_id is null then
    perform public.create_dual_invoice_from_dropship_order(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    if v_invoice.id is not null and v_invoice.invoice_status = 'draft'::public.global_invoice_status then
      perform public.post_global_invoice(v_order.global_invoice_id);
    v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_net_remitted := greatest(v_cod - v_charge, 0.00);
  v_ref := coalesce(nullif(trim(p_remittance_ref), ''), 'REMIT-' || v_order.order_no);

  return public.record_dropship_courier_remittance(
    p_order_id => p_order_id,
    p_net_amount => v_net_remitted,
    p_remittance_ref => v_ref,
    p_bank_trx_id => p_bank_trx_id,
    p_payment_date => current_date,
    p_method => 'cash',
    p_note => null,
    p_courier_charge => v_charge
  );
ALTER FUNCTION "public"."confirm_courier_remittance_to_tenant"("p_order_id" bigint, "p_courier_charge" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text") OWNER TO "postgres";


    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "billing_profile_id" bigint,
    "amount" numeric(12,2) NOT NULL,
    "payment_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "method" "text",
    "reference" "text",
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "unallocated_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "collection_source" "public"."collection_source_type" DEFAULT 'billing_profile'::"public"."collection_source_type" NOT NULL,
    CONSTRAINT "payments_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "payments_method_check" CHECK ((("method" = ANY (ARRAY['cash'::"text", 'bank'::"text", 'bank_transfer'::"text", 'mobile_banking'::"text", 'bkash'::"text", 'nagad'::"text", 'other'::"text"])) OR ("method" IS NULL)))
);


ALTER TABLE "public"."global_payments" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.cargo_companies;
  v_wallet public.wallet_accounts;
  v_code text;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  if not (
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  if exists (
    select 1 from public.tenants t where t.id = p_tenant_id and t.parent_id is not null
  ) then
    raise exception 'cargo companies belong on parent tenants only';
  v_code := upper(trim(p_code));
  if v_code is null or v_code = '' then
    raise exception 'code is required';
  if v_code = 'DEFAULT' then
    raise exception 'code DEFAULT is reserved for the system default cargo company';
  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  insert into public.cargo_companies (
    tenant_id,
    parent_tenant_id,
    name,
    code,
    email,
    phone,
    address,
    notes,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    p_tenant_id,
    trim(p_name),
    v_code,
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_notes), ''),
    false,
    true
  )
  returning * into v_row;

  insert into public.wallet_accounts (
    tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    'cargo_company',
    v_row.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  return jsonb_build_object(
    'cargo_company', to_jsonb(v_row),
    'wallet', to_jsonb(v_wallet)
  );
ALTER FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_or_update_courier_remittance_batch"("p_batch_id" bigint DEFAULT NULL::bigint, "p_tenant_id" bigint DEFAULT NULL::bigint, "p_courier_service_id" "uuid" DEFAULT NULL::"uuid", "p_batch_no" "text" DEFAULT NULL::"text", "p_bank_trx_id" "text" DEFAULT NULL::"text", "p_payment_date" "date" DEFAULT NULL::"date", "p_gross_cod_amount" numeric DEFAULT 0.00, "p_courier_charges_amount" numeric DEFAULT 0.00, "p_net_deposited_amount" numeric DEFAULT 0.00, "p_note" "text" DEFAULT NULL::"text", "p_items" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_batch_id bigint;
  v_courier_id uuid;
  v_batch_no text;
  v_item jsonb;
  v_order_id bigint;
  v_invoice_id bigint;
  v_tracking text;
  v_awb text;
  v_cod numeric(12,2);
  v_charge numeric(12,2);
  v_net numeric(12,2);
  v_tot_allocated numeric(12,2) := 0.00;
  v_tot_cod numeric(12,2) := 0.00;
  v_tot_charge numeric(12,2) := 0.00;
  v_item_status text;
  v_error_msg text;
  v_batch_status text;
begin
  -- Resolve batch or new parameters
  if p_batch_id is not null then
    select tenant_id, courier_service_id, batch_no, status
      into v_tenant_id, v_courier_id, v_batch_no, v_batch_status
    from public.courier_remittance_batches
    where id = p_batch_id for update;

    if v_tenant_id is null then
      raise exception 'Remittance batch #% not found', p_batch_id;
    if v_batch_status <> 'draft' then
      raise exception 'Cannot modify a remittance batch that is already %', v_batch_status;
    else
    v_tenant_id := p_tenant_id;
    v_courier_id := p_courier_service_id;
    v_batch_no := nullif(trim(p_batch_no), '');
  if v_tenant_id is null or v_courier_id is null or v_batch_no is null then
    raise exception 'Tenant ID, Courier Service ID, and Batch Number are required';
  -- Verify permissions
  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required for tenant %', v_tenant_id;
  -- Create or update batch header
  if p_batch_id is null then
    insert into public.courier_remittance_batches (
      tenant_id,
      courier_service_id,
      batch_no,
      bank_trx_id,
      payment_date,
      gross_cod_amount,
      courier_charges_amount,
      net_deposited_amount,
      allocated_amount,
      variance_amount,
      status,
      note,
      created_by
    )
    values (
      v_tenant_id,
      v_courier_id,
      v_batch_no,
      nullif(trim(p_bank_trx_id), ''),
      coalesce(p_payment_date, current_date),
      coalesce(p_gross_cod_amount, 0.00),
      coalesce(p_courier_charges_amount, 0.00),
      coalesce(p_net_deposited_amount, 0.00),
      0.00,
      coalesce(p_net_deposited_amount, 0.00),
      'draft',
      nullif(trim(p_note), ''),
      auth.uid()
    )
    returning id into v_batch_id;
  else
    v_batch_id := p_batch_id;
    update public.courier_remittance_batches
    set
      courier_service_id = coalesce(p_courier_service_id, courier_service_id),
      batch_no = coalesce(nullif(trim(p_batch_no), ''), batch_no),
      bank_trx_id = nullif(trim(p_bank_trx_id), ''),
      payment_date = coalesce(p_payment_date, payment_date),
      gross_cod_amount = coalesce(p_gross_cod_amount, gross_cod_amount),
      courier_charges_amount = coalesce(p_courier_charges_amount, courier_charges_amount),
      net_deposited_amount = coalesce(p_net_deposited_amount, net_deposited_amount),
      note = nullif(trim(p_note), ''),
      updated_at = now()
    where id = v_batch_id;

    -- Clear existing draft items for resync
    delete from public.courier_remittance_items where batch_id = v_batch_id;
  -- Process line items array
  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item in select * from jsonb_array_elements(p_items)
    loop
      v_order_id := (v_item->>'shop_order_id')::bigint;
      v_invoice_id := (v_item->>'global_invoice_id')::bigint;
      v_tracking := nullif(trim(v_item->>'tracking_number'), '');
      v_awb := nullif(trim(v_item->>'awb_number'), '');
      v_cod := coalesce((v_item->>'cod_collected_amount')::numeric, 0.00);
      v_charge := coalesce((v_item->>'courier_charge_amount')::numeric, 0.00);
      v_net := coalesce((v_item->>'net_remitted_amount')::numeric, (v_cod - v_charge));

      v_item_status := 'matched';
      v_error_msg := null;

      -- Validate order if provided
      if v_order_id is not null then
        select global_invoice_id, tracking_number, awb_number
          into v_invoice_id, v_tracking, v_awb
        from public.shop_orders
        where id = v_order_id and tenant_id = v_tenant_id;

        if not found then
          v_item_status := 'unmatched';
          v_error_msg := 'Order not found in tenant';
        insert into public.courier_remittance_items (
        tenant_id,
        batch_id,
        shop_order_id,
        global_invoice_id,
        tracking_number,
        awb_number,
        cod_collected_amount,
        courier_charge_amount,
        net_remitted_amount,
        status,
        error_message
      )
      values (
        v_tenant_id,
        v_batch_id,
        v_order_id,
        v_invoice_id,
        v_tracking,
        v_awb,
        v_cod,
        v_charge,
        v_net,
        v_item_status,
        v_error_msg
      );

      v_tot_allocated := v_tot_allocated + v_net;
      v_tot_cod := v_tot_cod + v_cod;
      v_tot_charge := v_tot_charge + v_charge;
    -- Recalculate batch totals and variance
  update public.courier_remittance_batches
  set
    allocated_amount = v_tot_allocated,
    gross_cod_amount = case when p_gross_cod_amount = 0 and v_tot_cod > 0 then v_tot_cod else gross_cod_amount end,
    courier_charges_amount = case when p_courier_charges_amount = 0 and v_tot_charge > 0 then v_tot_charge else courier_charges_amount end,
    variance_amount = net_deposited_amount - v_tot_allocated,
    updated_at = now()
  where id = v_batch_id;

  return jsonb_build_object(
    'success', true,
    'batch_id', v_batch_id,
    'allocated_amount', v_tot_allocated,
    'variance_amount', (coalesce(p_net_deposited_amount, 0.00) - v_tot_allocated)
  );
ALTER FUNCTION "public"."create_or_update_courier_remittance_batch"("p_batch_id" bigint, "p_tenant_id" bigint, "p_courier_service_id" "uuid", "p_batch_no" "text", "p_bank_trx_id" "text", "p_payment_date" "date", "p_gross_cod_amount" numeric, "p_courier_charges_amount" numeric, "p_net_deposited_amount" numeric, "p_note" "text", "p_items" "jsonb") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stores" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "vendor_code" "text",
    "tenant_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "vendor_id" bigint,
    CONSTRAINT "stores_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0))
);


ALTER TABLE "public"."stores" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_store"("p_name" "text", "p_vendor_code" "text", "p_tenant_id" bigint) RETURNS "public"."stores"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.stores;
begin
  if not public.can_manage_store(p_tenant_id) then
    raise exception 'not allowed';
  insert into public.stores (name, vendor_code, tenant_id)
  values (trim(p_name), nullif(trim(p_vendor_code), ''), p_tenant_id)
  returning * into v_row;

  ALTER FUNCTION "public"."create_store"("p_name" "text", "p_vendor_code" "text", "p_tenant_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_access" (
    "id" bigint NOT NULL,
    "store_id" bigint NOT NULL,
    "customer_group_id" bigint NOT NULL,
    "status" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "see_price" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."store_access" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_store_access"("p_store_id" bigint, "p_customer_group_id" bigint, "p_status" boolean DEFAULT true) RETURNS "public"."store_access"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.store_access;
  begin
  select tenant_id into v_tenant_id
  from public.stores
  where id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  insert into public.store_access (
    store_id,
    customer_group_id,
    status
  )
  values (
    p_store_id,
    p_customer_group_id,
    p_status
  )
  on conflict (store_id, customer_group_id)
  do update
  set
    status = excluded.status,
    updated_at = now()
  returning * into v_row;

  ALTER FUNCTION "public"."create_store_access"("p_store_id" bigint, "p_customer_group_id" bigint, "p_status" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_store_access"("p_store_id" bigint, "p_customer_group_id" bigint, "p_status" boolean DEFAULT true, "p_see_price" boolean DEFAULT false) RETURNS "public"."store_access"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.store_access;
  begin
  select tenant_id into v_tenant_id
  from public.stores
  where id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  insert into public.store_access (
    store_id,
    customer_group_id,
    status,
    see_price
  )
  values (
    p_store_id,
    p_customer_group_id,
    p_status,
    p_see_price
  )
  on conflict (store_id, customer_group_id)
  do update
  set
    status = excluded.status,
    see_price = excluded.see_price,
    updated_at = now()
  returning * into v_row;

  ALTER FUNCTION "public"."create_store_access"("p_store_id" bigint, "p_customer_group_id" bigint, "p_status" boolean, "p_see_price" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_tenant_for_superadmin"("p_name" "text", "p_slug" "text", "p_is_active" boolean DEFAULT true, "p_public_domain" "text" DEFAULT NULL::"text", "p_parent_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text", "is_active" boolean, "parent_id" bigint, "preference" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_id bigint;
  v_name text;
  v_slug text;
  v_public_domain text;
  v_is_active boolean;
  v_preference jsonb;
  v_created_at timestamptz;
  v_updated_at timestamptz;
begin
  if not public.is_superadmin() then
    return;
  insert into public.tenants (name, slug, public_domain, is_active, parent_id)
  values (
    trim(p_name),
    lower(trim(p_slug)),
    nullif(
      regexp_replace(
        lower(
          trim(
            split_part(
              regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
              '/',
              1
            )
          )
        ),
        ':\d+$',
        ''
      ),
      ''
    ),
    coalesce(p_is_active, true),
    p_parent_id
  )
  returning
    tenants.id,
    tenants.name,
    tenants.slug,
    tenants.public_domain,
    tenants.is_active,
    tenants.parent_id,
    tenants.preference,
    tenants.created_at,
    tenants.updated_at
  into
    v_id,
    v_name,
    v_slug,
    v_public_domain,
    v_is_active,
    v_parent_id,
    v_preference,
    v_created_at,
    v_updated_at;

  if v_parent_id is null then
    perform public.ensure_default_vendor(v_id);
    perform public.ensure_default_cargo_company(v_id);
  return query
  select
    v_id,
    v_name,
    v_slug,
    v_public_domain,
    v_is_active,
    v_parent_id,
    v_preference,
    v_created_at,
    v_updated_at;
$_$;


ALTER FUNCTION "public"."create_tenant_for_superadmin"("p_name" "text", "p_slug" "text", "p_is_active" boolean, "p_public_domain" "text", "p_parent_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_tenant_module_for_superadmin"("p_tenant_id" bigint, "p_module_key" "text", "p_is_active" boolean DEFAULT true) RETURNS TABLE("id" bigint, "tenant_id" bigint, "module_key" "text", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_key text := lower(trim(p_module_key));
  v_parent text;
begin
  if not public.is_superadmin() then
    return;
  select mo.parent_module_key into v_parent
  from public.modules mo
  where mo.key = v_key;

  if v_parent is not null then
    raise exception 'Child submodules cannot be enabled independently. Please assign the main parent feature "%" instead.', v_parent;
  if v_key = 'shop_order' and exists (
    select 1 from public.tenants child where child.parent_id = p_tenant_id
  ) then
    raise exception 'Shop & Order cannot be assigned to a parent company. Assign it on a sister concern or a standalone tenant.';
  return query
  insert into public.tenant_modules as tm (tenant_id, module_key, is_active)
  values (p_tenant_id, v_key, coalesce(p_is_active, true))
  returning
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at;
ALTER FUNCTION "public"."create_tenant_module_for_superadmin"("p_tenant_id" bigint, "p_module_key" "text", "p_is_active" boolean) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tenant_roles" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "scope" "text" NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "is_system" boolean DEFAULT false NOT NULL,
    "is_admin" boolean DEFAULT false NOT NULL,
    "source_app_role" "public"."app_role",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "tenant_roles_scope_check" CHECK (("scope" = ANY (ARRAY['app'::"text", 'shop'::"text"])))
);


ALTER TABLE "public"."tenant_roles" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_tenant_role"("p_tenant_id" bigint, "p_scope" "text", "p_name" "text", "p_slug" "text", "p_is_admin" boolean DEFAULT false) RETURNS "public"."tenant_roles"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.tenant_roles;
begin
  if not public.user_is_tenant_admin(p_tenant_id) then
    raise exception 'Unauthorized';
  if p_scope not in ('app', 'shop') then
    raise exception 'Invalid scope: %', p_scope;
  if p_is_admin = true and exists (
    select 1 from public.tenant_roles
    where tenant_id = p_tenant_id and scope = p_scope and is_admin = true
  ) then
    raise exception 'Only one Administrator role is allowed per scope';
  insert into public.tenant_roles (
    tenant_id,
    scope,
    name,
    slug,
    is_system,
    is_admin,
    source_app_role,
    is_active
  )
  values (
    p_tenant_id,
    p_scope,
    trim(p_name),
    lower(trim(p_slug)),
    false,
    p_is_admin,
    null,
    true
  )
  returning * into v_row;

  ALTER FUNCTION "public"."create_tenant_role"("p_tenant_id" bigint, "p_scope" "text", "p_name" "text", "p_slug" "text", "p_is_admin" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text" DEFAULT NULL::"text", "p_customer_name" "text" DEFAULT NULL::"text", "p_customer_phone" "text" DEFAULT NULL::"text", "p_date" timestamp with time zone DEFAULT "now"(), "p_payment_method" "text" DEFAULT NULL::"text", "p_payment_status" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text", "p_created_by" "text" DEFAULT 'cashier'::"text", "p_total_invoice_amount" numeric DEFAULT 0.00, "p_items" "jsonb" DEFAULT '[]'::"jsonb", "p_sale_channel" "text" DEFAULT 'IN_STORE'::"text", "p_customer_address" "text" DEFAULT NULL::"text", "p_customer_notes" "text" DEFAULT NULL::"text", "p_courier_amount" numeric DEFAULT 0.00, "p_courier_paid_by" "text" DEFAULT NULL::"text", "p_packing_amount" numeric DEFAULT 0.00, "p_packing_paid_by" "text" DEFAULT NULL::"text", "p_cod_fee_amount" numeric DEFAULT 0.00, "p_cod_fee_paid_by" "text" DEFAULT NULL::"text", "p_courier_provider" "text" DEFAULT NULL::"text", "p_courier_provider_id" bigint DEFAULT NULL::bigint, "p_meta" "jsonb" DEFAULT '{}'::"jsonb", "p_customer_secondary_phone" "text" DEFAULT NULL::"text", "p_customer_address_parts" "jsonb" DEFAULT '{}'::"jsonb", "p_advance_amount" numeric DEFAULT 0.00, "p_advance_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_invoice_id BIGINT;
  v_invoice_number TEXT;
  v_item JSONB;
  v_line JSONB;
  v_prepared_items JSONB := '[]'::jsonb;
  v_stock_id BIGINT;
  v_sell_price NUMERIC(12,2);
  v_discount_amount NUMERIC(12,2);
  v_final_price NUMERIC(12,2);
  v_quantity INT;
  v_total_invoice_amount NUMERIC(12,2) := 0.00;
  v_stock public.thrift_stocks%ROWTYPE;
  v_updated INT;
  v_sale_channel TEXT;
  v_phone_normalized TEXT;
  v_customer_id BIGINT := NULL;
  v_customer_display_name TEXT;
  v_courier_amount NUMERIC(12,2);
  v_courier_paid_by TEXT;
  v_packing_amount NUMERIC(12,2);
  v_packing_paid_by TEXT;
  v_cod_fee_amount NUMERIC(12,2);
  v_cod_fee_paid_by TEXT;
  v_courier_provider TEXT;
  v_courier_provider_id BIGINT := NULL;
  v_meta JSONB := '{}'::jsonb;
  v_address_parts JSONB := '{}'::jsonb;
  v_secondary_phone TEXT;
  v_provider public.thrift_courier_providers%ROWTYPE;
  v_payment_method TEXT;
  v_payment_status TEXT;
  v_cod_expected NUMERIC(12,2) := NULL;
  v_delivery_status TEXT := NULL;
  v_economics_closed_at TIMESTAMPTZ := NULL;
  v_event_at TIMESTAMPTZ;
  v_invoice_item_id BIGINT;
  v_inbound_shipment_id BIGINT;
  v_sell_amount NUMERIC(12,2);
  v_advance_amount NUMERIC(12,2);
  v_advance_note TEXT;
  v_gross_cod NUMERIC(12,2);
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create') THEN
    RAISE EXCEPTION 'Creating a thrift sales invoice requires thrift_sales create permission';
  END IF;

  v_event_at := COALESCE(p_date, NOW());
  v_invoice_number := public.generate_thrift_invoice_number(p_tenant_id, v_event_at);

  v_sale_channel := COALESCE(NULLIF(trim(p_sale_channel), ''), 'IN_STORE');
  IF v_sale_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE or ONLINE)', v_sale_channel;
  END IF;

  v_courier_amount := ROUND(COALESCE(p_courier_amount, 0.00), 2);
  v_courier_paid_by := NULLIF(upper(trim(COALESCE(p_courier_paid_by, ''))), '');
  v_packing_amount := ROUND(COALESCE(p_packing_amount, 0.00), 2);
  v_packing_paid_by := NULLIF(upper(trim(COALESCE(p_packing_paid_by, ''))), '');
  v_cod_fee_amount := ROUND(COALESCE(p_cod_fee_amount, 0.00), 2);
  v_cod_fee_paid_by := NULLIF(upper(trim(COALESCE(p_cod_fee_paid_by, ''))), '');
  v_courier_provider := NULLIF(trim(COALESCE(p_courier_provider, '')), '');
  v_courier_provider_id := p_courier_provider_id;
  v_meta := COALESCE(p_meta, '{}'::jsonb);
  IF jsonb_typeof(v_meta) <> 'object' THEN
    RAISE EXCEPTION 'p_meta must be a JSON object';
  END IF;

  v_advance_amount := ROUND(COALESCE(p_advance_amount, 0.00), 2);
  v_advance_note := NULLIF(trim(COALESCE(p_advance_note, '')), '');
  IF v_advance_amount < 0 THEN
    RAISE EXCEPTION 'Advance amount cannot be negative';
  END IF;

  v_address_parts := COALESCE(p_customer_address_parts, '{}'::jsonb);
  IF jsonb_typeof(v_address_parts) <> 'object' THEN
    RAISE EXCEPTION 'p_customer_address_parts must be a JSON object';
  END IF;
  -- Keep only known keys
  v_address_parts := jsonb_strip_nulls(
    jsonb_build_object(
      'district', NULLIF(trim(COALESCE(v_address_parts->>'district', '')), ''),
      'thana', NULLIF(trim(COALESCE(v_address_parts->>'thana', '')), ''),
      'post_code', NULLIF(trim(COALESCE(v_address_parts->>'post_code', '')), '')
    )
  );

  v_secondary_phone := NULLIF(trim(COALESCE(p_customer_secondary_phone, '')), '');

  IF NULLIF(trim(p_customer_name), '') IS NULL THEN
    RAISE EXCEPTION 'Customer name is required';
  END IF;
  IF NULLIF(trim(p_customer_phone), '') IS NULL THEN
    RAISE EXCEPTION 'Customer phone is required';
  END IF;

  IF v_sale_channel = 'IN_STORE' THEN
    IF v_advance_amount <> 0 THEN
      RAISE EXCEPTION 'Advance is only allowed for online COD sales';
    END IF;
    v_advance_amount := 0.00;
    v_advance_note := NULL;
    v_courier_amount := 0.00;
    v_courier_paid_by := NULL;
    v_packing_amount := 0.00;
    v_packing_paid_by := NULL;
    v_cod_fee_amount := 0.00;
    v_cod_fee_paid_by := NULL;
    v_courier_provider := NULL;
    v_courier_provider_id := NULL;
    v_meta := '{}'::jsonb;
    v_payment_method := 'CASH';
    v_payment_status := 'PAID';
    v_cod_expected := NULL;
    v_delivery_status := NULL;
    v_economics_closed_at := v_event_at;
  ELSE
    IF NULLIF(trim(p_customer_address), '') IS NULL THEN
      RAISE EXCEPTION 'Online sale requires delivery address';
    END IF;
    IF COALESCE(v_address_parts->>'district', '') = '' THEN
      RAISE EXCEPTION 'Online sale requires district';
    END IF;
    IF COALESCE(v_address_parts->>'thana', '') = '' THEN
      RAISE EXCEPTION 'Online sale requires thana / upazila';
    END IF;

    IF v_courier_amount < 0 OR v_packing_amount < 0 OR v_cod_fee_amount < 0 THEN
      RAISE EXCEPTION 'Fee amounts cannot be negative';
    END IF;

    IF v_courier_amount > 0 THEN
      IF v_courier_paid_by IS NULL OR v_courier_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'courier_paid_by is required when courier_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_courier_paid_by := NULL;
    END IF;

    IF v_packing_amount > 0 THEN
      IF v_packing_paid_by IS NULL OR v_packing_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'packing_paid_by is required when packing_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_packing_paid_by := NULL;
    END IF;

    IF v_cod_fee_amount > 0 THEN
      IF v_cod_fee_paid_by IS NULL OR v_cod_fee_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'cod_fee_paid_by is required when cod_fee_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_cod_fee_paid_by := NULL;
    END IF;

    IF v_courier_provider_id IS NOT NULL THEN
      SELECT * INTO v_provider
      FROM public.thrift_courier_providers
      WHERE id = v_courier_provider_id
        AND is_active = TRUE
        AND (
          (is_system = TRUE AND tenant_id IS NULL)
          OR (is_system = FALSE AND tenant_id = p_tenant_id)
        );

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Courier provider % is not available for this tenant', v_courier_provider_id;
      END IF;

      v_courier_provider := COALESCE(v_courier_provider, v_provider.name);
    END IF;

    v_payment_method := 'COD';
    v_payment_status := 'COD_PENDING';
    v_delivery_status := 'PENDING';
    v_economics_closed_at := NULL;
  END IF;

  v_phone_normalized := public.normalize_thrift_phone(p_customer_phone);
  IF v_phone_normalized = '' THEN
    RAISE EXCEPTION 'Customer phone is required';
  END IF;

  v_customer_display_name := trim(p_customer_name);

  INSERT INTO public.thrift_customers (
    tenant_id,
    name,
    phone,
    phone_normalized,
    secondary_phone,
    address,
    address_parts,
    notes,
    inserted_by
  ) VALUES (
    p_tenant_id,
    v_customer_display_name,
    COALESCE(NULLIF(trim(p_customer_phone), ''), v_phone_normalized),
    v_phone_normalized,
    v_secondary_phone,
    p_customer_address,
    v_address_parts,
    p_customer_notes,
    COALESCE(NULLIF(trim(p_created_by), ''), 'cashier')
  )
  ON CONFLICT (tenant_id, phone_normalized) DO UPDATE SET
    phone = EXCLUDED.phone,
    name = EXCLUDED.name,
    secondary_phone = CASE
      WHEN p_customer_secondary_phone IS NOT NULL THEN v_secondary_phone
      ELSE public.thrift_customers.secondary_phone
    END,
    address = CASE
      WHEN p_customer_address IS NOT NULL THEN p_customer_address
      ELSE public.thrift_customers.address
    END,
    address_parts = CASE
      WHEN p_customer_address_parts IS NOT NULL AND v_address_parts <> '{}'::jsonb
        THEN v_address_parts
      WHEN p_customer_address_parts IS NOT NULL AND v_sale_channel = 'ONLINE'
        THEN v_address_parts
      ELSE public.thrift_customers.address_parts
    END,
    notes = CASE
      WHEN p_customer_notes IS NOT NULL THEN p_customer_notes
      ELSE public.thrift_customers.notes
    END,
    updated_at = NOW()
  RETURNING id INTO v_customer_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    v_stock_id := NULLIF(trim(COALESCE(v_item->>'stock_id', '')), '')::BIGINT;
    IF v_stock_id IS NULL THEN
      RAISE EXCEPTION 'Each invoice item requires stock_id';
    END IF;

    v_sell_price := ROUND(COALESCE((v_item->>'sell_price')::NUMERIC, 0.00), 2);
    v_discount_amount := ROUND(COALESCE((v_item->>'discount_amount')::NUMERIC, 0.00), 2);
    v_quantity := GREATEST(COALESCE((v_item->>'quantity')::INT, 1), 1);
    v_final_price := ROUND(GREATEST(v_sell_price - v_discount_amount, 0.00), 2);

    SELECT *
    INTO v_stock
    FROM public.thrift_stocks
    WHERE id = v_stock_id
      AND tenant_id = p_tenant_id
      AND deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock item % not found for tenant %', v_stock_id, p_tenant_id;
    END IF;

    IF v_stock.shipment_id IS NULL THEN
      RAISE EXCEPTION 'Stock item % has no inbound shipment; cannot create sales PnL later', v_stock_id;
    END IF;

    IF v_stock.status = 'AVAILABLE'::public.thrift_stock_status THEN
      NULL;
    ELSIF v_stock.status = 'RESERVED'::public.thrift_stock_status THEN
      IF COALESCE(v_stock.held_for_phone_normalized, '') = ''
         OR v_stock.held_for_phone_normalized IS DISTINCT FROM v_phone_normalized
      THEN
        RAISE EXCEPTION
          'Stock item % is on hold; sell requires matching customer phone (same hold) or release first',
          v_stock_id;
      END IF;
    ELSE
      RAISE EXCEPTION
        'Stock item % is not AVAILABLE (status=%)',
        v_stock_id,
        v_stock.status;
    END IF;

    IF COALESCE(v_stock.quantity, 0) < v_quantity THEN
      RAISE EXCEPTION
        'Insufficient quantity for stock item % (have %, need %)',
        v_stock_id,
        COALESCE(v_stock.quantity, 0),
        v_quantity;
    END IF;

    v_prepared_items := v_prepared_items || jsonb_build_array(
      jsonb_build_object(
        'stock_id', v_stock_id,
        'sell_price', v_sell_price,
        'discount_amount', v_discount_amount,
        'final_price', v_final_price,
        'quantity', v_quantity,
        'inbound_shipment_id', v_stock.shipment_id
      )
    );

    v_total_invoice_amount := v_total_invoice_amount + (v_final_price * v_quantity);
  END LOOP;

  IF jsonb_array_length(v_prepared_items) = 0 THEN
    RAISE EXCEPTION 'Invoice requires at least one line item';
  END IF;

  IF v_sale_channel = 'ONLINE' THEN
    v_gross_cod := ROUND(
      v_total_invoice_amount
      + CASE WHEN v_courier_paid_by = 'CUSTOMER' THEN v_courier_amount ELSE 0.00 END
      + CASE WHEN v_cod_fee_paid_by = 'CUSTOMER' THEN v_cod_fee_amount ELSE 0.00 END
      + CASE WHEN v_packing_paid_by = 'CUSTOMER' THEN v_packing_amount ELSE 0.00 END,
      2
    );
    v_cod_expected := GREATEST(0.00, ROUND(v_gross_cod - v_advance_amount, 2));
  END IF;

  INSERT INTO public.thrift_sales_invoices (
    tenant_id,
    invoice_number,
    customer_name,
    customer_phone,
    customer_secondary_phone,
    customer_address,
    customer_address_parts,
    customer_id,
    sale_channel,
    date,
    payment_method,
    payment_status,
    notes,
    created_by,
    total_invoice_amount,
    courier_amount,
    courier_paid_by,
    courier_cod_amount,
    courier_provider,
    courier_provider_id,
    packing_amount,
    packing_paid_by,
    cod_fee_amount,
    cod_fee_paid_by,
    return_courier_amount,
    other_expense_amount,
    advance_amount,
    advance_note,
    cod_expected,
    delivery_status,
    economics_closed_at,
    meta,
    status
  ) VALUES (
    p_tenant_id,
    v_invoice_number,
    p_customer_name,
    p_customer_phone,
    v_secondary_phone,
    p_customer_address,
    v_address_parts,
    v_customer_id,
    v_sale_channel,
    v_event_at,
    v_payment_method,
    v_payment_status,
    p_notes,
    p_created_by,
    v_total_invoice_amount,
    v_courier_amount,
    v_courier_paid_by,
    v_courier_amount,
    v_courier_provider,
    v_courier_provider_id,
    v_packing_amount,
    v_packing_paid_by,
    v_cod_fee_amount,
    v_cod_fee_paid_by,
    0.00,
    0.00,
    v_advance_amount,
    v_advance_note,
    v_cod_expected,
    v_delivery_status,
    v_economics_closed_at,
    v_meta,
    'ACTIVE'
  )
  RETURNING id INTO v_invoice_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(v_prepared_items)
  LOOP
    v_stock_id := (v_line->>'stock_id')::BIGINT;
    v_sell_price := (v_line->>'sell_price')::NUMERIC(12,2);
    v_discount_amount := (v_line->>'discount_amount')::NUMERIC(12,2);
    v_final_price := (v_line->>'final_price')::NUMERIC(12,2);
    v_quantity := (v_line->>'quantity')::INT;
    v_inbound_shipment_id := (v_line->>'inbound_shipment_id')::BIGINT;
    v_sell_amount := ROUND(v_final_price * v_quantity, 2);

    INSERT INTO public.thrift_sales_invoice_items (
      tenant_id,
      invoice_id,
      stock_id,
      sell_price,
      discount_amount,
      final_price,
      landed_unit_cost_at_sale,
      quantity,
      net_profit
    ) VALUES (
      p_tenant_id,
      v_invoice_id,
      v_stock_id,
      v_sell_price,
      v_discount_amount,
      v_final_price,
      0.00,
      v_quantity,
      0.00
    )
    RETURNING id INTO v_invoice_item_id;

    UPDATE public.thrift_stocks
    SET
      quantity = quantity - v_quantity,
      status = 'SOLD'::public.thrift_stock_status,
      updated_at = NOW()
    WHERE id = v_stock_id
      AND tenant_id = p_tenant_id
      AND deleted_at IS NULL
      AND quantity >= v_quantity
      AND (
        status = 'AVAILABLE'::public.thrift_stock_status
        OR (
          status = 'RESERVED'::public.thrift_stock_status
          AND held_for_phone_normalized IS NOT DISTINCT FROM v_phone_normalized
          AND COALESCE(v_phone_normalized, '') <> ''
        )
      );

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated = 0 THEN
      RAISE EXCEPTION
        'Stock item % became unavailable during sale (tenant %)',
        v_stock_id,
        p_tenant_id;
    END IF;

    IF v_sale_channel = 'IN_STORE' THEN
      INSERT INTO public.thrift_sales_pnl_lines (
        tenant_id,
        invoice_id,
        invoice_item_id,
        stock_id,
        inbound_shipment_id,
        outcome,
        return_id,
        quantity,
        sell_amount,
        allocated_shop_delivery,
        allocated_shop_cod_fee,
        allocated_shop_packing,
        allocated_return_courier,
        allocated_fees_total,
        cogs_is_loss,
        event_at,
        event_date
      ) VALUES (
        p_tenant_id,
        v_invoice_id,
        v_invoice_item_id,
        v_stock_id,
        v_inbound_shipment_id,
        'DELIVERED',
        NULL,
        v_quantity,
        v_sell_amount,
        0.00,
        0.00,
        0.00,
        0.00,
        0.00,
        FALSE,
        v_event_at,
        (v_event_at AT TIME ZONE 'UTC')::DATE
      );
    END IF;
  END LOOP;

  INSERT INTO public.thrift_accounting_ledger (
    tenant_id,
    type,
    source,
    reference_id,
    amount,
    note,
    inserted_by,
    date
  ) VALUES (
    p_tenant_id,
    'REVENUE'::public.thrift_ledger_type,
    'INVOICE'::public.thrift_ledger_source,
    v_invoice_id,
    v_total_invoice_amount,
    'item_revenue',
    p_created_by,
    v_event_at
  );

  IF v_sale_channel = 'ONLINE' AND v_courier_amount > 0 AND v_courier_paid_by = 'SHOP' THEN
    INSERT INTO public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      note,
      inserted_by,
      date
    ) VALUES (
      p_tenant_id,
      'EXPENSE'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      v_invoice_id,
      v_courier_amount,
      'shop_delivery',
      p_created_by,
      v_event_at
    );
  END IF;

  IF v_sale_channel = 'ONLINE' AND v_packing_amount > 0 AND v_packing_paid_by = 'SHOP' THEN
    INSERT INTO public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      note,
      inserted_by,
      date
    ) VALUES (
      p_tenant_id,
      'EXPENSE'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      v_invoice_id,
      v_packing_amount,
      'shop_packing',
      p_created_by,
      v_event_at
    );
  END IF;

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', v_invoice_number,
    'payment_status', v_payment_status,
    'sale_channel', v_sale_channel,
    'cod_expected', v_cod_expected,
    'advance_amount', v_advance_amount,
    'delivery_status', v_delivery_status,
    'economics_closed_at', v_economics_closed_at,
    'status', 'success'
  );
END;
ALTER FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") IS 'Create thrift sales invoice. Online COD: optional advance_amount reduces cod_expected (floor 0). IN_STORE rejects non-zero advance. PnL sell lines unchanged.';


CREATE OR REPLACE FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric DEFAULT 0.00, "p_notes" "text" DEFAULT NULL::"text", "p_created_by" "text" DEFAULT 'cashier'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_return_courier NUMERIC(12,2);
  v_event_at TIMESTAMPTZ := NOW();
  v_is_online BOOLEAN;
  v_return_id BIGINT;
  v_return_number TEXT;
  v_refund_total NUMERIC(12,2) := 0.00;
  v_advance_amount NUMERIC(12,2) := 0.00;
  v_invoice_item_total NUMERIC(12,2) := 0.00;
  v_prior_line_refunds NUMERIC(12,2) := 0.00;
  v_advance_withheld NUMERIC(12,2) := 0.00;
  v_ledger_refund NUMERIC(12,2) := 0.00;
  v_item_count INT := 0;
  v_total_value NUMERIC(12,2) := 0.00;
  v_idx INT := 0;
  v_cum_return NUMERIC(12,2) := 0.00;
  v_alloc_return NUMERIC(12,2);
  v_share NUMERIC;
  v_line RECORD;
  v_remaining INT;
  v_new_status TEXT;
  v_new_payment TEXT;
  v_close_reason TEXT;
  v_actor TEXT := COALESCE(NULLIF(trim(p_created_by), ''), 'cashier');
BEGIN
  IF p_tenant_id IS NULL OR p_invoice_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id and invoice_id are required';
  END IF;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'force_return')
  ) THEN
    RAISE EXCEPTION 'Post-pay return requires thrift_sales return (or force_return) permission';
  END IF;

  v_return_courier := ROUND(COALESCE(p_return_courier_amount, 0.00), 2);
  IF v_return_courier < 0 THEN
    RAISE EXCEPTION 'return_courier_amount cannot be negative';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) < 1 THEN
    RAISE EXCEPTION 'p_items must be a non-empty JSON array';
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF COALESCE(v_invoice.close_reason, '') = 'RTO' THEN
    RAISE EXCEPTION 'Invoice % is RTO-closed; cannot create post-pay return', p_invoice_id;
  END IF;

  IF v_invoice.status NOT IN ('ACTIVE', 'PARTIALLY_RETURNED') THEN
    RAISE EXCEPTION 'Invoice % status % cannot accept returns', p_invoice_id, v_invoice.status;
  END IF;

  v_is_online := COALESCE(v_invoice.sale_channel, 'IN_STORE') = 'ONLINE';

  IF v_is_online THEN
    IF COALESCE(v_invoice.delivery_status, '') IS DISTINCT FROM 'DELIVERED'
       AND v_invoice.status IS DISTINCT FROM 'PARTIALLY_RETURNED'
    THEN
      RAISE EXCEPTION
        'Online invoice % must be DELIVERED before Return items (use Mark RTO if refuse)',
        p_invoice_id;
    END IF;
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS tmp_return_lines (
    invoice_item_id BIGINT PRIMARY KEY,
    stock_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    condition TEXT NOT NULL,
    refund_amount NUMERIC(12,2) NOT NULL,
    prior_delivery NUMERIC(12,2) NOT NULL DEFAULT 0,
    prior_cod_fee NUMERIC(12,2) NOT NULL DEFAULT 0,
    prior_packing NUMERIC(12,2) NOT NULL DEFAULT 0,
    prior_return_courier NUMERIC(12,2) NOT NULL DEFAULT 0
  ) ON COMMIT DROP;

  TRUNCATE tmp_return_lines;

  INSERT INTO tmp_return_lines (
    invoice_item_id,
    stock_id,
    quantity,
    condition,
    refund_amount,
    prior_delivery,
    prior_cod_fee,
    prior_packing,
    prior_return_courier
  )
  SELECT
    i.id,
    i.stock_id,
    GREATEST(req.qty, 1),
    req.condition,
    ROUND(i.final_price * GREATEST(req.qty, 1), 2),
    COALESCE(p.allocated_shop_delivery, 0),
    COALESCE(p.allocated_shop_cod_fee, 0),
    COALESCE(p.allocated_shop_packing, 0),
    COALESCE(p.allocated_return_courier, 0)
  FROM (
    SELECT DISTINCT ON (x.invoice_item_id)
      x.invoice_item_id,
      x.qty,
      x.condition
    FROM (
      SELECT
        (elem->>'invoice_item_id')::BIGINT AS invoice_item_id,
        GREATEST(COALESCE((elem->>'quantity')::INTEGER, 1), 1) AS qty,
        upper(trim(COALESCE(elem->>'condition', ''))) AS condition
      FROM jsonb_array_elements(p_items) AS elem
    ) x
    ORDER BY x.invoice_item_id
  ) req
  JOIN public.thrift_sales_invoice_items i
    ON i.id = req.invoice_item_id
   AND i.tenant_id = p_tenant_id
   AND i.invoice_id = p_invoice_id
  LEFT JOIN public.thrift_sales_pnl_lines p
    ON p.invoice_item_id = i.id
   AND p.tenant_id = p_tenant_id
  WHERE req.condition IN ('SELLABLE', 'DAMAGED')
    AND NOT EXISTS (
      SELECT 1
      FROM public.thrift_sales_return_items ri
      WHERE ri.invoice_item_id = i.id
    );

  GET DIAGNOSTICS v_item_count = ROW_COUNT;

  IF v_item_count = 0 THEN
    RAISE EXCEPTION 'No valid returnable lines in p_items (already returned, wrong invoice, or bad condition)';
  END IF;

  IF v_item_count <> jsonb_array_length(p_items) THEN
    RAISE EXCEPTION 'One or more return lines are invalid, already returned, or not on invoice %', p_invoice_id;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_return_lines t
    JOIN public.thrift_sales_invoice_items i
      ON i.id = t.invoice_item_id
    WHERE t.quantity > i.quantity
  ) THEN
    RAISE EXCEPTION 'Return quantity exceeds invoice line quantity';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_return_lines t
    LEFT JOIN public.thrift_sales_pnl_lines p
      ON p.invoice_item_id = t.invoice_item_id
     AND p.tenant_id = p_tenant_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION
      'Invoice % has lines without PnL — deliver Online first (or recreate Offline sale)',
      p_invoice_id;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_return_lines t
    JOIN public.thrift_sales_pnl_lines p
      ON p.invoice_item_id = t.invoice_item_id
     AND p.tenant_id = p_tenant_id
    WHERE p.outcome IS DISTINCT FROM 'DELIVERED'
  ) THEN
    RAISE EXCEPTION 'Only DELIVERED PnL lines can be returned';
  END IF;

  SELECT COALESCE(SUM(refund_amount), 0)
  INTO v_refund_total
  FROM tmp_return_lines;

  v_total_value := v_refund_total;

  -- Advance is non-refundable: withhold proportional remaining advance from ledger REFUND.
  -- Return doc refund_amount stays line sell sum (PnL/stock). Cash/ledger refund excludes advance.
  v_advance_amount := ROUND(COALESCE(v_invoice.advance_amount, 0.00), 2);
  SELECT COALESCE(SUM(ROUND(i.final_price * i.quantity, 2)), 0)
  INTO v_invoice_item_total
  FROM public.thrift_sales_invoice_items i
  WHERE i.tenant_id = p_tenant_id
    AND i.invoice_id = p_invoice_id;
  SELECT COALESCE(SUM(ri.refund_amount), 0)
  INTO v_prior_line_refunds
  FROM public.thrift_sales_return_items ri
  JOIN public.thrift_sales_returns r
    ON r.id = ri.return_id
   AND r.tenant_id = ri.tenant_id
  WHERE r.tenant_id = p_tenant_id
    AND r.invoice_id = p_invoice_id;
  IF v_invoice_item_total > 0 AND v_advance_amount > 0 THEN
    v_advance_withheld := ROUND(
      v_advance_amount * (v_refund_total / v_invoice_item_total),
      2
    );
    -- Clamp so cumulative withheld cannot exceed advance
    IF v_advance_withheld > GREATEST(0.00, v_advance_amount - ROUND(
      v_advance_amount * (v_prior_line_refunds / v_invoice_item_total), 2
    )) THEN
      v_advance_withheld := GREATEST(
        0.00,
        ROUND(v_advance_amount - ROUND(v_advance_amount * (v_prior_line_refunds / v_invoice_item_total), 2), 2)
      );
    END IF;
  ELSE
    v_advance_withheld := 0.00;
  END IF;
  v_ledger_refund := GREATEST(0.00, ROUND(v_refund_total - v_advance_withheld, 2));
  v_return_number := public.generate_thrift_return_number(p_tenant_id, v_event_at);

  INSERT INTO public.thrift_sales_returns (
    tenant_id,
    invoice_id,
    return_number,
    status,
    refund_amount,
    return_courier_amount,
    notes,
    created_by
  ) VALUES (
    p_tenant_id,
    p_invoice_id,
    v_return_number,
    'COMPLETED',
    v_refund_total,
    v_return_courier,
    NULLIF(trim(p_notes), ''),
    v_actor
  )
  RETURNING id INTO v_return_id;

  INSERT INTO public.thrift_sales_return_items (
    return_id,
    tenant_id,
    invoice_item_id,
    stock_id,
    quantity,
    condition,
    refund_amount
  )
  SELECT
    v_return_id,
    p_tenant_id,
    invoice_item_id,
    stock_id,
    quantity,
    condition,
    refund_amount
  FROM tmp_return_lines;

  -- Restore stock per condition
  UPDATE public.thrift_stocks s
  SET
    quantity = s.quantity + t.quantity,
    status = CASE
      WHEN t.condition = 'DAMAGED' THEN 'DAMAGED'::public.thrift_stock_status
      ELSE 'AVAILABLE'::public.thrift_stock_status
    END,
    updated_at = NOW()
  FROM tmp_return_lines t
  WHERE s.id = t.stock_id
    AND s.tenant_id = p_tenant_id;

  -- Ledger insert-only (REFUND excludes non-refundable advance share)
  IF v_ledger_refund > 0 THEN
    INSERT INTO public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      note,
      inserted_by,
      date
    ) VALUES (
      p_tenant_id,
      'REFUND'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_ledger_refund,
      'item_refund ' || v_return_number
        || CASE WHEN v_advance_withheld > 0
             THEN ' (advance retained ' || v_advance_withheld::TEXT || ')'
             ELSE ''
           END
        || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
      v_actor,
      v_event_at
    );
  END IF;

  IF v_return_courier > 0 THEN
    INSERT INTO public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      note,
      inserted_by,
      date
    ) VALUES (
      p_tenant_id,
      'LOSS'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_return_courier,
      'return_courier ' || v_return_number,
      v_actor,
      v_event_at
    );
  END IF;

  -- PnL: only returned lines → CUSTOMER_RETURN; keep sunk shop fees; add return courier share
  FOR v_line IN
    SELECT *
    FROM tmp_return_lines
    ORDER BY invoice_item_id
  LOOP
    v_idx := v_idx + 1;

    IF v_total_value > 0 THEN
      v_share := v_line.refund_amount / v_total_value;
    ELSE
      v_share := 1.0 / v_item_count;
    END IF;

    IF v_idx = v_item_count THEN
      v_alloc_return := ROUND(v_return_courier - v_cum_return, 2);
    ELSE
      v_alloc_return := ROUND(v_return_courier * v_share, 2);
      v_cum_return := v_cum_return + v_alloc_return;
    END IF;

    UPDATE public.thrift_sales_pnl_lines
    SET
      outcome = 'CUSTOMER_RETURN',
      return_id = v_return_id,
      sell_amount = 0.00,
      allocated_shop_delivery = v_line.prior_delivery,
      allocated_shop_cod_fee = v_line.prior_cod_fee,
      allocated_shop_packing = v_line.prior_packing,
      allocated_return_courier = ROUND(v_line.prior_return_courier + v_alloc_return, 2),
      allocated_fees_total = ROUND(
        v_line.prior_delivery
        + v_line.prior_cod_fee
        + v_line.prior_packing
        + v_line.prior_return_courier
        + v_alloc_return,
        2
      ),
      cogs_is_loss = (v_line.condition = 'DAMAGED'),
      event_at = v_event_at,
      event_date = (v_event_at AT TIME ZONE 'UTC')::DATE,
      updated_at = NOW()
    WHERE tenant_id = p_tenant_id
      AND invoice_item_id = v_line.invoice_item_id;
  END LOOP;

  SELECT COUNT(*)::INT
  INTO v_remaining
  FROM public.thrift_sales_invoice_items i
  WHERE i.tenant_id = p_tenant_id
    AND i.invoice_id = p_invoice_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.thrift_sales_return_items ri
      WHERE ri.invoice_item_id = i.id
    );

  IF v_remaining > 0 THEN
    v_new_status := 'PARTIALLY_RETURNED';
    v_close_reason := NULL;
    IF upper(COALESCE(v_invoice.payment_status, '')) = 'PAID'
       OR upper(COALESCE(v_invoice.payment_status, '')) = 'PARTIALLY_REFUNDED'
    THEN
      v_new_payment := 'PARTIALLY_REFUNDED';
    ELSE
      v_new_payment := v_invoice.payment_status;
    END IF;

    UPDATE public.thrift_sales_invoices
    SET
      status = v_new_status,
      payment_status = v_new_payment,
      close_reason = NULL,
      updated_at = NOW()
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;
  ELSE
    v_new_status := 'RETURNED';
    v_close_reason := 'CUSTOMER_RETURN';
    v_new_payment := 'REFUNDED';

    UPDATE public.thrift_sales_invoices
    SET
      status = v_new_status,
      payment_status = v_new_payment,
      close_reason = v_close_reason,
      reverted_at = v_event_at,
      reverted_by = v_actor,
      revert_reason = 'CUSTOMER_RETURN',
      revert_notes = NULLIF(trim(p_notes), ''),
      updated_at = NOW()
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;
  END IF;

  RETURN jsonb_build_object(
    'return_id', v_return_id,
    'return_number', v_return_number,
    'invoice_id', p_invoice_id,
    'refund_amount', v_refund_total,
    'ledger_refund_amount', v_ledger_refund,
    'advance_retained', v_advance_withheld,
    'return_courier_amount', v_return_courier,
    'status', v_new_status,
    'payment_status', v_new_payment,
    'close_reason', v_close_reason
  );
END;
ALTER FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") IS 'Post-pay return: docs + stock + PnL CUSTOMER_RETURN. Ledger REFUND excludes non-refundable advance share.';


CREATE OR REPLACE FUNCTION "public"."current_customer_group_id"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select cg.id
  from public.customer_groups cg
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where p_tenant_id is not null
    and cg.tenant_id = p_tenant_id
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by cg.id
  limit 1;
ALTER FUNCTION "public"."current_customer_group_id"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select nullif(current_setting('request.headers', true)::json->>'x-selected-tenant-id', '')::bigint
$$;


ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id into v_tenant_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cgm.id = p_cgm_id;

  if v_tenant_id is null then
    raise exception 'Customer group member not found';
  if not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Unauthorized';
  delete from public.customer_group_member_grants
  where customer_group_member_id = p_cgm_id
    and module_key = p_module_key
    and action = p_action;

  perform public.bump_tenant_permission_version(v_tenant_id);
ALTER FUNCTION "public"."delete_customer_group_member_grant"("p_cgm_id" bigint, "p_module_key" "text", "p_action" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_membership_grant"("p_membership_id" bigint, "p_module_key" "text", "p_action" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select m.tenant_id into v_tenant_id
  from public.memberships m
  where m.id = p_membership_id;

  if v_tenant_id is null then
    raise exception 'Membership not found';
  if not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Unauthorized';
  delete from public.membership_grants
  where membership_id = p_membership_id
    and module_key = p_module_key
    and action = p_action;

  perform public.bump_tenant_permission_version(v_tenant_id);
ALTER FUNCTION "public"."delete_membership_grant"("p_membership_id" bigint, "p_module_key" "text", "p_action" "text") OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.stores
  where id = p_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  delete from public.stores where id = p_id;
ALTER FUNCTION "public"."delete_store"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_store_access"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select s.tenant_id into v_tenant_id
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where sa.id = p_id;

  if v_tenant_id is null then
    raise exception 'store access not found';
  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  delete from public.store_access where id = p_id;
ALTER FUNCTION "public"."delete_store_access"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_tenant_for_superadmin"("p_tenant_id" bigint) RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text", "is_active" boolean, "parent_id" bigint, "preference" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  deleted as (
    delete from public.tenants as t
    using permission
    where allowed
      and t.id = p_tenant_id
    returning
      t.id,
      t.name,
      t.slug,
      t.public_domain,
      t.is_active,
      t.parent_id,
      t.preference,
      t.created_at,
      t.updated_at
  )
  select
    id,
    name,
    slug,
    public_domain,
    is_active,
    parent_id,
    preference,
    created_at,
    updated_at
  from deleted;
ALTER FUNCTION "public"."delete_tenant_for_superadmin"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_tenant_module_for_superadmin"("p_id" bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "module_key" "text", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_deleted public.tenant_modules%rowtype;
begin
  if not public.is_superadmin() then
    return;
  delete from public.tenant_modules tm
  where tm.id = p_id
  returning * into v_deleted;

  if v_deleted.id is not null then
    delete from public.tenant_module_submodules tms
    where tms.tenant_id = v_deleted.tenant_id
      and tms.parent_module_key = v_deleted.module_key;
  return query
  select
    v_deleted.id,
    v_deleted.tenant_id,
    v_deleted.module_key,
    v_deleted.is_active,
    v_deleted.created_at,
    v_deleted.updated_at;
ALTER FUNCTION "public"."delete_tenant_module_for_superadmin"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_tenant_role"("p_role_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.tenant_roles;
begin
  select * into v_row from public.tenant_roles where id = p_role_id;

  if v_row.id is null then
    raise exception 'Role not found';
  if not public.user_is_tenant_admin(v_row.tenant_id) then
    raise exception 'Unauthorized';
  if v_row.is_system = true then
    raise exception 'Cannot delete system roles';
  if exists (
    select 1 from public.memberships where tenant_role_id = p_role_id
  ) then
    raise exception 'Cannot delete role: members are currently assigned to it';
  if exists (
    select 1 from public.customer_group_members where tenant_role_id = p_role_id
  ) then
    raise exception 'Cannot delete role: customer group members are currently assigned to it';
  delete from public.tenant_roles where id = p_role_id;
ALTER FUNCTION "public"."delete_tenant_role"("p_role_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_blocked BIGINT;
  v_deleted INT;
  v_actor TEXT;
BEGIN
  IF p_stock_ids IS NULL OR cardinality(p_stock_ids) = 0 THEN
    RETURN jsonb_build_object('deleted', 0);
  END IF;

  SELECT si.stock_id
  INTO v_blocked
  FROM public.thrift_sales_invoice_items si
  INNER JOIN public.thrift_sales_invoices inv
    ON inv.id = si.invoice_id
   AND inv.tenant_id = si.tenant_id
  WHERE si.tenant_id = p_tenant_id
    AND si.stock_id = ANY (p_stock_ids)
    AND coalesce(inv.status, 'ACTIVE') = 'ACTIVE'
  LIMIT 1;

  IF v_blocked IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot delete stock %: it is on an active sales invoice. Return or mark staff mistake first.',
      v_blocked;
  END IF;

  v_actor := COALESCE(NULLIF(trim(public.current_user_email()), ''), 'system');

  UPDATE public.thrift_stocks
  SET
    deleted_at = NOW(),
    deleted_by = v_actor,
    updated_at = NOW()
  WHERE tenant_id = p_tenant_id
    AND id = ANY (p_stock_ids)
    AND deleted_at IS NULL;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object('deleted', v_deleted);
END;
ALTER FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."dispense_middleman_payout"("p_billing_profile_id" bigint, "p_amount" numeric, "p_method" "text" DEFAULT 'bkash'::"text", "p_trx_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_profile public.billing_profiles;
  v_avail_balance numeric(12,2) := 0.00;
  v_entry public.billing_profile_wallet_ledger;
begin
  if p_billing_profile_id is null then
    raise exception 'Billing Profile ID is required';
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payout amount must be greater than zero';
  if v_profile.id is null then
    raise exception 'Billing profile #% not found', p_billing_profile_id;
  -- Check available balance in ledger
  select balance_after into v_avail_balance
  from public.billing_profile_wallet_ledger
  where tenant_id = v_profile.tenant_id
    and billing_profile_id = p_billing_profile_id
  order by created_at desc, id desc
  limit 1
  for update;

  v_avail_balance := coalesce(v_avail_balance, 0.00);

  if v_avail_balance < p_amount then
    raise exception 'Insufficient wallet balance. Available balance: %, requested payout: %', v_avail_balance, p_amount;
  -- Record payout_paid entry in ledger
  v_entry := public.record_wallet_ledger_entry(
    p_tenant_id => v_profile.tenant_id,
    p_billing_profile_id => p_billing_profile_id,
    p_transaction_type => 'payout_paid',
    p_amount => p_amount,
    p_reference_id => p_trx_id,
    p_reference_notes => format('Dispensed payout via %s (TRX: %s)', coalesce(p_method, 'transfer'), coalesce(p_trx_id, 'N/A')),
    p_created_by => auth.uid()
  );

  return jsonb_build_object(
    'success', true,
    'billing_profile_id', p_billing_profile_id,
    'amount', p_amount,
    'new_balance', v_entry.balance_after
  );
ALTER FUNCTION "public"."dispense_middleman_payout"("p_billing_profile_id" bigint, "p_amount" numeric, "p_method" "text", "p_trx_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_customer_admin_email_conflict"("p_tenant_id" bigint, "p_email" "text", "p_exclude_billing_profile_id" bigint DEFAULT NULL::bigint, "p_exclude_member_id" bigint DEFAULT NULL::bigint) RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
declare
  v_normalized_email text;
  v_group_name text;
begin
  v_normalized_email := nullif(lower(trim(coalesce(p_email, ''))), '');
  if v_normalized_email is null then
    return null;
  end if;

  select cg.name
  into v_group_name
  from public.billing_profiles bp
  join public.customer_groups cg on cg.id = bp.customer_group_id
  where bp.tenant_id = p_tenant_id
    and lower(trim(bp.email)) = v_normalized_email
    and bp.id <> coalesce(p_exclude_billing_profile_id, -1)
  order by cg.id asc
  limit 1;

  if v_group_name is not null then
    return v_group_name;
  end if;

  select cg.name
  into v_group_name
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cg.tenant_id = p_tenant_id
    and cgm.role = 'admin'::public.customer_group_role
    and lower(trim(cgm.email)) = v_normalized_email
    and cgm.id <> coalesce(p_exclude_member_id, -1)
  order by cg.id asc
  limit 1;

  return v_group_name;
end;
$$;


ALTER FUNCTION "public"."find_customer_admin_email_conflict"("p_tenant_id" bigint, "p_email" "text", "p_exclude_billing_profile_id" bigint, "p_exclude_member_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_customer_group_member_email_rules"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_tenant_id bigint;
  v_normalized_email text;
  v_conflict_group_name text;
begin
  select cg.tenant_id
  into v_tenant_id
  from public.customer_groups cg
  where cg.id = new.customer_group_id;

  if v_tenant_id is null then
    raise exception 'customer group tenant could not be resolved';
  end if;

  v_normalized_email := lower(trim(new.email));
  new.email := v_normalized_email;

  if exists (
    select 1
    from public.customer_group_members cgm
    where cgm.customer_group_id = new.customer_group_id
      and lower(trim(cgm.email)) = v_normalized_email
      and cgm.id <> coalesce(new.id, -1)
  ) then
    raise exception 'This email is already used in this group';
  end if;

  if new.role = 'admin'::public.customer_group_role then
    v_conflict_group_name := public.find_customer_admin_email_conflict(
      v_tenant_id,
      v_normalized_email,
      null,
      new.id
    );

    if v_conflict_group_name is not null then
      raise exception 'This email is already admin of group "%".', v_conflict_group_name;
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."enforce_customer_group_member_email_rules"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_tenant_one_layer_hierarchy"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_parent_parent_id bigint;
begin
  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception 'tenant cannot be its own parent';
    select parent_id into v_parent_parent_id
    from public.tenants
    where id = new.parent_id;

    if v_parent_parent_id is not null then
      raise exception 'parent tenant must be a top-level company (one layer only)';
    if exists (
      select 1
      from public.tenants c
      where c.parent_id = new.id
    ) then
      raise exception 'tenant with child companies cannot be assigned a parent';
    ALTER FUNCTION "public"."enforce_tenant_one_layer_hierarchy"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant public.tenants%rowtype;
  v_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_cargo_company requires a parent tenant (got child %)', p_tenant_id;
  if auth.uid() is not null then
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    select id into v_id
  from public.cargo_companies
  where tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_id is not null then
    return v_id;
  select id into v_id
  from public.cargo_companies
  where tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_id is not null then
    update public.cargo_companies
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Cargo Company'),
        parent_tenant_id = coalesce(parent_tenant_id, p_tenant_id),
        is_active = true,
        updated_at = now()
    where id = v_id;
    return v_id;
  insert into public.cargo_companies (
    tenant_id,
    parent_tenant_id,
    name,
    code,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    p_tenant_id,
    'Default Cargo Company',
    'DEFAULT',
    true,
    true
  )
  returning id into v_id;

  insert into public.wallet_accounts (
    tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    'cargo_company',
    v_id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now();

  return v_id;
ALTER FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) OWNER TO "postgres";


    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain
  from public.tenants t
  where t.is_active = true
    and lower(trim(coalesce(t.public_domain, ''))) = nullif(
      regexp_replace(
        lower(
          trim(
            split_part(
              regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
              '/',
              1
            )
          )
        ),
        ':\d+$',
        ''
      ),
      ''
    )
  limit 1;
$_$;


ALTER FUNCTION "public"."find_active_tenant_by_public_domain"("p_public_domain" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_active_tenant_by_slug"("p_slug" "text") RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain
  from public.tenants t
  where t.is_active = true
    and lower(trim(t.slug)) = nullif(lower(trim(coalesce(p_slug, ''))), '')
  limit 1;
ALTER FUNCTION "public"."find_active_tenant_by_slug"("p_slug" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_recalculate_commerce_invoice_totals"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_subtotal numeric;
  v_is_delivery_charge_inclusive boolean;
begin
  -- 1. Calculate subtotal from commerce_order_items
  select coalesce(sum(quantity * recipient_price_bdt), 0)
  into v_subtotal
  from public.commerce_order_items
  where invoice_id = new.id;

  -- 2. Fetch order delivery inclusive flag
  select is_delivery_charge_inclusive
  into v_is_delivery_charge_inclusive
  from public.commerce_orders
  where id = new.order_id;

  v_is_delivery_charge_inclusive := coalesce(v_is_delivery_charge_inclusive, false);

  -- 3. Calculate total_amount
  if v_is_delivery_charge_inclusive then
    new.total_amount := greatest(0, v_subtotal + coalesce(new.wrapping_charge, 0) + coalesce(new.cod, 0) + coalesce(new.print_charge, 0) - coalesce(new.discount_amount, 0));
  else
    new.total_amount := greatest(0, v_subtotal + coalesce(new.delivery_charge, 0) + coalesce(new.wrapping_charge, 0) + coalesce(new.cod, 0) + coalesce(new.print_charge, 0) - coalesce(new.discount_amount, 0));
  -- 4. Calculate amount_due and payment status
  new.amount_due := greatest(0, new.total_amount - coalesce(new.amount_paid, 0));
  new.is_customer_group_paid := coalesce(new.amount_paid, 0) >= new.total_amount;

  -- 5. Update commerce_orders charges & shipment_payment
  update public.commerce_orders
  set delivery_charge = coalesce(new.delivery_charge, 0),
      wrapping_charge = coalesce(new.wrapping_charge, 0),
      cod = coalesce(new.cod, 0),
      invoice_print_charge = coalesce(new.print_charge, 0),
      shipment_payment = new.total_amount
  where id = new.order_id;

  ALTER FUNCTION "public"."fn_recalculate_commerce_invoice_totals"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fn_recalculate_normal_invoice_totals"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_subtotal numeric;
  v_discount numeric;
  v_total numeric;
begin
  select coalesce(sum(line_total_amount), 0)
  into v_subtotal
  from public.invoice_items
  where invoice_id = p_invoice_id;

  select discount_amount
  into v_discount
  from public.invoices
  where id = p_invoice_id;

  v_discount := coalesce(v_discount, 0);
  v_total := greatest(0, v_subtotal - v_discount);

  update public.invoices
  set subtotal_amount = v_subtotal,
      total_amount = v_total
  where id = p_invoice_id;

  perform public.recompute_invoice_payment_status(p_invoice_id);
ALTER FUNCTION "public"."fn_recalculate_normal_invoice_totals"("p_invoice_id" bigint) OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_current_year text;
  v_latest_barcode text;
  v_prefix text;
  v_max_seq integer := 0;
  v_barcode_id text;
  v_generated text[] := array[]::text[];
  v_tenant_prefix text;
  c1 integer;
  c2 integer;
  i integer;
begin
  -- Advisory lock to prevent race conditions on sequence generation for this tenant
  perform pg_advisory_xact_lock(p_tenant_id);

  -- Determine the current year (2 digits, e.g. '26')
  v_current_year := to_char(now(), 'YY');

  -- Format tenant prefix as 2 digits
  v_tenant_prefix := lpad(p_tenant_id::text, 2, '0');

  -- Validate quantity
  if p_quantity not in (50, 100, 150, 200, 300, 400, 500) then
    raise exception 'Quantity must be one of 50, 100, 150, 200, 300, 400, 500';
  -- Find the latest barcode generated for the current year with the new tenant prefix format
  select barcode_id into v_latest_barcode
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id like v_tenant_prefix || '-__-' || v_current_year || '-%'
  order by barcode_id desc
  limit 1;

  if v_latest_barcode is null then
    -- Start from AA for the new year
    v_prefix := 'AA';
    v_max_seq := 0;
  else
    -- Extract prefix and last sequence number (e.g. "01-AA-26-000001")
    v_prefix := substring(v_latest_barcode from 4 for 2);
    v_max_seq := substring(v_latest_barcode from 10)::integer;

    -- If sequence has reached the maximum of 999999, rollover prefix
    if v_max_seq >= 999999 then
      c1 := ascii(substring(v_prefix from 1 for 1));
      c2 := ascii(substring(v_prefix from 2 for 1));
      
      c2 := c2 + 1;
      if c2 > 90 then -- ASCII for 'Z'
        c2 := 65; -- ASCII for 'A'
        c1 := c1 + 1;
        if c1 > 90 then
          raise exception 'Maximum barcode prefix ZZ-999999 reached!';
        v_prefix := chr(c1) || chr(c2);
      v_max_seq := 0;
    -- Loop and insert p_quantity barcodes
  for i in 1..p_quantity loop
    v_barcode_id := v_tenant_prefix || '-' || v_prefix || '-' || v_current_year || '-' || lpad((v_max_seq + i)::text, 6, '0');
    
    insert into public.thrift_barcodes (
      tenant_id,
      barcode_id,
      status,
      is_printed,
      inserted_by
    )
    values (
      p_tenant_id,
      v_barcode_id,
      'AVAILABLE',
      0,
      p_inserted_by
    );
    
    v_generated := array_append(v_generated, v_barcode_id);
  return v_generated;
ALTER FUNCTION "public"."generate_thrift_barcodes"("p_tenant_id" bigint, "p_quantity" integer, "p_inserted_by" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone DEFAULT "now"()) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_year_month TEXT;
  v_next BIGINT;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  v_year_month := to_char(COALESCE(p_date, NOW()), 'YYYY-MM');

  INSERT INTO public.thrift_invoice_counters (tenant_id, year_month, last_value)
  VALUES (p_tenant_id, v_year_month, 1)
  ON CONFLICT (tenant_id, year_month)
  DO UPDATE
    SET last_value = public.thrift_invoice_counters.last_value + 1
  RETURNING last_value INTO v_next;

  RETURN 'INV-' || v_year_month || '-' || lpad(v_next::TEXT, 5, '0');
END;
ALTER FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone DEFAULT "now"()) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_year_month TEXT;
  v_next BIGINT;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  v_year_month := to_char(COALESCE(p_date, NOW()), 'YYYY-MM');

  INSERT INTO public.thrift_return_counters (tenant_id, year_month, last_value)
  VALUES (p_tenant_id, v_year_month, 1)
  ON CONFLICT (tenant_id, year_month)
  DO UPDATE
    SET last_value = public.thrift_return_counters.last_value + 1
  RETURNING last_value INTO v_next;

  RETURN 'RET-' || v_year_month || '-' || lpad(v_next::TEXT, 5, '0');
END;
ALTER FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_active_module_keys_for_tenant"("p_tenant_id" bigint) RETURNS "text"[]
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with active_assignments as (
    select tm.module_key
    from public.tenant_modules tm
    inner join public.modules mo on mo.key = tm.module_key
    inner join public.tenants t on t.id = tm.tenant_id
    where p_tenant_id is not null
      and tm.tenant_id = p_tenant_id
      and t.is_active = true
      and tm.is_active = true
      and mo.is_active = true
  ),
  expanded_child_keys as (
    select child.key as module_key
    from active_assignments a
    inner join public.modules child
      on child.parent_module_key = a.module_key
    where child.is_active = true
      and not exists (
        select 1
        from public.tenant_module_submodules tms
        where tms.tenant_id = p_tenant_id
          and tms.submodule_key = child.key
          and tms.is_enabled = false
      )
  ),
  combined as (
    select module_key from active_assignments
    union
    select module_key from expanded_child_keys
  ),
  tenant_kind as (
    select exists (
      select 1
      from public.tenants child
      where child.parent_id = p_tenant_id
    ) as is_parent_company
  ),
  visible as (
    select c.module_key
    from combined c
    cross join tenant_kind k
    where c.module_key is not null
      and not (
        k.is_parent_company
        and (
          c.module_key = 'shop_order'
          or exists (
            select 1
            from public.modules mo
            where mo.key = c.module_key
              and mo.parent_module_key = 'shop_order'
          )
        )
      )
  )
  select coalesce(
    array_agg(v.module_key order by v.module_key)
      filter (where v.module_key is not null),
    '{}'::text[]
  )
  from visible v;
ALTER FUNCTION "public"."get_active_module_keys_for_tenant"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_app_bootstrap_context"("p_email" "text" DEFAULT NULL::"text", "p_tenant_id" bigint DEFAULT NULL::bigint, "p_membership_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("member_id" bigint, "member_email" "text", "member_role" "public"."app_role", "member_is_active" boolean, "member_preference" "jsonb", "tenant_id" bigint, "tenant_name" "text", "tenant_slug" "text", "tenant_is_active" boolean, "tenant_preference" "jsonb", "active_module_keys" "text"[], "tenant_role_id" bigint, "is_admin" boolean, "effective_grants" "jsonb", "permission_version" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text;
  v_member record;
  v_grants jsonb;
  v_perm_version bigint;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email())));

  select
    m.id,
    lower(trim(m.email)) as email,
    m.role,
    m.is_active,
    m.preference as member_preference,
    m.tenant_role_id,
    t.id as tenant_id,
    t.name as tenant_name,
    t.slug as tenant_slug,
    t.is_active as tenant_is_active,
    t.preference as tenant_preference,
    tr.is_admin
  into v_member
  from public.memberships m
  inner join public.tenants t on t.id = m.tenant_id
  left join public.tenant_roles tr on tr.id = m.tenant_role_id
  where lower(trim(m.email)) = v_email
    and m.is_active = true
    and m.role in ('admin', 'staff', 'viewer')
    and (p_tenant_id is null or m.tenant_id = p_tenant_id)
    and (p_membership_id is null or m.id = p_membership_id)
  order by
    case m.role
      when 'admin' then 1
      when 'staff' then 2
      when 'viewer' then 3
      else 99
    end,
    m.id asc
  limit 1;

  if v_member.id is null then
    return;
  select coalesce(
    jsonb_agg(jsonb_build_object('module_key', module_key, 'action', action)),
    '[]'::jsonb
  )
  into v_grants
  from public.get_effective_grants(v_member.tenant_id);

  select tpv.version into v_perm_version
  from public.tenant_permission_versions tpv
  where tpv.tenant_id = v_member.tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(v_member.tenant_id);
    v_perm_version := 1;
  member_id := v_member.id;
  member_email := v_member.email;
  member_role := v_member.role;
  member_is_active := v_member.is_active;
  member_preference := coalesce(v_member.member_preference, '{}'::jsonb);
  tenant_id := v_member.tenant_id;
  tenant_name := v_member.tenant_name;
  tenant_slug := v_member.tenant_slug;
  tenant_is_active := v_member.tenant_is_active;
  tenant_preference := coalesce(v_member.tenant_preference, '{}'::jsonb);
  active_module_keys := coalesce(public.get_active_module_keys_for_tenant(v_member.tenant_id), '{}'::text[]);
  tenant_role_id := v_member.tenant_role_id;
  is_admin := coalesce(v_member.is_admin, false);
  effective_grants := v_grants;
  permission_version := v_perm_version;

  return next;
ALTER FUNCTION "public"."get_app_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_membership_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_cart"("p_cart_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_result jsonb;
begin
  if not public.can_access_cart(p_cart_id) then
    raise exception 'not authorized to access this cart';
  select jsonb_build_object(
    'cart',
    jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'store_id', c.store_id,
      'customer_group_id', c.customer_group_id,
      'can_see_price', c.can_see_price,
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'items',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'name', ci.name,
            'image_url', ci.image_url,
            'price_gbp', ci.price_gbp,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'created_at', ci.created_at,
            'updated_at', ci.updated_at
          )
          order by ci.id
        )
        from public.cart_items ci
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.carts c
  where c.id = p_cart_id;

  if v_result is null then
    raise exception 'cart not found';
  return v_result;
ALTER FUNCTION "public"."get_cart"("p_cart_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_cart"("p_cart_id" bigint) IS 'Returns a cart and its cart items without product join.';


CREATE OR REPLACE FUNCTION "public"."get_cart_details"("p_cart_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_result jsonb;
begin
  if not public.can_access_cart(p_cart_id) then
    raise exception 'not authorized to access this cart';
  select jsonb_build_object(
    'cart',
    jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'store_id', c.store_id,
      'customer_group_id', c.customer_group_id,
      'can_see_price', c.can_see_price,
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'items',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'name', ci.name,
            'image_url', ci.image_url,
            'price_gbp', ci.price_gbp,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'created_at', ci.created_at,
            'updated_at', ci.updated_at,
            'product',
            case
              when p.id is null then null
              else jsonb_build_object(
                'id', p.id,
                'tenant_id', p.tenant_id,
                'product_code', p.product_code,
                'barcode', p.barcode,
                'name', p.name,
                'price_gbp', p.list_price_amount, -- compatibility mapping
                'list_price_amount', p.list_price_amount,
                'list_price_currency_id', p.list_price_currency_id,
                'reference_cost_amount', p.reference_cost_amount,
                'reference_cost_currency_id', p.reference_cost_currency_id,
                'country_of_origin', p.country_of_origin,
                'brand', p.brand,
                'category', p.category,
                'available_units', p.available_units,
                'tariff_code', p.tariff_code,
                'languages', p.languages,
                'batch_code_manufacture_date', p.batch_code_manufacture_date,
                'image_url', p.image_url,
                'expire_date', p.expire_date,
                'minimum_order_quantity', p.minimum_order_quantity,
                'product_weight', p.product_weight,
                'package_weight', p.package_weight,
                'is_available', p.is_available,
                'vendor_code', p.vendor_code,
                'market_code', p.market_code,
                'created_at', p.created_at,
                'updated_at', p.updated_at
              )
            end
          )
          order by ci.id
        )
        from public.cart_items ci
        left join public.products p
          on p.id = ci.product_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.carts c
  where c.id = p_cart_id;

  if v_result is null then
    raise exception 'cart not found';
  return v_result;
ALTER FUNCTION "public"."get_cart_details"("p_cart_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_cart_details"("p_cart_id" bigint) IS 'Returns a cart and its cart items with nested product details.';


CREATE OR REPLACE FUNCTION "public"."get_courier_unremitted_financial_summary"("p_tenant_id" bigint) RETURNS TABLE("courier_service_id" "uuid", "courier_name" "text", "gross_cod_total" numeric, "company_wholesale_total" numeric, "middleman_margin_total" numeric, "order_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  return query
  select
    so.courier_service_id,
    coalesce(cs.name, so.courier_name, 'Unassigned') as courier_name,
    coalesce(sum(coalesce(so.cod_collect_amount, gi.total_amount, 0)), 0.00)::numeric(12,2) as gross_cod_total,
    (
      coalesce(sum(coalesce(so.cod_collect_amount, gi.total_amount, 0)), 0.00) -
      coalesce(sum(coalesce(wl.amount, 0)), 0.00)
    )::numeric(12,2) as company_wholesale_total,
    coalesce(sum(coalesce(wl.amount, 0)), 0.00)::numeric(12,2) as middleman_margin_total,
    count(so.id)::bigint as order_count
  from public.shop_orders so
  left join public.courier_services cs on cs.id = so.courier_service_id
  left join public.global_invoices gi on gi.id = so.global_invoice_id
  left join public.billing_profile_wallet_ledger wl
    on wl.shop_order_id = so.id and wl.transaction_type = 'dropship_profit'
  where so.tenant_id = p_tenant_id
    and so.status = 'delivered'
  group by so.courier_service_id, coalesce(cs.name, so.courier_name, 'Unassigned');
ALTER FUNCTION "public"."get_courier_unremitted_financial_summary"("p_tenant_id" bigint) OWNER TO "postgres";


    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
begin
  select m.id, m.tenant_role_id, tr.is_admin
  into v_member_id, v_tenant_role_id, v_role_is_admin
  from public.memberships m
  left join public.tenant_roles tr on tr.id = m.tenant_role_id
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = public.current_user_email()
    and m.is_active = true;

  if public.is_superadmin() or coalesce(v_role_is_admin, false) = true then
    return query
    select ma.module_key, ma.action
    from public.module_actions ma
    join public.tenant_modules tm on tm.module_key = ma.module_key
    where tm.tenant_id = p_tenant_id
      and tm.is_active = true
      and ma.is_active = true
      and (ma.scope <> 'platform' or public.is_superadmin())
      and not (
        exists (
          select 1
          from public.tenants
          where id = p_tenant_id
            and parent_id is not null
        ) and ma.module_key in (
          'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
          'shipment_reports', 'parent_dashboard', 'investor_reports',
          'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
        )
      );
    return;
  return query
  with role_allowed as (
    select rg.module_key, rg.action
    from public.tenant_role_grants rg
    where rg.tenant_role_id = v_tenant_role_id
      and rg.allowed = true
  ),
  with_overrides as (
    select ra.module_key, ra.action from role_allowed ra
    union
    select mg.module_key, mg.action
    from public.membership_grants mg
    where mg.membership_id = v_member_id
      and mg.effect = 'allow'
  ),
  effective as (
    select wo.module_key, wo.action from with_overrides wo
    except
    select mg.module_key, mg.action
    from public.membership_grants mg
    where mg.membership_id = v_member_id
      and mg.effect = 'deny'
  )
  select e.module_key, e.action
  from effective e
  join public.module_actions ma on ma.module_key = e.module_key and ma.action = e.action
  join public.tenant_modules tm on tm.module_key = e.module_key
  where tm.tenant_id = p_tenant_id
    and tm.is_active = true
    and ma.is_active = true
    and (ma.scope <> 'platform' or public.is_superadmin())
    and not (
      exists (
        select 1
        from public.tenants
        where id = p_tenant_id
          and parent_id is not null
      ) and ma.module_key in (
        'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
        'shipment_reports', 'parent_dashboard', 'investor_reports',
        'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
      )
    );
ALTER FUNCTION "public"."get_effective_grants"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_effective_item_role"("p_item_id" bigint, "p_user_email" "text") RETURNS "text"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_role text;
  v_created_by_email text;
  v_user_role_in_tenant text;
  v_is_superadmin boolean;
  v_email text;
  v_accessibility text;
  v_type text;
begin
  v_email := lower(trim(p_user_email));

  -- 1. Check if user is superadmin
  select exists (
    select 1 from public.memberships m
    where lower(trim(m.email)) = v_email
      and m.role = 'superadmin'
      and m.is_active = true
  ) into v_is_superadmin;

  if v_is_superadmin then
    return 'owner';
  -- Get item info
  select parent_id, tenant_id, created_by_email, accessibility, type
  into v_parent_id, v_tenant_id, v_created_by_email, v_accessibility, v_type
  from public.items
  where id = p_item_id;

  if not found then
    return null;
  -- PRIVATE accessibility checks (ONLY creator/superadmin)
  if v_accessibility = 'private' then
    if lower(trim(v_created_by_email)) = v_email then
      return 'owner';
    else
      return null;
    -- RESTRICTED accessibility checks (ONLY creator/superadmin, explicit permissions, or assignees)
  if v_accessibility = 'restricted' then
    -- Check creator
    if lower(trim(v_created_by_email)) = v_email then
      return 'owner';
    -- Check explicit permissions on this specific item
    select role into v_role
    from public.item_permissions
    where item_id = p_item_id and lower(trim(user_email)) = v_email;

    if v_role is not null then
      return v_role;
    -- Check if user is an assignee
    if exists (
      select 1 from public.item_assignees
      where item_id = p_item_id and lower(trim(user_email)) = v_email
    ) then
      return 'viewer';
    -- STANDARD PUBLIC accessibility checks
  -- Check creator
  if lower(trim(v_created_by_email)) = v_email then
    return 'owner';
  -- Check explicit permissions on this item
  select role into v_role
  from public.item_permissions
  where item_id = p_item_id and lower(trim(user_email)) = v_email;

  if v_role is not null then
    return v_role;
  -- Check recursive parent permissions
  if v_parent_id is not null then
    v_role := public.get_effective_item_role(v_parent_id, v_email);
    if v_role is not null then
      return v_role;
    -- Fallback to tenant memberships
  if v_tenant_id is not null then
    select m.role::text into v_user_role_in_tenant
    from public.memberships m
    where lower(trim(m.email)) = v_email
      and m.tenant_id = v_tenant_id
      and m.is_active = true;

    if v_user_role_in_tenant = 'admin' then
      return 'owner';
    elsif v_user_role_in_tenant = 'staff' then
      return 'editor';
    elsif v_user_role_in_tenant = 'viewer' then
      return 'viewer';
    ALTER FUNCTION "public"."get_effective_item_role"("p_item_id" bigint, "p_user_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_investor_allocation_detail"("p_tenant_id" bigint, "p_investor_id" bigint, "p_global_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shipment record;
  v_investment record;
  v_pnl jsonb;
begin
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  select * into v_shipment
  from public.global_shipments
  where id = p_global_shipment_id;

  if not found then
    return null;
  select * into v_investment
  from public.shipment_investments
  where investor_id = p_investor_id
    and global_shipment_id = p_global_shipment_id
    and status = 'active';

  if not found then
    return null;
  v_pnl := public.get_shipment_pnl(p_tenant_id, p_global_shipment_id);

  return jsonb_build_object(
    'id', v_investment.id,
    'global_shipment_id', v_investment.global_shipment_id,
    'shipment_name', v_shipment.name,
    'shipment_status', v_shipment.status,
    'cost_share_pct', v_investment.cost_share_pct,
    'allocated_cost', v_investment.allocated_cost,
    'computed_profit', v_investment.computed_profit,
    'profit_status', v_investment.profit_status,
    'created_at', v_investment.created_at,
    'invested_amount', v_investment.invested_amount,
    'total_landed_cost', coalesce((v_pnl -> 'totals' ->> 'landed_cost')::numeric, 0.00),
    'realized_revenue', coalesce((v_pnl -> 'totals' ->> 'revenue')::numeric, 0.00),
    'gross_profit', coalesce((v_pnl -> 'totals' ->> 'gross_profit')::numeric, 0.00),
    'unsold_value', coalesce((v_pnl -> 'totals' ->> 'unsold_value')::numeric, 0.00),
    'shrinkage_value', coalesce((v_pnl -> 'totals' ->> 'shrinkage_value')::numeric, 0.00)
  );
ALTER FUNCTION "public"."get_investor_allocation_detail"("p_tenant_id" bigint, "p_investor_id" bigint, "p_global_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_investor_bootstrap_context"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_membership public.memberships;
  v_tenant public.tenants;
  v_perm_version bigint;
begin
  select * into v_tenant from public.tenants where id = p_tenant_id;
  if v_tenant.id is null then raise exception 'tenant not found'; select * into v_membership
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = public.current_user_email()
    and m.is_active = true
    and m.role = 'investor'::public.app_role
  limit 1;

  if v_membership.id is null then
    return jsonb_build_object('authenticated', false, 'tenant', row_to_json(v_tenant));
  select version into v_perm_version
  from public.tenant_permission_versions
  where tenant_id = p_tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(p_tenant_id);
    v_perm_version := 1;
  return jsonb_build_object(
    'authenticated', true,
    'tenant', row_to_json(v_tenant),
    'investor_account', row_to_json(v_membership),
    'portfolio', public.get_investor_portfolio_summary(v_membership.investor_id),
    'module_keys', (
      select coalesce(jsonb_agg(tm.module_key), '[]'::jsonb)
      from public.tenant_modules tm
      where tm.tenant_id = p_tenant_id
        and tm.is_active = true
        and tm.module_key = 'investor_portal'
    ),
    'permission_version', v_perm_version
  );
ALTER FUNCTION "public"."get_investor_bootstrap_context"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_investor_capital_report"("p_tenant_id" bigint, "p_investor_id" bigint, "p_start_date" "date", "p_end_date" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_deposits numeric(12,2);
  v_withdrawals numeric(12,2);
  v_profit numeric(12,2);
  v_starting_balance numeric(12,2);
  v_ending_balance numeric(12,2);
  v_starting_deposits numeric(12,2);
  v_starting_withdrawals numeric(12,2);
  v_starting_profit numeric(12,2);
begin
  if not (
    public.membership_has_module_action(p_tenant_id, 'investor_reports', 'view')
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  select coalesce(sum(amount), 0) into v_deposits
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment')
    and date >= p_start_date and date <= p_end_date;

  select coalesce(sum(amount), 0) into v_withdrawals
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('withdrawal', 'withdrawal_paid', 'profit_payout')
    and date >= p_start_date and date <= p_end_date;

  select coalesce(sum(computed_profit), 0) into v_profit
  from public.shipment_investments
  where investor_id = p_investor_id
    and status = 'active'
    and profit_status = 'realized'
    and updated_at::date >= p_start_date and updated_at::date <= p_end_date;

  select coalesce(sum(amount), 0) into v_starting_deposits
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment')
    and date < p_start_date;

  select coalesce(sum(amount), 0) into v_starting_withdrawals
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('withdrawal', 'withdrawal_paid', 'profit_payout')
    and date < p_start_date;

  select coalesce(sum(computed_profit), 0) into v_starting_profit
  from public.shipment_investments
  where investor_id = p_investor_id
    and status = 'active'
    and profit_status = 'realized'
    and updated_at::date < p_start_date;

  v_starting_balance := v_starting_deposits + v_starting_profit - v_starting_withdrawals;
  v_ending_balance := v_starting_balance + v_deposits + v_profit - v_withdrawals;

  return jsonb_build_object(
    'investor_id', p_investor_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'starting_balance', v_starting_balance,
    'deposits_sum', v_deposits,
    'withdrawals_sum', v_withdrawals,
    'profit_earned_sum', v_profit,
    'ending_balance', v_ending_balance
  );
ALTER FUNCTION "public"."get_investor_capital_report"("p_tenant_id" bigint, "p_investor_id" bigint, "p_start_date" "date", "p_end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_investor_dashboard_summary"("p_tenant_id" bigint, "p_investor_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_capital_in numeric(12,2) := 0;
  v_total_withdrawn numeric(12,2) := 0;
  v_deployed_capital numeric(12,2) := 0;
  v_realized_profit numeric(12,2) := 0;
  v_unrealized_profit numeric(12,2) := 0;
  v_withdrawable_balance numeric(12,2) := 0;
begin
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  select coalesce(sum(amount), 0) into v_total_capital_in
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment');

  select coalesce(sum(amount), 0) into v_total_withdrawn
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('withdrawal', 'withdrawal_paid', 'profit_payout');

  select coalesce(sum(allocated_cost), 0) into v_deployed_capital
  from public.shipment_investments
  where investor_id = p_investor_id
    and status = 'active';

  select
    coalesce(sum(case when profit_status = 'realized' then computed_profit else 0 end), 0),
    coalesce(sum(case when profit_status in ('open', 'partial') then computed_profit else 0 end), 0)
  into v_realized_profit, v_unrealized_profit
  from public.shipment_investments
  where investor_id = p_investor_id
    and status = 'active';

  v_withdrawable_balance := v_realized_profit - v_total_withdrawn;

  return jsonb_build_object(
    'total_capital_in', v_total_capital_in,
    'deployed_capital', v_deployed_capital,
    'unallocated_cash', v_total_capital_in - v_total_withdrawn - v_deployed_capital,
    'realized_profit', v_realized_profit,
    'unrealized_profit', v_unrealized_profit,
    'withdrawable_balance', v_withdrawable_balance,
    'total_withdrawn', v_total_withdrawn
  );
ALTER FUNCTION "public"."get_investor_dashboard_summary"("p_tenant_id" bigint, "p_investor_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_investor_portfolio_summary"("p_investor_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_investor public.investors;
  v_deposits numeric(12,2);
  v_withdrawals numeric(12,2);
  v_deployed numeric(12,2);
  v_payouts numeric(12,2);
  v_realized_profit numeric(12,2);
  v_unrealized_profit numeric(12,2);
begin
  select * into v_investor from public.investors where id = p_investor_id;
  if v_investor.id is null then raise exception 'investor not found'; if not (
    public.user_can_manage_parent_tenant(v_investor.tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  -- Total capital in including adjustments
  select coalesce(sum(amount), 0) into v_deposits
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment');

  -- Total withdrawals
  select coalesce(sum(amount), 0) into v_withdrawals
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('withdrawal', 'withdrawal_paid', 'profit_payout');

  -- Legacy payouts field (for compatibility if needed)
  select coalesce(sum(amount), 0) into v_payouts
  from public.investor_transactions
  where investor_id = p_investor_id
    and type = 'profit_payout';

  -- Deployed capital
  select coalesce(sum(allocated_cost), 0) into v_deployed
  from public.shipment_investments
  where investor_id = p_investor_id and status = 'active';

  -- Realized & Unrealized profits
  select
    coalesce(sum(case when profit_status = 'realized' then computed_profit else 0 end), 0),
    coalesce(sum(case when profit_status in ('open', 'partial') then computed_profit else 0 end), 0)
  into v_realized_profit, v_unrealized_profit
  from public.shipment_investments
  where investor_id = p_investor_id and status = 'active';

  return jsonb_build_object(
    'investor', row_to_json(v_investor),
    'balances', jsonb_build_object(
      'deposits', v_deposits,
      'withdrawals', v_withdrawals,
      'deployed', v_deployed,
      'available', v_deposits - v_withdrawals - v_deployed,
      'payouts', v_payouts,
      'realized_profit', v_realized_profit,
      'unrealized_profit', v_unrealized_profit,
      'withdrawable_balance', v_realized_profit - v_withdrawals
    ),
    'active_investments', (
      select coalesce(jsonb_agg(to_jsonb(si.*)), '[]'::jsonb)
      from public.shipment_investments si
      where si.investor_id = p_investor_id and si.status = 'active'
    )
  );
ALTER FUNCTION "public"."get_investor_portfolio_summary"("p_investor_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_item_details"("p_item_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text;
  v_item jsonb;
  v_assignees jsonb;
  v_tags jsonb;
  v_comments jsonb;
  v_permissions jsonb;
  v_activity_logs jsonb;
begin
  v_email := public.current_user_email();

  -- Check item exists and permissions allow reading it
  if public.get_effective_item_role(p_item_id, v_email) is null then
    return null;
  -- 1. Fetch item details
  select row_to_json(i)
  into v_item
  from public.items i
  where i.id = p_item_id;

  -- 2. Fetch assignees
  select coalesce(json_agg(row_to_json(ia)), '[]'::json)
  into v_assignees
  from (
    select * from public.item_assignees
    where item_id = p_item_id
  ) ia;

  -- 3. Fetch tags
  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  into v_tags
  from (
    select t.* from public.item_tags it
    join public.tags t on t.id = it.tag_id
    where it.item_id = p_item_id
  ) t;

  -- 4. Fetch comments (ordered by created_at asc)
  select coalesce(json_agg(row_to_json(c)), '[]'::json)
  into v_comments
  from (
    select * from public.comments
    where item_id = p_item_id
    order by created_at asc
  ) c;

  -- 5. Fetch permissions
  select coalesce(json_agg(row_to_json(ip)), '[]'::json)
  into v_permissions
  from (
    select * from public.item_permissions
    where item_id = p_item_id
  ) ip;

  -- 6. Fetch activity logs (ordered by created_at desc)
  select coalesce(json_agg(row_to_json(al)), '[]'::json)
  into v_activity_logs
  from (
    select * from public.activity_logs
    where item_id = p_item_id
    order by created_at desc
  ) al;

  -- Return combined result
  return jsonb_build_object(
    'item', v_item,
    'assignees', v_assignees,
    'tags', v_tags,
    'comments', v_comments,
    'permissions', v_permissions,
    'activity_logs', v_activity_logs
  );
ALTER FUNCTION "public"."get_item_details"("p_item_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_koba_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select jsonb_build_object(
    'cart',
    to_jsonb(c),
    'items',
    coalesce(
      (
        select jsonb_agg(to_jsonb(ci) order by ci.id)
        from public.koba_cart_items ci
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  from public.koba_carts c
  where c.tenant_id = p_tenant_id
    and c.customer_group_id is not distinct from p_customer_group_id
  limit 1;
ALTER FUNCTION "public"."get_koba_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_koba_customer_profile"("p_tenant_id" bigint, "p_phone" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_latest_order_id bigint;
  v_latest_name text;
  v_latest_district text;
  v_latest_thana text;
  v_latest_address text;
  
  v_total_orders bigint;
  v_total_spent numeric(12,2);
  v_first_order_date timestamptz;
  v_last_order_date timestamptz;
  v_avg_days_between_orders numeric(10,2);
  
  v_brand_demand jsonb;
  v_top_products jsonb;
  v_order_history jsonb;
begin
  -- Access Control Check: Only tenant admin, staff, or superadmin can view analytics
  if not (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.tenant_id = p_tenant_id
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  ) then
    raise exception 'access denied';
  -- Get overview stats
  select
    max(id) as last_order_id,
    count(id) as total_orders,
    coalesce(sum(subtotal_gbp), 0) as total_spent,
    min(created_at) as first_order_date,
    max(created_at) as last_order_date
  into
    v_latest_order_id,
    v_total_orders,
    v_total_spent,
    v_first_order_date,
    v_last_order_date
  from public.koba_orders
  where tenant_id = p_tenant_id
    and shipping_phone = p_phone;
    
  if v_total_orders = 0 or v_total_orders is null then
    return null;
  -- Calculate average frequency (days between orders)
  if v_total_orders > 1 then
    v_avg_days_between_orders := (extract(epoch from (v_last_order_date - v_first_order_date)) / 86400.0) / (v_total_orders - 1);
  else
    v_avg_days_between_orders := null;
  -- Get contact details from latest order
  select
    shipping_name,
    shipping_district,
    shipping_thana,
    shipping_address
  into
    v_latest_name,
    v_latest_district,
    v_latest_thana,
    v_latest_address
  from public.koba_orders
  where id = v_latest_order_id;
  
  -- Aggregate brand demand (Top 5 ordered brands)
  select coalesce(jsonb_agg(x), '[]'::jsonb)
  into v_brand_demand
  from (
    select
      coalesce(nullif(trim(oi.brand), ''), 'Unknown') as brand,
      count(distinct o.id) as order_count,
      sum(oi.quantity) as item_count
    from public.koba_orders o
    join public.koba_order_items oi on oi.order_id = o.id
    where o.tenant_id = p_tenant_id
      and o.shipping_phone = p_phone
    group by coalesce(nullif(trim(oi.brand), ''), 'Unknown')
    order by order_count desc, item_count desc
    limit 5
  ) x;
  
  -- Aggregate top products (Top 5 ordered products)
  select coalesce(jsonb_agg(y), '[]'::jsonb)
  into v_top_products
  from (
    select
      oi.product_id,
      oi.name,
      coalesce(nullif(trim(oi.brand), ''), 'Unknown') as brand,
      sum(oi.quantity) as total_quantity
    from public.koba_orders o
    join public.koba_order_items oi on oi.order_id = o.id
    where o.tenant_id = p_tenant_id
      and o.shipping_phone = p_phone
    group by oi.product_id, oi.name, oi.brand
    order by total_quantity desc
    limit 5
  ) y;
  
  -- Aggregate order history timeline
  select coalesce(jsonb_agg(z), '[]'::jsonb)
  into v_order_history
  from (
    select
      o.id as order_id,
      o.subtotal_gbp,
      o.net_order_commission,
      o.status,
      o.created_at
    from public.koba_orders o
    where o.tenant_id = p_tenant_id
      and o.shipping_phone = p_phone
    order by o.created_at desc
    limit 15
  ) z;
  
  -- Return consolidated JSON response
  return jsonb_build_object(
    'phone', p_phone,
    'name', v_latest_name,
    'district', v_latest_district,
    'thana', v_latest_thana,
    'address', v_latest_address,
    'total_orders', v_total_orders,
    'total_spent', v_total_spent,
    'first_order_date', v_first_order_date,
    'last_order_date', v_last_order_date,
    'avg_days_between_orders', v_avg_days_between_orders,
    'brand_demand', v_brand_demand,
    'top_products', v_top_products,
    'order_history', v_order_history
  );
ALTER FUNCTION "public"."get_koba_customer_profile"("p_tenant_id" bigint, "p_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_koba_customers_list"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("phone" "text", "name" "text", "district" "text", "thana" "text", "address" "text", "total_orders" bigint, "total_spent" numeric, "last_order_date" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  -- Access Control Check: Only tenant admin, staff, or superadmin can view analytics
  if not (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.tenant_id = p_tenant_id
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  ) then
    raise exception 'access denied';
  return query
  with customer_phones as (
    select
      o.shipping_phone as cp_phone,
      count(o.id) as cp_total_orders,
      coalesce(sum(o.subtotal_gbp), 0) as cp_total_spent,
      max(o.created_at) as cp_last_order_date,
      max(o.id) as cp_last_order_id
    from public.koba_orders o
    where o.tenant_id = p_tenant_id
      and o.shipping_phone is not null
      and o.shipping_phone <> ''
      and (
        p_search is null 
        or p_search = '' 
        or o.shipping_phone iLike '%' || trim(p_search) || '%' 
        or o.shipping_name iLike '%' || trim(p_search) || '%'
      )
    group by o.shipping_phone
  )
  select
    cp.cp_phone as phone,
    o.shipping_name as name,
    o.shipping_district as district,
    o.shipping_thana as thana,
    o.shipping_address as address,
    cp.cp_total_orders as total_orders,
    cp.cp_total_spent::numeric(12,2) as total_spent,
    cp.cp_last_order_date as last_order_date
  from customer_phones cp
  join public.koba_orders o on o.id = cp.cp_last_order_id
  order by cp.cp_last_order_date desc
  limit p_limit offset p_offset;
ALTER FUNCTION "public"."get_koba_customers_list"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_deposits numeric(12,2);
  v_withdrawals numeric(12,2);
  v_deployed numeric(12,2);
  v_ar_due numeric(12,2);
  v_ar_paid numeric(12,2);
  v_stock_cost numeric(12,2);
  v_profit_mtd numeric(12,2);
  v_payouts numeric(12,2);
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  select
    coalesce(sum(case when type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment') then amount else 0 end), 0),
    coalesce(sum(case when type in ('withdrawal', 'withdrawal_paid') then amount else 0 end), 0)
  into v_deposits, v_withdrawals
  from public.investor_transactions it
  where it.tenant_id = p_parent_tenant_id;

  select coalesce(sum(coalesce(allocated_cost, invested_amount)), 0) into v_deployed
  from public.shipment_investments
  where tenant_id = p_parent_tenant_id and status = 'active';

  select
    coalesce(sum(due_amount), 0),
    coalesce(sum(paid_amount), 0)
  into v_ar_due, v_ar_paid
  from public.global_invoices
  where parent_tenant_id = p_parent_tenant_id;

  select coalesce(sum(
    public.calculate_landed_unit_cost(gs.shipment_item_id) * gs.quantity
  ), 0) into v_stock_cost
  from public.global_stocks gs
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_parent_tenant_id
    and gst.is_sellable = true
    and gs.quantity > 0;

  with invoice_line_margin as (
    select
      ii.invoice_id,
      sum((ii.sell_price_amount - ii.unit_cost_price) * ii.quantity - ii.line_discount_amount) as lines_margin
    from public.global_invoice_items ii
    join public.global_invoices i on i.id = ii.invoice_id
    where i.parent_tenant_id = p_parent_tenant_id
      and i.invoice_status = 'issued'::public.global_invoice_status
      and i.invoice_date >= date_trunc('month', current_date)::date
    group by ii.invoice_id
  ),
  invoice_return_margin as (
    select
      ri.invoice_id,
      sum(ri.return_accounting_amount - (ii.unit_cost_price * ri.quantity)) as returns_margin
    from public.global_return_items ri
    join public.global_invoice_items ii on ii.id = ri.invoice_item_id
    join public.global_invoices i on i.id = ri.invoice_id
    where i.parent_tenant_id = p_parent_tenant_id
      and i.invoice_status = 'issued'::public.global_invoice_status
      and i.invoice_date >= date_trunc('month', current_date)::date
    group by ri.invoice_id
  )
  select coalesce(sum(
    coalesce(lm.lines_margin, 0.00)
      - i.discount_amount
      + (case
           when i.invoice_type = 'wholesale' or i.invoice_type = 'dropship' then i.shipping_charge
           when i.invoice_type = 'retail' then i.shipping_charge + i.cod_charge + i.print_charge + i.wrapping_charge
           else 0.00
         end)
      - coalesce(rm.returns_margin, 0.00)
  ), 0) into v_profit_mtd
  from public.global_invoices i
  left join invoice_line_margin lm on lm.invoice_id = i.id
  left join invoice_return_margin rm on rm.invoice_id = i.id
  where i.parent_tenant_id = p_parent_tenant_id
    and i.invoice_status = 'issued'::public.global_invoice_status
    and i.invoice_date >= date_trunc('month', current_date)::date;

  select coalesce(sum(amount), 0) into v_payouts
  from public.investor_transactions
  where tenant_id = p_parent_tenant_id
    and type in ('profit_payout', 'profit_reinvest');

  return jsonb_build_object(
    'investor_capital_in', v_deposits,
    'investor_capital_withdrawn', v_withdrawals,
    'investor_capital_deployed', v_deployed,
    'investor_capital_available', v_deposits - v_withdrawals - v_deployed,
    'customer_ar_due', v_ar_due,
    'customer_ar_paid', v_ar_paid,
    'stock_cost_in_circulation', v_stock_cost,
    'realized_profit_mtd', v_profit_mtd,
    'profit_distributed', v_payouts
  );
ALTER FUNCTION "public"."get_parent_cash_circulation"("p_parent_tenant_id" bigint) OWNER TO "postgres";




CREATE OR REPLACE FUNCTION "public"."get_pending_order_qty"("p_allocation_id" bigint) RETURNS integer
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(sum(oi.quantity)::integer, 0)
  from public.shop_order_items oi
  join public.shop_orders o on o.id = oi.order_id
  where oi.global_stock_allocation_id = p_allocation_id
    and o.status not in ('cancelled', 'fulfilled');
ALTER FUNCTION "public"."get_pending_order_qty"("p_allocation_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "product_code" "text",
    "barcode" "text",
    "name" "text",
    "country_of_origin" "text",
    "brand" "text",
    "category" "text",
    "available_units" integer,
    "tariff_code" "text",
    "languages" "text",
    "batch_code_manufacture_date" "text",
    "image_url" "text",
    "expire_date" "text",
    "minimum_order_quantity" integer,
    "product_weight" numeric(12,3),
    "package_weight" numeric(12,3),
    "is_available" boolean,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "vendor_code" "text",
    "market_code" "text",
    "vendor_id" bigint,
    "source" "text",
    "hazardous" boolean,
    "parent_tenant_id" bigint,
    "list_price_amount" numeric(12,4),
    "list_price_currency_id" bigint,
    "reference_cost_amount" numeric(12,4),
    "reference_cost_currency_id" bigint,
    CONSTRAINT "products_list_price_currency_check" CHECK ((("list_price_amount" IS NULL) = ("list_price_currency_id" IS NULL))),
    CONSTRAINT "products_reference_cost_currency_check" CHECK ((("reference_cost_amount" IS NULL) = ("reference_cost_currency_id" IS NULL))),
    CONSTRAINT "products_source_check" CHECK (("source" = ANY (ARRAY['website'::"text", 'excel'::"text"])))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_product_for_tenant"("p_id" bigint, "p_tenant_id" bigint) RETURNS "public"."products"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.products;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_row
  from public.products
  where id = p_id
    and parent_tenant_id = v_scope_tenant_id;

  ALTER FUNCTION "public"."get_product_for_tenant"("p_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select sa.*
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where (p_store_id is null or sa.store_id = p_store_id)
    and (p_tenant_id is null or s.tenant_id = p_tenant_id)
    and public.can_manage_store(s.tenant_id)
  order by sa.id asc
$$;


ALTER FUNCTION "public"."get_store_access_admin"("p_store_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_store_access_admin_v2"("p_store_id" bigint DEFAULT NULL::bigint, "p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."store_access"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select sa.*
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where (p_store_id is null or sa.store_id = p_store_id)
    and (p_tenant_id is null or s.tenant_id = p_tenant_id)
    and public.can_manage_store(s.tenant_id)
  order by sa.id asc
$$;


ALTER FUNCTION "public"."get_store_access_admin_v2"("p_store_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_store_product_brands"("p_store_id" bigint) RETURNS TABLE("brand" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_vendor_code text;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
begin
  select s.tenant_id, s.vendor_code
  into v_tenant_id, v_vendor_code
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id = v_tenant_id
      and m.role in ('admin', 'staff')
  ) into v_has_internal_access;

  v_has_customer_access := public.can_customer_access_store(p_store_id);

  if not v_has_internal_access and not v_has_customer_access then
    raise exception 'not allowed';
  return query
  select distinct p.brand
  from public.products p
  where p.tenant_id = v_tenant_id
    and p.vendor_code = v_vendor_code
    and p.brand is not null
    and length(trim(p.brand)) > 0
  order by p.brand asc;
ALTER FUNCTION "public"."get_store_product_brands"("p_store_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_store_product_categories"("p_store_id" bigint) RETURNS TABLE("category" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_vendor_code text;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
begin
  select s.tenant_id, s.vendor_code
  into v_tenant_id, v_vendor_code
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id = v_tenant_id
      and m.role in ('admin', 'staff')
  ) into v_has_internal_access;

  v_has_customer_access := public.can_customer_access_store(p_store_id);

  if not v_has_internal_access and not v_has_customer_access then
    raise exception 'not allowed';
  return query
  select distinct p.category
  from public.products p
  where p.tenant_id = v_tenant_id
    and p.vendor_code = v_vendor_code
    and p.category is not null
    and length(trim(p.category)) > 0
  order by p.category asc;
ALTER FUNCTION "public"."get_store_product_categories"("p_store_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_stores_admin"("p_tenant_id" bigint) RETURNS SETOF "public"."stores"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select *
  from public.stores
  where tenant_id = p_tenant_id
    and public.can_manage_store(p_tenant_id)
$$;


ALTER FUNCTION "public"."get_stores_admin"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_stores_for_customer"() RETURNS TABLE("id" bigint, "name" "text", "vendor_code" "text", "tenant_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "see_price" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    s.id,
    s.name,
    s.vendor_code,
    s.tenant_id,
    s.created_at,
    s.updated_at,
    bool_or(sa.see_price) as see_price
  from public.stores s
  join public.store_access sa
    on sa.store_id = s.id
  join public.customer_group_members cgm
    on cgm.customer_group_id = sa.customer_group_id
  where sa.status = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  group by
    s.id,
    s.name,
    s.vendor_code,
    s.tenant_id,
    s.created_at,
    s.updated_at
  order by s.id asc
$$;


ALTER FUNCTION "public"."get_stores_for_customer"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_stores_for_customer_v2"("p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "name" "text", "vendor_code" "text", "tenant_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "see_price" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    s.id,
    s.name,
    s.vendor_code,
    s.tenant_id,
    s.created_at,
    s.updated_at,
    bool_or(sa.see_price) as see_price
  from public.stores s
  join public.store_access sa
    on sa.store_id = s.id
  join public.customer_group_members cgm
    on cgm.customer_group_id = sa.customer_group_id
  where sa.status = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
    and (p_tenant_id is null or s.tenant_id = p_tenant_id)
  group by
    s.id,
    s.name,
    s.vendor_code,
    s.tenant_id,
    s.created_at,
    s.updated_at
  order by s.id asc;
ALTER FUNCTION "public"."get_stores_for_customer_v2"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tag_by_slug"("p_category_id" bigint DEFAULT NULL::bigint, "p_module_key" "text" DEFAULT NULL::"text", "p_code" "text" DEFAULT NULL::"text", "p_slug" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_category_id bigint;
  v_res json;
begin
  if p_slug is null then
    return null;
  if p_category_id is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.id = p_category_id
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      );
  elsif p_module_key is not null and p_code is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.module_key = p_module_key
      and tc.code = p_code
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      )
    order by tc.is_system desc, tc.id asc
    limit 1;
  if v_category_id is null then
    return null;
  select row_to_json(t)
  into v_res
  from (
    select
      tg.id,
      tg.category_id,
      tg.slug,
      tg.name,
      tg.color,
      tg.metadata,
      tg.sort_order,
      tg.is_system,
      tg.is_active,
      tg.tenant_id,
      tg.group_name,
      tg.type
    from public.tags tg
    where tg.category_id = v_category_id
      and tg.slug = p_slug
      and tg.is_active = true
    limit 1
  ) t;

  return v_res;
ALTER FUNCTION "public"."get_tag_by_slug"("p_category_id" bigint, "p_module_key" "text", "p_code" "text", "p_slug" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_details_by_membership"("p_tenant_id" bigint, "p_email" "text" DEFAULT NULL::"text", "p_role" "public"."app_role" DEFAULT NULL::"public"."app_role") RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text", "is_active" boolean, "parent_id" bigint, "preference" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select distinct
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.parent_id,
    t.preference,
    t.created_at,
    t.updated_at
  from public.tenants t
  inner join public.memberships m
    on m.tenant_id = t.id
  where t.id = p_tenant_id
    and m.is_active = true
    and (
      p_email is null
      or lower(trim(m.email)) = lower(trim(p_email))
    )
    and (p_role is null or m.role = p_role)
  limit 1;
ALTER FUNCTION "public"."get_tenant_details_by_membership"("p_tenant_id" bigint, "p_email" "text", "p_role" "public"."app_role") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_module_by_id"("p_id" bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "module_key" "text", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at
  from public.tenant_modules tm
  where tm.id = p_id
    and public.can_view_tenant_modules(tm.tenant_id)
  limit 1;
ALTER FUNCTION "public"."get_tenant_module_by_id"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_permission_version"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_version bigint;
begin
  select version into v_version
  from public.tenant_permission_versions
  where tenant_id = p_tenant_id;
  
  return coalesce(v_version, 1);
ALTER FUNCTION "public"."get_tenant_permission_version"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_role_detail"("p_role_id" bigint) RETURNS json
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_role json;
begin
  select row_to_json(r) into v_role
  from (
    select id, tenant_id, scope, name, slug, is_system, is_admin, source_app_role, is_active, created_at, updated_at
    from public.tenant_roles
    where id = p_role_id
  ) r;
  
  if v_role is null then
    raise exception 'Role not found';
  return v_role;
ALTER FUNCTION "public"."get_tenant_role_detail"("p_role_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_phone TEXT := public.normalize_thrift_phone(p_phone);
  v_customer_id BIGINT;
  v_rto_count BIGINT := 0;
  v_return_count BIGINT := 0;
  v_rtos JSONB := '[]'::jsonb;
  v_returns JSONB := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'view') THEN
    RAISE EXCEPTION 'Get thrift customer sales risk requires thrift_sales view permission';
  END IF;

  IF v_phone = '' THEN
    RETURN jsonb_build_object(
      'customer_id', NULL,
      'rto_count', 0,
      'return_count', 0,
      'rtos', '[]'::jsonb,
      'returns', '[]'::jsonb
    );
  END IF;

  SELECT c.id
  INTO v_customer_id
  FROM public.thrift_customers c
  WHERE c.tenant_id = p_tenant_id
    AND c.phone_normalized = v_phone
  LIMIT 1;

  SELECT count(*)
  INTO v_rto_count
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND inv.close_reason = 'RTO'
    AND (
      (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
      OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_rtos
  FROM (
    SELECT
      jsonb_build_object(
        'kind', 'RTO',
        'invoice_id', inv.id,
        'invoice_number', inv.invoice_number,
        'at', COALESCE(inv.reverted_at, inv.economics_closed_at, inv.updated_at),
        'total_invoice_amount', inv.total_invoice_amount
      ) AS row_data,
      COALESCE(inv.reverted_at, inv.economics_closed_at, inv.updated_at) AS sort_at,
      inv.id AS sort_id
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND inv.close_reason = 'RTO'
      AND (
        (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
        OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
      )
    ORDER BY sort_at DESC, sort_id DESC
    LIMIT 20
  ) t;

  SELECT count(*)
  INTO v_return_count
  FROM public.thrift_sales_returns r
  JOIN public.thrift_sales_invoices inv
    ON inv.id = r.invoice_id
   AND inv.tenant_id = r.tenant_id
  WHERE r.tenant_id = p_tenant_id
    AND (
      (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
      OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_returns
  FROM (
    SELECT
      jsonb_build_object(
        'kind', 'CUSTOMER_RETURN',
        'return_id', r.id,
        'return_number', r.return_number,
        'invoice_id', r.invoice_id,
        'invoice_number', inv.invoice_number,
        'at', r.created_at,
        'refund_amount', r.refund_amount,
        'line_count', (
          SELECT count(*)::INT
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
        ),
        'has_damaged', EXISTS (
          SELECT 1
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
            AND ri.condition = 'DAMAGED'
        )
      ) AS row_data,
      r.created_at AS sort_at,
      r.id AS sort_id
    FROM public.thrift_sales_returns r
    JOIN public.thrift_sales_invoices inv
      ON inv.id = r.invoice_id
     AND inv.tenant_id = r.tenant_id
    WHERE r.tenant_id = p_tenant_id
      AND (
        (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
        OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
      )
    ORDER BY sort_at DESC, sort_id DESC
    LIMIT 20
  ) t;

  RETURN jsonb_build_object(
    'customer_id', v_customer_id,
    'rto_count', v_rto_count,
    'return_count', v_return_count,
    'rtos', v_rtos,
    'returns', v_returns
  );
END;
ALTER FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") IS 'Customer RTO + post-pay return history by phone for create-sale risk panel. Separate lists, dated DESC, max 20 each.';


CREATE OR REPLACE FUNCTION "public"."get_thrift_dashboard_metrics"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_items_added_today BIGINT;
  v_total_items BIGINT;
  v_available_items BIGINT;
  v_sold_items BIGINT;
  v_cod_pending_count BIGINT;
  v_cod_expected_total NUMERIC(14,2);
  v_active_invoices_today BIGINT;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift dashboard metrics require thrift_reports view permission';
  END IF;

  SELECT COUNT(*)
  INTO v_items_added_today
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL
    AND created_at >= date_trunc('day', NOW());

  SELECT COUNT(*)
  INTO v_total_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL;

  SELECT COUNT(*)
  INTO v_available_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL
    AND status = 'AVAILABLE'::public.thrift_stock_status;

  SELECT COUNT(*)
  INTO v_sold_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL
    AND status = 'SOLD'::public.thrift_stock_status;

  SELECT
    COUNT(*)::BIGINT,
    COALESCE(SUM(COALESCE(inv.cod_expected, 0)), 0)::NUMERIC(14,2)
  INTO v_cod_pending_count, v_cod_expected_total
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.payment_status = 'COD_PENDING';

  SELECT COUNT(*)
  INTO v_active_invoices_today
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.date >= date_trunc('day', NOW());

  RETURN jsonb_build_object(
    'items_added_today', v_items_added_today,
    'total_items', v_total_items,
    'available_items', v_available_items,
    'sold_items', v_sold_items,
    'cod_pending_count', v_cod_pending_count,
    'cod_expected_total', v_cod_expected_total,
    'active_invoices_today', v_active_invoices_today
  );
END;
ALTER FUNCTION "public"."get_thrift_dashboard_metrics"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text" DEFAULT NULL::"text", "p_outcome" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_channel TEXT;
  v_outcome TEXT;
  v_date_from DATE;
  v_date_to DATE;
  v_summary JSONB;
  v_by_channel JSONB;
  v_by_outcome JSONB;
  v_cod_outstanding JSONB;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift sales report requires thrift_reports view permission';
  END IF;

  IF p_date_from IS NULL OR p_date_to IS NULL THEN
    RAISE EXCEPTION 'p_date_from and p_date_to are required';
  END IF;

  IF p_date_from > p_date_to THEN
    RAISE EXCEPTION 'p_date_from must be <= p_date_to';
  END IF;

  v_date_from := (p_date_from AT TIME ZONE 'UTC')::DATE;
  v_date_to := (p_date_to AT TIME ZONE 'UTC')::DATE;

  v_channel := NULLIF(trim(COALESCE(p_sale_channel, '')), '');
  IF v_channel IS NOT NULL AND v_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE, ONLINE, or null)', v_channel;
  END IF;

  v_outcome := NULLIF(upper(trim(COALESCE(p_outcome, ''))), '');
  IF v_outcome IS NOT NULL AND v_outcome NOT IN ('DELIVERED', 'RTO', 'CUSTOMER_RETURN') THEN
    RAISE EXCEPTION 'Invalid outcome: % (expected DELIVERED, RTO, CUSTOMER_RETURN, or null)', p_outcome;
  END IF;

  WITH pnl AS (
    SELECT
      p.invoice_id,
      p.outcome,
      p.quantity,
      p.sell_amount,
      p.allocated_shop_delivery,
      p.allocated_shop_cod_fee,
      p.allocated_shop_packing,
      p.allocated_return_courier,
      p.allocated_fees_total,
      p.cogs_is_loss,
      COALESCE(inv.sale_channel, 'IN_STORE') AS sale_channel,
      CASE
        WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
          ROUND(
            ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
            * p.quantity,
            2
          )
        ELSE 0.00
      END AS cogs
    FROM public.thrift_sales_pnl_lines p
    JOIN public.thrift_sales_invoices inv
      ON inv.id = p.invoice_id
     AND inv.tenant_id = p.tenant_id
    WHERE p.tenant_id = p_tenant_id
      AND p.event_date >= v_date_from
      AND p.event_date <= v_date_to
      AND (v_channel IS NULL OR COALESCE(inv.sale_channel, 'IN_STORE') = v_channel)
      AND (v_outcome IS NULL OR p.outcome = v_outcome)
  ),
  summary_agg AS (
    SELECT
      COUNT(DISTINCT invoice_id)::BIGINT AS invoice_count,
      COALESCE(SUM(quantity), 0)::BIGINT AS units_sold,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_shop_delivery), 0)::NUMERIC(14,2) AS allocated_shop_delivery,
      COALESCE(SUM(allocated_shop_cod_fee), 0)::NUMERIC(14,2) AS allocated_shop_cod_fee,
      COALESCE(SUM(allocated_shop_packing), 0)::NUMERIC(14,2) AS allocated_shop_packing,
      COALESCE(SUM(allocated_return_courier), 0)::NUMERIC(14,2) AS allocated_return_courier,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2) AS net_profit,
      COUNT(*) FILTER (WHERE outcome = 'RTO')::BIGINT AS rto_count,
      COALESCE(SUM(allocated_fees_total) FILTER (WHERE outcome = 'RTO'), 0)::NUMERIC(14,2)
        AS rto_amount,
      COUNT(*) FILTER (WHERE outcome = 'CUSTOMER_RETURN')::BIGINT AS customer_return_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'CUSTOMER_RETURN'),
        0
      )::NUMERIC(14,2) AS customer_return_amount,
      -- BC aliases used by existing UI
      COALESCE(SUM(sell_amount - cogs), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2)
        AS net_after_fees,
      COUNT(*) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN'))::BIGINT AS refund_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN')),
        0
      )::NUMERIC(14,2) AS refund_amount
    FROM pnl
  ),
  channel_rows AS (
    SELECT
      sale_channel,
      COUNT(DISTINCT invoice_id)::BIGINT AS invoice_count,
      COALESCE(SUM(quantity), 0)::BIGINT AS units_sold,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(sell_amount - cogs), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2)
        AS net_after_fees,
      COUNT(*) FILTER (WHERE outcome = 'RTO')::BIGINT AS rto_count,
      COALESCE(SUM(allocated_fees_total) FILTER (WHERE outcome = 'RTO'), 0)::NUMERIC(14,2)
        AS rto_amount,
      COUNT(*) FILTER (WHERE outcome = 'CUSTOMER_RETURN')::BIGINT AS customer_return_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'CUSTOMER_RETURN'),
        0
      )::NUMERIC(14,2) AS customer_return_amount,
      COUNT(*) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN'))::BIGINT AS refund_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN')),
        0
      )::NUMERIC(14,2) AS refund_amount
    FROM pnl
    GROUP BY sale_channel
  ),
  outcome_rows AS (
    SELECT
      outcome,
      COUNT(DISTINCT invoice_id)::BIGINT AS invoice_count,
      COALESCE(SUM(quantity), 0)::BIGINT AS units,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2) AS net_profit
    FROM pnl
    GROUP BY outcome
  )
  SELECT
    jsonb_build_object(
      'invoice_count', s.invoice_count,
      'units_sold', s.units_sold,
      'units', s.units_sold,
      'net_revenue', s.net_revenue,
      'cogs', s.cogs,
      'line_profit', s.line_profit,
      'allocated_shop_delivery', s.allocated_shop_delivery,
      'allocated_shop_cod_fee', s.allocated_shop_cod_fee,
      'allocated_shop_packing', s.allocated_shop_packing,
      'allocated_return_courier', s.allocated_return_courier,
      'allocated_fees_total', s.allocated_fees_total,
      'net_profit', s.net_profit,
      'courier_cod_amount', s.allocated_shop_delivery + s.allocated_shop_cod_fee,
      'other_expense_amount', s.allocated_shop_packing + s.allocated_return_courier,
      'total_fees', s.total_fees,
      'net_after_fees', s.net_after_fees,
      'refund_count', s.refund_count,
      'refund_amount', s.refund_amount,
      'rto_count', s.rto_count,
      'rto_amount', s.rto_amount,
      'customer_return_count', s.customer_return_count,
      'customer_return_amount', s.customer_return_amount
    ),
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'sale_channel', c.sale_channel,
            'invoice_count', c.invoice_count,
            'units_sold', c.units_sold,
            'net_revenue', c.net_revenue,
            'cogs', c.cogs,
            'line_profit', c.line_profit,
            'courier_cod_amount', c.total_fees,
            'other_expense_amount', 0::NUMERIC(14,2),
            'total_fees', c.total_fees,
            'net_after_fees', c.net_after_fees,
            'refund_count', c.refund_count,
            'refund_amount', c.refund_amount,
            'rto_count', c.rto_count,
            'rto_amount', c.rto_amount,
            'customer_return_count', c.customer_return_count,
            'customer_return_amount', c.customer_return_amount
          )
          ORDER BY c.sale_channel
        )
        FROM channel_rows c
      ),
      '[]'::jsonb
    ),
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'outcome', o.outcome,
            'invoice_count', o.invoice_count,
            'units', o.units,
            'net_revenue', o.net_revenue,
            'cogs', o.cogs,
            'allocated_fees_total', o.allocated_fees_total,
            'net_profit', o.net_profit
          )
          ORDER BY o.outcome
        )
        FROM outcome_rows o
      ),
      '[]'::jsonb
    )
  INTO v_summary, v_by_channel, v_by_outcome
  FROM summary_agg s;

  SELECT jsonb_build_object(
    'invoice_count', COUNT(*)::BIGINT,
    'cod_expected_total', COALESCE(SUM(COALESCE(inv.cod_expected, 0)), 0)::NUMERIC(14,2),
    'cod_remitted_total', COALESCE(SUM(COALESCE(inv.cod_remitted_amount, 0)), 0)::NUMERIC(14,2)
  )
  INTO v_cod_outstanding
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') IN ('ACTIVE', 'PARTIALLY_RETURNED')
    AND inv.payment_status = 'COD_PENDING';

  RETURN jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'sale_channel', v_channel,
    'outcome', v_outcome,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'by_channel', COALESCE(v_by_channel, '[]'::jsonb),
    'by_outcome', COALESCE(v_by_outcome, '[]'::jsonb),
    'cod_outstanding', COALESCE(v_cod_outstanding, jsonb_build_object(
      'invoice_count', 0,
      'cod_expected_total', 0,
      'cod_remitted_total', 0
    ))
  );
END;
ALTER FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") IS 'Period P&L from thrift_sales_pnl_lines + live COGS (cogs_is_loss). Includes RTO and customer-return cards.';


CREATE OR REPLACE FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shipment JSONB;
  v_summary JSONB;
  v_lines JSONB;
  v_by_outcome JSONB;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift shipment report requires thrift_reports view permission';
  END IF;

  SELECT jsonb_build_object(
    'id', s.id,
    'name', s.name,
    'created_at', s.created_at,
    'updated_at', s.updated_at
  )
  INTO v_shipment
  FROM public.thrift_shipments s
  WHERE s.id = p_shipment_id
    AND s.tenant_id = p_tenant_id;

  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment % not found for tenant %', p_shipment_id, p_tenant_id;
  END IF;

  WITH pnl AS (
    SELECT
      p.id,
      p.invoice_id,
      p.invoice_item_id,
      p.stock_id,
      p.outcome,
      p.quantity,
      p.sell_amount,
      p.allocated_shop_delivery,
      p.allocated_shop_cod_fee,
      p.allocated_shop_packing,
      p.allocated_return_courier,
      p.allocated_fees_total,
      p.cogs_is_loss,
      p.event_at,
      p.event_date,
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2) AS landed_unit_cost,
      CASE
        WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
          ROUND(
            ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
            * p.quantity,
            2
          )
        ELSE 0.00
      END AS cogs,
      ROUND(
        p.sell_amount
        - CASE
            WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
              ROUND(
                ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
                * p.quantity,
                2
              )
            ELSE 0.00
          END
        - p.allocated_fees_total,
        2
      ) AS net_profit,
      inv.invoice_number,
      inv.date AS invoice_date,
      i.sell_price,
      i.discount_amount,
      i.final_price,
      st.name AS stock_name,
      st.barcode
    FROM public.thrift_sales_pnl_lines p
    JOIN public.thrift_sales_invoices inv
      ON inv.id = p.invoice_id
     AND inv.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_sales_invoice_items i
      ON i.id = p.invoice_item_id
     AND i.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_stocks st
      ON st.id = p.stock_id
     AND st.tenant_id = p.tenant_id
    WHERE p.tenant_id = p_tenant_id
      AND p.inbound_shipment_id = p_shipment_id
  ),
  summary AS (
    SELECT
      COALESCE(SUM(quantity) FILTER (WHERE outcome = 'DELIVERED'), 0)::BIGINT AS units_sold,
      COALESCE(SUM(quantity) FILTER (WHERE outcome = 'RTO'), 0)::BIGINT AS units_rto,
      COALESCE(SUM(quantity) FILTER (WHERE outcome = 'CUSTOMER_RETURN'), 0)::BIGINT AS units_returned,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(sell_amount) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS delivered_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(net_profit), 0)::NUMERIC(14,2) AS net_profit,
      COALESCE(SUM(net_profit) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS delivered_net,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'RTO'),
        0
      )::NUMERIC(14,2) AS rto_fee_loss,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'CUSTOMER_RETURN'),
        0
      )::NUMERIC(14,2) AS return_fee_loss,
      COUNT(*) FILTER (WHERE outcome = 'DELIVERED')::BIGINT AS delivered_line_count,
      COUNT(*) FILTER (WHERE outcome = 'RTO')::BIGINT AS rto_line_count,
      COUNT(*) FILTER (WHERE outcome = 'CUSTOMER_RETURN')::BIGINT AS return_line_count,
      COALESCE(SUM(sell_price * quantity) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS gross_sales,
      COALESCE(SUM(discount_amount * quantity) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS discounts
    FROM pnl
  )
  SELECT jsonb_build_object(
    'units_sold', s.units_sold,
    'units_rto', s.units_rto,
    'units_returned', s.units_returned,
    'gross_sales', s.gross_sales,
    'discounts', s.discounts,
    'net_revenue', s.net_revenue,
    'delivered_revenue', s.delivered_revenue,
    'cogs', s.cogs,
    'allocated_fees_total', s.allocated_fees_total,
    'net_profit', s.net_profit,
    'delivered_net', s.delivered_net,
    'rto_fee_loss', s.rto_fee_loss,
    'return_fee_loss', s.return_fee_loss,
    'delivered_line_count', s.delivered_line_count,
    'rto_line_count', s.rto_line_count,
    'return_line_count', s.return_line_count,
    'margin_pct', CASE
      WHEN s.net_revenue > 0 THEN ROUND((s.net_profit / s.net_revenue) * 100, 2)
      ELSE 0::NUMERIC(8,2)
    END
  )
  INTO v_summary
  FROM summary s;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'outcome', o.outcome,
        'line_count', o.line_count,
        'units', o.units,
        'net_revenue', o.net_revenue,
        'cogs', o.cogs,
        'allocated_fees_total', o.allocated_fees_total,
        'net_profit', o.net_profit
      )
      ORDER BY o.outcome
    ),
    '[]'::jsonb
  )
  INTO v_by_outcome
  FROM (
    SELECT
      p.outcome,
      COUNT(*)::BIGINT AS line_count,
      COALESCE(SUM(p.quantity), 0)::BIGINT AS units,
      COALESCE(SUM(p.sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(p.cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(p.allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(p.net_profit), 0)::NUMERIC(14,2) AS net_profit
    FROM (
      SELECT
        p2.outcome,
        p2.quantity,
        p2.sell_amount,
        p2.allocated_fees_total,
        CASE
          WHEN p2.sell_amount > 0 OR p2.cogs_is_loss THEN
            ROUND(
              ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p2.stock_id), 0.00), 2)
              * p2.quantity,
              2
            )
          ELSE 0.00
        END AS cogs,
        ROUND(
          p2.sell_amount
          - CASE
              WHEN p2.sell_amount > 0 OR p2.cogs_is_loss THEN
                ROUND(
                  ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p2.stock_id), 0.00), 2)
                  * p2.quantity,
                  2
                )
              ELSE 0.00
            END
          - p2.allocated_fees_total,
          2
        ) AS net_profit
      FROM public.thrift_sales_pnl_lines p2
      WHERE p2.tenant_id = p_tenant_id
        AND p2.inbound_shipment_id = p_shipment_id
    ) p
    GROUP BY p.outcome
  ) o;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', x.id,
        'invoice_id', x.invoice_id,
        'invoice_item_id', x.invoice_item_id,
        'invoice_number', x.invoice_number,
        'invoice_date', x.invoice_date,
        'event_date', x.event_date,
        'outcome', x.outcome,
        'stock_id', x.stock_id,
        'stock_name', x.stock_name,
        'barcode', x.barcode,
        'quantity', x.quantity,
        'sell_price', COALESCE(x.sell_price, 0),
        'discount_amount', COALESCE(x.discount_amount, 0),
        'final_price', COALESCE(x.final_price, x.sell_amount),
        'sell_amount', x.sell_amount,
        'landed_unit_cost_at_sale', x.landed_unit_cost,
        'cogs', x.cogs,
        'cogs_is_loss', x.cogs_is_loss,
        'allocated_shop_delivery', x.allocated_shop_delivery,
        'allocated_shop_cod_fee', x.allocated_shop_cod_fee,
        'allocated_shop_packing', x.allocated_shop_packing,
        'allocated_return_courier', x.allocated_return_courier,
        'allocated_fees_total', x.allocated_fees_total,
        'net_profit', x.net_profit
      )
      ORDER BY x.event_at DESC NULLS LAST, x.id DESC
    ),
    '[]'::jsonb
  )
  INTO v_lines
  FROM (
    SELECT
      p.id,
      p.invoice_id,
      p.invoice_item_id,
      p.stock_id,
      p.outcome,
      p.quantity,
      p.sell_amount,
      p.allocated_shop_delivery,
      p.allocated_shop_cod_fee,
      p.allocated_shop_packing,
      p.allocated_return_courier,
      p.allocated_fees_total,
      p.cogs_is_loss,
      p.event_at,
      p.event_date,
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2) AS landed_unit_cost,
      CASE
        WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
          ROUND(
            ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
            * p.quantity,
            2
          )
        ELSE 0.00
      END AS cogs,
      ROUND(
        p.sell_amount
        - CASE
            WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
              ROUND(
                ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
                * p.quantity,
                2
              )
            ELSE 0.00
          END
        - p.allocated_fees_total,
        2
      ) AS net_profit,
      inv.invoice_number,
      inv.date AS invoice_date,
      i.sell_price,
      i.discount_amount,
      i.final_price,
      st.name AS stock_name,
      st.barcode
    FROM public.thrift_sales_pnl_lines p
    JOIN public.thrift_sales_invoices inv
      ON inv.id = p.invoice_id
     AND inv.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_sales_invoice_items i
      ON i.id = p.invoice_item_id
     AND i.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_stocks st
      ON st.id = p.stock_id
     AND st.tenant_id = p.tenant_id
    WHERE p.tenant_id = p_tenant_id
      AND p.inbound_shipment_id = p_shipment_id
  ) x;

  RETURN jsonb_build_object(
    'shipment', v_shipment,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'by_outcome', COALESCE(v_by_outcome, '[]'::jsonb),
    'lines', COALESCE(v_lines, '[]'::jsonb)
  );
END;
ALTER FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) IS 'Inbound shipment P&L from thrift_sales_pnl_lines + live COGS (includes cogs_is_loss).';


CREATE OR REPLACE FUNCTION "public"."get_wallet_account_balances"(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_currency_code text DEFAULT 'BDT'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_books_id bigint;
  v_entity_id bigint;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
  END IF;

  SELECT jsonb_build_object(
    'parent_tenant_id', v_books_id,
    'tenant_id', v_books_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(w.currency_code, p_currency_code),
    'available_balance', coalesce(w.available_balance, 0.0000),
    'pending_balance', coalesce(w.pending_balance, 0.0000),
    'locked_balance', coalesce(w.locked_balance, 0.0000),
    'total_balance', (
      coalesce(w.available_balance, 0.0000)
      + coalesce(w.pending_balance, 0.0000)
      + coalesce(w.locked_balance, 0.0000)
    )
  )
  INTO v_result
  FROM (SELECT 1) dummy
  LEFT JOIN public.wallet_accounts w
    ON w.parent_tenant_id = v_books_id
   AND w.entity_type = p_entity_type
   AND w.entity_id = v_entity_id
   AND w.currency_code = coalesce(p_currency_code, 'BDT');

  RETURN v_result;
END;
$$;
ALTER FUNCTION "public"."get_wallet_account_balances"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_wallet_dashboard_summary"(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_tenant_cash numeric(18,4) := 0.0000;
  v_courier_cod_holding numeric(18,4) := 0.0000;
  v_merchant_pending numeric(18,4) := 0.0000;
  v_merchant_available numeric(18,4) := 0.0000;
  v_vendor_payables numeric(18,4) := 0.0000;
  v_customer_deposits numeric(18,4) := 0.0000;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT
    coalesce(sum(CASE WHEN entity_type = 'tenant' THEN available_balance ELSE 0 END), 0),
    coalesce(sum(CASE WHEN entity_type = 'courier' THEN pending_balance + available_balance ELSE 0 END), 0),
    coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance ELSE 0 END), 0),
    coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN available_balance ELSE 0 END), 0),
    coalesce(sum(CASE WHEN entity_type = 'vendor' THEN available_balance ELSE 0 END), 0),
    coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0)
  INTO
    v_tenant_cash,
    v_courier_cod_holding,
    v_merchant_pending,
    v_merchant_available,
    v_vendor_payables,
    v_customer_deposits
  FROM public.wallet_accounts
  WHERE parent_tenant_id = v_books_id;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'parent_tenant_id', v_books_id,
    'tenant_cash_total', v_tenant_cash,
    'courier_cod_holding_total', v_courier_cod_holding,
    'merchant_pending_total', v_merchant_pending,
    'merchant_available_total', v_merchant_available,
    'vendor_payables_total', v_vendor_payables,
    'customer_deposits_total', v_customer_deposits
  );
END;
$$;
ALTER FUNCTION "public"."get_wallet_dashboard_summary"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION public.wallet_staff_can_view(p_tenant_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.is_superadmin()
    OR public.membership_has_module_action(public.resolve_parent_tenant_id(p_tenant_id), 'universal_wallet', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'universal_wallet', 'view')
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id));
$$;

CREATE OR REPLACE FUNCTION public.wallet_staff_can_edit(p_tenant_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.is_superadmin()
    OR public.membership_has_module_action(public.resolve_parent_tenant_id(p_tenant_id), 'universal_wallet', 'edit')
    OR public.membership_has_module_action(p_tenant_id, 'universal_wallet', 'edit')
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id));
$$;

CREATE OR REPLACE FUNCTION public.list_wallet_entities_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0,
  p_currency_code text DEFAULT 'BDT'
)
RETURNS TABLE (
  entity_id bigint,
  entity_type text,
  name text,
  code text,
  caption text,
  available_balance numeric(18,4),
  pending_balance numeric(18,4),
  locked_balance numeric(18,4),
  total_balance numeric(18,4),
  source_uuid uuid,
  operating_tenant_id bigint,
  has_wallet_activity boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_search text;
  v_limit integer;
  v_offset integer;
BEGIN
  IF p_entity_type NOT IN ('customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    RAISE EXCEPTION 'Invalid entity_type %. Allowed: customer, vendor, courier, cargo_company, investor', p_entity_type;
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN
    RETURN;
  END IF;

  v_search := nullif(trim(p_search), '');
  v_limit := greatest(least(coalesce(p_limit, 100), 500), 1);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  IF p_entity_type = 'customer' THEN
    RETURN QUERY
    SELECT
      bp.id,
      'customer'::text,
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || bp.name ELSE bp.name END,
      NULL::text,
      nullif(trim(concat_ws(' • ', bp.phone, bp.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid,
      bp.tenant_id,
      wa.id IS NOT NULL
    FROM public.billing_profiles bp
    LEFT JOIN public.customer_groups cg ON cg.id = bp.customer_group_id
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id
     AND wa.entity_type = 'customer'
     AND wa.entity_id = bp.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE (bp.tenant_id = v_books_id
       OR bp.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id))
      AND (
        v_search IS NULL
        OR bp.name ILIKE '%' || v_search || '%'
        OR coalesce(cg.name, '') ILIKE '%' || v_search || '%'
        OR coalesce(bp.phone, '') ILIKE '%' || v_search || '%'
        OR coalesce(bp.email, '') ILIKE '%' || v_search || '%'
      )
    ORDER BY 3 ASC, bp.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'vendor' THEN
    RETURN QUERY
    SELECT
      v.id, 'vendor'::text, v.name, v.code,
      nullif(trim(concat_ws(' • ', v.phone, v.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, v.tenant_id, wa.id IS NOT NULL
    FROM public.vendors v
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'vendor' AND wa.entity_id = v.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE v.tenant_id = v_books_id
      AND (v_search IS NULL OR v.name ILIKE '%' || v_search || '%' OR coalesce(v.code, '') ILIKE '%' || v_search || '%')
    ORDER BY v.name ASC, v.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'cargo_company' THEN
    RETURN QUERY
    SELECT
      c.id, 'cargo_company'::text, c.name, c.code,
      nullif(trim(concat_ws(' • ', c.phone, c.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, c.tenant_id, wa.id IS NOT NULL
    FROM public.cargo_companies c
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'cargo_company' AND wa.entity_id = c.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE c.tenant_id = v_books_id
      AND (v_search IS NULL OR c.name ILIKE '%' || v_search || '%' OR coalesce(c.code, '') ILIKE '%' || v_search || '%')
    ORDER BY c.name ASC, c.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'courier' THEN
    RETURN QUERY
    SELECT
      cs.wallet_entity_id,
      'courier'::text,
      cs.name,
      upper(cs.code),
      coalesce(nullif(trim(cs.notes), ''), 'Courier service'),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      cs.id,
      coalesce(cs.tenant_id, v_books_id),
      wa.id IS NOT NULL
    FROM public.courier_services cs
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'courier' AND wa.entity_id = cs.wallet_entity_id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE cs.is_active = true
      AND cs.wallet_entity_id IS NOT NULL
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id))
      AND (v_search IS NULL OR cs.name ILIKE '%' || v_search || '%' OR coalesce(cs.code, '') ILIKE '%' || v_search || '%')
    ORDER BY cs.name ASC, cs.wallet_entity_id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'investor' THEN
    RETURN QUERY
    SELECT
      i.id, 'investor'::text, i.name, NULL::text,
      nullif(trim(concat_ws(' • ', i.phone, i.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, i.tenant_id, wa.id IS NOT NULL
    FROM public.investors i
    LEFT JOIN public.wallet_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'investor' AND wa.entity_id = i.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE i.tenant_id = v_books_id
      AND (v_search IS NULL OR i.name ILIKE '%' || v_search || '%')
    ORDER BY i.name ASC, i.id ASC
    LIMIT v_limit OFFSET v_offset;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_wallet_detail_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_currency_code text DEFAULT 'BDT'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_name text;
  v_code text;
  v_caption text;
  v_source_uuid uuid;
  v_entity_id bigint;
  v_account jsonb;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_entity_id := p_entity_id;

  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
    SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = v_books_id;
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;
    v_caption := 'Company cash pool';

  ELSIF p_entity_type = 'customer' THEN
    SELECT
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || bp.name ELSE bp.name END,
      nullif(trim(concat_ws(' • ', bp.phone, bp.email)), '')
    INTO v_name, v_caption
    FROM public.billing_profiles bp
    LEFT JOIN public.customer_groups cg ON cg.id = bp.customer_group_id
    WHERE bp.id = p_entity_id
      AND (bp.tenant_id = v_books_id OR bp.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;

  ELSIF p_entity_type = 'vendor' THEN
    SELECT v.name, v.code, nullif(trim(concat_ws(' • ', v.phone, v.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.vendors v WHERE v.id = p_entity_id AND v.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'cargo_company' THEN
    SELECT c.name, c.code, nullif(trim(concat_ws(' • ', c.phone, c.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.cargo_companies c WHERE c.id = p_entity_id AND c.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'courier' THEN
    SELECT cs.name, upper(cs.code), coalesce(nullif(trim(cs.notes), ''), 'Courier service'), cs.id
    INTO v_name, v_code, v_caption, v_source_uuid
    FROM public.courier_services cs
    WHERE cs.wallet_entity_id = p_entity_id AND cs.is_active = true
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'investor' THEN
    SELECT i.name, nullif(trim(concat_ws(' • ', i.phone, i.email)), '')
    INTO v_name, v_caption
    FROM public.investors i WHERE i.id = p_entity_id AND i.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_account := public.get_wallet_account_balances(v_books_id, p_entity_type, v_entity_id, p_currency_code);

  RETURN jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'operating_tenant_id', v_operating_id,
    'entity', jsonb_build_object(
      'entity_type', p_entity_type,
      'entity_id', v_entity_id,
      'name', v_name,
      'code', v_code,
      'caption', v_caption,
      'source_uuid', v_source_uuid
    ),
    'account', jsonb_build_object(
      'currency_code', coalesce(v_account->>'currency_code', p_currency_code),
      'available_balance', coalesce((v_account->>'available_balance')::numeric, 0),
      'pending_balance', coalesce((v_account->>'pending_balance')::numeric, 0),
      'locked_balance', coalesce((v_account->>'locked_balance')::numeric, 0),
      'total_balance', coalesce((v_account->>'total_balance')::numeric, 0)
    ),
    'permissions', jsonb_build_object(
      'can_record_manual', public.wallet_staff_can_edit(p_tenant_id),
      'can_reverse', public.wallet_staff_can_edit(p_tenant_id)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_wallet_ledger_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_search text DEFAULT NULL,
  p_operating_tenant_id bigint DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  parent_tenant_id bigint,
  operating_tenant_id bigint,
  entity_type text,
  entity_id bigint,
  type text,
  amount numeric(15,4),
  currency_code text,
  exchange_rate numeric(15,6),
  base_amount numeric(15,4),
  balance_after numeric(15,4),
  source_type text,
  source_id text,
  metadata jsonb,
  created_at timestamptz,
  is_reversal boolean,
  reversed_entry_id uuid
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_entity_id bigint;
  v_search text;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN v_entity_id := v_books_id; END IF;

  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN RETURN; END IF;

  v_search := nullif(trim(p_search), '');

  RETURN QUERY
  SELECT
    l.id,
    l.parent_tenant_id,
    l.operating_tenant_id,
    l.entity_type,
    l.entity_id,
    l.type,
    l.amount,
    l.currency_code,
    l.exchange_rate,
    l.base_amount,
    l.balance_after,
    l.source_type,
    l.source_id,
    l.metadata,
    l.created_at,
    (l.metadata ? 'reversal_of'),
    CASE WHEN l.metadata ? 'reversal_of' THEN (l.metadata->>'reversal_of')::uuid ELSE NULL END
  FROM public.universal_wallet_ledger l
  WHERE l.parent_tenant_id = v_books_id
    AND l.entity_type = p_entity_type
    AND l.entity_id = v_entity_id
    AND (p_operating_tenant_id IS NULL OR l.operating_tenant_id = p_operating_tenant_id)
    AND (
      v_search IS NULL
      OR coalesce(l.source_id, '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'note', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'trx_id', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'section', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.source_type, '') ILIKE '%' || v_search || '%'
    )
  ORDER BY l.created_at DESC, l.id DESC
  LIMIT greatest(least(coalesce(p_limit, 50), 200), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_wallet_manual_transaction_for_staff(
  p_tenant_id bigint,
  p_action_type text,
  p_primary_entity_type text,
  p_primary_entity_id bigint,
  p_amount numeric,
  p_currency_code text DEFAULT 'BDT',
  p_exchange_rate numeric DEFAULT 1.000000,
  p_category text DEFAULT NULL,
  p_payment_method text DEFAULT NULL,
  p_reference_id text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_counterparty_entity_type text DEFAULT NULL,
  p_counterparty_entity_id bigint DEFAULT NULL,
  p_target_bucket text DEFAULT 'available'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_source_id text;
  v_meta jsonb;
  v_primary_id bigint;
  v_ledger_ids uuid[] := '{}';
  v_entry jsonb;
  v_primary_entity_id bigint;
  v_counterparty_id bigint;
BEGIN
  IF NOT public.wallet_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF coalesce(p_amount, 0) <= 0 OR coalesce(p_exchange_rate, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount and exchange_rate must be positive');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_primary_entity_id := p_primary_entity_id;
  IF p_primary_entity_type = 'tenant' THEN v_primary_entity_id := v_books_id; END IF;

  v_source_id := coalesce(nullif(trim(p_reference_id), ''),
    CASE p_action_type
      WHEN 'pay' THEN 'MAN-PAY-' || gen_random_uuid()::text
      WHEN 'withdraw' THEN 'MAN-WD-' || gen_random_uuid()::text
      WHEN 'deposit' THEN 'MAN-DEP-' || gen_random_uuid()::text
      ELSE 'MAN-CR-' || gen_random_uuid()::text
    END);

  v_meta := jsonb_build_object(
    'section', p_category,
    'method', p_payment_method,
    'trx_id', v_source_id,
    'note', p_note,
    'action_type', p_action_type,
    'transaction_type', 'manual_adjustment',
    'label', initcap(p_action_type),
    'recorded_by', public.current_user_email(),
    'target_bucket', coalesce(p_target_bucket, 'available')
  );

  IF p_action_type IN ('pay', 'credit') AND p_primary_entity_type = 'tenant'
     AND (p_counterparty_entity_type IS NULL OR p_counterparty_entity_id IS NULL) THEN
    RETURN jsonb_build_object('success', false, 'error', 'counterparty required');
  END IF;

  IF p_action_type = 'deposit' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'withdraw' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      'payout', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'credit' AND p_primary_entity_type = 'tenant' THEN
    v_counterparty_id := p_counterparty_entity_id;
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_counterparty_entity_type, v_counterparty_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'credit' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'pay' AND p_primary_entity_type = 'tenant' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, 'tenant', v_books_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      CASE WHEN p_category = 'vendor_purchase' THEN 'vendor_purchase' ELSE 'adjustment' END,
      v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_counterparty_entity_type, p_counterparty_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      CASE WHEN p_category = 'vendor_purchase' THEN 'vendor_purchase' ELSE 'adjustment' END,
      v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'pay' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, 'tenant', v_books_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid action_type');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'ledger_entry_ids', to_jsonb(v_ledger_ids),
    'primary_account', public.get_wallet_account_balances(v_books_id, p_primary_entity_type, v_primary_entity_id, p_currency_code)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.reverse_wallet_ledger_entry_for_staff(
  p_tenant_id bigint,
  p_ledger_entry_id uuid,
  p_reason text,
  p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_orig public.universal_wallet_ledger%ROWTYPE;
  v_reversal_type text;
  v_reversal_id uuid;
  v_meta jsonb;
  v_entry jsonb;
BEGIN
  IF NOT public.wallet_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF nullif(trim(p_reason), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason required');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT * INTO v_orig FROM public.universal_wallet_ledger WHERE id = p_ledger_entry_id;
  IF v_orig.id IS NULL OR v_orig.parent_tenant_id <> v_books_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'entry not found');
  END IF;

  IF v_orig.metadata ? 'reversed_by' OR v_orig.metadata ? 'reversal_of' THEN
    RETURN jsonb_build_object('success', false, 'error', 'entry already reversed or is a reversal');
  END IF;

  IF v_orig.source_type = 'shop_order' AND NOT coalesce((v_orig.metadata->>'allow_manual_reversal')::boolean, false)
     AND NOT public.is_superadmin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'system shop_order entries cannot be reversed');
  END IF;

  v_reversal_type := CASE WHEN v_orig.type = 'credit' THEN 'debit' ELSE 'credit' END;
  v_meta := jsonb_build_object(
    'reversal_of', v_orig.id::text,
    'transaction_type', 'manual_reversal',
    'note', p_reason,
    'trx_id', coalesce(p_reference_id, 'REV-' || gen_random_uuid()::text),
    'recorded_by', public.current_user_email()
  );

  v_entry := public.record_ledger_transaction(
    v_orig.parent_tenant_id,
    v_orig.operating_tenant_id,
    v_orig.entity_type,
    v_orig.entity_id,
    v_reversal_type,
    v_orig.amount,
    v_orig.currency_code,
    v_orig.exchange_rate,
    v_orig.source_type,
    coalesce(p_reference_id, v_orig.source_id),
    v_meta,
    coalesce(v_orig.metadata->>'target_bucket', 'available'),
    false
  );
  v_reversal_id := (v_entry->>'id')::uuid;

  UPDATE public.universal_wallet_ledger
  SET metadata = metadata || jsonb_build_object('reversed_by', v_reversal_id::text)
  WHERE id = v_orig.id;

  RETURN jsonb_build_object(
    'success', true,
    'reversal_entry_id', v_reversal_id,
    'account', public.get_wallet_account_balances(
      v_books_id, v_orig.entity_type, v_orig.entity_id, v_orig.currency_code
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_wallet_entities_for_staff(bigint, text, text, integer, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_wallet_detail_for_staff(bigint, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_wallet_ledger_for_staff(bigint, text, bigint, text, bigint, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_wallet_manual_transaction_for_staff(
  bigint, text, text, bigint, numeric, text, numeric, text, text, text, text, text, bigint, text
) TO authenticated;

CREATE OR REPLACE FUNCTION "public"."get_wallet_entity_statement"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_opening_balance NUMERIC(18,4) := 0.0000;
  v_total_credits NUMERIC(18,4) := 0.0000;
  v_total_debits NUMERIC(18,4) := 0.0000;
  v_closing_balance NUMERIC(18,4) := 0.0000;
  v_entries JSONB;
BEGIN
  IF p_start_date IS NOT NULL THEN
    SELECT COALESCE(
      SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END),
      0.0000
    )
    INTO v_opening_balance
    FROM universal_wallet_ledger
    WHERE tenant_id = p_tenant_id
      AND entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND created_at < p_start_date;
  END IF;

  SELECT 
    COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0.0000),
    COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END), 0.0000)
  INTO v_total_credits, v_total_debits
  FROM universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  v_closing_balance := v_opening_balance + v_total_credits - v_total_debits;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'tenant_id', tenant_id,
      'entity_type', entity_type,
      'entity_id', entity_id,
      'type', type,
      'amount', amount,
      'currency_code', currency_code,
      'exchange_rate', exchange_rate,
      'base_amount', base_amount,
      'balance_after', balance_after,
      'source_type', source_type,
      'source_id', source_id,
      'metadata', metadata,
      'created_at', created_at
    ) ORDER BY created_at ASC, id ASC
  ), '[]'::jsonb)
  INTO v_entries
  FROM universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'opening_balance', v_opening_balance,
    'total_credits', v_total_credits,
    'total_debits', v_total_debits,
    'closing_balance', v_closing_balance,
    'entries', v_entries
  );
END;
ALTER FUNCTION "public"."get_wallet_entity_statement"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_cash_in_report"(
  "p_tenant_id" bigint,
  "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone,
  "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone
) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_cash_in numeric(18,4) := 0.0000;
  v_count integer := 0;
  v_by_method jsonb;
  v_entries jsonb;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant ID is required';
  END IF;

  SELECT coalesce(t.parent_id, t.id)
  INTO v_books_id
  FROM public.tenants t
  WHERE t.id = p_tenant_id;

  IF v_books_id IS NULL THEN
    RAISE EXCEPTION 'Tenant not found';
  END IF;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'universal_wallet', 'view')
    OR public.membership_has_module_action(v_books_id, 'universal_wallet', 'view')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH lined AS (
    SELECT
      l.id,
      l.amount,
      l.source_type,
      l.source_id,
      l.metadata,
      l.created_at,
      coalesce(
        nullif(trim(l.metadata->>'method'), ''),
        nullif(trim(gp.method), ''),
        'other'
      ) AS method,
      nullif(l.metadata->>'label', '') AS label,
      CASE
        WHEN (l.metadata->>'invoice_id') ~ '^[0-9]+$' THEN (l.metadata->>'invoice_id')::bigint
        ELSE NULL
      END AS invoice_id
    FROM public.universal_wallet_ledger l
    LEFT JOIN public.global_payments gp
      ON l.source_id ~ '^[0-9]+$'
     AND gp.id = l.source_id::bigint
     AND gp.tenant_id = v_books_id
    WHERE l.tenant_id = v_books_id
      AND l.entity_type = 'tenant'
      AND l.entity_id = v_books_id
      AND l.type = 'credit'
      AND coalesce(l.metadata->>'purpose', '') <> 'apply_store_credit'
      AND (p_start_date IS NULL OR l.created_at >= p_start_date)
      AND (p_end_date IS NULL OR l.created_at <= p_end_date)
  )
  SELECT
    coalesce(sum(amount), 0.0000),
    count(*)::integer,
    coalesce(
      (
        SELECT jsonb_agg(jsonb_build_object(
          'method', m.method,
          'amount', m.amt,
          'count', m.cnt
        ) ORDER BY m.amt DESC)
        FROM (
          SELECT method, sum(amount) AS amt, count(*)::integer AS cnt
          FROM lined
          GROUP BY method
        ) m
      ),
      '[]'::jsonb
    ),
    coalesce(
      (
        SELECT jsonb_agg(jsonb_build_object(
          'id', e.id,
          'amount', e.amount,
          'method', e.method,
          'source_type', e.source_type,
          'source_id', e.source_id,
          'label', e.label,
          'invoice_id', e.invoice_id,
          'created_at', e.created_at
        ) ORDER BY e.created_at DESC, e.id DESC)
        FROM lined e
      ),
      '[]'::jsonb
    )
  INTO v_cash_in, v_count, v_by_method, v_entries
  FROM lined;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'cash_in_total', v_cash_in,
    'entry_count', v_count,
    'by_method', v_by_method,
    'entries', v_entries
  );
END;
$$;

ALTER FUNCTION "public"."get_tenant_cash_in_report"("p_tenant_id" bigint, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."global_search_tasks"("p_query" "text") RETURNS TABLE("id" bigint, "tenant_id" bigint, "tenant_name" "text", "parent_id" bigint, "type" "text", "title" "text", "content" "text", "status" "text", "priority" "text", "created_by_email" "text", "due_date" timestamp with time zone, "start_date" timestamp with time zone, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text;
begin
  v_email := public.current_user_email();

  return query
  select distinct
    i.id,
    i.tenant_id,
    t.name as tenant_name,
    i.parent_id,
    i.type,
    i.title,
    i.content,
    i.status,
    i.priority,
    i.created_by_email,
    i.due_date,
    i.start_date,
    i.created_at,
    i.updated_at
  from public.items i
  left join public.tenants t on t.id = i.tenant_id
  left join public.item_tags it on it.item_id = i.id
  left join public.tags tag on tag.id = it.tag_id
  left join public.comments c on c.item_id = i.id
  where
    public.get_effective_item_role(i.id, v_email) is not null
    and (
      i.title ilike '%' || p_query || '%'
      or i.content ilike '%' || p_query || '%'
      or tag.name ilike '%' || p_query || '%'
      or c.body ilike '%' || p_query || '%'
    )
  order by i.updated_at desc
  limit 50;
ALTER FUNCTION "public"."global_search_tasks"("p_query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_membership_update"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if public.is_superadmin() then
    return new;
  if old.tenant_id is distinct from new.tenant_id then
    raise exception 'Only superadmin can move memberships across tenants';
  -- Preference-only self-update (e.g. update_membership_preference_for_self)
  if lower(trim(old.email)) = lower(trim(public.current_user_email()))
    and old.email is not distinct from new.email
    and old.role is not distinct from new.role
    and old.is_active is not distinct from new.is_active
    and old.investor_id is not distinct from new.investor_id
    and old.tenant_role_id is not distinct from new.tenant_role_id
    and old.accent_color is not distinct from new.accent_color
    and old.preference is distinct from new.preference
  then
    return new;
  if not public.is_tenant_admin(old.tenant_id) then
    raise exception 'Only tenant admins can update tenant memberships';
  if old.role not in ('staff', 'viewer') then
    raise exception 'Tenant admins can only update staff or viewer memberships';
  if new.role not in ('staff', 'viewer') then
    raise exception 'Tenant admins cannot promote membership role beyond staff/viewer';
  ALTER FUNCTION "public"."guard_membership_update"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_koba_retail_settings_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  ALTER FUNCTION "public"."handle_koba_retail_settings_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_tenant_retail_settings"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  insert into public.koba_retail_settings (tenant_id)
  values (new.id)
  on conflict (tenant_id) do nothing;
  ALTER FUNCTION "public"."handle_new_tenant_retail_settings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_active_tenant_membership"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = p_tenant_id
      and m.is_active = true
  )
  or public.is_superadmin();
ALTER FUNCTION "public"."has_active_tenant_membership"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_module_action"("p_tenant_id" bigint, "p_module_key" "text", "p_action" "text") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_has_app_action boolean;
  v_has_shop_action boolean;
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_override_effect text;
  v_role_allowed boolean;
  v_shop_allowed boolean;
begin
  -- Superadmin bypass
  if public.is_superadmin() then
    return true;
  -- 1. Check module status for the tenant (supports submodules via expansion helper)
  if not (p_module_key = any(public.get_active_module_keys_for_tenant(p_tenant_id))) then
    return false;
  -- 2. parent/child hierarchy blocks module for tenant
  if exists (
    select 1
    from public.tenants
    where id = p_tenant_id
      and parent_id is not null
  ) and p_module_key in (
    'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
    'shipment_reports', 'parent_dashboard', 'investor_reports',
    'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
  ) then
    return false;
  -- 3. Resolve active action entries in module_actions
  select
    exists(
      select 1 from public.module_actions ma
      where ma.module_key = p_module_key and ma.action = p_action
        and ma.scope in ('app', 'investor') and ma.is_active = true
    ),
    exists(
      select 1 from public.module_actions ma
      where ma.module_key = p_module_key and ma.action = p_action
        and ma.scope = 'shop' and ma.is_active = true
    )
  into v_has_app_action, v_has_shop_action;

  -- 4. Check App Scope permissions
  if v_has_app_action and exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    select m.id, m.tenant_role_id, tr.is_admin
    into v_member_id, v_tenant_role_id, v_role_is_admin
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true;

    -- Administrator shortcut
    if coalesce(v_role_is_admin, false) = true then
      return true;
    -- Member overrides
    select effect
    into v_override_effect
    from public.membership_grants
    where membership_id = v_member_id
      and module_key = p_module_key
      and action = p_action;

    if v_override_effect = 'deny' then
      return false;
    elsif v_override_effect = 'allow' then
      return true;
    -- Role grants
    select allowed
    into v_role_allowed
    from public.tenant_role_grants
    where tenant_role_id = v_tenant_role_id
      and module_key = p_module_key
      and action = p_action;

    return coalesce(v_role_allowed, false);

  -- 5. Check Shop Scope permissions
  elsif v_has_shop_action and exists (
    select 1
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cg.tenant_id = p_tenant_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
      and cg.is_active = true
  ) then
    -- Administrator shortcut check
    if exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      join public.tenant_roles tr on tr.id = cgm.tenant_role_id
      where cg.tenant_id = p_tenant_id
        and cg.is_active = true
        and cgm.is_active = true
        and lower(trim(cgm.email)) = public.current_user_email()
        and tr.is_admin = true
    ) then
      return true;
    -- Resolve overrides and role grants
    select
      coalesce(
        bool_or(case when g.effect = 'allow' then true else null end),
        bool_or(case when g.effect = 'deny' then false else null end),
        bool_or(rg.allowed)
      ) into v_shop_allowed
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    left join public.customer_group_member_grants g
      on g.customer_group_member_id = cgm.id
      and g.module_key = p_module_key
      and g.action = p_action
    left join public.tenant_role_grants rg
      on rg.tenant_role_id = cgm.tenant_role_id
      and rg.module_key = p_module_key
      and rg.action = p_action
    where cg.tenant_id = p_tenant_id
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email();

    return coalesce(v_shop_allowed, false);
  return false;
ALTER FUNCTION "public"."has_module_action"("p_tenant_id" bigint, "p_module_key" "text", "p_action" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text" DEFAULT NULL::"text", "p_hold_note" "text" DEFAULT NULL::"text", "p_held_by" "text" DEFAULT NULL::"text", "p_hold_expires_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_stock public.thrift_stocks%ROWTYPE;
  v_phone_normalized TEXT;
  v_updated INT;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.tenant_id = p_tenant_id
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'Not authorized for this tenant';
  END IF;

  v_phone_normalized := public.normalize_thrift_phone(p_held_for_phone);
  IF v_phone_normalized = '' THEN
    RAISE EXCEPTION 'Hold requires a customer phone';
  END IF;

  SELECT *
  INTO v_stock
  FROM public.thrift_stocks
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock item % not found for tenant %', p_stock_id, p_tenant_id;
  END IF;

  IF v_stock.status IS DISTINCT FROM 'AVAILABLE'::public.thrift_stock_status THEN
    RAISE EXCEPTION
      'Stock item % cannot be held (status=%); only AVAILABLE units can be held',
      p_stock_id,
      v_stock.status;
  END IF;

  UPDATE public.thrift_stocks
  SET
    status = 'RESERVED'::public.thrift_stock_status,
    held_for_name = NULLIF(trim(p_held_for_name), ''),
    held_for_phone = COALESCE(NULLIF(trim(p_held_for_phone), ''), v_phone_normalized),
    held_for_phone_normalized = v_phone_normalized,
    hold_note = NULLIF(trim(p_hold_note), ''),
    held_by = COALESCE(NULLIF(trim(p_held_by), ''), public.current_user_email()),
    held_at = NOW(),
    hold_expires_at = p_hold_expires_at,
    updated_at = NOW()
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
    AND status = 'AVAILABLE'::public.thrift_stock_status;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RAISE EXCEPTION 'Stock item % became unavailable during hold', p_stock_id;
  END IF;

  RETURN jsonb_build_object(
    'id', p_stock_id,
    'status', 'RESERVED',
    'held_for_phone_normalized', v_phone_normalized
  );
END;
ALTER FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) IS 'Place AVAILABLE thrift stock on RESERVED hold for a customer phone (FB/online).';


CREATE OR REPLACE FUNCTION "public"."investor_tenant_can_view"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.membership_has_module_action(p_tenant_id, 'investor_profiles', 'view')
    or public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'view')
    or public.membership_has_module_action(p_tenant_id, 'investor_shipment_share', 'view')
    or public.membership_has_module_action(p_tenant_id, 'investor_reports', 'view');
ALTER FUNCTION "public"."investor_tenant_can_view"("p_tenant_id" bigint) OWNER TO "postgres";


    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    (select t.parent_id is not null from public.tenants t where t.id = p_tenant_id),
    false
  );
ALTER FUNCTION "public"."is_child_tenant"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_customer_group_admin_or_negotiator"("p_customer_group_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.customer_group_members cgm
    where cgm.customer_group_id = p_customer_group_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.role in ('admin', 'negotiator')
      and cgm.is_active = true
  )
$$;


ALTER FUNCTION "public"."is_customer_group_admin_or_negotiator"("p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_customer_group_member"("p_customer_group_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.customer_group_members
    where customer_group_id = p_customer_group_id
      and lower(trim(email)) = public.current_user_email()
      and is_active = true
  );
ALTER FUNCTION "public"."is_customer_group_member"("p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_parent_company"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    (select t.parent_id is null from public.tenants t where t.id = p_tenant_id),
    false
  );
ALTER FUNCTION "public"."is_parent_company"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_superadmin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'superadmin'
      and m.is_active = true
      and m.tenant_id is null
  )
$$;


ALTER FUNCTION "public"."is_superadmin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_tenant_admin"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = p_tenant_id
      and m.role = 'admin'
      and m.is_active = true
  )
$$;


ALTER FUNCTION "public"."is_tenant_admin"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_tenant_staff"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'superadmin'::public.app_role
        or m.role = 'admin'::public.app_role
        or public.has_module_action(p_tenant_id, 'shop_order_mgmt', 'view')
      )
  );
ALTER FUNCTION "public"."is_tenant_staff"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."koba_cart_allowed"("p_cart_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.koba_carts c
    where c.id = p_cart_id
      and public.koba_context_access_allowed(c.tenant_id, c.customer_group_id)
  );
ALTER FUNCTION "public"."koba_cart_allowed"("p_cart_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."koba_context_access_allowed"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
    or (
      p_customer_group_id is not null
      and public.is_customer_group_member(p_customer_group_id)
    );
ALTER FUNCTION "public"."koba_context_access_allowed"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."koba_order_allowed"("p_order_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.koba_orders o
    where o.id = p_order_id
      and public.koba_context_access_allowed(o.tenant_id, o.customer_group_id)
  );
ALTER FUNCTION "public"."koba_order_allowed"("p_order_id" bigint) OWNER TO "postgres";


    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.customer_groups
  where id = p_customer_group_id;

  if v_tenant_id is null then
    raise exception 'Customer group not found';
  if not public.is_superadmin() and not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Unauthorized';
  return query
  select distinct cgmg.customer_group_member_id
  from public.customer_group_member_grants cgmg
  join public.customer_group_members cgm on cgm.id = cgmg.customer_group_member_id
  where cgm.customer_group_id = p_customer_group_id;
ALTER FUNCTION "public"."list_cgm_ids_with_overrides"("p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_child_tenant_ids"("p_parent_tenant_id" bigint) RETURNS SETOF bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select t.id
  from public.tenants t
  where t.parent_id = p_parent_tenant_id
  order by t.id;
$$;
ALTER FUNCTION "public"."list_child_tenant_ids"("p_parent_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_child_tenant_refs"("p_parent_tenant_ids" bigint[]) RETURNS TABLE("id" bigint, "parent_id" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select t.id, t.parent_id
  from public.tenants t
  where t.parent_id = any (coalesce(p_parent_tenant_ids, array[]::bigint[]))
  order by t.parent_id, t.id;
$$;
ALTER FUNCTION "public"."list_child_tenant_refs"(bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_commerce_global_stock_for_store"("p_tenant_id" bigint, "p_store_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_rows jsonb;
select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb) into v_rows
  from (
    select
      gs.id as global_stock_id,
      gs.name,
      gs.barcode,
      gs.product_code,
      gs.image_url,
      gs.cost,
      gs.product_id,
      coalesce(sum(q.quantity) filter (where q.status in ('excellent', 'box_less')), 0)::integer as available_qty,
      spp.price_bdt,
      spp.minimum_sell_price_bdt
    from public.global_stocks gs
    left join public.global_stock_quantities q on q.stock_id = gs.id
    left join public.store_product_prices spp
      on spp.global_stock_id = gs.id and spp.store_id = p_store_id
    left join public.child_tenant_stock_allocations a
      on a.stock_id = gs.id and a.child_tenant_id = p_tenant_id
    where gs.parent_tenant_id = v_parent_id
      and gs.status = 'active'
      and (
        p_tenant_id = v_parent_id
        or a.quantity > 0
        or a.id is null
      )
      and (
        p_search is null or trim(p_search) = ''
        or gs.name ilike '%' || trim(p_search) || '%'
        or coalesce(gs.barcode, '') ilike '%' || trim(p_search) || '%'
      )
    group by gs.id, spp.price_bdt, spp.minimum_sell_price_bdt
    having coalesce(sum(q.quantity) filter (where q.status in ('excellent', 'box_less')), 0) > 0
    order by gs.id desc
    limit greatest(coalesce(p_limit, 50), 1)
    offset greatest(coalesce(p_offset, 0), 0)
  ) t;

  return jsonb_build_object('items', coalesce(v_rows, '[]'::jsonb));
ALTER FUNCTION "public"."list_commerce_global_stock_for_store"("p_tenant_id" bigint, "p_store_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_configurable_module_actions"("p_scope" "text", "p_tenant_id" bigint) RETURNS TABLE("id" bigint, "module_key" "text", "action" "text", "description" "text", "scope" "text", "tenant_configurable" boolean, "is_active" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_scope not in ('app', 'shop', 'investor') then
    raise exception 'Invalid scope: %', p_scope;
  if not public.is_superadmin() and not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  return query
  select
    ma.id,
    ma.module_key,
    ma.action,
    ma.description,
    ma.scope,
    ma.tenant_configurable,
    ma.is_active
  from public.module_actions ma
  where ma.is_active = true
    and ma.tenant_configurable = true
    and ma.scope = p_scope
    and ma.scope <> 'platform'
    and ma.module_key = any(public.get_active_module_keys_for_tenant(p_tenant_id));
ALTER FUNCTION "public"."list_configurable_module_actions"("p_scope" "text", "p_tenant_id" bigint) OWNER TO "postgres";


    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id into v_tenant_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cgm.id = p_cgm_id;

  if v_tenant_id is null then
    raise exception 'Customer group member not found';
  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  return query
  select cgmg.id, cgmg.customer_group_member_id, cgmg.module_key, cgmg.action, cgmg.effect
  from public.customer_group_member_grants cgmg
  where cgmg.customer_group_member_id = p_cgm_id;
ALTER FUNCTION "public"."list_customer_group_member_grants"("p_cgm_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_customer_order_backlog_items"("p_tenant_id" bigint, "p_billing_profile_id" bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "billing_profile_id" bigint, "product_id" bigint, "order_id" bigint, "order_item_id" bigint, "requested_quantity" integer, "fulfilled_quantity" integer, "open_quantity" integer, "backlog_status" "text", "name" "text", "image_url" "text", "barcode" "text", "product_code" "text", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.tenant_id,
    b.billing_profile_id,
    b.product_id,
    b.order_id,
    b.order_item_id,
    b.requested_quantity,
    b.fulfilled_quantity,
    (b.requested_quantity - b.fulfilled_quantity) AS open_quantity,
    b.backlog_status,
    p.name,
    p.image_url,
    p.barcode,
    p.product_code,
    b.created_at
  FROM customer_order_backlog_items b
  JOIN products p ON p.id = b.product_id
  WHERE b.tenant_id = p_tenant_id
    AND b.billing_profile_id = p_billing_profile_id
    AND b.backlog_status IN ('open', 'partially_fulfilled')
  ORDER BY b.created_at DESC;
END;
ALTER FUNCTION "public"."list_customer_order_backlog_items"("p_tenant_id" bigint, "p_billing_profile_id" bigint) OWNER TO "postgres";


    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select gc.id, gc.name, gc.country, gc.code, gc.symbol
  from public.global_currencies gc
  where gc.is_active = true
  order by gc.code asc;
ALTER FUNCTION "public"."list_global_currencies"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_investor_allocations"("p_tenant_id" bigint, "p_investor_id" bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" bigint, "global_shipment_id" bigint, "shipment_name" "text", "shipment_status" "text", "cost_share_pct" numeric, "allocated_cost" numeric, "computed_profit" numeric, "profit_status" "text", "created_at" timestamp with time zone, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_count bigint;
begin
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  select count(*) into v_total_count
  from public.shipment_investments si
  where si.investor_id = p_investor_id
    and si.status = 'active';

  return query
  select
    si.id,
    si.global_shipment_id,
    gs.name as shipment_name,
    gs.status as shipment_status,
    si.cost_share_pct::numeric,
    si.allocated_cost::numeric,
    si.computed_profit::numeric,
    si.profit_status,
    si.created_at,
    v_total_count
  from public.shipment_investments si
  left join public.global_shipments gs on gs.id = si.global_shipment_id
  where si.investor_id = p_investor_id
    and si.status = 'active'
  order by si.created_at desc
  limit p_limit
  offset p_offset;
ALTER FUNCTION "public"."list_investor_allocations"("p_tenant_id" bigint, "p_investor_id" bigint, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_investor_profiles"("p_tenant_id" bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "tenant_id" bigint, "name" "text", "phone" "text", "email" "text", "address" "text", "is_active" boolean, "currency_code" "text", "notes" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "total_capital_in" numeric, "total_withdrawn" numeric, "deployed_capital" numeric, "available_balance" numeric, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_count bigint;
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_profiles', 'view') then
    raise exception 'not allowed';
  select count(*) into v_total_count
  from public.investors i
  where i.tenant_id = p_tenant_id
    and (p_search is null or i.name ilike '%' || p_search || '%' or i.email ilike '%' || p_search || '%');

  return query
  select
    i.id,
    i.tenant_id,
    i.name,
    i.phone,
    i.email,
    i.address,
    i.is_active,
    i.currency_code,
    i.notes,
    i.created_at,
    i.updated_at,
    coalesce((
      select sum(amount) from public.investor_transactions tx
      where tx.investor_id = i.id
        and tx.type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment')
    ), 0.00)::numeric as total_capital_in,
    coalesce((
      select sum(amount) from public.investor_transactions tx
      where tx.investor_id = i.id
        and tx.type in ('withdrawal', 'withdrawal_paid', 'profit_payout')
    ), 0.00)::numeric as total_withdrawn,
    coalesce((
      select sum(allocated_cost) from public.shipment_investments si
      where si.investor_id = i.id and si.status = 'active'
    ), 0.00)::numeric as deployed_capital,
    (
      coalesce((select sum(amount) from public.investor_transactions tx where tx.investor_id = i.id and tx.type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment')), 0.00) -
      coalesce((select sum(amount) from public.investor_transactions tx where tx.investor_id = i.id and tx.type in ('withdrawal', 'withdrawal_paid', 'profit_payout')), 0.00) -
      coalesce((select sum(allocated_cost) from public.shipment_investments si where si.investor_id = i.id and si.status = 'active'), 0.00)
    )::numeric as available_balance,
    v_total_count
  from public.investors i
  where i.tenant_id = p_tenant_id
    and (p_search is null or i.name ilike '%' || p_search || '%' or i.email ilike '%' || p_search || '%')
  order by i.name asc
  limit p_limit
  offset p_offset;
ALTER FUNCTION "public"."list_investor_profiles"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_investor_transactions"("p_tenant_id" bigint, "p_investor_id" bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" bigint, "amount" numeric, "date" "date", "method" "public"."investor_payment_method", "type" "public"."investor_transaction_type", "note" "text", "created_at" timestamp with time zone, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_count bigint;
begin
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  select count(*) into v_total_count
  from public.investor_transactions tx
  where tx.investor_id = p_investor_id;

  return query
  select
    tx.id,
    tx.amount::numeric,
    tx.date,
    tx.method,
    tx.type,
    tx.note,
    tx.created_at,
    v_total_count
  from public.investor_transactions tx
  where tx.investor_id = p_investor_id
  order by tx.date desc, tx.created_at desc
  limit p_limit
  offset p_offset;
ALTER FUNCTION "public"."list_investor_transactions"("p_tenant_id" bigint, "p_investor_id" bigint, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_invoices_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_count bigint;
  begin
  -- 1. Get total count of matching invoices
  select count(*)
  into v_total_count
  from public.invoices i
  where i.tenant_id = p_tenant_id
    and (p_status is null or p_status = '' or p_status = '__all__' or i.status = p_status)
    and (
      p_search is null or p_search = '' or (
        i.invoice_no ilike '%' || p_search || '%'
        or i.note ilike '%' || p_search || '%'
      )
    );

  -- 2. Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select *
    from public.invoices i
    where i.tenant_id = p_tenant_id
      and (p_status is null or p_status = '' or p_status = '__all__' or i.status = p_status)
      and (
        p_search is null or p_search = '' or (
          i.invoice_no ilike '%' || p_search || '%'
          or i.note ilike '%' || p_search || '%'
        )
      )
    order by i.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  ALTER FUNCTION "public"."list_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_items_paginated"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_type" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_priority" "text" DEFAULT NULL::"text", "p_assignee" "text" DEFAULT NULL::"text", "p_my_tasks_email" "text" DEFAULT NULL::"text", "p_include_parents" boolean DEFAULT false, "p_tag_id" bigint DEFAULT NULL::bigint, "p_date_field" "text" DEFAULT NULL::"text", "p_date_from" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_date_to" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text;
  -- Status count variables
  v_todo_count bigint;
  v_in_progress_count bigint;
  v_review_count bigint;
  v_done_count bigint;
  v_blocked_count bigint;
  v_archived_count bigint;
begin
  v_email := public.current_user_email();

  -- Calculate status counts for all items matching the query filters (ignoring pagination limits, type, and status)
  -- restricted strictly to i.type = 'task'
  select
    count(*) filter (where i.status = 'todo'),
    count(*) filter (where i.status = 'in_progress'),
    count(*) filter (where i.status = 'review'),
    count(*) filter (where i.status = 'done'),
    count(*) filter (where i.status = 'blocked'),
    count(*) filter (where i.status = 'archived')
  into
    v_todo_count,
    v_in_progress_count,
    v_review_count,
    v_done_count,
    v_blocked_count,
    v_archived_count
  from public.items i
  where
    i.type = 'task'
    and public.get_effective_item_role(i.id, v_email) is not null
    and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
    and (p_priority is null or p_priority = '' or i.priority = p_priority)
    and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
    and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
    and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id))
    and (
      p_date_field is null or p_date_field = '' or (
        (p_date_field = 'created' and (p_date_from is null or i.created_at >= p_date_from) and (p_date_to is null or i.created_at <= p_date_to)) or
        (p_date_field = 'updated' and (p_date_from is null or i.updated_at >= p_date_from) and (p_date_to is null or i.updated_at <= p_date_to)) or
        (p_date_field = 'start' and (p_date_from is null or i.start_date >= p_date_from) and (p_date_to is null or i.start_date <= p_date_to)) or
        (p_date_field = 'due' and (p_date_from is null or i.due_date >= p_date_from) and (p_date_to is null or i.due_date <= p_date_to))
      )
    );

  if p_include_parents then
    -- 1. Get total count of all unique items in matching items hierarchy
    select count(*)
    into v_total_count
    from (
      with recursive matching_items as (
        select i.id, i.parent_id
        from public.items i
        where
          public.get_effective_item_role(i.id, v_email) is not null
          and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
          and (p_type is null or p_type = '' or i.type = p_type)
          and (p_status is null or p_status = '' or i.status = p_status)
          and (p_priority is null or p_priority = '' or i.priority = p_priority)
          and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
          and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
          and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id))
          and (
            p_date_field is null or p_date_field = '' or (
              (p_date_field = 'created' and (p_date_from is null or i.created_at >= p_date_from) and (p_date_to is null or i.created_at <= p_date_to)) or
              (p_date_field = 'updated' and (p_date_from is null or i.updated_at >= p_date_from) and (p_date_to is null or i.updated_at <= p_date_to)) or
              (p_date_field = 'start' and (p_date_from is null or i.start_date >= p_date_from) and (p_date_to is null or i.start_date <= p_date_to)) or
              (p_date_field = 'due' and (p_date_from is null or i.due_date >= p_date_from) and (p_date_to is null or i.due_date <= p_date_to))
            )
          )
      ),
      item_hierarchy as (
        select m.id, m.parent_id
        from matching_items m
        
        union
        
        select p.id, p.parent_id
        from public.items p
        join item_hierarchy h on h.parent_id = p.id
        where public.get_effective_item_role(p.id, v_email) is not null
      )
      select distinct id from item_hierarchy
    ) distinct_hierarchy;

    -- 2. Get hierarchy records as a jsonb array
    select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
    into v_data
    from (
      with recursive matching_items as (
        select *
        from public.items i
        where
          public.get_effective_item_role(i.id, v_email) is not null
          and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
          and (p_type is null or p_type = '' or i.type = p_type)
          and (p_status is null or p_status = '' or i.status = p_status)
          and (p_priority is null or p_priority = '' or i.priority = p_priority)
          and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
          and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
          and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id))
          and (
            p_date_field is null or p_date_field = '' or (
              (p_date_field = 'created' and (p_date_from is null or i.created_at >= p_date_from) and (p_date_to is null or i.created_at <= p_date_to)) or
              (p_date_field = 'updated' and (p_date_from is null or i.updated_at >= p_date_from) and (p_date_to is null or i.updated_at <= p_date_to)) or
              (p_date_field = 'start' and (p_date_from is null or i.start_date >= p_date_from) and (p_date_to is null or i.start_date <= p_date_to)) or
              (p_date_field = 'due' and (p_date_from is null or i.due_date >= p_date_from) and (p_date_to is null or i.due_date <= p_date_to))
            )
          )
      ),
      item_hierarchy as (
        select
          m.id, m.tenant_id, m.parent_id, m.type, m.title, m.content, m.status, m.priority, m.is_markdown,
          m.created_by_email, m.due_date, m.start_date, m.created_at, m.updated_at, m.archived_at
        from matching_items m
        
        union
        
        select
          p.id, p.tenant_id, p.parent_id, p.type, p.title, p.content, p.status, p.priority, p.is_markdown,
          p.created_by_email, p.due_date, p.start_date, p.created_at, p.updated_at, p.archived_at
        from public.items p
        join item_hierarchy h on h.parent_id = p.id
        where public.get_effective_item_role(p.id, v_email) is not null
      ),
      distinct_hierarchy as (
        select distinct
          id, tenant_id, parent_id, type, title, content, status, priority, is_markdown,
          created_by_email, due_date, start_date, created_at, updated_at, archived_at
        from item_hierarchy
      )
      select
        dh.id, dh.tenant_id, dh.parent_id, dh.type, dh.title, dh.content, dh.status, dh.priority, dh.is_markdown,
        dh.created_by_email, dh.due_date, dh.start_date, dh.created_at, dh.updated_at, dh.archived_at,
        (
          select coalesce(json_agg(json_build_object(
            'id', ia.id,
            'item_id', ia.item_id,
            'user_email', ia.user_email,
            'assigned_by_email', ia.assigned_by_email,
            'created_at', ia.created_at
          )), '[]'::json)
          from public.item_assignees ia
          where ia.item_id = dh.id
        ) as assignees,
        (
          select coalesce(json_agg(json_build_object(
            'id', t.id,
            'tenant_id', t.tenant_id,
            'name', t.name,
            'slug', t.slug,
            'color', t.color,
            'type', t.type,
            'created_by_email', t.created_by_email,
            'created_at', t.created_at
          )), '[]'::json)
          from public.item_tags it
          join public.tags t on t.id = it.tag_id
          where it.item_id = dh.id
        ) as tags
      from distinct_hierarchy dh
      order by dh.created_at asc
      limit p_page_size
      offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
    ) r;

  else
    -- Flat list pagination
    -- 1. Get total count
    select count(*)
    into v_total_count
    from public.items i
    where
      public.get_effective_item_role(i.id, v_email) is not null
      and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
      and (p_type is null or p_type = '' or i.type = p_type)
      and (p_status is null or p_status = '' or i.status = p_status)
      and (p_priority is null or p_priority = '' or i.priority = p_priority)
      and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
      and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
      and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id))
      and (
        p_date_field is null or p_date_field = '' or (
          (p_date_field = 'created' and (p_date_from is null or i.created_at >= p_date_from) and (p_date_to is null or i.created_at <= p_date_to)) or
          (p_date_field = 'updated' and (p_date_from is null or i.updated_at >= p_date_from) and (p_date_to is null or i.updated_at <= p_date_to)) or
          (p_date_field = 'start' and (p_date_from is null or i.start_date >= p_date_from) and (p_date_to is null or i.start_date <= p_date_to)) or
          (p_date_field = 'due' and (p_date_from is null or i.due_date >= p_date_from) and (p_date_to is null or i.due_date <= p_date_to))
        )
      );

    -- 2. Get flat list items
    select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
    into v_data
    from (
      select
        i.id, i.tenant_id, i.parent_id, i.type, i.title, i.content, i.status, i.priority, i.is_markdown,
        i.created_by_email, i.due_date, i.start_date, i.created_at, i.updated_at, i.archived_at,
        (
          select coalesce(json_agg(json_build_object(
            'id', ia.id,
            'item_id', ia.item_id,
            'user_email', ia.user_email,
            'assigned_by_email', ia.assigned_by_email,
            'created_at', ia.created_at
          )), '[]'::json)
          from public.item_assignees ia
          where ia.item_id = i.id
        ) as assignees,
        (
          select coalesce(json_agg(json_build_object(
            'id', t.id,
            'tenant_id', t.tenant_id,
            'name', t.name,
            'slug', t.slug,
            'color', t.color,
            'type', t.type,
            'created_by_email', t.created_by_email,
            'created_at', t.created_at
          )), '[]'::json)
          from public.item_tags it
          join public.tags t on t.id = it.tag_id
          where it.item_id = i.id
        ) as tags
      from public.items i
      where
        public.get_effective_item_role(i.id, v_email) is not null
        and (p_search is null or p_search = '' or (i.title ilike '%' || p_search || '%' or i.content ilike '%' || p_search || '%'))
        and (p_type is null or p_type = '' or i.type = p_type)
        and (p_status is null or p_status = '' or i.status = p_status)
        and (p_priority is null or p_priority = '' or i.priority = p_priority)
        and (p_assignee is null or p_assignee = '' or exists (select 1 from public.item_assignees ia where ia.item_id = i.id and ia.user_email = p_assignee))
        and (p_my_tasks_email is null or p_my_tasks_email = '' or (i.created_by_email = p_my_tasks_email or exists (select 1 from public.item_assignees ia2 where ia2.item_id = i.id and ia2.user_email = p_my_tasks_email)))
        and (p_tag_id is null or exists (select 1 from public.item_tags it where it.item_id = i.id and it.tag_id = p_tag_id))
        and (
          p_date_field is null or p_date_field = '' or (
            (p_date_field = 'created' and (p_date_from is null or i.created_at >= p_date_from) and (p_date_to is null or i.created_at <= p_date_to)) or
            (p_date_field = 'updated' and (p_date_from is null or i.updated_at >= p_date_from) and (p_date_to is null or i.updated_at <= p_date_to)) or
            (p_date_field = 'start' and (p_date_from is null or i.start_date >= p_date_from) and (p_date_to is null or i.start_date <= p_date_to)) or
            (p_date_field = 'due' and (p_date_from is null or i.due_date >= p_date_from) and (p_date_to is null or i.due_date <= p_date_to))
          )
        )
      order by i.created_at asc
      limit p_page_size
      offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
    ) r;
  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total_count', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages,
      'status_counts', jsonb_build_object(
        'todo', coalesce(v_todo_count, 0),
        'in_progress', coalesce(v_in_progress_count, 0),
        'review', coalesce(v_review_count, 0),
        'done', coalesce(v_done_count, 0),
        'blocked', coalesce(v_blocked_count, 0),
        'archived', coalesce(v_archived_count, 0)
      )
    )
  );
ALTER FUNCTION "public"."list_items_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_type" "text", "p_status" "text", "p_priority" "text", "p_assignee" "text", "p_my_tasks_email" "text", "p_include_parents" boolean, "p_tag_id" bigint, "p_date_field" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_koba_brands_for_tenant"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object('id', kb.id, 'name', kb.name)
      order by kb.name asc
    ),
    '[]'::jsonb
  )
  from public.koba_brands kb
  where kb.tenant_id = p_tenant_id
    and exists (
      select 1
      from public.koba_products kp
      where kp.brand_id    = kb.id
        and kp.tenant_id   = p_tenant_id
        and kp.source_type = 'retail'
        and kp.in_stock    = true
    );
ALTER FUNCTION "public"."list_koba_brands_for_tenant"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_koba_categories_for_tenant"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object('id', kc.id, 'name', kc.name)
      order by kc.name asc
    ),
    '[]'::jsonb
  )
  from public.koba_categories kc
  where kc.tenant_id = p_tenant_id
    and exists (
      select 1
      from public.koba_products kp
      where kp.category_id = kc.id
        and kp.tenant_id   = p_tenant_id
        and kp.source_type = 'retail'
        and kp.in_stock    = true
    );
ALTER FUNCTION "public"."list_koba_categories_for_tenant"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_koba_orders"("p_tenant_id" bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with filtered as (
    select
      o.*,
      count(*) over() as total_count
    from public.koba_orders o
    where o.tenant_id = p_tenant_id
      and public.koba_context_access_allowed(p_tenant_id, o.customer_group_id)
      and (
        p_customer_group_id is null
        or o.customer_group_id = p_customer_group_id
      )
      and (
        p_status is null
        or o.status::text = p_status
      )
  ),
  paged as (
    select *
    from filtered
    order by created_at desc, id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total', coalesce(max(paged.total_count), 0),
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
        case
          when coalesce(max(paged.total_count), 0) = 0 then 1
          else ceil(
            coalesce(max(paged.total_count), 0)::numeric
            / greatest(coalesce(p_page_size, 20), 1)
          )::int
        end
    )
  )
  from paged;
ALTER FUNCTION "public"."list_koba_orders"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_page" integer, "p_page_size" integer, "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_koba_retail_products"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_brand_id" bigint DEFAULT NULL::bigint, "p_category_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with filtered as (
    select
      kp.id,
      kp.name,
      kp.sku,
      kp.barcode,
      kp.description,
      kp.stock_quantity,
      kp.in_stock,
      kp.price                   as price_gbp,
      kp.regular_price,
      kp.sale_price,
      kp.commission_percentage,
      kp.commission,
      kp.image_url,
      kp.brand_id,
      kb.name                    as brand,
      kp.category_id,
      kc.name                    as category,
      kp.created_at,
      kp.updated_at,
      count(*) over()            as total_count
    from public.koba_products kp
    left join public.koba_brands     kb on kb.id = kp.brand_id
    left join public.koba_categories kc on kc.id = kp.category_id
    where
      kp.tenant_id  = p_tenant_id
      and kp.source_type = 'retail'
      and kp.in_stock    = true
      -- search across name, sku, barcode
      and (
        coalesce(trim(p_search), '') = ''
        or kp.name    ilike ('%' || trim(p_search) || '%')
        or kp.sku     ilike ('%' || trim(p_search) || '%')
        or kp.barcode ilike ('%' || trim(p_search) || '%')
      )
      -- brand filter
      and (p_brand_id    is null or kp.brand_id    = p_brand_id)
      -- category filter
      and (p_category_id is null or kp.category_id = p_category_id)
  ),
  paged as (
    select *
    from filtered
    order by name asc, id asc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit  greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total',       coalesce(max(paged.total_count), 0),
      'page',        greatest(coalesce(p_page, 1), 1),
      'page_size',   greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
      case
        when coalesce(max(paged.total_count), 0) = 0 then 1
        else ceil(coalesce(max(paged.total_count), 0)::numeric
               / greatest(coalesce(p_page_size, 20), 1))::int
      end
    )
  )
  from paged;
ALTER FUNCTION "public"."list_koba_retail_products"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_brand_id" bigint, "p_category_id" bigint) OWNER TO "postgres";


    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select m.tenant_id into v_tenant_id
  from public.memberships m
  where m.id = p_membership_id;

  if v_tenant_id is null then
    raise exception 'Membership not found';
  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  return query
  select mg.id, mg.membership_id, mg.module_key, mg.action, mg.effect, mg.created_by_email, mg.created_at, mg.updated_at
  from public.membership_grants mg
  where mg.membership_id = p_membership_id;
ALTER FUNCTION "public"."list_membership_grants"("p_membership_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_membership_ids_with_overrides"("p_tenant_id" bigint) RETURNS TABLE("membership_id" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_superadmin() and not public.user_is_tenant_admin(p_tenant_id) then
    raise exception 'Unauthorized';
  return query
  select distinct mg.membership_id
  from public.membership_grants mg
  join public.memberships m on m.id = mg.membership_id
  where m.tenant_id = p_tenant_id;
ALTER FUNCTION "public"."list_membership_ids_with_overrides"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_my_admin_tenants"() RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text", "is_active" boolean, "parent_id" bigint, "preference" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.parent_id,
    t.preference,
    t.created_at,
    t.updated_at
  from public.tenants t
  where exists (
    select 1
    from public.memberships m
    where m.tenant_id = t.id
      and lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
  )
  order by t.id asc;
ALTER FUNCTION "public"."list_my_admin_tenants"() OWNER TO "postgres";


    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select pm.code, pm.name, pm.category, pm.scope, pm.sort_order
  from public.payment_methods pm
  where pm.is_active = true
  order by pm.sort_order asc, pm.name asc;
ALTER FUNCTION "public"."list_payment_methods"() OWNER TO "postgres";


    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "value" "text" GENERATED ALWAYS AS ("lower"(TRIM(BOTH FROM "name"))) STORED,
    "vendor_code" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "vendor_id" bigint,
    "tenant_id" bigint,
    "parent_tenant_id" bigint,
    CONSTRAINT "product_brands_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0))
);


ALTER TABLE "public"."product_brands" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_product_brands_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text" DEFAULT NULL::"text", "p_vendor_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."product_brands"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_vendor_code text;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_vendor_code := nullif(upper(trim(coalesce(p_vendor_code, ''))), '');

  return query
  select pb.*
  from public.product_brands pb
  where pb.parent_tenant_id = v_scope_tenant_id
    and (v_vendor_code is null or pb.vendor_code = v_vendor_code)
    and (p_vendor_id is null or pb.vendor_id = p_vendor_id)
  order by pb.name asc;
ALTER FUNCTION "public"."list_product_brands_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text", "p_vendor_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_categories" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "value" "text" GENERATED ALWAYS AS ("lower"(TRIM(BOTH FROM "name"))) STORED,
    "vendor_code" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "vendor_id" bigint,
    "tenant_id" bigint,
    "parent_tenant_id" bigint,
    CONSTRAINT "product_categories_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0))
);


ALTER TABLE "public"."product_categories" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_product_categories_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text" DEFAULT NULL::"text", "p_vendor_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."product_categories"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_vendor_code text;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_vendor_code := nullif(upper(trim(coalesce(p_vendor_code, ''))), '');

  return query
  select pc.*
  from public.product_categories pc
  where pc.parent_tenant_id = v_scope_tenant_id
    and (v_vendor_code is null or pc.vendor_code = v_vendor_code)
    and (p_vendor_id is null or pc.vendor_id = p_vendor_id)
  order by pc.name asc;
ALTER FUNCTION "public"."list_product_categories_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text", "p_vendor_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_products_paginated"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_search_field" "text" DEFAULT 'name'::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_vendor_code" "text" DEFAULT NULL::"text", "p_market_code" "text" DEFAULT NULL::"text", "p_is_available" boolean DEFAULT NULL::boolean, "p_sort_by" "text" DEFAULT 'name'::"text", "p_sort_dir" "text" DEFAULT 'asc'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_limit integer;
  v_offset integer;
  v_sort_by text;
  v_sort_dir text;
  v_search_field text;
  v_scope_tenant_id bigint;
  v_result jsonb;
  v_tokens text[] := '{}'::text[];
  v_phrase_escaped text;
begin
  if p_tenant_id is not null and not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  v_scope_tenant_id := case
    when p_tenant_id is null then null
    else public.resolve_parent_tenant_id(p_tenant_id)
  end;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  v_sort_by := lower(trim(coalesce(p_sort_by, 'name')));
  if not (v_sort_by = any (array[
    'id',
    'name',
    'product_code',
    'barcode',
    'brand',
    'category',
    'list_price_amount',
    'available_units',
    'created_at',
    'updated_at'
  ])) then
    v_sort_by := 'name';
  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  v_search_field := lower(trim(coalesce(p_search_field, 'name')));
  if v_search_field not in ('name', 'barcode', 'product_code', 'id') then
    v_search_field := 'name';
  if v_search_field = 'name' and p_search is not null and trim(p_search) <> '' then
    v_phrase_escaped := replace(replace(replace(trim(p_search), E'\\', E'\\\\'), '%', E'\\%'), '_', E'\\_');

    select coalesce(array_agg(tok), '{}'::text[])
    into v_tokens
    from unnest(regexp_split_to_array(trim(p_search), E'[^[:alnum:]]+')) as tok
    where tok <> ''
      and lower(tok) not in ('a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on');

    if cardinality(v_tokens) = 0 then
      v_tokens := array[trim(p_search)];
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where
            ($1 is null or p.parent_tenant_id = $1)
            and ($2 is null or trim($2) = '' or (
              ($3 = 'name' and (
                cardinality($11) = 0
                or (
                  select coalesce(bool_and(
                    concat_ws(' ', p.name, p.brand) ~* ('(^|[^[:alnum:]])' || t || '([^[:alnum:]]|$)')
                  ), true)
                  from unnest($11) t
                )
              ))
              or ($3 = 'barcode' and p.barcode ilike ('%%' || trim($2) || '%%'))
              or ($3 = 'product_code' and p.product_code ilike ('%%' || trim($2) || '%%'))
              or ($3 = 'id' and trim($2) ~ '^[0-9]+$' and p.id = trim($2)::bigint)
            ))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
            and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
            and ($6 is null or trim($6) = '' or upper(coalesce(p.vendor_code, '')) = upper(trim($6)))
            and ($7 is null or trim($7) = '' or upper(coalesce(p.market_code, '')) = upper(trim($7)))
            and ($8 is null or p.is_available = $8)
        ),
        paged as (
          select
            f.*,
            row_number() over (
              order by
                (
                  select count(*)
                  from unnest($11) t
                  where concat_ws(' ', f.name, f.brand) ~* ('(^|[^[:alnum:]])' || t || '([^[:alnum:]]|$)')
                ) desc,
                case
                  when $12 is not null
                    and concat_ws(' ', f.name, f.brand) ilike ('%%' || $12 || '%%') escape E'\\' then 0
                  else 1
                end,
                %I %s nulls last,
                f.id asc
            ) as _search_rank
          from filtered f
          order by _search_rank
          limit $9
          offset $10
        )
        select jsonb_build_object(
          'data',
          coalesce((
            select jsonb_agg((to_jsonb(p) - '_search_rank') order by p._search_rank)
            from paged p
          ), '[]'::jsonb),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($10 / $9) + 1),
            'page_size', $9,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $9::numeric))
          )
        )
      $sql$,
      v_sort_by,
      v_sort_dir
    )
    into v_result
    using
      v_scope_tenant_id,
      p_search,
      v_search_field,
      p_category,
      p_brand,
      p_vendor_code,
      p_market_code,
      p_is_available,
      v_limit,
      v_offset,
      v_tokens,
      v_phrase_escaped;

  return coalesce(
    v_result,
    jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'total', 0,
        'page', ((v_offset / v_limit) + 1),
        'page_size', v_limit,
        'total_pages', 1
      )
    )
  );
$_$;


ALTER FUNCTION "public"."list_products_paginated"("p_tenant_id" bigint, "p_search" "text", "p_search_field" "text", "p_category" "text", "p_brand" "text", "p_vendor_code" "text", "p_market_code" "text", "p_is_available" boolean, "p_sort_by" "text", "p_sort_dir" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_result jsonb;
begin
  with target_batches as (
    -- Filter active inventory items
    select ii.id as inventory_item_id, ii.product_id
    from public.inventory_items ii
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    left join public.inventory_stocks ist
      on ist.inventory_item_id = ii.id
    where ii.tenant_id = p_tenant_id
      and ii.status = 'active'
      and (p_shipment_id is null or (ii.source_type = 'shipment' and si.shipment_id = p_shipment_id))
      and (ist.stolen_quantity is null or ist.stolen_quantity = 0 or ist.stolen_quantity < ist.available_quantity)
  ),
  batches_with_details as (
    -- Search in batches or parent product details
    select
      tb.inventory_item_id,
      ii.product_id,
      ii.name,
      ii.image_url,
      ii.barcode,
      ii.product_code,
      ii.expire_date,
      ii.cost
    from target_batches tb
    join public.inventory_items ii on ii.id = tb.inventory_item_id
    left join public.products p on p.id = tb.product_id
    where (
      p_search is null
      or trim(p_search) = ''
      or ii.name ilike ('%' || trim(p_search) || '%')
      or ii.product_code ilike ('%' || trim(p_search) || '%')
      or ii.barcode ilike ('%' || trim(p_search) || '%')
      or p.name ilike ('%' || trim(p_search) || '%')
      or p.product_code ilike ('%' || trim(p_search) || '%')
      or p.barcode ilike ('%' || trim(p_search) || '%')
    )
  ),
  counted as (
    select *, count(*) over() as total_count
    from batches_with_details
  ),
  paged_batches as (
    select *
    from counted
    order by name asc, inventory_item_id asc
    limit p_page_size
    offset (p_page - 1) * p_page_size
  ),
  batch_items as (
    -- Construct cost, stock, and shipment info for each batch
    select
      pb.inventory_item_id,
      jsonb_build_object(
        'id', pb.inventory_item_id,
        'cost', pb.cost,
        'quantities', jsonb_build_object(
          'available', coalesce(ist.available_quantity, 0),
          'reserved', coalesce(ist.reserved_quantity, 0),
          'damaged', coalesce(ist.damaged_quantity, 0),
          'stolen', coalesce(ist.stolen_quantity, 0),
          'expired', coalesce(ist.expired_quantity, 0),
          'open_box', coalesce(ist.open_box_quantity, 0)
        ),
        'shipment', case
          when sh.id is null then null
          else jsonb_build_object(
            'shipment', jsonb_build_object(
              'id', sh.id,
              'name', sh.name,
              'tenant_shipment_id', sh.tenant_shipment_id
            )
          )
        end
      ) as item_json
    from paged_batches pb
    left join public.inventory_stocks ist
      on ist.inventory_item_id = pb.inventory_item_id
    left join public.inventory_items ii
      on ii.id = pb.inventory_item_id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
  ),
  final_data as (
    -- Return one row per batch, mapping batch ID to product_id for frontend table compatibility
    select
      pb.inventory_item_id as product_id,
      pb.name,
      pb.image_url,
      pb.barcode,
      pb.product_code,
      spp.stock_override,
      spp.price_bdt,
      spp.minimum_sell_price_bdt,
      jsonb_build_array(bi.item_json) as items
    from paged_batches pb
    join batch_items bi on bi.inventory_item_id = pb.inventory_item_id
    left join public.store_product_prices spp
      on spp.store_id = p_store_id
     and spp.tenant_id = p_tenant_id
     and spp.inventory_item_id = pb.inventory_item_id
     and spp.is_active = true
  )
  select jsonb_build_object(
    'data', coalesce((select jsonb_agg(to_jsonb(fd)) from final_data fd), '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', coalesce((select max(total_count) from counted), 0),
      'page', p_page,
      'page_size', p_page_size,
      'total_pages', case
        when coalesce((select max(total_count) from counted), 0) = 0 then 1
        else ceil(coalesce((select max(total_count) from counted), 0)::numeric / p_page_size)::int
      end
    )
  )
  into v_result;

  return v_result;
ALTER FUNCTION "public"."list_store_product_pricing"("p_tenant_id" bigint, "p_store_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_store_products"("p_store_id" bigint, "p_fields" "text"[] DEFAULT NULL::"text"[], "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_is_available" boolean DEFAULT NULL::boolean, "p_sort_by" "text" DEFAULT 'id'::"text", "p_sort_dir" "text" DEFAULT 'asc'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_tenant_id bigint;
  v_vendor_code text;
  v_sort_by text;
  v_sort_dir text;
  v_limit integer;
  v_offset integer;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
  v_can_see_price boolean;
  v_allowed_fields text[] := array[
    'id',
    'tenant_id',
    'product_code',
    'barcode',
    'name',
    'price_gbp',
    'country_of_origin',
    'brand',
    'category',
    'available_units',
    'tariff_code',
    'languages',
    'batch_code_manufacture_date',
    'image_url',
    'expire_date',
    'minimum_order_quantity',
    'product_weight',
    'package_weight',
    'is_available',
    'created_at',
    'updated_at',
    'vendor_code',
    'market_code'
  ];
  v_selected_fields text[];
  v_result jsonb;
begin
  select s.tenant_id, s.vendor_code
  into v_tenant_id, v_vendor_code
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id = v_tenant_id
      and m.role in ('admin', 'staff')
  ) into v_has_internal_access;

  v_has_customer_access := public.can_customer_access_store(p_store_id);

  if not v_has_internal_access and not v_has_customer_access then
    raise exception 'not allowed';
  v_can_see_price := v_has_internal_access or public.can_customer_see_store_price(p_store_id);

  v_sort_by := lower(trim(coalesce(p_sort_by, 'id')));
  if not (v_sort_by = any (array[
    'id',
    'name',
    'product_code',
    'barcode',
    'brand',
    'category',
    'price_gbp',
    'available_units',
    'created_at',
    'updated_at'
  ])) then
    v_sort_by := 'id';
  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  select coalesce(array_agg(distinct field_name), '{}'::text[])
  into v_selected_fields
  from unnest(coalesce(p_fields, v_allowed_fields)) as field_name
  where field_name = any (v_allowed_fields);

  if coalesce(array_length(v_selected_fields, 1), 0) = 0 then
    v_selected_fields := array['id', 'name', 'vendor_code', 'brand', 'category'];
  if not v_can_see_price then
    select coalesce(array_agg(field_name), '{}'::text[])
    into v_selected_fields
    from unnest(v_selected_fields) as field_name
    where field_name <> 'price_gbp';
  execute format(
    $sql$
      with filtered as (
        select p.*
        from public.products p
        where p.vendor_code = $1
          and p.tenant_id = $2
          and (
            $3 is null
            or trim($3) = ''
            or p.name ilike ('%%' || trim($3) || '%%')
            or p.product_code ilike ('%%' || trim($3) || '%%')
            or p.barcode ilike ('%%' || trim($3) || '%%')
          )
          and (
            $4 is null
            or trim($4) = ''
            or lower(coalesce(p.category, '')) = lower(trim($4))
          )
          and (
            $5 is null
            or trim($5) = ''
            or lower(coalesce(p.brand, '')) = lower(trim($5))
          )
          and p.is_available is true
      ),
      paged as (
        select f.*
        from filtered f
        order by %I %s nulls last, f.id asc
        limit $8
        offset $9
      )
      select jsonb_build_object(
        'data',
        coalesce(
          (
            select jsonb_agg(
              (
                select jsonb_object_agg(field_name, to_jsonb(p) -> field_name)
                from unnest($7::text[]) as field_name
              )
            )
            from paged p
          ),
          '[]'::jsonb
        ),
        'meta',
        jsonb_build_object(
          'store_id', $10,
          'limit', $8,
          'offset', $9,
          'current_page', (($9 / $8) + 1),
          'sort_by', $11,
          'sort_dir', $12,
          'total', (select count(*) from filtered),
          'can_see_price', $13
        )
      )
    $sql$,
    v_sort_by,
    v_sort_dir
  )
  into v_result
  using
    v_vendor_code,
    v_tenant_id,
    p_search,
    p_category,
    p_brand,
    p_is_available,
    v_selected_fields,
    v_limit,
    v_offset,
    p_store_id,
    v_sort_by,
    v_sort_dir,
    v_can_see_price;

  return coalesce(
    v_result,
    jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'store_id', p_store_id,
        'limit', v_limit,
        'offset', v_offset,
        'current_page', ((v_offset / v_limit) + 1),
        'sort_by', v_sort_by,
        'sort_dir', v_sort_dir,
        'total', 0,
        'can_see_price', v_can_see_price
      )
    )
  );
$_$;


ALTER FUNCTION "public"."list_store_products"("p_store_id" bigint, "p_fields" "text"[], "p_search" "text", "p_category" "text", "p_brand" "text", "p_is_available" boolean, "p_sort_by" "text", "p_sort_dir" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_store_products_inventory_aggregated"("p_store_id" bigint, "p_fields" "text"[] DEFAULT NULL::"text"[], "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_is_available" boolean DEFAULT NULL::boolean, "p_sort_by" "text" DEFAULT 'id'::"text", "p_sort_dir" "text" DEFAULT 'asc'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_tenant_id bigint;
  v_vendor_code text;
  v_sort_by text;
  v_sort_dir text;
  v_limit integer;
  v_offset integer;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
  v_can_see_price boolean;
  v_allowed_fields text[] := array[
    'id',
    'tenant_id',
    'product_code',
    'barcode',
    'name',
    'price_gbp',
    'price_bdt',
    'minimum_sell_price_bdt',
    'country_of_origin',
    'brand',
    'category',
    'available_units',
    'stock_override',
    'tariff_code',
    'languages',
    'batch_code_manufacture_date',
    'image_url',
    'expire_date',
    'minimum_order_quantity',
    'product_weight',
    'package_weight',
    'is_available',
    'created_at',
    'updated_at',
    'vendor_code',
    'market_code'
  ];
  v_selected_fields text[];
  v_result jsonb;
begin
  select s.tenant_id, s.vendor_code
  into v_tenant_id, v_vendor_code
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id = v_tenant_id
      and m.role in ('admin', 'staff')
  ) into v_has_internal_access;

  v_has_customer_access := public.can_customer_access_store(p_store_id);

  if not v_has_internal_access and not v_has_customer_access then
    raise exception 'not allowed';
  v_can_see_price := v_has_internal_access or public.can_customer_see_store_price(p_store_id);

  v_sort_by := lower(trim(coalesce(p_sort_by, 'id')));
  if not (v_sort_by = any (array[
    'id',
    'name',
    'product_code',
    'barcode',
    'brand',
    'category',
    'price_bdt',
    'available_units',
    'created_at',
    'updated_at'
  ])) then
    v_sort_by := 'id';
  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  select coalesce(array_agg(distinct field_name), '{}'::text[])
  into v_selected_fields
  from unnest(coalesce(p_fields, v_allowed_fields)) as field_name
  where field_name = any (v_allowed_fields);

  if coalesce(array_length(v_selected_fields, 1), 0) = 0 then
    v_selected_fields := array['id', 'name', 'vendor_code', 'brand', 'category', 'available_units', 'stock_override'];
  if not v_can_see_price then
    select coalesce(array_agg(field_name), '{}'::text[])
    into v_selected_fields
    from unnest(v_selected_fields) as field_name
    where field_name not in ('price_gbp', 'price_bdt', 'minimum_sell_price_bdt');
  execute format(
    $sql$
      with base as (
        select
          ii.id,
          ii.tenant_id,
          ii.product_code,
          ii.barcode,
          ii.name,
          spp.price_bdt,
          spp.minimum_sell_price_bdt,
          spp.price_bdt as price_gbp,
          p.country_of_origin,
          p.brand,
          p.category,
          coalesce(spp.stock_override, greatest(0, ist.available_quantity - ist.reserved_quantity - ist.damaged_quantity - ist.stolen_quantity - ist.expired_quantity - ist.open_box_quantity), 0) as available_units,
          spp.stock_override,
          p.tariff_code,
          p.languages,
          ii.manufacturing_date as batch_code_manufacture_date,
          ii.image_url,
          ii.expire_date,
          p.minimum_order_quantity,
          p.product_weight,
          p.package_weight,
          case when ii.status = 'active' then true else false end as is_available,
          ii.created_at,
          ii.updated_at,
          p.vendor_code,
          p.market_code
        from public.inventory_items ii
        join public.products p
          on p.id = ii.product_id
        left join public.inventory_stocks ist
          on ist.inventory_item_id = ii.id
        left join public.store_product_prices spp
          on spp.store_id = $14
         and spp.tenant_id = ii.tenant_id
         and spp.inventory_item_id = ii.id
        where ii.tenant_id = $1
          and p.vendor_code = $2
          and ii.status = 'active'
          and (ist.stolen_quantity is null or ist.stolen_quantity = 0 or ist.stolen_quantity < ist.available_quantity)
      ),
      filtered as (
        select b.*
        from base b
        where (
            $3 is null
            or trim($3) = ''
            or b.name ilike ('%%' || trim($3) || '%%')
            or b.product_code ilike ('%%' || trim($3) || '%%')
            or b.barcode ilike ('%%' || trim($3) || '%%')
          )
          and (
            $4 is null
            or trim($4) = ''
            or lower(coalesce(b.category, '')) = lower(trim($4))
          )
          and (
            $5 is null
            or trim($5) = ''
            or lower(coalesce(b.brand, '')) = lower(trim($5))
          )
          and (
            $6 is null
            or b.available_units > 0
          )
      ),
      paged as (
        select f.*
        from filtered f
        order by %I %s nulls last, f.id asc
        limit $8
        offset $9
      )
      select jsonb_build_object(
        'data',
        coalesce(
          (
            select jsonb_agg(
              (
                select jsonb_object_agg(field_name, to_jsonb(p) -> field_name)
                from unnest($7::text[]) as field_name
              )
            )
            from paged p
          ),
          '[]'::jsonb
        ),
        'meta',
        jsonb_build_object(
          'store_id', $10,
          'limit', $8,
          'offset', $9,
          'current_page', (($9 / $8) + 1),
          'sort_by', $11,
          'sort_dir', $12,
          'total', (select count(*) from filtered),
          'can_see_price', $13
        )
      )
    $sql$,
    v_sort_by,
    v_sort_dir
  )
  into v_result
  using
    v_tenant_id,
    v_vendor_code,
    p_search,
    p_category,
    p_brand,
    p_is_available,
    v_selected_fields,
    v_limit,
    v_offset,
    p_store_id,
    v_sort_by,
    v_sort_dir,
    v_can_see_price,
    p_store_id;

  return coalesce(
    v_result,
    jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'store_id', p_store_id,
        'limit', v_limit,
        'offset', v_offset,
        'current_page', ((v_offset / v_limit) + 1),
        'sort_by', v_sort_by,
        'sort_dir', v_sort_dir,
        'total', 0,
        'can_see_price', v_can_see_price
      )
    )
  );
$_$;


ALTER FUNCTION "public"."list_store_products_inventory_aggregated"("p_store_id" bigint, "p_fields" "text"[], "p_search" "text", "p_category" "text", "p_brand" "text", "p_is_available" boolean, "p_sort_by" "text", "p_sort_dir" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_tag_categories"("p_module_key" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_res json;
begin
  select coalesce(json_agg(row_to_json(c)), '[]'::json)
  into v_res
  from (
    select
      tc.id,
      tc.module_key,
      tc.code,
      tc.name,
      tc.cardinality,
      tc.is_system,
      tc.tenant_id,
      tc.sort_order,
      tc.is_active,
      tc.created_at
    from public.tag_categories tc
    where tc.is_active = true
      and (p_module_key is null or tc.module_key = p_module_key)
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      )
    order by tc.sort_order asc nulls last, tc.id asc
  ) c;

  return v_res;
ALTER FUNCTION "public"."list_tag_categories"("p_module_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_tags_for_category"("p_category_id" bigint DEFAULT NULL::bigint, "p_module_key" "text" DEFAULT NULL::"text", "p_code" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_category_id bigint;
  v_res json;
begin
  if p_category_id is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.id = p_category_id
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      );
  elsif p_module_key is not null and p_code is not null then
    select tc.id into v_category_id
    from public.tag_categories tc
    where tc.module_key = p_module_key
      and tc.code = p_code
      and tc.is_active = true
      and (
        tc.is_system = true
        or tc.tenant_id is null
        or public.has_active_tenant_membership(tc.tenant_id)
      )
    order by tc.is_system desc, tc.id asc
    limit 1;
  if v_category_id is null then
    return '[]'::json;
  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  into v_res
  from (
    select
      tg.id,
      tg.category_id,
      tg.slug,
      tg.name,
      tg.color,
      tg.metadata,
      tg.sort_order,
      tg.is_system,
      tg.is_active,
      tg.tenant_id,
      tg.group_name,
      tg.type
    from public.tags tg
    where tg.category_id = v_category_id
      and tg.is_active = true
    order by tg.sort_order asc nulls last, tg.id asc
  ) t;

  return v_res;
ALTER FUNCTION "public"."list_tags_for_category"("p_category_id" bigint, "p_module_key" "text", "p_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_tenant_module_submodules_for_superadmin"("p_tenant_id" bigint, "p_parent_module_key" "text") RETURNS TABLE("id" bigint, "tenant_id" bigint, "parent_module_key" "text", "submodule_key" "text", "is_enabled" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    tms.id,
    tms.tenant_id,
    tms.parent_module_key,
    tms.submodule_key,
    tms.is_enabled,
    tms.created_at,
    tms.updated_at
  from public.tenant_module_submodules tms
  where public.is_superadmin()
    and p_tenant_id is not null
    and tms.tenant_id = p_tenant_id
    and tms.parent_module_key = lower(trim(p_parent_module_key))
  order by tms.submodule_key asc;
ALTER FUNCTION "public"."list_tenant_module_submodules_for_superadmin"("p_tenant_id" bigint, "p_parent_module_key" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_tenant_modules_by_tenant"("p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "module_key" "text", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at
  from public.tenant_modules tm
  where p_tenant_id is not null
    and tm.tenant_id = p_tenant_id
    and public.can_view_tenant_modules(tm.tenant_id)
  order by tm.id asc;
ALTER FUNCTION "public"."list_tenant_modules_by_tenant"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_tenant_role_grants"("p_tenant_role_id" bigint) RETURNS TABLE("id" bigint, "tenant_role_id" bigint, "module_key" "text", "action" "text", "allowed" boolean, "updated_by_email" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tr.tenant_id into v_tenant_id
  from public.tenant_roles tr
  where tr.id = p_tenant_role_id;

  if v_tenant_id is null then
    raise exception 'Role not found';
  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  return query
  select rg.id, rg.tenant_role_id, rg.module_key, rg.action, rg.allowed, rg.updated_by_email, rg.created_at, rg.updated_at
  from public.tenant_role_grants rg
  where rg.tenant_role_id = p_tenant_role_id;
ALTER FUNCTION "public"."list_tenant_role_grants"("p_tenant_role_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_tenant_roles"("p_tenant_id" bigint, "p_scope" "text") RETURNS TABLE("id" bigint, "tenant_id" bigint, "scope" "text", "name" "text", "slug" "text", "is_system" boolean, "is_admin" boolean, "source_app_role" "public"."app_role", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  return query
  select r.id, r.tenant_id, r.scope, r.name, r.slug, r.is_system, r.is_admin, r.source_app_role, r.is_active, r.created_at, r.updated_at
  from public.tenant_roles r
  where r.tenant_id = p_tenant_id
    and r.scope = p_scope
    and r.is_active = true;
ALTER FUNCTION "public"."list_tenant_roles"("p_tenant_id" bigint, "p_scope" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_tenant_viewers"("p_tenant_id" bigint) RETURNS TABLE("membership_id" bigint, "tenant_id" bigint, "name" "text", "email" "text", "role" "public"."app_role", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    m.id as membership_id,
    m.tenant_id,
    m.email as name,
    m.email,
    m.role,
    m.is_active,
    m.created_at,
    m.updated_at
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and exists (
      select 1
      from public.tenants t
      where t.id = p_tenant_id
        and public.can_manage_costing_file_viewers(t.id)
    )
    and m.role = 'viewer'
  order by m.created_at asc, m.id asc;
ALTER FUNCTION "public"."list_tenant_viewers"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_tenants_by_membership"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_email" "text" DEFAULT NULL::"text", "p_role" "public"."app_role" DEFAULT NULL::"public"."app_role") RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text", "is_active" boolean, "parent_id" bigint, "preference" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select distinct
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.parent_id,
    t.preference,
    t.created_at,
    t.updated_at
  from public.tenants t
  inner join public.memberships m
    on m.tenant_id = t.id
  where m.is_active = true
    and (p_tenant_id is null or t.id = p_tenant_id)
    and (
      p_email is null
      or lower(trim(m.email)) = lower(trim(p_email))
    )
    and (p_role is null or m.role = p_role)
  order by t.id asc;
ALTER FUNCTION "public"."list_tenants_by_membership"("p_tenant_id" bigint, "p_email" "text", "p_role" "public"."app_role") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_tenants_for_superadmin"() RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text", "is_active" boolean, "parent_id" bigint, "preference" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_superadmin() then
    return;
  return query
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.parent_id,
    t.preference,
    t.created_at,
    t.updated_at
  from public.tenants t
  order by t.id asc;
ALTER FUNCTION "public"."list_tenants_for_superadmin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_thrift_barcodes_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_search" "text" DEFAULT NULL::"text", "p_is_printed" smallint DEFAULT NULL::smallint, "p_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 50), 1);
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_unprinted_total bigint;
  v_available_total bigint;
  v_printable_total bigint;
  v_latest_current_year text;
  v_current_year text := to_char(now(), 'YY');
begin
  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Not authorized for this tenant';
  select count(*)
  into v_total_count
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and (p_is_printed is null or b.is_printed = p_is_printed)
    and (v_status is null or b.status = v_status)
    and (
      v_search is null
      or coalesce(b.barcode_id, '') ilike '%' || v_search || '%'
      or coalesce(b.inserted_by, '') ilike '%' || v_search || '%'
    );

  select count(*)
  into v_unprinted_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.is_printed = 0;

  select count(*)
  into v_available_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.status = 'AVAILABLE';

  select count(*)
  into v_printable_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.is_printed = 0
    and b.status = 'AVAILABLE';

  select b.barcode_id
  into v_latest_current_year
  from public.thrift_barcodes b
  cross join lateral public.thrift_barcode_sequence_sort_key(b.barcode_id) sk
  where b.tenant_id = p_tenant_id
    and b.barcode_id like '%-' || v_current_year || '-%'
  order by sk.sort_prefix desc, sk.sort_year desc, sk.sort_seq desc, b.barcode_id desc
  limit 1;

  select coalesce(jsonb_agg(row_data order by sort_prefix asc, sort_year asc, sort_seq asc, sort_barcode_id asc), '[]'::jsonb)
  into v_data
  from (
    select
      jsonb_build_object(
        'id', b.id,
        'tenant_id', b.tenant_id,
        'barcode_id', b.barcode_id,
        'status', b.status,
        'is_printed', b.is_printed,
        'inserted_by', b.inserted_by,
        'created_at', b.created_at,
        'updated_at', b.updated_at
      ) as row_data,
      sk.sort_prefix,
      sk.sort_year,
      sk.sort_seq,
      b.barcode_id as sort_barcode_id
    from public.thrift_barcodes b
    cross join lateral public.thrift_barcode_sequence_sort_key(b.barcode_id) sk
    where b.tenant_id = p_tenant_id
      and (p_is_printed is null or b.is_printed = p_is_printed)
      and (v_status is null or b.status = v_status)
      and (
        v_search is null
        or coalesce(b.barcode_id, '') ilike '%' || v_search || '%'
        or coalesce(b.inserted_by, '') ilike '%' || v_search || '%'
      )
    order by sk.sort_prefix asc, sk.sort_year asc, sk.sort_seq asc, b.barcode_id asc
    offset (v_page - 1) * v_page_size
    limit v_page_size
  ) paged;

  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  return jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages,
      'unprinted_total', v_unprinted_total,
      'available_total', v_available_total,
      'printable_total', v_printable_total,
      'latest_current_year_barcode_id', v_latest_current_year
    )
  );
ALTER FUNCTION "public"."list_thrift_barcodes_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_is_printed" smallint, "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_payment_status" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_delivery_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_page INTEGER := greatest(coalesce(p_page, 1), 1);
  v_page_size INTEGER := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_search TEXT := nullif(trim(coalesce(p_search, '')), '');
  v_payment_status TEXT := nullif(upper(trim(coalesce(p_payment_status, ''))), '');
  v_status TEXT := nullif(upper(trim(coalesce(p_status, ''))), '');
  v_delivery_status TEXT := nullif(upper(trim(coalesce(p_delivery_status, ''))), '');
  v_total_count BIGINT;
  v_total_pages INTEGER;
  v_data JSONB;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.tenant_id = p_tenant_id
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'Not authorized for this tenant';
  END IF;

  SELECT count(*)
  INTO v_total_count
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND (
      v_search IS NULL
      OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
      OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
      OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
    )
    AND (v_payment_status IS NULL OR inv.payment_status = v_payment_status)
    AND (v_status IS NULL OR coalesce(inv.status, 'ACTIVE') = v_status)
    AND (
      v_delivery_status IS NULL
      OR inv.delivery_status = v_delivery_status
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      jsonb_build_object(
        'id', inv.id,
        'invoice_number', inv.invoice_number,
        'sale_channel', inv.sale_channel,
        'customer_id', inv.customer_id,
        'customer_name', inv.customer_name,
        'customer_phone', inv.customer_phone,
        'customer_address', inv.customer_address,
        'date', inv.date,
        'payment_method', inv.payment_method,
        'payment_status', inv.payment_status,
        'delivery_status', inv.delivery_status,
        'total_invoice_amount', inv.total_invoice_amount,
        'courier_amount', inv.courier_amount,
        'courier_paid_by', inv.courier_paid_by,
        'cod_expected', inv.cod_expected,
        'cod_remitted_amount', inv.cod_remitted_amount,
        'cod_remitted_at', inv.cod_remitted_at,
        'created_by', inv.created_by,
        'notes', inv.notes,
        'created_at', inv.created_at,
        'status', inv.status,
        'reverted_at', inv.reverted_at,
        'reverted_by', inv.reverted_by,
        'revert_reason', inv.revert_reason,
        'revert_notes', inv.revert_notes,
        'item_count', (
          SELECT count(*)::INT
          FROM public.thrift_sales_invoice_items si
          WHERE si.invoice_id = inv.id
            AND si.tenant_id = inv.tenant_id
        )
      ) AS row_data,
      inv.created_at AS sort_created_at,
      inv.id AS sort_id
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND (
        v_search IS NULL
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
      AND (v_payment_status IS NULL OR inv.payment_status = v_payment_status)
      AND (v_status IS NULL OR coalesce(inv.status, 'ACTIVE') = v_status)
      AND (
        v_delivery_status IS NULL
        OR inv.delivery_status = v_delivery_status
      )
    ORDER BY inv.created_at DESC, inv.id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  ) paged;

  IF v_total_count = 0 THEN
    v_total_pages := 0;
  ELSE
    v_total_pages := ceil(v_total_count::NUMERIC / v_page_size)::INTEGER;
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'page', v_page,
      'total', v_total_count,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
END;
ALTER FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_payment_status" "text", "p_status" "text", "p_delivery_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_date_from" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_date_to" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_invoice_id" bigint DEFAULT NULL::bigint, "p_has_damaged" boolean DEFAULT NULL::boolean, "p_skip_count" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_page INTEGER := greatest(coalesce(p_page, 1), 1);
  v_page_size INTEGER := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_search TEXT := nullif(trim(coalesce(p_search, '')), '');
  v_total_count BIGINT := 0;
  v_total_pages INTEGER := 0;
  v_data JSONB;
  v_skip_count BOOLEAN := COALESCE(p_skip_count, false);
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'view') THEN
    RAISE EXCEPTION 'List thrift sales returns requires thrift_sales view permission';
  END IF;

  IF NOT v_skip_count THEN
    SELECT count(*)
    INTO v_total_count
    FROM public.thrift_sales_returns r
    JOIN public.thrift_sales_invoices inv
      ON inv.id = r.invoice_id
     AND inv.tenant_id = r.tenant_id
    WHERE r.tenant_id = p_tenant_id
      AND (p_invoice_id IS NULL OR r.invoice_id = p_invoice_id)
      AND (p_date_from IS NULL OR r.created_at >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at <= p_date_to)
      AND (
        v_search IS NULL
        OR coalesce(r.return_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
      AND (
        p_has_damaged IS NULL
        OR (
          p_has_damaged = TRUE
          AND EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
        OR (
          p_has_damaged = FALSE
          AND NOT EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
      );
  END IF;

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      jsonb_build_object(
        'id', r.id,
        'return_number', r.return_number,
        'invoice_id', r.invoice_id,
        'invoice_number', inv.invoice_number,
        'customer_name', inv.customer_name,
        'customer_phone', inv.customer_phone,
        'refund_amount', r.refund_amount,
        'return_courier_amount', r.return_courier_amount,
        'status', r.status,
        'notes', r.notes,
        'line_count', (
          SELECT count(*)::INT
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
        ),
        'has_damaged', EXISTS (
          SELECT 1
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
            AND ri.condition = 'DAMAGED'
        ),
        'created_by', r.created_by,
        'created_at', r.created_at
      ) AS row_data,
      r.created_at AS sort_created_at,
      r.id AS sort_id
    FROM public.thrift_sales_returns r
    JOIN public.thrift_sales_invoices inv
      ON inv.id = r.invoice_id
     AND inv.tenant_id = r.tenant_id
    WHERE r.tenant_id = p_tenant_id
      AND (p_invoice_id IS NULL OR r.invoice_id = p_invoice_id)
      AND (p_date_from IS NULL OR r.created_at >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at <= p_date_to)
      AND (
        v_search IS NULL
        OR coalesce(r.return_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
      AND (
        p_has_damaged IS NULL
        OR (
          p_has_damaged = TRUE
          AND EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
        OR (
          p_has_damaged = FALSE
          AND NOT EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
      )
    ORDER BY r.created_at DESC, r.id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  ) paged;

  IF v_skip_count THEN
    v_total_pages := 0;
  ELSIF v_total_count = 0 THEN
    v_total_pages := 0;
  ELSE
    v_total_pages := ceil(v_total_count::NUMERIC / v_page_size)::INTEGER;
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'page', v_page,
      'total', CASE WHEN v_skip_count THEN NULL ELSE v_total_count END,
      'page_size', v_page_size,
      'total_pages', CASE WHEN v_skip_count THEN NULL ELSE v_total_pages END,
      'skip_count', v_skip_count
    )
  );
END;
ALTER FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) IS 'Paginated thrift post-pay returns list for hub + invoice history.';


CREATE OR REPLACE FUNCTION "public"."list_thrift_stocks_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_condition" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 20), 1);
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_condition text := nullif(trim(coalesce(p_condition, '')), '');
begin
  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Not authorized for this tenant';
  with filtered as materialized (
    select s.*
    from public.thrift_stocks s
    where s.tenant_id = p_tenant_id
      and s.deleted_at is null
      and (v_status is null or s.status::text = v_status)
      and (v_condition is null or s.condition::text = v_condition)
      and (
        v_search is null
        or s.name ilike '%' || v_search || '%'
        or s.brand_name ilike '%' || v_search || '%'
        or s.barcode ilike '%' || v_search || '%'
      )
  ),
  counts as (
    select count(*)::bigint as total
    from filtered
  ),
  paged as (
    select s.*
    from filtered s
    order by s.created_at desc
    offset (v_page - 1) * v_page_size
    limit v_page_size
  ),
  rows as (
    select
      jsonb_build_object(
        'id', s.id,
        'tenant_id', s.tenant_id,
        'shipment_id', s.shipment_id,
        'box_id', s.box_id,
        'name', s.name,
        'brand_name', s.brand_name,
        'category_id', s.category_id,
        'type_id', s.type_id,
        'section', s.section,
        'shelf_id', s.shelf_id,
        'color', s.color,
        'size', s.size,
        'condition', s.condition,
        'barcode', s.barcode,
        'stock_type', s.stock_type,
        'quantity', s.quantity,
        'product_weight', s.product_weight,
        'extra_weight', s.extra_weight,
        'status', s.status,
        'note', s.note,
        'origin_unit_price', s.origin_unit_price,
        'extra_origin_unit_price', s.extra_origin_unit_price,
        'additional_charges_cost', s.additional_charges_cost,
        'held_for_name', s.held_for_name,
        'held_for_phone', s.held_for_phone,
        'held_for_phone_normalized', s.held_for_phone_normalized,
        'hold_note', s.hold_note,
        'held_by', s.held_by,
        'held_at', s.held_at,
        'hold_expires_at', s.hold_expires_at,
        'inserted_by', s.inserted_by,
        'created_at', s.created_at,
        'updated_at', s.updated_at,
        'pricing', case
          when p.stock_id is not null then jsonb_build_object(
            'cost_of_goods_sold', p.cost_of_goods_sold,
            'target_price', p.target_price,
            'listed_unit_price', p.listed_unit_price,
            'is_listed_price_manual', p.is_listed_price_manual,
            'markup_rate_override', p.markup_rate_override,
            'extra_expense_cost', p.extra_expense_cost
          )
          else '{}'::jsonb
        end,
        'image_url', img.image_url,
        'drive_file_id', img.drive_file_id,
        'measurements', case
          when m.stock_id is not null then jsonb_build_object(
            'stock_id', m.stock_id,
            'tenant_id', m.tenant_id,
            'bust_in', m.bust_in,
            'waist_in', m.waist_in,
            'hips_in', m.hips_in,
            'length_in', m.length_in,
            'shoulder_width_in', m.shoulder_width_in,
            'sleeve_length_in', m.sleeve_length_in,
            'arm_circumference_in', m.arm_circumference_in,
            'hem_width_in', m.hem_width_in,
            'neck_opening_in', m.neck_opening_in,
            'sleeve_type', m.sleeve_type,
            'neckline', m.neckline,
            'dress_style', m.dress_style,
            'fabric_stretch', m.fabric_stretch,
            'lining', m.lining,
            'closure_type', m.closure_type,
            'measurement_notes', m.measurement_notes
          )
          else null
        end
      ) as row_data,
      s.created_at as sort_created_at
    from paged s
    left join public.thrift_pricings p on p.stock_id = s.id
    left join public.thrift_stock_measurements m on m.stock_id = s.id
    left join lateral (
      select i.image_url, i.drive_file_id
      from public.thrift_stock_images i
      where i.stock_id = s.id
        and i.is_primary = true
      limit 1
    ) img on true
  )
  select
    (select total from counts),
    coalesce(
      (select jsonb_agg(r.row_data order by r.sort_created_at desc) from rows r),
      '[]'::jsonb
    )
  into v_total_count, v_data;

  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  return jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
ALTER FUNCTION "public"."list_thrift_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text", "p_condition" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_units_of_measure"() RETURNS TABLE("code" "text", "name" "text", "unit_type" "text", "symbol" "text", "sort_order" integer)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select u.code, u.name, u.unit_type, u.symbol, u.sort_order
  from public.units_of_measure u
  where u.is_active = true
  order by u.sort_order asc, u.name asc;
ALTER FUNCTION "public"."list_units_of_measure"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_thrift_stock_loss_ledger"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_landed numeric(12, 2);
begin
  if (new.status in ('DAMAGED'::public.thrift_stock_status, 'STOLEN'::public.thrift_stock_status))
     and (old.status is null or old.status <> new.status) then
     
    v_landed := coalesce(public.compute_thrift_landed_unit_cost(new.id), 0.00);

    if v_landed > 0 then
      insert into public.thrift_accounting_ledger (
        tenant_id,
        type,
        source,
        reference_id,
        amount,
        inserted_by,
        note
      )
      values (
        new.tenant_id,
        'LOSS'::public.thrift_ledger_type,
        'SHIPMENT'::public.thrift_ledger_source,
        new.shipment_id,
        v_landed * new.quantity,
        new.inserted_by,
        'Auto-logged loss for stock item status set to ' || new.status || ' (Barcode: ' || coalesce(new.barcode, '') || ')'
      );
    ALTER FUNCTION "public"."log_thrift_stock_loss_ledger"() OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_invoice_id bigint;
  v_item jsonb;
  v_stock_id bigint;
  v_sold_price numeric(12,2);
  v_platform_fees numeric(12,2);
  v_ship_paid_by_shop numeric(12,2);
  v_available_qty integer;
  v_total_ship_paid_by_shop numeric(12,2) := 0.00;
begin
  -- 1. Insert Invoice
  insert into public.thrift_invoices (
    tenant_id,
    invoice_number,
    recipient_name,
    address,
    phone,
    transaction_method,
    cod_charge,
    packing_charge,
    invoice_print_charge,
    shipping_charge_customer,
    inserted_by
  )
  values (
    p_tenant_id,
    p_invoice_number,
    p_recipient_name,
    p_address,
    p_phone,
    p_transaction_method,
    p_cod_charge,
    p_packing_charge,
    p_invoice_print_charge,
    p_shipping_charge_customer,
    p_inserted_by
  )
  returning id into v_invoice_id;

  -- 2. Process items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_stock_id := (v_item->>'stock_id')::bigint;
    v_qty := (v_item->>'quantity')::integer;
    v_sold_price := (v_item->>'sold_price')::numeric;
    v_platform_fees := coalesce((v_item->>'platform_fees')::numeric, 0.00);
    v_ship_paid_by_shop := coalesce((v_item->>'shipping_cost_paid_by_shop')::numeric, 0.00);

    v_total_ship_paid_by_shop := v_total_ship_paid_by_shop + v_ship_paid_by_shop;

    -- Qty validation
    select quantity into v_available_qty
    from public.thrift_stocks
    where id = v_stock_id and tenant_id = p_tenant_id;

    if v_available_qty < v_qty then
      raise exception 'Insufficient stock for stock ID %', v_stock_id;
    -- Add item to invoice
    insert into public.thrift_invoice_items (
      invoice_id,
      stock_id,
      quantity,
      sold_price,
      platform_fees,
      shipping_cost_paid_by_shop,
      item_status
    )
    values (
      v_invoice_id,
      v_stock_id,
      v_qty,
      v_sold_price,
      v_platform_fees,
      v_ship_paid_by_shop,
      'SOLD'::public.thrift_item_status
    );

    -- Deduct stock qty
    update public.thrift_stocks
    set 
      quantity = quantity - v_qty,
      status = case when (quantity - v_qty) = 0 then 'OUT_OF_STOCK'::public.thrift_stock_status else status end,
      updated_at = now()
    where id = v_stock_id;
  -- 3. Log Revenue (accrual basis)
  insert into public.thrift_accounting_ledger (
    tenant_id,
    type,
    source,
    reference_id,
    amount,
    inserted_by,
    note
  )
  select 
    p_tenant_id,
    'REVENUE'::public.thrift_ledger_type,
    'INVOICE'::public.thrift_ledger_source,
    v_invoice_id,
    total_invoice_amount,
    p_inserted_by,
    'Auto-logged revenue from Thrift Invoice #' || invoice_number
  from public.thrift_invoices
  where id = v_invoice_id;

  -- 4. Log Shipping Expense (if applicable)
  if v_total_ship_paid_by_shop > 0 then
    insert into public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      inserted_by,
      note
    )
    values (
      p_tenant_id,
      'EXPENSE'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      v_invoice_id,
      v_total_ship_paid_by_shop,
      p_inserted_by,
      'Auto-logged shipping cost absorbed by shop for Invoice #' || p_invoice_number
    );
  return v_invoice_id;
ALTER FUNCTION "public"."mark_thrift_items_as_sold"("p_tenant_id" bigint, "p_invoice_number" "text", "p_recipient_name" "text", "p_address" "text", "p_phone" "text", "p_transaction_method" "public"."thrift_transaction_method", "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_print_charge" numeric, "p_shipping_charge_customer" numeric, "p_inserted_by" "text", "p_items" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."mark_thrift_items_as_sold"("p_tenant_id" bigint, "p_invoice_number" "text", "p_recipient_name" "text", "p_address" "text", "p_phone" "text", "p_transaction_method" "public"."thrift_transaction_method", "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_print_charge" numeric, "p_shipping_charge_customer" numeric, "p_inserted_by" "text", "p_items" "jsonb") IS 'LEGACY ARCHIVE — execute revoked (P21). Use create_thrift_sales_invoice.';


CREATE OR REPLACE FUNCTION "public"."membership_has_module_action"("p_tenant_id" bigint, "p_module_key" "text", "p_action" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'admin'::public.app_role
        or public.has_module_action(p_tenant_id, p_module_key, p_action)
      )
  );
ALTER FUNCTION "public"."membership_has_module_action"("p_tenant_id" bigint, "p_module_key" "text", "p_action" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."next_tenant_scoped_counter"("p_tenant_id" bigint, "p_scope" "text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_next bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  if p_scope not in ('shipment', 'order') then
    raise exception 'invalid scope: %', p_scope;
  insert into public.tenant_scoped_counters (tenant_id, scope, last_value)
  values (p_tenant_id, p_scope, 1)
  on conflict (tenant_id, scope)
  do update
    set last_value = public.tenant_scoped_counters.last_value + 1
  returning last_value into v_next;

  return v_next;
ALTER FUNCTION "public"."next_tenant_scoped_counter"("p_tenant_id" bigint, "p_scope" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_bd_mobile"("p_phone" "text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $_$
declare
  v text;
begin
  v := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  if left(v, 4) = '8801' then
    v := substring(v from 3);
  elsif left(v, 3) = '880' and length(v) = 13 then
    v := substring(v from 3);
  if v !~ '^01[0-9]{9}$' then
    raise exception 'Invalid BD mobile phone: %', p_phone;
  return v;
$_$;


ALTER FUNCTION "public"."normalize_bd_mobile"("p_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_membership_email"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.email := lower(trim(coalesce(new.email, '')));

  if new.email = '' then
    raise exception 'membership email cannot be empty';
  ALTER FUNCTION "public"."normalize_membership_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    AS $$
  SELECT regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
ALTER FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") IS 'Digits-only thrift customer phone key; empty/null input → empty string.';


CREATE OR REPLACE FUNCTION "public"."parent_tenant_has_module_action"("p_parent_tenant_id" bigint, "p_module_key" "text", "p_action" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.membership_has_module_action(p_parent_tenant_id, p_module_key, p_action);
ALTER FUNCTION "public"."parent_tenant_has_module_action"("p_parent_tenant_id" bigint, "p_module_key" "text", "p_action" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."place_commerce_order"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_shipment_payment" numeric, "p_invoice_print_charge" numeric, "p_wrapping_charge" numeric, "p_cod" numeric, "p_delivery_charge" numeric, "p_is_delivery_charge_inclusive" boolean, "p_items" "jsonb") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order_id bigint;
  v_item jsonb;
  v_batch_id bigint;
begin
  -- 1. Insert Commerce Order
  insert into public.commerce_orders (
    recipient_name,
    recipient_phone,
    shipping_address,
    shipment_payment,
    invoice_print_charge,
    wrapping_charge,
    cod,
    tenant_id,
    customer_group_id,
    order_placement_date,
    delivery_charge,
    is_delivery_charge_inclusive,
    status
  )
  values (
    p_recipient_name,
    p_recipient_phone,
    p_shipping_address,
    p_shipment_payment,
    p_invoice_print_charge,
    p_wrapping_charge,
    p_cod,
    p_tenant_id,
    p_customer_group_id,
    now(),
    p_delivery_charge,
    p_is_delivery_charge_inclusive,
    'placed'::public.commerce_order_status
  )
  returning id into v_order_id;

  -- 2. Insert Order Items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_batch_id := (v_item->>'product_id')::bigint; -- product_id in payload represents the inventory_item_id

    -- Resolve the actual parent product ID from the inventory batch
    select product_id into v_product_id
    from public.inventory_items
    where id = v_batch_id;

    insert into public.commerce_order_items (
      order_id,
      product_id,
      image_url,
      cost_bdt,
      sell_price_bdt,
      recipient_price_bdt,
      quantity,
      phone_invite_id,
      inventory_item_id
    )
    values (
      v_order_id,
      v_product_id,
      v_item->>'image_url',
      (v_item->>'cost_bdt')::numeric,
      (v_item->>'sell_price_bdt')::numeric,
      (v_item->>'recipient_price_bdt')::numeric,
      (v_item->>'quantity')::integer,
      v_item->>'phone_invite_id',
      v_batch_id
    );

    -- 3. Delete from commerce_cart
    delete from public.commerce_cart
    where tenant_id = p_tenant_id
      and customer_group_id = p_customer_group_id
      and inventory_item_id = v_batch_id;
  return v_order_id;
ALTER FUNCTION "public"."place_commerce_order"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_shipment_payment" numeric, "p_invoice_print_charge" numeric, "p_wrapping_charge" numeric, "p_cod" numeric, "p_delivery_charge" numeric, "p_is_delivery_charge_inclusive" boolean, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."place_koba_order"("p_tenant_id" bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_shipping_name" "text" DEFAULT NULL::"text", "p_shipping_phone" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_shipping_address" "text" DEFAULT NULL::"text", "p_free_delivery" boolean DEFAULT false, "p_extra_profit_user" numeric DEFAULT 0, "p_extra_profit_company" numeric DEFAULT 0, "p_delivery_adjustment" numeric DEFAULT 0, "p_cod_charge" numeric DEFAULT 0, "p_packing_charge" numeric DEFAULT 0, "p_invoice_charge" numeric DEFAULT 0, "p_net_order_commission" numeric DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cart_id bigint;
  v_order_id bigint;
  v_commission numeric(12,2) := 0;
  v_count integer := 0;
  v_gateway_charge numeric(12,2) := 20.00;
begin
  if not public.koba_context_access_allowed(p_tenant_id, p_customer_group_id) then
    raise exception 'not allowed';
  select id into v_cart_id
  from public.koba_carts
  where tenant_id = p_tenant_id
    and customer_group_id is not distinct from p_customer_group_id
  limit 1;

  if v_cart_id is null then
    raise exception 'no cart found for this customer group';
  select count(*) into v_count
  from public.koba_cart_items
  where cart_id = v_cart_id;

  if v_count = 0 then
    raise exception 'cart is empty';
  -- Fetch gateway charge from settings for this tenant
  select coalesce(gateway_charge_flat, 20.00) into v_gateway_charge
  from public.koba_retail_settings
  where tenant_id = p_tenant_id
  limit 1;

  if v_gateway_charge is null then
    v_gateway_charge := 20.00;
  -- Calculate totals: subtotal and total_commission (deducting gateway charge per unit)
  select
    coalesce(sum(coalesce(custom_price_gbp, unit_price_gbp, 0) * quantity), 0),
    coalesce(sum(greatest(0, coalesce(commission, 0) - v_gateway_charge) * quantity), 0),
    count(*)
  into v_subtotal, v_commission, v_count
  from public.koba_cart_items
  where cart_id = v_cart_id;

  insert into public.koba_orders (
    tenant_id,
    customer_group_id,
    shipping_name,
    shipping_phone,
    shipping_district,
    shipping_thana,
    shipping_address,
    free_delivery,
    subtotal_gbp,
    total_commission,
    item_count,
    status,
    extra_profit_user,
    extra_profit_company,
    delivery_adjustment,
    cod_charge,
    packing_charge,
    invoice_charge,
    net_order_commission
  ) values (
    p_tenant_id,
    p_customer_group_id,
    p_shipping_name,
    p_shipping_phone,
    p_shipping_district,
    p_shipping_thana,
    p_shipping_address,
    p_free_delivery,
    v_subtotal,
    v_commission,
    v_count,
    'pending',
    p_extra_profit_user,
    p_extra_profit_company,
    p_delivery_adjustment,
    p_cod_charge,
    p_packing_charge,
    p_invoice_charge,
    p_net_order_commission
  )
  returning id into v_order_id;

  insert into public.koba_order_items (
    order_id,
    product_id,
    product_code,
    barcode,
    name,
    brand,
    image_url,
    case_size,
    unit_price_gbp,
    custom_price_gbp,
    commission,
    commission_percentage,
    quantity
  )
  select
    v_order_id,
    product_id,
    product_code,
    barcode,
    name,
    brand,
    image_url,
    case_size,
    unit_price_gbp,
    custom_price_gbp,
    commission,
    commission_percentage,
    quantity
  from public.koba_cart_items
  where cart_id = v_cart_id;

  delete from public.koba_cart_items
  where cart_id = v_cart_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'customer_group_id', p_customer_group_id,
    'item_count', v_count,
    'subtotal_gbp', v_subtotal,
    'total_commission', v_commission,
    'status', 'pending'
  );
ALTER FUNCTION "public"."place_koba_order"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_shipping_name" "text", "p_shipping_phone" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_shipping_address" "text", "p_free_delivery" boolean, "p_extra_profit_user" numeric, "p_extra_profit_company" numeric, "p_delivery_adjustment" numeric, "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_charge" numeric, "p_net_order_commission" numeric) OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cycle_exists boolean;
begin
  if new.parent_id is null then
    return new;
  if new.id is not null and new.parent_id = new.id then
    raise exception 'An item cannot be its own parent.'
      using errcode = '23514';
  with recursive descendants as (
    select i.id, i.parent_id
    from public.items i
    where i.id = new.id
    union all
    select child.id, child.parent_id
    from public.items child
    join descendants d on child.parent_id = d.id
  )
  select exists (
    select 1
    from descendants
    where id = new.parent_id
  ) into v_cycle_exists;

  if v_cycle_exists then
    raise exception 'Invalid parent relationship: a parent cannot be assigned to one of its descendants.'
      using errcode = '23514';
  ALTER FUNCTION "public"."prevent_item_parent_cycles"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_system_global_currency_mutation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System currencies cannot be deleted.';
    return old;
  if tg_op = 'UPDATE' and old.is_system and (
    row(new.name, new.country, new.code, new.symbol, new.is_active, new.is_system)
    is distinct from
    row(old.name, old.country, old.code, old.symbol, old.is_active, old.is_system)
  ) then
    raise exception 'System currencies cannot be edited.';
  ALTER FUNCTION "public"."prevent_system_global_currency_mutation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_system_market_mutation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System markets cannot be deleted.';
    return old;
  if tg_op = 'UPDATE' then
    if old.is_system and (
      row(new.name, new.code, new.is_active, new.is_system, new.region)
      is distinct from
      row(old.name, old.code, old.is_active, old.is_system, old.region)
    ) then
      raise exception 'System markets cannot be edited.';
    ALTER FUNCTION "public"."prevent_system_market_mutation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_system_payment_method_mutation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System payment methods cannot be deleted.';
    return old;
  if tg_op = 'UPDATE' and old.is_system and (
    row(new.code, new.name, new.category, new.scope, new.sort_order, new.is_active, new.is_system)
    is distinct from
    row(old.code, old.name, old.category, old.scope, old.sort_order, old.is_active, old.is_system)
  ) then
    raise exception 'System payment methods cannot be edited.';
  ALTER FUNCTION "public"."prevent_system_payment_method_mutation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_system_unit_of_measure_mutation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System units of measure cannot be deleted.';
    return old;
  if tg_op = 'UPDATE' and old.is_system and (
    row(new.code, new.name, new.unit_type, new.symbol, new.sort_order, new.is_active, new.is_system)
    is distinct from
    row(old.code, old.name, old.unit_type, old.symbol, old.sort_order, old.is_active, old.is_system)
  ) then
    raise exception 'System units of measure cannot be edited.';
  ALTER FUNCTION "public"."prevent_system_unit_of_measure_mutation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_courier_bulk_remittance_batch"("p_batch_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_batch record;
  v_order record;
  v_processed_count integer := 0;
  v_error_count integer := 0;
  v_net_remitted numeric(12,2);
  v_total_allocated numeric(12,2) := 0.00;
begin
  -- Lock batch record
  select * into v_batch
  from public.courier_remittance_batches
  where id = p_batch_id for update;

  if v_batch.id is null then
    raise exception 'Remittance batch #% not found', p_batch_id;
  if v_batch.status <> 'draft' then
    raise exception 'Batch #% is already %', v_batch.batch_no, v_batch.status;
  -- Permission check
  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_batch.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required for tenant %', v_batch.tenant_id;
  -- Process line items sequentially
  for v_item in
    select * from public.courier_remittance_items
    where batch_id = p_batch_id
    for update
  loop
    v_net_remitted := v_item.net_remitted_amount;

    -- Validate order
    if v_item.shop_order_id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Missing linked order'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    select * into v_order from public.shop_orders
    where id = v_item.shop_order_id for update;

    if v_order.id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Shop order record not found'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    if v_order.status <> 'delivered' then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Order is not in delivered status (current: ' || v_order.status || ')'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    if v_order.global_invoice_id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Missing accounting global invoice'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    -- Lock & validate global invoice
    select * into v_invoice from public.global_invoices
    where id = v_order.global_invoice_id for update;

    if v_invoice.id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Global invoice not found'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    -- Create global payment record
    insert into public.global_payments (
      tenant_id,
      billing_profile_id,
      collection_source,
      amount,
      unallocated_amount,
      payment_date,
      method,
      reference,
      note
    )
    values (
      v_batch.tenant_id,
      v_invoice.billing_profile_id,
      v_invoice.collection_source,
      v_net_remitted,
      0.00,
      coalesce(v_batch.payment_date, current_date),
      'bank_transfer',
      v_batch.batch_no,
      'Courier remittance batch #' || v_batch.batch_no || ' order #' || v_order.order_no
    )
    returning id into v_payment_id;

    -- Insert invoice payment allocation
    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_batch.tenant_id, v_payment_id, v_order.global_invoice_id, v_net_remitted);

    -- Update invoice paid amount
    update public.global_invoices
    set
      paid_amount = coalesce(paid_amount, 0.00) + v_net_remitted,
      updated_at = now()
    where id = v_order.global_invoice_id;

    -- Recompute payment status
    perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

    -- Update order status to payment_received & stamp references
    update public.shop_orders
    set
      status = 'payment_received'::public.shop_order_status,
      courier_remittance_ref = v_batch.batch_no,
      courier_bank_trx_id = coalesce(v_batch.bank_trx_id, courier_bank_trx_id),
      updated_at = now()
    where id = v_order.id;

    -- Mark item as processed
    update public.courier_remittance_items
    set
      status = 'processed',
      error_message = null,
      global_invoice_id = v_order.global_invoice_id
    where id = v_item.id;

    v_processed_count := v_processed_count + 1;
    v_total_allocated := v_total_allocated + v_net_remitted;
  -- Mark batch header as posted if no fatal block
  update public.courier_remittance_batches
  set
    status = 'posted',
    allocated_amount = v_total_allocated,
    variance_amount = net_deposited_amount - v_total_allocated,
    posted_at = now(),
    posted_by = auth.uid(),
    updated_at = now()
  where id = p_batch_id;

  return jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'processed_count', v_processed_count,
    'error_count', v_error_count,
    'allocated_amount', v_total_allocated,
    'status', 'posted'
  );
ALTER FUNCTION "public"."process_courier_bulk_remittance_batch"("p_batch_id" bigint) OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net_remitted numeric(12,2) := 0.00;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id for update;

  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  if v_order.status <> 'delivered' then
    raise exception 'Order #% cannot be remitted because current status is "%" (must be "delivered")', v_order.order_no, v_order.status;
  -- Permission check
  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required for tenant %', v_order.tenant_id;
  -- Ensure global invoice exists or create it
  if v_order.global_invoice_id is null then
    perform public.create_dual_invoice_from_dropship_order(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.global_invoice_id is null then
    raise exception 'Failed to resolve accounting invoice for order #%', v_order.order_no;
  select * into v_invoice
  from public.global_invoices
  where id = v_order.global_invoice_id for update;

  v_cod := coalesce(v_order.cod_collect_amount, v_invoice.total_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_net_remitted := greatest(v_cod - v_charge, 0.00);

  -- Record global payment with valid 'bank' method
  insert into public.global_payments (
    tenant_id,
    billing_profile_id,
    collection_source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    v_order.tenant_id,
    v_invoice.billing_profile_id,
    coalesce(v_invoice.collection_source, 'recipient'),
    v_net_remitted,
    0.00,
    current_date,
    'bank',
    coalesce(v_order.courier_awb_number, v_order.order_no),
    'Single-order inline remittance for order #' || v_order.order_no
  )
  returning id into v_payment_id;

  -- Allocate invoice payment
  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (v_order.tenant_id, v_payment_id, v_order.global_invoice_id, v_net_remitted);

  -- Update global invoice paid amount & status
  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0.00) + v_net_remitted,
    updated_at = now()
  where id = v_order.global_invoice_id;

  perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

  -- Update shop order status to payment_received
  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = coalesce(courier_remittance_ref, 'SINGLE-REMIT-' || v_order.order_no),
    updated_at = now()
  where id = v_order.id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'payment_received',
    'net_remitted', v_net_remitted
  );
ALTER FUNCTION "public"."reconcile_single_order_remittance"("p_order_id" bigint, "p_courier_charge" numeric) OWNER TO "postgres";


    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "investor_id" bigint NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "method" "public"."investor_payment_method" NOT NULL,
    "type" "public"."investor_transaction_type" NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "investor_transactions_amount_check" CHECK (("amount" > (0)::numeric))
);


ALTER TABLE "public"."investor_transactions" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_investor_capital_adjustment"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") RETURNS "public"."investor_transactions"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.investor_transactions;
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'edit') then
    raise exception 'not allowed';
  insert into public.investor_transactions (
    tenant_id, investor_id, amount, date, method, type, note
  ) values (
    p_tenant_id, p_investor_id, p_amount, p_date, p_method, 'capital_adjustment'::public.investor_transaction_type, p_note
  )
  returning * into v_row;

  ALTER FUNCTION "public"."record_investor_capital_adjustment"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_investor_capital_in"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") RETURNS "public"."investor_transactions"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.investor_transactions;
begin
  if not public.user_can_manage_parent_tenant(p_tenant_id) then
    raise exception 'not allowed';
  insert into public.investor_transactions (
    tenant_id, investor_id, amount, date, method, type, note
  ) values (
    p_tenant_id, p_investor_id, p_amount, p_date, p_method, 'capital_in'::public.investor_transaction_type, p_note
  )
  returning * into v_row;

  -- 1. Credit Tenant Cash Available (money received into platform)
  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'adjustment',
    p_source_id => v_row.id::text,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'capital_in_tenant_cash',
      'transaction_type', 'capital_in',
      'label', 'Capital In Deposit',
      'investor_id', p_investor_id,
      'notes', p_note
    )
  );

  -- 2. Credit Investor Available (capital liability owed to investor)
  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'investor',
    p_entity_id => p_investor_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'adjustment',
    p_source_id => v_row.id::text,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'capital_in_investor_liability',
      'transaction_type', 'capital_in',
      'label', 'Capital Injected',
      'notes', p_note
    )
  );

  ALTER FUNCTION "public"."record_investor_capital_in"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_investor_withdrawal_paid"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") RETURNS "public"."investor_transactions"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.investor_transactions;
begin
  if not public.user_can_manage_parent_tenant(p_tenant_id) then
    raise exception 'not allowed';
  insert into public.investor_transactions (
    tenant_id, investor_id, amount, date, method, type, note
  ) values (
    p_tenant_id, p_investor_id, p_amount, p_date, p_method, 'withdrawal_paid'::public.investor_transaction_type, p_note
  )
  returning * into v_row;

  -- 1. Debit Investor Available (reduces capital liability)
  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'investor',
    p_entity_id => p_investor_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_row.id::text,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'investor_withdrawal_debit',
      'transaction_type', 'withdrawal_paid',
      'label', 'Capital Withdrawal Paid',
      'notes', p_note
    )
  );

  -- 2. Debit Tenant Cash (cash outflow from platform)
  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_row.id::text,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'tenant_investor_cash_outflow',
      'transaction_type', 'withdrawal_paid',
      'label', 'Investor Withdrawal Outflow',
      'investor_id', p_investor_id,
      'notes', p_note
    )
  );

  ALTER FUNCTION "public"."record_investor_withdrawal_paid"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_ledger_transaction"(
  p_parent_tenant_id bigint,
  p_operating_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_type text,
  p_amount numeric,
  p_currency_code text DEFAULT 'BDT',
  p_exchange_rate numeric DEFAULT 1.000000,
  p_source_type text DEFAULT 'adjustment',
  p_source_id text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_target_bucket text DEFAULT 'available',
  p_allow_overdraft boolean DEFAULT false
)
RETURNS jsonb
    LANGUAGE "plpgsql"
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_base_amount numeric(18,4);
  v_new_balance numeric(18,4);
  v_ledger_entry jsonb;
  v_ledger_id uuid;
  v_entity_id bigint;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transaction amount must be greater than zero.';
  END IF;

  IF p_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Transaction type must be credit or debit.';
  END IF;

  IF p_target_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Target bucket must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' AND v_entity_id IS DISTINCT FROM p_parent_tenant_id THEN
    v_entity_id := p_parent_tenant_id;
  END IF;

  INSERT INTO public.wallet_accounts (
    tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    p_parent_tenant_id, p_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (parent_tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.wallet_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      IF v_avail < p_amount AND NOT coalesce(p_allow_overdraft, false) THEN
        RAISE EXCEPTION 'Insufficient available balance (Available: %, Requested debit: %).', v_avail, p_amount;
      END IF;
      v_avail := v_avail - p_amount;
    END IF;
    v_new_balance := v_avail;
  ELSIF p_target_bucket = 'pending' THEN
    IF p_type = 'credit' THEN
      v_pend := v_pend + p_amount;
    ELSE
      v_pend := v_pend - p_amount;
    END IF;
    v_new_balance := v_pend;
  ELSIF p_target_bucket = 'locked' THEN
    IF p_type = 'credit' THEN
      v_lock := v_lock + p_amount;
    ELSE
      v_lock := v_lock - p_amount;
    END IF;
    v_new_balance := v_lock;
  END IF;

  UPDATE public.wallet_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = p_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  v_base_amount := p_amount * coalesce(p_exchange_rate, 1.000000);

  INSERT INTO public.universal_wallet_ledger (
    tenant_id,
    parent_tenant_id,
    operating_tenant_id,
    entity_type,
    entity_id,
    type,
    amount,
    currency_code,
    exchange_rate,
    base_amount,
    balance_after,
    source_type,
    source_id,
    metadata
  )
  VALUES (
    p_parent_tenant_id,
    p_parent_tenant_id,
    p_operating_tenant_id,
    p_entity_type,
    v_entity_id,
    p_type,
    p_amount,
    coalesce(p_currency_code, 'BDT'),
    coalesce(p_exchange_rate, 1.000000),
    v_base_amount,
    v_new_balance,
    coalesce(p_source_type, 'adjustment'),
    p_source_id,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('target_bucket', p_target_bucket)
  )
  RETURNING id INTO v_ledger_id;

  SELECT jsonb_build_object(
    'id', id,
    'parent_tenant_id', parent_tenant_id,
    'operating_tenant_id', operating_tenant_id,
    'tenant_id', parent_tenant_id,
    'entity_type', entity_type,
    'entity_id', entity_id,
    'type', type,
    'amount', amount,
    'currency_code', currency_code,
    'exchange_rate', exchange_rate,
    'base_amount', base_amount,
    'balance_after', balance_after,
    'source_type', source_type,
    'source_id', source_id,
    'metadata', metadata,
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.universal_wallet_ledger
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;
ALTER FUNCTION "public"."record_ledger_transaction"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text", "p_exchange_rate" numeric, "p_source_type" "text", "p_source_id" "text", "p_metadata" "jsonb", "p_target_bucket" "text", "p_allow_overdraft" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone DEFAULT "now"(), "p_remittance_ref" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text", "p_outcome" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_remitted NUMERIC(12,2);
  v_outcome TEXT;
  v_payment_status TEXT;
  v_notes TEXT;
BEGIN
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'edit')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
  ) THEN
    RAISE EXCEPTION 'Recording COD remittance requires thrift_sales edit or create permission';
  END IF;

  v_remitted := ROUND(COALESCE(p_remitted_amount, 0.00), 2);
  IF v_remitted < 0 THEN
    RAISE EXCEPTION 'Remitted amount cannot be negative';
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF upper(trim(COALESCE(v_invoice.sale_channel, ''))) IS DISTINCT FROM 'ONLINE' THEN
    RAISE EXCEPTION
      'Invoice % sale_channel is % — remittance only allowed on ONLINE invoices',
      p_invoice_id,
      v_invoice.sale_channel;
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Invoice % is % — remittance only allowed on ACTIVE invoices', p_invoice_id, v_invoice.status;
  END IF;

  IF v_invoice.payment_status IS DISTINCT FROM 'COD_PENDING' THEN
    RAISE EXCEPTION
      'Invoice % payment_status is % — remittance only allowed when COD_PENDING',
      p_invoice_id,
      v_invoice.payment_status;
  END IF;

  v_outcome := upper(trim(COALESCE(p_outcome, '')));
  IF v_outcome = '' THEN
    IF v_invoice.cod_expected IS NULL OR v_remitted >= v_invoice.cod_expected THEN
      v_outcome := 'PAID';
    ELSE
      v_outcome := 'KEEP_PENDING';
    END IF;
  END IF;

  IF v_outcome NOT IN ('PAID', 'KEEP_PENDING', 'WRITTEN_OFF') THEN
    RAISE EXCEPTION 'Invalid outcome % (expected PAID, KEEP_PENDING, or WRITTEN_OFF)', p_outcome;
  END IF;

  IF v_outcome = 'WRITTEN_OFF' AND NULLIF(trim(COALESCE(p_notes, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Notes are required when writing off COD remittance';
  END IF;

  IF v_outcome = 'PAID' THEN
    v_payment_status := 'PAID';
  ELSIF v_outcome = 'WRITTEN_OFF' THEN
    v_payment_status := 'WRITTEN_OFF';
  ELSE
    v_payment_status := 'COD_PENDING';
  END IF;

  v_notes := v_invoice.notes;
  IF NULLIF(trim(p_notes), '') IS NOT NULL THEN
    v_notes := CASE
      WHEN NULLIF(trim(v_notes), '') IS NULL THEN trim(p_notes)
      ELSE trim(v_notes) || E'\n' || trim(p_notes)
    END;
  END IF;

  UPDATE public.thrift_sales_invoices
  SET
    cod_remitted_amount = v_remitted,
    cod_remitted_at = COALESCE(p_remitted_at, NOW()),
    cod_remittance_ref = COALESCE(NULLIF(trim(p_remittance_ref), ''), cod_remittance_ref),
    payment_status = v_payment_status,
    notes = v_notes,
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'invoice_id', p_invoice_id,
    'payment_status', v_payment_status,
    'cod_expected', v_invoice.cod_expected,
    'cod_remitted_amount', v_remitted,
    'outcome', v_outcome
  );
END;
ALTER FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone, "p_remittance_ref" "text", "p_notes" "text", "p_outcome" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone, "p_remittance_ref" "text", "p_notes" "text", "p_outcome" "text") IS 'Record Online COD cash on invoice. Outcomes PAID/KEEP_PENDING/WRITTEN_OFF. No ledger/PnL. WRITTEN_OFF requires notes.';


CREATE OR REPLACE FUNCTION "public"."refresh_commerce_inventory_product_summaries"("p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row record;
begin
  for v_row in
    select distinct ii.tenant_id, ii.product_id
    from public.inventory_items ii
    where ii.product_id is not null
      and (p_tenant_id is null or ii.tenant_id = p_tenant_id)
  loop
    perform public.refresh_commerce_inventory_product_summary_single(v_row.tenant_id, v_row.product_id);
  ALTER FUNCTION "public"."refresh_commerce_inventory_product_summaries"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_commerce_inventory_product_summary_single"("p_tenant_id" bigint, "p_product_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_available integer := 0;
  v_reserved integer := 0;
  v_damaged integer := 0;
  v_stolen integer := 0;
  v_expired integer := 0;
  v_open_box integer := 0;
  v_usable integer := 0;
  v_exists boolean := false;
begin
  if p_tenant_id is null or p_product_id is null then
    return;
  select
    count(*) > 0,
    coalesce(sum(coalesce(st.available_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.reserved_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.damaged_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.stolen_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.expired_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.open_box_quantity, 0)), 0)::int,
    coalesce(
      sum(
        greatest(
          0,
          coalesce(st.available_quantity, 0)
          - coalesce(st.reserved_quantity, 0)
          - coalesce(st.damaged_quantity, 0)
          - coalesce(st.stolen_quantity, 0)
        )
      ),
      0
    )::int
  into
    v_exists,
    v_available,
    v_reserved,
    v_damaged,
    v_stolen,
    v_expired,
    v_open_box,
    v_usable
  from public.inventory_items ii
  left join public.inventory_stocks st
    on st.inventory_item_id = ii.id
  where ii.tenant_id = p_tenant_id
    and ii.product_id = p_product_id
    and ii.status = 'active';

  if not v_exists then
    delete from public.commerce_inventory_product_summaries
    where tenant_id = p_tenant_id
      and product_id = p_product_id;
    return;
  insert into public.commerce_inventory_product_summaries (
    tenant_id,
    product_id,
    available_quantity,
    reserved_quantity,
    damaged_quantity,
    stolen_quantity,
    expired_quantity,
    open_box_quantity,
    usable_quantity,
    updated_at
  )
  values (
    p_tenant_id,
    p_product_id,
    v_available,
    v_reserved,
    v_damaged,
    v_stolen,
    v_expired,
    v_open_box,
    v_usable,
    now()
  )
  on conflict (tenant_id, product_id)
  do update set
    available_quantity = excluded.available_quantity,
    reserved_quantity = excluded.reserved_quantity,
    damaged_quantity = excluded.damaged_quantity,
    stolen_quantity = excluded.stolen_quantity,
    expired_quantity = excluded.expired_quantity,
    open_box_quantity = excluded.open_box_quantity,
    usable_quantity = excluded.usable_quantity,
    updated_at = now();
ALTER FUNCTION "public"."refresh_commerce_inventory_product_summary_single"("p_tenant_id" bigint, "p_product_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_investor_balance"("p_tenant_id" bigint, "p_investor_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_total_deposit numeric(12,2);
  v_total_withdrawal numeric(12,2);
  v_total_profit_payout numeric(12,2);
  v_total_invested_active numeric(12,2);
begin
  select coalesce(sum(it.amount), 0)
  into v_total_deposit
  from public.investor_transactions it
  where it.tenant_id = p_tenant_id
    and it.investor_id = p_investor_id
    and it.type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment');

  select coalesce(sum(it.amount), 0)
  into v_total_withdrawal
  from public.investor_transactions it
  where it.tenant_id = p_tenant_id
    and it.investor_id = p_investor_id
    and it.type in ('withdrawal', 'withdrawal_paid');

  select coalesce(sum(it.amount), 0)
  into v_total_profit_payout
  from public.investor_transactions it
  where it.tenant_id = p_tenant_id
    and it.investor_id = p_investor_id
    and it.type in ('profit_payout', 'profit_reinvest');

  select coalesce(sum(coalesce(si.allocated_cost, si.invested_amount)), 0)
  into v_total_invested_active
  from public.shipment_investments si
  where si.tenant_id = p_tenant_id
    and si.investor_id = p_investor_id
    and si.status = 'active';

  insert into public.investor_balances (
    tenant_id,
    investor_id,
    total_deposit,
    total_withdrawal,
    total_profit_payout,
    total_invested_active,
    available_balance
  )
  values (
    p_tenant_id,
    p_investor_id,
    v_total_deposit,
    v_total_withdrawal,
    v_total_profit_payout,
    v_total_invested_active,
    (v_total_deposit - v_total_withdrawal - v_total_invested_active)
  )
  on conflict (tenant_id, investor_id)
  do update set
    total_deposit = excluded.total_deposit,
    total_withdrawal = excluded.total_withdrawal,
    total_profit_payout = excluded.total_profit_payout,
    total_invested_active = excluded.total_invested_active,
    available_balance = excluded.available_balance,
    updated_at = now();
ALTER FUNCTION "public"."refresh_investor_balance"("p_tenant_id" bigint, "p_investor_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text" DEFAULT NULL::"text", "p_category_id" bigint DEFAULT NULL::bigint, "p_type_id" bigint DEFAULT NULL::bigint, "p_section" "text" DEFAULT NULL::"text", "p_shelf_id" bigint DEFAULT NULL::bigint, "p_color" "text" DEFAULT NULL::"text", "p_size" "text" DEFAULT NULL::"text", "p_condition" "text" DEFAULT NULL::"text", "p_box_id" bigint DEFAULT NULL::bigint, "p_product_weight" numeric DEFAULT NULL::numeric, "p_extra_weight" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text", "p_origin_purchase_price" numeric DEFAULT NULL::numeric, "p_extra_origin_purchase_expense" numeric DEFAULT NULL::numeric, "p_cost_of_goods_sold" numeric DEFAULT 0, "p_target_price" numeric DEFAULT 0, "p_listed_price" numeric DEFAULT 0, "p_extra_expense_cost" numeric DEFAULT 0, "p_inserted_by" "text" DEFAULT 'app-user'::"text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_barcode_row public.thrift_barcodes%rowtype;
  v_stock_id bigint;
  v_section public.thrift_section;
  v_condition public.thrift_condition;
  v_canonical_barcode text;
begin
  if trim(coalesce(p_barcode, '')) = '' then
    raise exception 'Barcode is required';
  if trim(coalesce(p_image_url, '')) = '' then
    raise exception 'Image URL is required';
  v_section := nullif(trim(coalesce(p_section, '')), '')::public.thrift_section;
  v_condition := nullif(trim(coalesce(p_condition, '')), '')::public.thrift_condition;

  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  ) then
    raise exception 'Not authorized for this tenant';
  v_canonical_barcode := public.resolve_thrift_barcode_id_internal(p_tenant_id, p_barcode);
  if v_canonical_barcode is null then
    raise exception 'Barcode not found in catalog';
  select *
  into v_barcode_row
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id = v_canonical_barcode
  for update;

  if not found then
    raise exception 'Barcode not found in catalog';
  select id
  into v_stock_id
  from public.thrift_stocks
  where tenant_id = p_tenant_id
    and barcode = v_canonical_barcode
  limit 1;

  if v_stock_id is null then
    if v_barcode_row.status <> 'AVAILABLE' then
      raise exception 'Barcode is already used';
    insert into public.thrift_stocks (
      tenant_id,
      shipment_id,
      brand_name,
      category_id,
      type_id,
      section,
      shelf_id,
      color,
      size,
      condition,
      barcode,
      stock_type,
      quantity,
      box_id,
      product_weight,
      extra_weight,
      status,
      note,
      inserted_by,
      origin_purchase_price,
      extra_origin_purchase_expense
    )
    values (
      p_tenant_id,
      p_shipment_id,
      nullif(trim(coalesce(p_brand_name, '')), ''),
      p_category_id,
      p_type_id,
      v_section,
      p_shelf_id,
      nullif(trim(coalesce(p_color, '')), ''),
      nullif(trim(coalesce(p_size, '')), ''),
      v_condition,
      v_canonical_barcode,
      'SINGLE',
      1,
      p_box_id,
      p_product_weight,
      p_extra_weight,
      'AVAILABLE',
      coalesce(p_note, ''),
      p_inserted_by,
      p_origin_purchase_price,
      p_extra_origin_purchase_expense
    )
    returning id into v_stock_id;
  else
    update public.thrift_stocks
    set
      shipment_id = p_shipment_id,
      brand_name = nullif(trim(coalesce(p_brand_name, '')), ''),
      category_id = p_category_id,
      type_id = p_type_id,
      section = v_section,
      shelf_id = p_shelf_id,
      color = nullif(trim(coalesce(p_color, '')), ''),
      size = nullif(trim(coalesce(p_size, '')), ''),
      condition = v_condition,
      box_id = p_box_id,
      product_weight = p_product_weight,
      extra_weight = p_extra_weight,
      note = coalesce(p_note, ''),
      origin_purchase_price = p_origin_purchase_price,
      extra_origin_purchase_expense = p_extra_origin_purchase_expense,
      inserted_by = p_inserted_by
    where id = v_stock_id;
  insert into public.thrift_pricings (
    stock_id,
    cost_of_goods_sold,
    target_price,
    listed_price,
    extra_expense_cost,
    inserted_by
  )
  values (
    v_stock_id,
    coalesce(p_cost_of_goods_sold, 0),
    coalesce(p_target_price, 0),
    coalesce(p_listed_price, 0),
    coalesce(p_extra_expense_cost, 0),
    p_inserted_by
  )
  on conflict (stock_id) do update
  set
    cost_of_goods_sold = excluded.cost_of_goods_sold,
    target_price = excluded.target_price,
    listed_price = excluded.listed_price,
    extra_expense_cost = excluded.extra_expense_cost,
    inserted_by = excluded.inserted_by;

  update public.thrift_stock_images
  set image_url = p_image_url,
      inserted_by = p_inserted_by
  where stock_id = v_stock_id
    and is_primary = true;

  if not found then
    insert into public.thrift_stock_images (
      stock_id,
      image_url,
      is_primary,
      inserted_by
    )
    values (
      v_stock_id,
      p_image_url,
      true,
      p_inserted_by
    );
  update public.thrift_barcodes
  set status = 'USED'
  where tenant_id = p_tenant_id
    and barcode_id = v_canonical_barcode;

  return v_stock_id;
ALTER FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_extra_origin_purchase_expense" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_extra_expense_cost" numeric, "p_inserted_by" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint DEFAULT NULL::bigint, "p_product_weight" numeric DEFAULT NULL::numeric, "p_extra_weight" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text", "p_origin_purchase_price" numeric DEFAULT NULL::numeric, "p_cost_of_goods_sold" numeric DEFAULT 0, "p_target_price" numeric DEFAULT 0, "p_listed_price" numeric DEFAULT 0, "p_inserted_by" "text" DEFAULT 'app-user'::"text", "p_origin_unit_price" numeric DEFAULT NULL::numeric, "p_extra_origin_unit_price" numeric DEFAULT NULL::numeric, "p_listed_unit_price" numeric DEFAULT NULL::numeric, "p_extra_origin_purchase_expense" numeric DEFAULT NULL::numeric) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_barcode_row public.thrift_barcodes%rowtype;
  v_stock_id bigint;
  v_origin_unit_price numeric := coalesce(p_origin_unit_price, p_origin_purchase_price);
  v_extra_origin_unit_price numeric := coalesce(p_extra_origin_unit_price, p_extra_origin_purchase_expense, 0);
  v_listed_unit_price numeric := coalesce(p_listed_unit_price, p_listed_price);
begin
  if trim(coalesce(p_barcode, '')) = '' then
    raise exception 'Barcode is required';
  if trim(coalesce(p_image_url, '')) = '' then
    raise exception 'Image URL is required';
  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  ) then
    raise exception 'Not authorized for this tenant';
  select *
  into v_barcode_row
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id = trim(p_barcode)
  for update;

  if not found then
    raise exception 'Barcode not found in catalog';
  select id
  into v_stock_id
  from public.thrift_stocks
  where tenant_id = p_tenant_id
    and barcode = trim(p_barcode)
  limit 1;

  if v_stock_id is null then
    if v_barcode_row.status <> 'AVAILABLE' then
      raise exception 'Barcode is already used';
    insert into public.thrift_stocks (
      tenant_id,
      shipment_id,
      brand_name,
      category_id,
      type_id,
      section,
      shelf_id,
      color,
      size,
      condition,
      barcode,
      stock_type,
      quantity,
      box_id,
      product_weight,
      extra_weight,
      status,
      note,
      inserted_by,
      origin_unit_price,
      extra_origin_unit_price
    )
    values (
      p_tenant_id,
      p_shipment_id,
      coalesce(p_brand_name, ''),
      p_category_id,
      p_type_id,
      p_section::public.thrift_section,
      p_shelf_id,
      p_color,
      p_size,
      p_condition::public.thrift_condition,
      trim(p_barcode),
      'SINGLE',
      1,
      p_box_id,
      p_product_weight,
      p_extra_weight,
      'AVAILABLE',
      coalesce(p_note, ''),
      p_inserted_by,
      v_origin_unit_price,
      v_extra_origin_unit_price
    )
    returning id into v_stock_id;
  else
    update public.thrift_stocks
    set
      shipment_id = p_shipment_id,
      brand_name = coalesce(p_brand_name, ''),
      category_id = p_category_id,
      type_id = p_type_id,
      section = p_section::public.thrift_section,
      shelf_id = p_shelf_id,
      color = p_color,
      size = p_size,
      condition = p_condition::public.thrift_condition,
      box_id = p_box_id,
      product_weight = p_product_weight,
      extra_weight = p_extra_weight,
      note = coalesce(p_note, ''),
      origin_unit_price = v_origin_unit_price,
      extra_origin_unit_price = v_extra_origin_unit_price,
      inserted_by = p_inserted_by
    where id = v_stock_id;
  insert into public.thrift_pricings (
    stock_id,
    listed_unit_price,
    inserted_by
  )
  values (
    v_stock_id,
    coalesce(v_listed_unit_price, 0),
    p_inserted_by
  )
  on conflict (stock_id) do update
  set
    listed_unit_price = excluded.listed_unit_price,
    inserted_by = excluded.inserted_by;

  update public.thrift_stock_images
  set image_url = p_image_url,
      inserted_by = p_inserted_by
  where stock_id = v_stock_id
    and is_primary = true;

  if not found then
    insert into public.thrift_stock_images (
      stock_id,
      image_url,
      is_primary,
      inserted_by
    )
    values (
      v_stock_id,
      p_image_url,
      true,
      p_inserted_by
    );
  update public.thrift_barcodes
  set status = 'USED'
  where tenant_id = p_tenant_id
    and barcode_id = trim(p_barcode);

  return v_stock_id;
ALTER FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_inserted_by" "text", "p_origin_unit_price" numeric, "p_extra_origin_unit_price" numeric, "p_listed_unit_price" numeric, "p_extra_origin_purchase_expense" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."release_thrift_barcode_on_stock_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if old.barcode is not null and trim(old.barcode) <> '' then
    update public.thrift_barcodes
    set status = 'AVAILABLE'
    where tenant_id = old.tenant_id
      and barcode_id = trim(old.barcode);
  return old;
ALTER FUNCTION "public"."release_thrift_barcode_on_stock_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_stock public.thrift_stocks%ROWTYPE;
  v_updated INT;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.tenant_id = p_tenant_id
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'Not authorized for this tenant';
  END IF;

  SELECT *
  INTO v_stock
  FROM public.thrift_stocks
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock item % not found for tenant %', p_stock_id, p_tenant_id;
  END IF;

  IF v_stock.status IS DISTINCT FROM 'RESERVED'::public.thrift_stock_status THEN
    RAISE EXCEPTION
      'Stock item % is not on hold (status=%)',
      p_stock_id,
      v_stock.status;
  END IF;

  UPDATE public.thrift_stocks
  SET
    status = 'AVAILABLE'::public.thrift_stock_status,
    updated_at = NOW()
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
    AND status = 'RESERVED'::public.thrift_stock_status;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RAISE EXCEPTION 'Stock item % hold could not be released', p_stock_id;
  END IF;

  RETURN jsonb_build_object(
    'id', p_stock_id,
    'status', 'AVAILABLE'
  );
END;
ALTER FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) IS 'Release RESERVED thrift stock back to AVAILABLE; clears hold metadata via trigger.';


    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    (select t.parent_id from public.tenants t where t.id = p_tenant_id),
    p_tenant_id
  );
ALTER FUNCTION "public"."resolve_parent_tenant_id"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_tenant_for_entry"("p_slug" "text" DEFAULT NULL::"text", "p_hostname" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with domain_match as (
    select *
    from public.find_active_tenant_by_public_domain(p_hostname)
  ),
  slug_match as (
    select *
    from public.find_active_tenant_by_slug(p_slug)
  )
  select *
  from domain_match
  union all
  select *
  from slug_match
  where not exists (select 1 from domain_match)
  limit 1;
ALTER FUNCTION "public"."resolve_tenant_for_entry"("p_slug" "text", "p_hostname" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_thrift_barcode"("p_tenant_id" bigint, "p_scanned_value" "text") RETURNS TABLE("barcode_id" "text", "status" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_canonical text;
begin
  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Not authorized for this tenant';
  v_canonical := public.resolve_thrift_barcode_id_internal(p_tenant_id, p_scanned_value);
  if v_canonical is null then
    return;
  return query
  select b.barcode_id, b.status
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.barcode_id = v_canonical
  limit 1;
ALTER FUNCTION "public"."resolve_thrift_barcode"("p_tenant_id" bigint, "p_scanned_value" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_thrift_barcode_id_internal"("p_tenant_id" bigint, "p_scanned_value" "text") RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $_$
declare
  v_raw text;
  v_candidates text[] := array[]::text[];
  v_match text;
  v_tenant_prefix text;
  v_compact text[];
begin
  v_raw := upper(trim(regexp_replace(coalesce(p_scanned_value, ''), '[^A-Za-z0-9-]', '', 'g')));
  if v_raw = '' then
    return null;
  v_tenant_prefix := lpad(p_tenant_id::text, 2, '0');
  v_candidates := array_append(v_candidates, v_raw);

  if v_raw ~ '^\d+-[A-Z]{2}-\d{2}-\d+$' then
    v_candidates := array_append(v_candidates,
      split_part(v_raw, '-', 1) || '-' ||
      split_part(v_raw, '-', 2) || '-' ||
      split_part(v_raw, '-', 3) || '-' ||
      lpad(split_part(v_raw, '-', 4), 6, '0'));
  if v_raw ~ '^[A-Z]{2}-\d{2}-\d+$' then
    v_candidates := array_append(v_candidates, v_tenant_prefix || '-' || v_raw);
    v_candidates := array_append(v_candidates,
      v_tenant_prefix || '-' ||
      split_part(v_raw, '-', 1) || '-' ||
      split_part(v_raw, '-', 2) || '-' ||
      lpad(split_part(v_raw, '-', 3), 6, '0'));
  v_compact := regexp_match(v_raw, '^(\d+)([A-Z]{2})(\d{2})(\d+)$');
  if v_compact is not null then
    v_candidates := array_append(v_candidates,
      v_compact[1] || '-' || v_compact[2] || '-' || v_compact[3] || '-' || lpad(v_compact[4], 6, '0'));
  select b.barcode_id
  into v_match
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.barcode_id = any (v_candidates)
  order by b.barcode_id
  limit 1;

  return v_match;
$_$;


ALTER FUNCTION "public"."resolve_thrift_barcode_id_internal"("p_tenant_id" bigint, "p_scanned_value" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text" DEFAULT 'cashier'::"text", "p_notes" "text" DEFAULT NULL::"text", "p_force" boolean DEFAULT false, "p_return_courier_amount" numeric DEFAULT 0.00) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_item RECORD;
  v_reason TEXT;
  v_invoice_number TEXT;
  v_force BOOLEAN := COALESCE(p_force, false);
  v_has_returns BOOLEAN := FALSE;
  v_return_courier NUMERIC(12,2);
  v_event_at TIMESTAMPTZ := NOW();
  v_is_online BOOLEAN;
  v_uncollected_delivery NUMERIC(12,2) := 0.00;
  v_advance_amount NUMERIC(12,2) := 0.00;
  v_ledger_refund NUMERIC(12,2) := 0.00;
  v_pool_delivery NUMERIC(12,2) := 0.00;
  v_pool_packing NUMERIC(12,2) := 0.00;
  v_pool_return NUMERIC(12,2) := 0.00;
  v_total_value NUMERIC(12,2) := 0.00;
  v_line_count INT := 0;
  v_idx INT := 0;
  v_cum_delivery NUMERIC(12,2) := 0.00;
  v_cum_packing NUMERIC(12,2) := 0.00;
  v_cum_return NUMERIC(12,2) := 0.00;
  v_line RECORD;
  v_line_value NUMERIC(12,2);
  v_share NUMERIC;
  v_alloc_delivery NUMERIC(12,2);
  v_alloc_packing NUMERIC(12,2);
  v_alloc_return NUMERIC(12,2);
  v_inbound_shipment_id BIGINT;
BEGIN
  v_reason := upper(trim(COALESCE(p_reason, '')));
  -- Legacy RETURN → RTO (temporary compat)
  IF v_reason = 'RETURN' THEN
    v_reason := 'RTO';
  END IF;

  IF v_reason NOT IN ('RTO', 'STAFF_MISTAKE') THEN
    RAISE EXCEPTION 'Invalid revert reason %. Expected RTO or STAFF_MISTAKE', p_reason;
  END IF;

  v_return_courier := ROUND(COALESCE(p_return_courier_amount, 0.00), 2);
  IF v_return_courier < 0 THEN
    RAISE EXCEPTION 'return_courier_amount cannot be negative';
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Invoice % is already % and cannot be reverted', p_invoice_id, v_invoice.status;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.thrift_sales_returns r
    WHERE r.tenant_id = p_tenant_id
      AND r.invoice_id = p_invoice_id
  )
  INTO v_has_returns;

  IF v_has_returns THEN
    RAISE EXCEPTION
      'Invoice % already has return documents; use create_thrift_sales_return, not whole-invoice RTO/staff mistake.',
      p_invoice_id;
  END IF;

  v_is_online := COALESCE(v_invoice.sale_channel, 'IN_STORE') = 'ONLINE';

  IF v_reason = 'STAFF_MISTAKE' THEN
    IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'staff_mistake') THEN
      RAISE EXCEPTION 'Staff mistake revert requires thrift_sales staff_mistake permission';
    END IF;
  ELSE
    -- RTO
    IF COALESCE(v_invoice.delivery_status, '') = 'DELIVERED' THEN
      RAISE EXCEPTION
        'Invoice % is already DELIVERED — use post-accept return (Return items), not Mark RTO',
        p_invoice_id;
    END IF;

    IF v_force THEN
      IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'force_return') THEN
        RAISE EXCEPTION
          'Force RTO requires thrift_sales force_return permission for tenant %',
          p_tenant_id;
      END IF;
    ELSE
      IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return') THEN
        RAISE EXCEPTION 'Mark RTO requires thrift_sales return permission';
      END IF;
    END IF;

    IF NOT v_is_online THEN
      RAISE EXCEPTION 'Mark RTO applies to Online invoices only (use Return items for in-store)';
    END IF;
  END IF;

  v_invoice_number := v_invoice.invoice_number;

  -- Restore every sell line stock
  FOR v_item IN
    SELECT stock_id, quantity
    FROM public.thrift_sales_invoice_items
    WHERE invoice_id = p_invoice_id
      AND tenant_id = p_tenant_id
  LOOP
    UPDATE public.thrift_stocks
    SET
      quantity = quantity + GREATEST(v_item.quantity, 1),
      status = 'AVAILABLE'::public.thrift_stock_status,
      updated_at = NOW()
    WHERE id = v_item.stock_id
      AND tenant_id = p_tenant_id;
  END LOOP;

  IF v_reason = 'STAFF_MISTAKE' THEN
    DELETE FROM public.thrift_accounting_ledger
    WHERE tenant_id = p_tenant_id
      AND source = 'INVOICE'::public.thrift_ledger_source
      AND reference_id = p_invoice_id;

    DELETE FROM public.thrift_sales_pnl_lines
    WHERE tenant_id = p_tenant_id
      AND invoice_id = p_invoice_id;

    DELETE FROM public.thrift_sales_invoices
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;

    RETURN jsonb_build_object(
      'id', p_invoice_id,
      'invoice_number', v_invoice_number,
      'status', 'DELETED',
      'reason', 'STAFF_MISTAKE',
      'deleted', true,
      'counter_unchanged', true
    );
  END IF;

  -- ── RTO soft close ──────────────────────────────────────────────
  -- Ledger insert-only: REFUND item total minus non-refundable advance;
  -- LOSS uncollected customer delivery; LOSS return courier.
  -- Keep prior EXPENSE rows (shop packing / shop delivery). Advance is never paid back.

  v_advance_amount := ROUND(COALESCE(v_invoice.advance_amount, 0.00), 2);
  v_ledger_refund := GREATEST(
    0.00,
    ROUND(COALESCE(v_invoice.total_invoice_amount, 0.00) - v_advance_amount, 2)
  );

  IF v_ledger_refund > 0 THEN
    INSERT INTO public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      note,
      inserted_by,
      date
    ) VALUES (
      p_tenant_id,
      'REFUND'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_ledger_refund,
      'RTO refund for Sales Invoice #' || v_invoice_number
        || CASE WHEN v_advance_amount > 0
             THEN ' (advance retained ' || v_advance_amount::TEXT || ')'
             ELSE ''
           END
        || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
      p_reverted_by,
      v_event_at
    );
  END IF;

  IF upper(COALESCE(v_invoice.courier_paid_by, '')) = 'CUSTOMER'
     AND COALESCE(v_invoice.courier_amount, 0) > 0
  THEN
    v_uncollected_delivery := ROUND(v_invoice.courier_amount, 2);
    INSERT INTO public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      note,
      inserted_by,
      date
    ) VALUES (
      p_tenant_id,
      'LOSS'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_uncollected_delivery,
      'uncollected_delivery',
      p_reverted_by,
      v_event_at
    );
  END IF;

  IF v_return_courier > 0 THEN
    INSERT INTO public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      note,
      inserted_by,
      date
    ) VALUES (
      p_tenant_id,
      'LOSS'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_return_courier,
      'return_courier',
      p_reverted_by,
      v_event_at
    );
  END IF;

  -- PnL: all lines → RTO; pool = full forward delivery + packing + return courier
  v_pool_delivery := ROUND(COALESCE(v_invoice.courier_amount, 0), 2);
  v_pool_packing := ROUND(COALESCE(v_invoice.packing_amount, 0), 2);
  v_pool_return := v_return_courier;

  SELECT
    COALESCE(SUM(ROUND(i.final_price * i.quantity, 2)), 0),
    COUNT(*)::INT
  INTO v_total_value, v_line_count
  FROM public.thrift_sales_invoice_items i
  WHERE i.tenant_id = p_tenant_id
    AND i.invoice_id = p_invoice_id;

  IF v_line_count = 0 THEN
    RAISE EXCEPTION 'Invoice % has no lines; cannot close RTO', p_invoice_id;
  END IF;

  FOR v_line IN
    SELECT
      i.id AS invoice_item_id,
      i.stock_id,
      i.quantity,
      ROUND(i.final_price * i.quantity, 2) AS sell_amount,
      s.shipment_id
    FROM public.thrift_sales_invoice_items i
    JOIN public.thrift_stocks s
      ON s.id = i.stock_id
     AND s.tenant_id = i.tenant_id
    WHERE i.tenant_id = p_tenant_id
      AND i.invoice_id = p_invoice_id
    ORDER BY i.id
  LOOP
    v_idx := v_idx + 1;
    v_inbound_shipment_id := v_line.shipment_id;
    IF v_inbound_shipment_id IS NULL THEN
      RAISE EXCEPTION
        'Stock item % has no inbound shipment; cannot write RTO PnL',
        v_line.stock_id;
    END IF;

    v_line_value := v_line.sell_amount;
    IF v_total_value > 0 THEN
      v_share := v_line_value / v_total_value;
    ELSE
      v_share := 1.0 / v_line_count;
    END IF;

    IF v_idx = v_line_count THEN
      v_alloc_delivery := ROUND(v_pool_delivery - v_cum_delivery, 2);
      v_alloc_packing := ROUND(v_pool_packing - v_cum_packing, 2);
      v_alloc_return := ROUND(v_pool_return - v_cum_return, 2);
    ELSE
      v_alloc_delivery := ROUND(v_pool_delivery * v_share, 2);
      v_alloc_packing := ROUND(v_pool_packing * v_share, 2);
      v_alloc_return := ROUND(v_pool_return * v_share, 2);
      v_cum_delivery := v_cum_delivery + v_alloc_delivery;
      v_cum_packing := v_cum_packing + v_alloc_packing;
      v_cum_return := v_cum_return + v_alloc_return;
    END IF;

    INSERT INTO public.thrift_sales_pnl_lines (
      tenant_id,
      invoice_id,
      invoice_item_id,
      stock_id,
      inbound_shipment_id,
      outcome,
      return_id,
      quantity,
      sell_amount,
      allocated_shop_delivery,
      allocated_shop_cod_fee,
      allocated_shop_packing,
      allocated_return_courier,
      allocated_fees_total,
      cogs_is_loss,
      event_at,
      event_date
    ) VALUES (
      p_tenant_id,
      p_invoice_id,
      v_line.invoice_item_id,
      v_line.stock_id,
      v_inbound_shipment_id,
      'RTO',
      NULL,
      v_line.quantity,
      0.00,
      v_alloc_delivery,
      0.00,
      v_alloc_packing,
      v_alloc_return,
      ROUND(v_alloc_delivery + v_alloc_packing + v_alloc_return, 2),
      FALSE,
      v_event_at,
      (v_event_at AT TIME ZONE 'UTC')::DATE
    )
    ON CONFLICT (invoice_item_id) DO UPDATE SET
      outcome = 'RTO',
      return_id = NULL,
      sell_amount = 0.00,
      allocated_shop_delivery = EXCLUDED.allocated_shop_delivery,
      allocated_shop_cod_fee = 0.00,
      allocated_shop_packing = EXCLUDED.allocated_shop_packing,
      allocated_return_courier = EXCLUDED.allocated_return_courier,
      allocated_fees_total = EXCLUDED.allocated_fees_total,
      cogs_is_loss = FALSE,
      event_at = EXCLUDED.event_at,
      event_date = EXCLUDED.event_date,
      updated_at = NOW();
  END LOOP;

  UPDATE public.thrift_sales_invoices
  SET
    status = 'RETURNED',
    payment_status = 'REFUNDED',
    close_reason = 'RTO',
    delivery_status = 'RETURNED',
    return_courier_amount = v_return_courier,
    economics_closed_at = v_event_at,
    cod_expected = NULL,
    cod_remitted_amount = NULL,
    cod_remitted_at = NULL,
    cod_remittance_ref = NULL,
    reverted_at = v_event_at,
    reverted_by = p_reverted_by,
    revert_reason = 'RTO',
    revert_notes = NULLIF(trim(p_notes), ''),
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'id', p_invoice_id,
    'invoice_number', v_invoice_number,
    'status', 'RETURNED',
    'close_reason', 'RTO',
    'delivery_status', 'RETURNED',
    'payment_status', 'REFUNDED',
    'return_courier_amount', v_return_courier,
    'ledger_refund_amount', v_ledger_refund,
    'advance_retained', v_advance_amount,
    'reason', 'RTO',
    'deleted', false
  );
END;
ALTER FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) IS 'RTO: soft-close; ledger REFUND excludes advance_amount (non-refundable). STAFF_MISTAKE: hard-delete. Legacy RETURN→RTO.';


CREATE OR REPLACE FUNCTION "public"."round_bdt_up_to_zero_or_five"("p_value" numeric) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_rounded_up integer;
  v_remainder integer;
begin
  v_rounded_up := ceil(coalesce(p_value, 0))::integer;
  v_remainder := mod(v_rounded_up, 5);

  if v_remainder = 0 then
    return v_rounded_up;
  return v_rounded_up + (5 - v_remainder);
ALTER FUNCTION "public"."round_bdt_up_to_zero_or_five"("p_value" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_customer_phone" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_search TEXT := NULLIF(trim(COALESCE(p_search, '')), '');
  v_phone TEXT := public.normalize_thrift_phone(p_customer_phone);
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
  v_result JSONB;
BEGIN
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_stock', 'view')
  ) THEN
    RAISE EXCEPTION 'Searching thrift stock for sale requires thrift_sales or thrift_stock access';
  END IF;

  IF v_search IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  WITH matched AS (
    SELECT s.*
    FROM public.thrift_stocks s
    WHERE s.tenant_id = p_tenant_id
      AND s.deleted_at IS NULL
      AND (
        s.name ILIKE '%' || v_search || '%'
        OR COALESCE(s.barcode, '') ILIKE '%' || v_search || '%'
        OR COALESCE(s.brand_name, '') ILIKE '%' || v_search || '%'
        OR COALESCE(s.color, '') ILIKE '%' || v_search || '%'
        OR COALESCE(s.size, '') ILIKE '%' || v_search || '%'
      )
      AND (
        s.status = 'AVAILABLE'::public.thrift_stock_status
        OR (
          v_phone <> ''
          AND s.status = 'RESERVED'::public.thrift_stock_status
          AND s.held_for_phone_normalized IS NOT DISTINCT FROM v_phone
        )
      )
    ORDER BY s.created_at DESC
    LIMIT v_limit
  ),
  enriched AS (
    SELECT
      b.id,
      b.created_at,
      b.name,
      b.barcode,
      b.available_quantity,
      b.landed_cost,
      b.category,
      b.status,
      b.brand_name,
      b.type_name,
      b.color,
      b.size,
      b.condition,
      b.section,
      b.shelf_code,
      b.box_name,
      b.image_url,
      b.shipment_id,
      b.shipment_name,
      b.held_for_phone,
      b.held_for_name,
      CASE
        WHEN b.is_listed_price_manual THEN b.listed_unit_price
        ELSE public.ceil_thrift_retail_price(
          b.landed_cost * (1 + b.applied_markup_rate)
        )
      END AS default_sell_price
    FROM (
      SELECT
        m.id,
        m.created_at,
        COALESCE(NULLIF(trim(m.name), ''), 'Unnamed Item') AS name,
        COALESCE(NULLIF(trim(m.barcode), ''), 'NO-BARCODE') AS barcode,
        GREATEST(COALESCE(m.quantity, 0), 0) AS available_quantity,
        ROUND(COALESCE(public.compute_thrift_landed_unit_cost(m.id), 0.00), 2) AS landed_cost,
        COALESCE(c.name, 'Uncategorized') AS category,
        m.status::text AS status,
        m.brand_name,
        t.name AS type_name,
        m.color,
        m.size,
        m.condition::text AS condition,
        m.section::text AS section,
        sh.shelf_code,
        b.name AS box_name,
        (
          SELECT i.image_url
          FROM public.thrift_stock_images i
          WHERE i.stock_id = m.id
          ORDER BY i.is_primary DESC NULLS LAST, i.id ASC
          LIMIT 1
        ) AS image_url,
        COALESCE(m.shipment_id, 0) AS shipment_id,
        ship.name AS shipment_name,
        m.held_for_phone,
        m.held_for_name,
        COALESCE(p.is_listed_price_manual, false) AS is_listed_price_manual,
        ROUND(COALESCE(p.listed_unit_price, 0), 2) AS listed_unit_price,
        COALESCE(p.markup_rate_override, ship.default_markup_rate, 0) AS applied_markup_rate
      FROM matched m
      LEFT JOIN public.thrift_categories c ON c.id = m.category_id
      LEFT JOIN public.thrift_types t ON t.id = m.type_id
      LEFT JOIN public.thrift_shelves sh ON sh.id = m.shelf_id
      LEFT JOIN public.thrift_boxes b ON b.id = m.box_id
      LEFT JOIN public.thrift_shipments ship ON ship.id = m.shipment_id
      LEFT JOIN LATERAL (
        SELECT
          pr.listed_unit_price,
          pr.is_listed_price_manual,
          pr.markup_rate_override
        FROM public.thrift_pricings pr
        WHERE pr.stock_id = m.id
        ORDER BY pr.id DESC
        LIMIT 1
      ) p ON TRUE
    ) b
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', e.id,
        'name', e.name,
        'barcode', e.barcode,
        'available_quantity', e.available_quantity,
        'landed_cost', e.landed_cost,
        'default_sell_price', e.default_sell_price,
        'category', e.category,
        'status', e.status,
        'brand_name', e.brand_name,
        'type', e.type_name,
        'color', e.color,
        'size', e.size,
        'condition', e.condition,
        'section', e.section,
        'shelf_code', e.shelf_code,
        'box_name', e.box_name,
        'image_url', e.image_url,
        'shipment_id', e.shipment_id,
        'shipment_name', e.shipment_name,
        'held_for_phone', e.held_for_phone,
        'held_for_name', e.held_for_name
      )
      ORDER BY e.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_result
  FROM enriched e;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
ALTER FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) IS 'POS stock picker: default_sell_price = manual listed else ceil_thrift_retail_price(landed*(1+markup)); hold-aware.';


CREATE OR REPLACE FUNCTION "public"."seed_tenant_roles_and_grants"("p_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_role record;
begin
  -- App default roles
  insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role)
  values
    (p_tenant_id, 'app', 'Administrator', 'administrator', true, true, 'admin'::public.app_role),
    (p_tenant_id, 'app', 'Staff', 'staff', true, false, 'staff'::public.app_role),
    (p_tenant_id, 'app', 'Viewer', 'viewer', true, false, 'viewer'::public.app_role)
  on conflict (tenant_id, scope, slug) do nothing;

  -- Shop default roles
  insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role)
  values
    (p_tenant_id, 'shop', 'Customer Admin', 'customer-admin', true, false, null),
    (p_tenant_id, 'shop', 'Negotiator', 'negotiator', true, false, null),
    (p_tenant_id, 'shop', 'Customer Staff', 'customer-staff', true, false, null)
  on conflict (tenant_id, scope, slug) do nothing;

  -- Seed role grants from templates (additive only — preserve customizations)
  for v_role in (
    select id, scope, slug
    from public.tenant_roles
    where tenant_id = p_tenant_id and is_admin = false
  ) loop
    insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
    select v_role.id, t.module_key, t.action, t.allowed
    from public.system_role_templates t
    where t.scope = v_role.scope and t.role_slug = v_role.slug
    on conflict (tenant_role_id, module_key, action) do nothing;
  ALTER FUNCTION "public"."seed_tenant_roles_and_grants"("p_tenant_id" bigint) OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_product record;
begin
  if new.product_id is null then
    return new;
  select p.barcode, p.product_code
  into v_product
  from public.products p
  where p.id = new.product_id;

  if found then
    new.barcode := coalesce(new.barcode, v_product.barcode);
    new.product_code := coalesce(new.product_code, v_product.product_code);
  ALTER FUNCTION "public"."set_order_item_product_identity"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_order_parent_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_parent_id bigint;
begin
  select parent_id into v_parent_id
  from public.tenants
  where id = new.tenant_id;

  new.parent_tenant_id := coalesce(v_parent_id, new.tenant_id);
  ALTER FUNCTION "public"."set_order_parent_tenant_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_parent_tenant_id_from_tenant"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
begin
  if new.tenant_id is not null then
    select parent_id into v_parent_id
    from public.tenants
    where id = new.tenant_id;

    new.parent_tenant_id := coalesce(v_parent_id, new.tenant_id);
  ALTER FUNCTION "public"."set_parent_tenant_id_from_tenant"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_product_lookup_updated_at_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at := now();
  ALTER FUNCTION "public"."set_product_lookup_updated_at_timestamp"() OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.tenant_id is null then
    new.tenant_id := public.current_tenant_id();
  ALTER FUNCTION "public"."set_tenant_id_on_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_tenant_module_submodule_for_superadmin"("p_tenant_id" bigint, "p_parent_module_key" "text", "p_submodule_key" "text", "p_is_enabled" boolean) RETURNS TABLE("id" bigint, "tenant_id" bigint, "parent_module_key" "text", "submodule_key" "text", "is_enabled" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  upserted as (
    insert into public.tenant_module_submodules (
      tenant_id,
      parent_module_key,
      submodule_key,
      is_enabled
    )
    select
      p_tenant_id,
      lower(trim(p_parent_module_key)),
      lower(trim(p_submodule_key)),
      coalesce(p_is_enabled, true)
    from permission
    where allowed
      and p_tenant_id is not null
      and exists (
        select 1
        from public.tenant_modules tm
        where tm.tenant_id = p_tenant_id
          and tm.module_key = lower(trim(p_parent_module_key))
          and tm.is_active = true
      )
    on conflict (tenant_id, submodule_key) do update
    set
      parent_module_key = excluded.parent_module_key,
      is_enabled = excluded.is_enabled
    returning
      id,
      tenant_id,
      parent_module_key,
      submodule_key,
      is_enabled,
      created_at,
      updated_at
  )
  select
    id,
    tenant_id,
    parent_module_key,
    submodule_key,
    is_enabled,
    created_at,
    updated_at
  from upserted;
ALTER FUNCTION "public"."set_tenant_module_submodule_for_superadmin"("p_tenant_id" bigint, "p_parent_module_key" "text", "p_submodule_key" "text", "p_is_enabled" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_final_amount numeric;
  v_final_currency_id bigint;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_finalize_catalog_prices is only valid for vendor_catalog orders.';
  END IF;

  -- Update items final offer
  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_final_amount := (v_elem->>'final_offer_amount')::numeric;
    v_final_currency_id := (v_elem->>'final_offer_currency_id')::bigint;

    UPDATE public.shop_order_items
    SET
      final_offer_amount = v_final_amount,
      final_offer_currency_id = v_final_currency_id,
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;

  -- Update status to final_offered
  UPDATE public.shop_orders
  SET
    status = 'final_offered'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;
END;
ALTER FUNCTION "public"."staff_finalize_catalog_prices"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_delivered_qty integer;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_set_catalog_delivered_qty is only valid for vendor_catalog orders.';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_delivered_qty := (v_elem->>'delivered_quantity')::integer;

    UPDATE public.shop_order_items
    SET
      delivered_quantity = COALESCE(v_delivered_qty, 0),
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;

  -- Transition status to delivered
  UPDATE public.shop_orders
  SET
    status = 'delivered'::public.shop_order_status,
    fulfilled_at = COALESCE(fulfilled_at, now()),
    updated_at = now()
  WHERE id = p_order_id;
END;
ALTER FUNCTION "public"."staff_set_catalog_delivered_qty"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_ordered_qty integer;
  v_item_row record;
  v_target_qty integer;
  v_shortfall integer;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_ordered_qty := (v_elem->>'ordered_quantity')::integer;

    SELECT * INTO v_item_row FROM public.shop_order_items WHERE id = v_item_id AND order_id = p_order_id;

    IF v_item_row.id IS NOT NULL THEN
      UPDATE public.shop_order_items
      SET
        ordered_quantity = COALESCE(v_ordered_qty, 0),
        updated_at = now()
      WHERE id = v_item_id;

      -- Check shortfall for backlog creation
      v_target_qty := COALESCE(v_item_row.confirmed_quantity, v_item_row.quantity, 0);
      v_shortfall := v_target_qty - COALESCE(v_ordered_qty, 0);

      IF v_shortfall > 0 AND v_order.billing_profile_id IS NOT NULL THEN
        INSERT INTO public.customer_order_backlog_items (
          tenant_id,
          billing_profile_id,
          product_id,
          order_id,
          order_item_id,
          requested_quantity,
          fulfilled_quantity,
          backlog_status
        ) VALUES (
          v_order.tenant_id,
          v_order.billing_profile_id,
          v_item_row.product_id,
          p_order_id,
          v_item_id,
          v_shortfall,
          0,
          'open'
        )
        ON CONFLICT (tenant_id, billing_profile_id, product_id)
        DO UPDATE SET
          requested_quantity = customer_order_backlog_items.requested_quantity + EXCLUDED.requested_quantity,
          backlog_status = 'open',
          updated_at = now();
      END IF;
    END IF;
  END LOOP;

  -- Transition status to ordered
  UPDATE public.shop_orders
  SET
    status = 'ordered'::public.shop_order_status,
    placed_at = COALESCE(placed_at, now()),
    updated_at = now()
  WHERE id = p_order_id;
END;
ALTER FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_start_catalog_procurement"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_order record;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_start_catalog_procurement is only valid for vendor_catalog orders.';
  END IF;

  IF v_order.status <> 'confirmed' THEN
    RAISE EXCEPTION 'Order % cannot start procurement from status %', p_order_id, v_order.status;
  END IF;

  -- Default confirmed_quantity to quantity if null
  UPDATE public.shop_order_items
  SET
    confirmed_quantity = COALESCE(confirmed_quantity, quantity),
    updated_at = now()
  WHERE order_id = p_order_id;

  -- Update order status to procuring
  UPDATE public.shop_orders
  SET
    status = 'procuring'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;
END;
ALTER FUNCTION "public"."staff_start_catalog_procurement"("p_order_id" bigint) OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_commerce_inventory_product_summary_single(old.tenant_id, old.product_id);
    return old;
  perform public.refresh_commerce_inventory_product_summary_single(new.tenant_id, new.product_id);

  if tg_op = 'UPDATE' and (old.product_id is distinct from new.product_id) then
    perform public.refresh_commerce_inventory_product_summary_single(old.tenant_id, old.product_id);
  ALTER FUNCTION "public"."sync_commerce_summary_from_inventory_items"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_commerce_summary_from_inventory_stocks"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_inventory_item_id bigint;
  begin
  v_inventory_item_id := coalesce(new.inventory_item_id, old.inventory_item_id);

  select ii.tenant_id, ii.product_id
  into v_tenant_id, v_product_id
  from public.inventory_items ii
  where ii.id = v_inventory_item_id;

  perform public.refresh_commerce_inventory_product_summary_single(v_tenant_id, v_product_id);
  return coalesce(new, old);
ALTER FUNCTION "public"."sync_commerce_summary_from_inventory_stocks"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_investor_balance_from_investors"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  perform public.refresh_investor_balance(new.tenant_id, new.id);
  ALTER FUNCTION "public"."sync_investor_balance_from_investors"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_investor_balance_from_transactions"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_investor_balance(old.tenant_id, old.investor_id);
    return old;
  if tg_op = 'UPDATE' and (old.tenant_id <> new.tenant_id or old.investor_id <> new.investor_id) then
    perform public.refresh_investor_balance(old.tenant_id, old.investor_id);
  perform public.refresh_investor_balance(new.tenant_id, new.investor_id);
  ALTER FUNCTION "public"."sync_investor_balance_from_transactions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_lookup_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_tenant_id bigint;
  begin
  if new.vendor_id is not null then
    select tenant_id, parent_tenant_id
    into v_tenant_id, v_parent_tenant_id
    from public.vendors
    where id = new.vendor_id;

    if v_tenant_id is not null then
      new.tenant_id := v_tenant_id;
    if v_parent_tenant_id is not null then
      new.parent_tenant_id := v_parent_tenant_id;
    ALTER FUNCTION "public"."sync_lookup_tenant_id"() OWNER TO "postgres";


    LANGUAGE "sql" IMMUTABLE
    AS $_$
  select
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 2)
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 1)
      else coalesce(p_barcode_id, '')
    end as sort_prefix,
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 3)
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 2)
      else ''
    end as sort_year,
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 4)::integer
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 3)::integer
      else 0
    end as sort_seq;
$_$;


ALTER FUNCTION "public"."thrift_barcode_sequence_sort_key"("p_barcode_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."thrift_courier_providers_guard_system"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'System courier providers cannot be deleted';
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'System courier providers cannot be updated';
    END IF;
    IF NEW.is_system IS DISTINCT FROM FALSE OR NEW.tenant_id IS NULL THEN
      RAISE EXCEPTION 'Tenant courier providers must keep is_system=false and a tenant_id';
    END IF;
    IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
      RAISE EXCEPTION 'Cannot move courier provider across tenants';
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
ALTER FUNCTION "public"."thrift_courier_providers_guard_system"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."thrift_stocks_enforce_hold_metadata"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.status = 'RESERVED'::public.thrift_stock_status THEN
    IF COALESCE(NEW.held_for_phone_normalized, '') = '' THEN
      RAISE EXCEPTION 'RESERVED stock requires held_for_phone_normalized';
    END IF;
    NEW.held_for_phone_normalized := public.normalize_thrift_phone(
      COALESCE(NEW.held_for_phone_normalized, NEW.held_for_phone)
    );
    IF COALESCE(NEW.held_for_phone_normalized, '') = '' THEN
      RAISE EXCEPTION 'RESERVED stock requires a non-empty customer phone';
    END IF;
    IF NEW.held_at IS NULL THEN
      NEW.held_at := NOW();
    END IF;
  ELSIF TG_OP = 'UPDATE'
    AND OLD.status = 'RESERVED'::public.thrift_stock_status
  THEN
    NEW.held_for_name := NULL;
    NEW.held_for_phone := NULL;
    NEW.held_for_phone_normalized := NULL;
    NEW.hold_note := NULL;
    NEW.held_by := NULL;
    NEW.held_at := NULL;
    NEW.hold_expires_at := NULL;
  END IF;

  RETURN NEW;
END;
ALTER FUNCTION "public"."thrift_stocks_enforce_hold_metadata"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_wallet_balance"(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_from_bucket text,
  p_to_bucket text,
  p_amount numeric,
  p_currency_code text DEFAULT 'BDT',
  p_notes text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_parent_tenant_id bigint;
  v_operating_tenant_id bigint;
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_result jsonb;
  v_entity_id bigint;
BEGIN
  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_tenant_id := p_tenant_id;
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be greater than zero.';
  END IF;

  IF p_from_bucket = p_to_bucket THEN
    RAISE EXCEPTION 'Source and target buckets cannot be identical.';
  END IF;

  IF p_from_bucket NOT IN ('available', 'pending', 'locked')
     OR p_to_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Invalid bucket specifiers. Must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_parent_tenant_id;
  END IF;

  INSERT INTO public.wallet_accounts (
    tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    v_parent_tenant_id, v_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (parent_tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.wallet_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_from_bucket = 'pending' THEN
    IF v_pend < p_amount THEN
      RAISE EXCEPTION 'Insufficient pending balance (Pending: %, Requested: %).', v_pend, p_amount;
    END IF;
    v_pend := v_pend - p_amount;
  ELSIF p_from_bucket = 'available' THEN
    IF v_avail < p_amount THEN
      RAISE EXCEPTION 'Insufficient available balance (Available: %, Requested: %).', v_avail, p_amount;
    END IF;
    v_avail := v_avail - p_amount;
  ELSIF p_from_bucket = 'locked' THEN
    IF v_lock < p_amount THEN
      RAISE EXCEPTION 'Insufficient locked balance (Locked: %, Requested: %).', v_lock, p_amount;
    END IF;
    v_lock := v_lock - p_amount;
  END IF;

  IF p_to_bucket = 'pending' THEN
    v_pend := v_pend + p_amount;
  ELSIF p_to_bucket = 'available' THEN
    v_avail := v_avail + p_amount;
  ELSIF p_to_bucket = 'locked' THEN
    v_lock := v_lock + p_amount;
  END IF;

  UPDATE public.wallet_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = v_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  INSERT INTO public.universal_wallet_ledger (
    tenant_id, parent_tenant_id, operating_tenant_id,
    entity_type, entity_id, type, amount, currency_code,
    exchange_rate, base_amount, balance_after, source_type, source_id, metadata
  )
  VALUES (
    v_parent_tenant_id, v_parent_tenant_id, v_operating_tenant_id,
    p_entity_type, v_entity_id, 'credit', p_amount, coalesce(p_currency_code, 'BDT'),
    1.000000, p_amount, v_avail, 'bucket_transfer', NULL,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'from_bucket', p_from_bucket,
      'to_bucket', p_to_bucket,
      'notes', p_notes
    )
  );

  SELECT jsonb_build_object(
    'account_id', v_account_id,
    'parent_tenant_id', v_parent_tenant_id,
    'tenant_id', v_parent_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(p_currency_code, 'BDT'),
    'available_balance', v_avail,
    'pending_balance', v_pend,
    'locked_balance', v_lock
  ) INTO v_result;

  RETURN v_result;
END;
$$;
ALTER FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text", "p_notes" "text", "p_metadata" "jsonb") OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_role_slug text;
  v_role_id bigint;
begin
  if new.tenant_role_id is null and new.customer_group_id is not null and new.role is not null then
    select tenant_id into v_tenant_id
    from public.customer_groups
    where id = new.customer_group_id;

    if v_tenant_id is not null then
      v_role_slug := case new.role
        when 'admin' then 'customer-admin'
        when 'negotiator' then 'negotiator'
        when 'staff' then 'customer-staff'
        else 'customer-staff'
      end;

      select id into v_role_id
      from public.tenant_roles
      where tenant_id = v_tenant_id
        and scope = 'shop'
        and slug = v_role_slug;

      new.tenant_role_id := v_role_id;
    ALTER FUNCTION "public"."trg_fn_assign_default_customer_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_assign_default_membership_role"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_role_slug text;
  v_role_id bigint;
begin
  if new.tenant_role_id is null and new.tenant_id is not null and new.role is not null then
    v_role_slug := case new.role
      when 'admin' then 'administrator'
      when 'staff' then 'staff'
      when 'viewer' then 'viewer'
      else 'viewer'
    end;

    select id into v_role_id
    from public.tenant_roles
    where tenant_id = new.tenant_id
      and scope = 'app'
      and slug = v_role_slug;

    new.tenant_role_id := v_role_id;
  ALTER FUNCTION "public"."trg_fn_assign_default_membership_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_bump_cgm_grant_tenant_version"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select cg.tenant_id into v_tenant_id
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cgm.id = old.customer_group_member_id;
  else
    select cg.tenant_id into v_tenant_id
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cgm.id = new.customer_group_member_id;
  if v_tenant_id is not null then
    perform public.bump_tenant_permission_version(v_tenant_id);
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  ALTER FUNCTION "public"."trg_fn_bump_cgm_grant_tenant_version"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_bump_cgm_version"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select tenant_id into v_tenant_id from public.customer_groups where id = old.customer_group_id;
  else
    select tenant_id into v_tenant_id from public.customer_groups where id = new.customer_group_id;
  if v_tenant_id is not null then
    if tg_op = 'DELETE' or tg_op = 'INSERT' or coalesce(old.tenant_role_id, 0) <> coalesce(new.tenant_role_id, 0) or old.is_active <> new.is_active or old.role <> new.role then
      perform public.bump_tenant_permission_version(v_tenant_id);
    if tg_op = 'DELETE' then
    return old;
  else
    return new;
  ALTER FUNCTION "public"."trg_fn_bump_cgm_version"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_bump_grant_tenant_version"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select tenant_id into v_tenant_id from public.tenant_roles where id = old.tenant_role_id;
  else
    select tenant_id into v_tenant_id from public.tenant_roles where id = new.tenant_role_id;
  if v_tenant_id is not null then
    perform public.bump_tenant_permission_version(v_tenant_id);
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  ALTER FUNCTION "public"."trg_fn_bump_grant_tenant_version"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_bump_membership_grant_tenant_version"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select tenant_id into v_tenant_id from public.memberships where id = old.membership_id;
  else
    select tenant_id into v_tenant_id from public.memberships where id = new.membership_id;
  if v_tenant_id is not null then
    perform public.bump_tenant_permission_version(v_tenant_id);
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  ALTER FUNCTION "public"."trg_fn_bump_membership_grant_tenant_version"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_bump_membership_version"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  if tg_op = 'DELETE' then
    perform public.bump_tenant_permission_version(old.tenant_id);
    return old;
  elsif tg_op = 'INSERT' then
    perform public.bump_tenant_permission_version(new.tenant_id);
    elsif coalesce(old.tenant_role_id, 0) <> coalesce(new.tenant_role_id, 0) or old.is_active <> new.is_active or old.role <> new.role then
    perform public.bump_tenant_permission_version(new.tenant_id);
    ALTER FUNCTION "public"."trg_fn_bump_membership_version"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_bump_role_tenant_version"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  if tg_op = 'DELETE' then
    perform public.bump_tenant_permission_version(old.tenant_id);
    return old;
  else
    perform public.bump_tenant_permission_version(new.tenant_id);
    ALTER FUNCTION "public"."trg_fn_bump_role_tenant_version"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_bump_tenant_modules_version"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  if tg_op = 'DELETE' then
    perform public.bump_tenant_permission_version(old.tenant_id);
    return old;
  else
    perform public.bump_tenant_permission_version(new.tenant_id);
    ALTER FUNCTION "public"."trg_fn_bump_tenant_modules_version"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_cgm_permission_guardrails"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_role_scope text;
  v_role_tenant bigint;
  v_cg_tenant bigint;
begin
  if new.tenant_role_id is not null then
    select scope, tenant_id into v_role_scope, v_role_tenant
    from public.tenant_roles
    where id = new.tenant_role_id;

    select tenant_id into v_cg_tenant
    from public.customer_groups
    where id = new.customer_group_id;

    if v_role_tenant <> v_cg_tenant then
      raise exception 'Cross-tenant role assignment is not allowed';
    if v_role_scope <> 'shop' then
      raise exception 'Scope mismatch: customer group member cannot be assigned a % scoped role', v_role_scope;
    ALTER FUNCTION "public"."trg_fn_cgm_permission_guardrails"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_memberships_permission_guardrails"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_role_scope text;
  v_role_tenant bigint;
  v_role_is_admin boolean;
  v_active_admins int;
begin
  if new.tenant_role_id is not null then
    select scope, tenant_id, is_admin into v_role_scope, v_role_tenant, v_role_is_admin
    from public.tenant_roles
    where id = new.tenant_role_id;

    if v_role_tenant <> new.tenant_id then
      raise exception 'Cross-tenant role assignment is not allowed';
    if v_role_scope <> 'app' then
      raise exception 'Scope mismatch: app membership cannot be assigned a % scoped role', v_role_scope;
    if tg_op = 'UPDATE' and old.is_active = true then
    declare
      v_was_admin boolean;
      v_is_admin boolean;
    begin
      v_was_admin := (old.role = 'admin') or exists (
        select 1 from public.tenant_roles where id = old.tenant_role_id and is_admin = true
      );
      v_is_admin := (new.is_active = true) and ((new.role = 'admin') or exists (
        select 1 from public.tenant_roles where id = new.tenant_role_id and is_admin = true
      ));

      if v_was_admin and not v_is_admin then
        select count(*) into v_active_admins
        from public.memberships m
        left join public.tenant_roles tr on tr.id = m.tenant_role_id
        where m.tenant_id = old.tenant_id
          and m.is_active = true
          and m.id <> old.id
          and (m.role = 'admin' or tr.is_admin = true);

        if v_active_admins = 0 then
          raise exception 'Cannot downgrade or deactivate the last active administrator for this tenant';
        ALTER FUNCTION "public"."trg_fn_memberships_permission_guardrails"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_seed_new_tenant"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public.seed_tenant_roles_and_grants(new.id);
  ALTER FUNCTION "public"."trg_fn_seed_new_tenant"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_sync_cgm_tenant_role"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_target_slug text;
  v_role_id bigint;
begin
  if new.tenant_role_id is null or (tg_op = 'UPDATE' and old.role <> new.role) then
    select cg.tenant_id into v_tenant_id
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_tenant_id is not null then
      v_target_slug := case new.role
        when 'admin' then 'customer-admin'
        when 'negotiator' then 'negotiator'
        when 'staff' then 'customer-staff'
        else 'customer-staff'
      end;

      select tr.id into v_role_id
      from public.tenant_roles tr
      where tr.tenant_id = v_tenant_id
        and tr.scope = 'shop'
        and (tr.slug = v_target_slug or (new.role = 'admin' and tr.is_admin = true))
      order by tr.is_admin desc, tr.id asc
      limit 1;

      if v_role_id is not null then
        new.tenant_role_id := v_role_id;
      ALTER FUNCTION "public"."trg_fn_sync_cgm_tenant_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_tenant_modules_disable_guardrails"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_has_grants boolean;
  v_has_overrides boolean;
begin
  if tg_op = 'UPDATE' and old.is_active = true and new.is_active = false then
    if coalesce(current_setting('request.force_module_disable', true), '') <> 'true' then
      select exists (
        select 1 from public.tenant_role_grants tg
        join public.tenant_roles tr on tr.id = tg.tenant_role_id
        where tr.tenant_id = old.tenant_id and tg.module_key = old.module_key
      ) into v_has_grants;

      if v_has_grants then
        raise exception 'Cannot disable module %: active role grants depend on it. Use force to override.', old.module_key;
      select exists (
        select 1 from public.membership_grants mg
        join public.memberships m on m.id = mg.membership_id
        where m.tenant_id = old.tenant_id and mg.module_key = old.module_key
      ) into v_has_overrides;

      if v_has_overrides then
        raise exception 'Cannot disable module %: active member overrides depend on it. Use force to override.', old.module_key;
      ALTER FUNCTION "public"."trg_fn_tenant_modules_disable_guardrails"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_tenant_role_guardrails"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_count int;
begin
  if tg_op = 'DELETE' then
    if old.is_admin = true and old.is_active = true then
      raise exception 'Cannot delete the final active admin role for this scope';
    return old;
  elsif tg_op = 'UPDATE' then
    if old.is_admin = true and old.is_active = true and (new.is_admin = false or new.is_active = false) then
      select count(*) into v_count
      from public.tenant_roles
      where tenant_id = old.tenant_id
        and scope = old.scope
        and is_admin = true
        and is_active = true
        and id <> old.id;
      if v_count = 0 then
        raise exception 'Cannot deactivate or downgrade the final active admin role for this scope';
      ALTER FUNCTION "public"."trg_fn_tenant_role_guardrails"() OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not exists (
    select 1
    from public.memberships m
    where m.id = p_membership_id
      and lower(trim(m.email)) = lower(trim(public.current_user_email()))
      and m.is_active = true
  ) then
    raise exception 'Unauthorized to update this membership preference';
  if jsonb_typeof(p_preference) is distinct from 'object' then
    raise exception 'Membership preference must be a JSON object';
  return query
  update public.memberships as m
  set preference = p_preference
  where m.id = p_membership_id
  returning
    m.id,
    m.email,
    m.role,
    m.is_active,
    m.tenant_id,
    m.preference,
    m.created_at,
    m.updated_at;
ALTER FUNCTION "public"."update_membership_preference_for_self"("p_membership_id" bigint, "p_preference" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_payment_allocation_amount"("p_tenant_id" bigint, "p_allocation_id" bigint, "p_amount" numeric) RETURNS "public"."invoice_payments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_alloc public.payment_allocations;
  v_payment public.payments;
  v_invoice public.invoices;
  v_other_allocated numeric(12,2);
  v_remaining numeric(12,2);
  v_due_excluding_current numeric(12,2);
  v_delta numeric(12,2);
begin
  if p_tenant_id is null or p_allocation_id is null then
    raise exception 'Tenant and allocation are required.';
  select *
  into v_alloc
  from public.payment_allocations
  where id = p_allocation_id
  for update;

  if not found then
    raise exception 'Allocation not found.';
  if v_alloc.tenant_id <> p_tenant_id then
    raise exception 'Allocation does not belong to tenant.';
  select *
  into v_payment
  from public.payments
  where id = v_alloc.payment_id
  for update;

  select *
  into v_invoice
  from public.invoices
  where id = v_alloc.invoice_id
  for update;

  if coalesce(v_payment.billing_profile_id, 0) <> coalesce(v_invoice.billing_profile_id, 0) then
    raise exception 'Payment and invoice billing profile mismatch.';
  select coalesce(sum(amount), 0)
  into v_other_allocated
  from public.payment_allocations
  where payment_id = v_alloc.payment_id
    and id <> v_alloc.id;

  v_remaining := coalesce(v_payment.amount, 0) - coalesce(v_other_allocated, 0);
  if p_amount > v_remaining then
    raise exception 'Allocation amount exceeds payment remaining amount.';
  v_due_excluding_current :=
    coalesce(v_invoice.total_amount, 0) - (coalesce(v_invoice.paid_amount, 0) - coalesce(v_alloc.amount, 0));
  if p_amount > v_due_excluding_current then
    raise exception 'Allocation amount exceeds invoice due amount.';
  v_delta := p_amount - coalesce(v_alloc.amount, 0);

  update public.payment_allocations
  set amount = p_amount
  where id = v_alloc.id
  returning * into v_alloc;

  update public.invoices
  set paid_amount = coalesce(paid_amount, 0) + v_delta,
      updated_at = now()
  where id = v_invoice.id;

  perform public.recompute_invoice_payment_status(v_invoice.id);

  return v_alloc;
ALTER FUNCTION "public"."update_payment_allocation_amount"("p_tenant_id" bigint, "p_allocation_id" bigint, "p_amount" numeric) OWNER TO "postgres";


    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.stores;
  begin
  select tenant_id into v_tenant_id
  from public.stores
  where id = p_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  update public.stores
  set
    name = trim(p_name),
    vendor_code = nullif(trim(p_vendor_code), '')
  where id = p_id
  returning * into v_row;

  ALTER FUNCTION "public"."update_store"("p_id" bigint, "p_name" "text", "p_vendor_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_store_access"("p_id" bigint, "p_status" boolean) RETURNS "public"."store_access"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.store_access;
  begin
  select s.tenant_id into v_tenant_id
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where sa.id = p_id;

  if v_tenant_id is null then
    raise exception 'store access not found';
  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  update public.store_access
  set status = p_status
  where id = p_id
  returning * into v_row;

  ALTER FUNCTION "public"."update_store_access"("p_id" bigint, "p_status" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_store_access_fields"("p_id" bigint, "p_status" boolean DEFAULT NULL::boolean, "p_see_price" boolean DEFAULT NULL::boolean) RETURNS "public"."store_access"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.store_access;
  begin
  select s.tenant_id into v_tenant_id
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where sa.id = p_id;

  if v_tenant_id is null then
    raise exception 'store access not found';
  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  update public.store_access
  set
    status = coalesce(p_status, status),
    see_price = coalesce(p_see_price, see_price)
  where id = p_id
  returning * into v_row;

  ALTER FUNCTION "public"."update_store_access_fields"("p_id" bigint, "p_status" boolean, "p_see_price" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_tenant_for_superadmin"("p_tenant_id" bigint, "p_name" "text", "p_slug" "text", "p_is_active" boolean, "p_public_domain" "text" DEFAULT NULL::"text", "p_parent_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text", "is_active" boolean, "parent_id" bigint, "preference" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  updated as (
    update public.tenants as t
    set
      name = trim(p_name),
      slug = lower(trim(p_slug)),
      public_domain = nullif(
        regexp_replace(
          lower(
            trim(
              split_part(
                regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
                '/',
                1
              )
            )
          ),
          ':\d+$',
          ''
        ),
        ''
      ),
      is_active = coalesce(p_is_active, true),
      parent_id = p_parent_id
    from permission
    where allowed
      and t.id = p_tenant_id
    returning
      t.id,
      t.name,
      t.slug,
      t.public_domain,
      t.is_active,
      t.parent_id,
      t.preference,
      t.created_at,
      t.updated_at
  )
  select
    id,
    name,
    slug,
    public_domain,
    is_active,
    parent_id,
    preference,
    created_at,
    updated_at
  from updated;
$_$;


ALTER FUNCTION "public"."update_tenant_for_superadmin"("p_tenant_id" bigint, "p_name" "text", "p_slug" "text", "p_is_active" boolean, "p_public_domain" "text", "p_parent_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_tenant_module_for_superadmin"("p_id" bigint, "p_tenant_id" bigint DEFAULT NULL::bigint, "p_module_key" "text" DEFAULT NULL::"text", "p_is_active" boolean DEFAULT NULL::boolean) RETURNS TABLE("id" bigint, "tenant_id" bigint, "module_key" "text", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  updated as (
    update public.tenant_modules tm
    set
      tenant_id = coalesce(p_tenant_id, tm.tenant_id),
      module_key = coalesce(lower(trim(p_module_key)), tm.module_key),
      is_active = coalesce(p_is_active, tm.is_active)
    from permission
    where allowed
      and tm.id = p_id
    returning
      tm.id,
      tm.tenant_id,
      tm.module_key,
      tm.is_active,
      tm.created_at,
      tm.updated_at
  )
  select
    id,
    tenant_id,
    module_key,
    is_active,
    created_at,
    updated_at
  from updated;
ALTER FUNCTION "public"."update_tenant_module_for_superadmin"("p_id" bigint, "p_tenant_id" bigint, "p_module_key" "text", "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_tenant_preference_for_admin"("p_tenant_id" bigint, "p_preference" "jsonb") RETURNS TABLE("id" bigint, "name" "text", "slug" "text", "public_domain" "text", "is_active" boolean, "parent_id" bigint, "preference" "jsonb", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not (
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
  ) then
    return;
  if jsonb_typeof(p_preference) is distinct from 'object' then
    raise exception 'Tenant preference must be a JSON object';
  return query
  update public.tenants as t
  set preference = p_preference
  where t.id = p_tenant_id
  returning
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.parent_id,
    t.preference,
    t.created_at,
    t.updated_at;
ALTER FUNCTION "public"."update_tenant_preference_for_admin"("p_tenant_id" bigint, "p_preference" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_tenant_role"("p_role_id" bigint, "p_name" "text", "p_is_admin" boolean) RETURNS "public"."tenant_roles"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.tenant_roles;
begin
  select * into v_row from public.tenant_roles where id = p_role_id;

  if v_row.id is null then
    raise exception 'Role not found';
  if not public.user_is_tenant_admin(v_row.tenant_id) then
    raise exception 'Unauthorized';
  if p_is_admin = true and v_row.is_admin = false and exists (
    select 1 from public.tenant_roles
    where tenant_id = v_row.tenant_id and scope = v_row.scope and is_admin = true and id <> p_role_id
  ) then
    raise exception 'Only one Administrator role is allowed per scope';
  if v_row.is_system = true and v_row.is_admin <> p_is_admin then
    raise exception 'Cannot modify admin status of system roles';
  update public.tenant_roles
  set
    name = trim(p_name),
    is_admin = p_is_admin,
    updated_at = now()
  where id = p_role_id
  returning * into v_row;

  ALTER FUNCTION "public"."update_tenant_role"("p_role_id" bigint, "p_name" "text", "p_is_admin" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text" DEFAULT 'cashier'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_target TEXT;
  v_current TEXT;
  v_event_at TIMESTAMPTZ := NOW();
  v_pool_delivery NUMERIC(12,2) := 0.00;
  v_pool_cod NUMERIC(12,2) := 0.00;
  v_pool_packing NUMERIC(12,2) := 0.00;
  v_total_value NUMERIC(12,2) := 0.00;
  v_line_count INT := 0;
  v_idx INT := 0;
  v_cum_delivery NUMERIC(12,2) := 0.00;
  v_cum_cod NUMERIC(12,2) := 0.00;
  v_cum_packing NUMERIC(12,2) := 0.00;
  v_line RECORD;
  v_line_value NUMERIC(12,2);
  v_share NUMERIC;
  v_alloc_delivery NUMERIC(12,2);
  v_alloc_cod NUMERIC(12,2);
  v_alloc_packing NUMERIC(12,2);
  v_inbound_shipment_id BIGINT;
  v_pnl_exists BOOLEAN := FALSE;
  v_non_delivered_pnl INT := 0;
  v_deleted_pnl INT := 0;
  v_economics_closed_at TIMESTAMPTZ;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
     AND NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return')
  THEN
    RAISE EXCEPTION 'Updating delivery status requires thrift_sales create or return permission';
  END IF;

  v_target := upper(trim(COALESCE(p_delivery_status, '')));
  IF v_target NOT IN ('PENDING', 'READY', 'IN_TRANSIT', 'DELIVERED', 'RETURNED') THEN
    RAISE EXCEPTION 'Invalid delivery_status: %', p_delivery_status;
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF COALESCE(v_invoice.sale_channel, 'IN_STORE') <> 'ONLINE' THEN
    RAISE EXCEPTION 'delivery_status applies to Online invoices only';
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Cannot update delivery on invoice status %', v_invoice.status;
  END IF;

  IF v_target = 'RETURNED' THEN
    RAISE EXCEPTION
      'Set delivery RETURNED via revert_thrift_sales_invoice (RTO), not delivery advance';
  END IF;

  v_current := COALESCE(v_invoice.delivery_status, 'PENDING');
  v_economics_closed_at := v_invoice.economics_closed_at;

  IF v_current = v_target THEN
    RETURN jsonb_build_object(
      'id', v_invoice.id,
      'delivery_status', v_current,
      'unchanged', true,
      'economics_closed_at', v_invoice.economics_closed_at
    );
  END IF;

  -- Correction: undo mistaken deliver (only to IN_TRANSIT; reopen economics).
  IF v_current = 'DELIVERED' AND v_target = 'IN_TRANSIT' THEN
    SELECT COUNT(*)::INT
    INTO v_non_delivered_pnl
    FROM public.thrift_sales_pnl_lines p
    WHERE p.tenant_id = p_tenant_id
      AND p.invoice_id = p_invoice_id
      AND p.outcome IS DISTINCT FROM 'DELIVERED';

    IF v_non_delivered_pnl > 0 THEN
      RAISE EXCEPTION
        'Cannot move delivery from DELIVERED to IN_TRANSIT after return/RTO PnL exists';
    END IF;

    DELETE FROM public.thrift_sales_pnl_lines p
    WHERE p.tenant_id = p_tenant_id
      AND p.invoice_id = p_invoice_id
      AND p.outcome = 'DELIVERED';

    GET DIAGNOSTICS v_deleted_pnl = ROW_COUNT;

    UPDATE public.thrift_sales_invoices
    SET
      delivery_status = 'IN_TRANSIT',
      economics_closed_at = NULL,
      updated_at = NOW()
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;

    RETURN jsonb_build_object(
      'id', p_invoice_id,
      'delivery_status', 'IN_TRANSIT',
      'previous_delivery_status', v_current,
      'actor', COALESCE(NULLIF(trim(p_actor), ''), 'cashier'),
      'unchanged', false,
      'pnl_lines_deleted', v_deleted_pnl,
      'economics_closed_at', NULL
    );
  END IF;

  IF v_current = 'DELIVERED' AND v_target <> 'DELIVERED' THEN
    RAISE EXCEPTION 'Cannot move delivery from DELIVERED to %', v_target;
  END IF;

  UPDATE public.thrift_sales_invoices
  SET
    delivery_status = v_target,
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  -- First DELIVERED: write PnL (shop-paid fee pools only). Never flip payment_status.
  IF v_target = 'DELIVERED' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.thrift_sales_pnl_lines p
      WHERE p.tenant_id = p_tenant_id
        AND p.invoice_id = p_invoice_id
    )
    INTO v_pnl_exists;

    IF NOT v_pnl_exists THEN
      v_pool_delivery := CASE
        WHEN upper(COALESCE(v_invoice.courier_paid_by, '')) = 'SHOP'
        THEN ROUND(COALESCE(v_invoice.courier_amount, 0), 2)
        ELSE 0.00
      END;
      v_pool_cod := CASE
        WHEN upper(COALESCE(v_invoice.cod_fee_paid_by, '')) = 'SHOP'
        THEN ROUND(COALESCE(v_invoice.cod_fee_amount, 0), 2)
        ELSE 0.00
      END;
      v_pool_packing := CASE
        WHEN upper(COALESCE(v_invoice.packing_paid_by, '')) = 'SHOP'
        THEN ROUND(COALESCE(v_invoice.packing_amount, 0), 2)
        ELSE 0.00
      END;

      SELECT
        COALESCE(SUM(ROUND(i.final_price * i.quantity, 2)), 0),
        COUNT(*)::INT
      INTO v_total_value, v_line_count
      FROM public.thrift_sales_invoice_items i
      WHERE i.tenant_id = p_tenant_id
        AND i.invoice_id = p_invoice_id;

      IF v_line_count = 0 THEN
        RAISE EXCEPTION 'Invoice % has no lines; cannot close economics', p_invoice_id;
      END IF;

      FOR v_line IN
        SELECT
          i.id AS invoice_item_id,
          i.stock_id,
          i.quantity,
          ROUND(i.final_price * i.quantity, 2) AS sell_amount,
          s.shipment_id
        FROM public.thrift_sales_invoice_items i
        JOIN public.thrift_stocks s
          ON s.id = i.stock_id
         AND s.tenant_id = i.tenant_id
        WHERE i.tenant_id = p_tenant_id
          AND i.invoice_id = p_invoice_id
        ORDER BY i.id
      LOOP
        v_idx := v_idx + 1;
        v_inbound_shipment_id := v_line.shipment_id;
        IF v_inbound_shipment_id IS NULL THEN
          RAISE EXCEPTION
            'Stock item % has no inbound shipment; cannot write PnL',
            v_line.stock_id;
        END IF;

        v_line_value := v_line.sell_amount;
        IF v_total_value > 0 THEN
          v_share := v_line_value / v_total_value;
        ELSE
          v_share := 1.0 / v_line_count;
        END IF;

        IF v_idx = v_line_count THEN
          v_alloc_delivery := ROUND(v_pool_delivery - v_cum_delivery, 2);
          v_alloc_cod := ROUND(v_pool_cod - v_cum_cod, 2);
          v_alloc_packing := ROUND(v_pool_packing - v_cum_packing, 2);
        ELSE
          v_alloc_delivery := ROUND(v_pool_delivery * v_share, 2);
          v_alloc_cod := ROUND(v_pool_cod * v_share, 2);
          v_alloc_packing := ROUND(v_pool_packing * v_share, 2);
          v_cum_delivery := v_cum_delivery + v_alloc_delivery;
          v_cum_cod := v_cum_cod + v_alloc_cod;
          v_cum_packing := v_cum_packing + v_alloc_packing;
        END IF;

        INSERT INTO public.thrift_sales_pnl_lines (
          tenant_id,
          invoice_id,
          invoice_item_id,
          stock_id,
          inbound_shipment_id,
          outcome,
          return_id,
          quantity,
          sell_amount,
          allocated_shop_delivery,
          allocated_shop_cod_fee,
          allocated_shop_packing,
          allocated_return_courier,
          allocated_fees_total,
          cogs_is_loss,
          event_at,
          event_date
        ) VALUES (
          p_tenant_id,
          p_invoice_id,
          v_line.invoice_item_id,
          v_line.stock_id,
          v_inbound_shipment_id,
          'DELIVERED',
          NULL,
          v_line.quantity,
          v_line_value,
          v_alloc_delivery,
          v_alloc_cod,
          v_alloc_packing,
          0.00,
          ROUND(v_alloc_delivery + v_alloc_cod + v_alloc_packing, 2),
          FALSE,
          v_event_at,
          (v_event_at AT TIME ZONE 'UTC')::DATE
        );
      END LOOP;

      UPDATE public.thrift_sales_invoices
      SET
        economics_closed_at = v_event_at,
        updated_at = NOW()
      WHERE id = p_invoice_id
        AND tenant_id = p_tenant_id;

      v_economics_closed_at := v_event_at;
    ELSIF v_invoice.economics_closed_at IS NULL THEN
      UPDATE public.thrift_sales_invoices
      SET
        economics_closed_at = v_event_at,
        updated_at = NOW()
      WHERE id = p_invoice_id
        AND tenant_id = p_tenant_id;

      v_economics_closed_at := v_event_at;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'id', p_invoice_id,
    'delivery_status', v_target,
    'previous_delivery_status', v_current,
    'actor', COALESCE(NULLIF(trim(p_actor), ''), 'cashier'),
    'unchanged', false,
    'economics_closed_at', CASE
      WHEN v_target = 'DELIVERED' THEN COALESCE(v_economics_closed_at, v_event_at)
      ELSE v_economics_closed_at
    END
  );
END;
ALTER FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") IS 'Advance Online parcel status. First DELIVERED inserts thrift_sales_pnl_lines (shop-paid fees) and sets economics_closed_at. DELIVERED→IN_TRANSIT deletes DELIVERED PnL and clears economics_closed_at. Never changes payment_status. RETURNED requires revert RTO.';


CREATE TABLE IF NOT EXISTS "public"."customer_group_member_grants" (
    "id" bigint NOT NULL,
    "customer_group_member_id" bigint NOT NULL,
    "module_key" "text" NOT NULL,
    "action" "text" NOT NULL,
    "effect" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "customer_group_member_grants_effect_check" CHECK (("effect" = ANY (ARRAY['allow'::"text", 'deny'::"text"])))
);


ALTER TABLE "public"."customer_group_member_grants" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_customer_group_member_grant"("p_cgm_id" bigint, "p_module_key" "text", "p_action" "text", "p_effect" "text") RETURNS "public"."customer_group_member_grants"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_member public.customer_group_members;
  v_group public.customer_groups;
  v_row public.customer_group_member_grants;
begin
  select * into v_member from public.customer_group_members where id = p_cgm_id;
  if v_member.id is null then
    raise exception 'Customer group member not found';
  select * into v_group from public.customer_groups where id = v_member.customer_group_id;
  if v_group.id is null then
    raise exception 'Customer group not found';
  if not public.user_is_tenant_admin(v_group.tenant_id) then
    raise exception 'Unauthorized';
  if p_effect not in ('allow', 'deny') then
    raise exception 'Invalid effect: %', p_effect;
  if not (p_module_key = any(public.get_active_module_keys_for_tenant(v_group.tenant_id))) then
    raise exception 'Module is not active for this tenant';
  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  insert into public.customer_group_member_grants (
    customer_group_member_id,
    module_key,
    action,
    effect
  )
  values (
    p_cgm_id,
    p_module_key,
    p_action,
    p_effect
  )
  on conflict (customer_group_member_id, module_key, action) do update set
    effect = excluded.effect
  returning * into v_row;

  perform public.bump_tenant_permission_version(v_group.tenant_id);
  ALTER FUNCTION "public"."upsert_customer_group_member_grant"("p_cgm_id" bigint, "p_module_key" "text", "p_action" "text", "p_effect" "text") OWNER TO "postgres";


    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "phone" "text",
    "email" "text",
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "notes" "text"
);


ALTER TABLE "public"."investors" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_investor_profile"("p_id" bigint, "p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_is_active" boolean, "p_currency_code" "text", "p_notes" "text") RETURNS "public"."investors"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.investors;
  v_action text;
begin
  v_action := case when p_id is null then 'create' else 'edit' end;
  if not public.membership_has_module_action(p_tenant_id, 'investor_profiles', v_action) then
    raise exception 'not allowed';
  if p_id is not null then
    update public.investors
    set
      name = p_name,
      phone = p_phone,
      email = p_email,
      address = p_address,
      is_active = p_is_active,
      currency_code = p_currency_code,
      notes = p_notes,
      updated_at = now()
    where id = p_id and tenant_id = p_tenant_id
    returning * into v_row;
  else
    insert into public.investors (
      tenant_id, name, phone, email, address, is_active, currency_code, notes
    ) values (
      p_tenant_id, p_name, p_phone, p_email, p_address, p_is_active, p_currency_code, p_notes
    )
    returning * into v_row;
  ALTER FUNCTION "public"."upsert_investor_profile"("p_id" bigint, "p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_is_active" boolean, "p_currency_code" "text", "p_notes" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."membership_grants" (
    "id" bigint NOT NULL,
    "membership_id" bigint NOT NULL,
    "module_key" "text" NOT NULL,
    "action" "text" NOT NULL,
    "effect" "text" NOT NULL,
    "created_by_email" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "membership_grants_effect_check" CHECK (("effect" = ANY (ARRAY['allow'::"text", 'deny'::"text"])))
);


ALTER TABLE "public"."membership_grants" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_membership_grant"("p_membership_id" bigint, "p_module_key" "text", "p_action" "text", "p_effect" "text") RETURNS "public"."membership_grants"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_member public.memberships;
  v_row public.membership_grants;
begin
  select * into v_member from public.memberships where id = p_membership_id;
  if v_member.id is null then
    raise exception 'Membership not found';
  if not public.user_is_tenant_admin(v_member.tenant_id) then
    raise exception 'Unauthorized';
  if p_effect not in ('allow', 'deny') then
    raise exception 'Invalid effect: %', p_effect;
  if not (p_module_key = any(public.get_active_module_keys_for_tenant(v_member.tenant_id))) then
    raise exception 'Module is not active for this tenant';
  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  insert into public.membership_grants (
    membership_id,
    module_key,
    action,
    effect,
    created_by_email
  )
  values (
    p_membership_id,
    p_module_key,
    p_action,
    p_effect,
    public.current_user_email()
  )
  on conflict (membership_id, module_key, action) do update set
    effect = excluded.effect,
    created_by_email = excluded.created_by_email,
    updated_at = now()
  returning * into v_row;

  perform public.bump_tenant_permission_version(v_member.tenant_id);
  ALTER FUNCTION "public"."upsert_membership_grant"("p_membership_id" bigint, "p_module_key" "text", "p_action" "text", "p_effect" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_recipient_profile_and_address"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_phone_secondary" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_district" "text" DEFAULT NULL::"text", "p_thana" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return public.upsert_recipient_profile_by_phone(
    p_tenant_id => p_tenant_id,
    p_name => p_name,
    p_phone => p_phone,
    p_secondary_phone => p_phone_secondary,
    p_address => p_address,
    p_district => p_district,
    p_thana => p_thana
  );
ALTER FUNCTION "public"."upsert_recipient_profile_and_address"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_phone_secondary" "text", "p_address" "text", "p_district" "text", "p_thana" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_recipient_profile_by_phone"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_secondary_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_district" "text" DEFAULT NULL::"text", "p_thana" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_phone text;
  v_secondary text;
  v_name text;
  v_address text;
  v_district text;
  v_thana text;
  v_entry jsonb;
  v_addresses jsonb;
  v_next jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_matched boolean := false;
  v_phone := public.normalize_bd_mobile(p_phone);
  v_name := nullif(trim(coalesce(p_name, '')), '');
  if v_name is null then
    raise exception 'Recipient name is required';
  v_address := nullif(trim(coalesce(p_address, '')), '');
  if v_address is null then
    raise exception 'Recipient address is required';
  v_district := nullif(trim(coalesce(p_district, '')), '');
  v_thana := nullif(trim(coalesce(p_thana, '')), '');

  if nullif(trim(coalesce(p_secondary_phone, '')), '') is not null then
    begin
      v_secondary := public.normalize_bd_mobile(p_secondary_phone);
    exception when others then
      v_secondary := nullif(trim(p_secondary_phone), '');
    else
    v_secondary := null;
  v_entry := jsonb_build_object(
    'id', gen_random_uuid()::text,
    'line', v_address,
    'district', v_district,
    'thana', v_thana,
    'is_default', true,
    'updated_at', now()
  );

  select * into v_row
  from public.recipient_profiles
  where tenant_id = p_tenant_id and phone = v_phone
  for update;

  if v_row.id is null then
    insert into public.recipient_profiles (
      tenant_id, name, phone, secondary_phone, address, district, thana, addresses
    )
    values (
      p_tenant_id, v_name, v_phone, v_secondary, v_address, v_district, v_thana,
      jsonb_build_array(v_entry)
    )
    returning * into v_row;
  else
    v_addresses := coalesce(v_row.addresses, '[]'::jsonb);
    v_next := '[]'::jsonb;
    v_matched := false;

    for v_elem in select * from jsonb_array_elements(v_addresses)
    loop
      if v_elem->>'line' = v_address then
        v_matched := true;
        v_next := v_next || jsonb_build_array(
          jsonb_build_object(
            'id', coalesce(v_elem->>'id', gen_random_uuid()::text),
            'line', v_address,
            'district', v_district,
            'thana', v_thana,
            'is_default', true,
            'updated_at', now()
          )
        );
      else
        v_next := v_next || jsonb_build_array(
          jsonb_set(v_elem, '{is_default}', 'false'::jsonb)
        );
      if not v_matched then
      v_next := v_next || jsonb_build_array(v_entry);
    update public.recipient_profiles
    set
      name = v_name,
      secondary_phone = coalesce(v_secondary, secondary_phone),
      address = v_address,
      district = v_district,
      thana = v_thana,
      addresses = v_next,
      updated_at = now()
    where id = v_row.id
    returning * into v_row;
  ALTER FUNCTION "public"."upsert_recipient_profile_by_phone"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_secondary_phone" "text", "p_address" "text", "p_district" "text", "p_thana" "text") OWNER TO "postgres";


    "id" bigint NOT NULL,
    "tenant_role_id" bigint NOT NULL,
    "module_key" "text" NOT NULL,
    "action" "text" NOT NULL,
    "allowed" boolean NOT NULL,
    "updated_by_email" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."tenant_role_grants" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_tenant_role_grant"("p_tenant_role_id" bigint, "p_module_key" "text", "p_action" "text", "p_allowed" boolean) RETURNS "public"."tenant_role_grants"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_role public.tenant_roles;
  v_row public.tenant_role_grants;
begin
  select * into v_role from public.tenant_roles where id = p_tenant_role_id;

  if v_role.id is null then
    raise exception 'Role not found';
  if not public.user_is_tenant_admin(v_role.tenant_id) then
    raise exception 'Unauthorized';
  if v_role.is_admin = true then
    raise exception 'Cannot assign explicit grants to an Administrator role';
  if not (p_module_key = any(public.get_active_module_keys_for_tenant(v_role.tenant_id))) then
    raise exception 'Module is not active for this tenant';
  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  insert into public.tenant_role_grants (
    tenant_role_id,
    module_key,
    action,
    allowed,
    updated_by_email
  )
  values (
    p_tenant_role_id,
    p_module_key,
    p_action,
    p_allowed,
    public.current_user_email()
  )
  on conflict (tenant_role_id, module_key, action) do update set
    allowed = excluded.allowed,
    updated_by_email = excluded.updated_by_email,
    updated_at = now()
  returning * into v_row;

  ALTER FUNCTION "public"."upsert_tenant_role_grant"("p_tenant_role_id" bigint, "p_module_key" "text", "p_action" "text", "p_allowed" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_can_access_tenant_fetch"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      where cg.tenant_id = p_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
        and cg.is_active = true
    );
ALTER FUNCTION "public"."user_can_access_tenant_fetch"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_can_manage_parent_tenant"("p_parent_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'admin'
        or public.has_module_action(p_parent_tenant_id, 'procurement_stock', 'manage')
      )
  );
ALTER FUNCTION "public"."user_can_manage_parent_tenant"("p_parent_tenant_id" bigint) OWNER TO "postgres";


    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if public.is_superadmin() then
    return true;
  return exists (
    select 1
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'admin'
        or tr.is_admin = true
      )
  );
ALTER FUNCTION "public"."user_is_tenant_admin"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."activity_logs" (
    "id" bigint NOT NULL,
    "item_id" bigint NOT NULL,
    "user_email" "text" DEFAULT "public"."current_user_email"() NOT NULL,
    "action" "text" NOT NULL,
    "old_value" "text",
    "new_value" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."activity_logs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."activity_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."activity_logs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."activity_logs_id_seq" OWNED BY "public"."activity_logs"."id";


CREATE TABLE IF NOT EXISTS "public"."batch_code_pc" (
    "id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "shipment_item_id" bigint,
    "product_code" "text",
    "batch_id" "text",
    "manufacturing_date" "date",
    "expire_date" "date",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."batch_code_pc" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."batch_code_pc_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."batch_code_pc_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."batch_code_pc_id_seq" OWNED BY "public"."batch_code_pc"."id";


CREATE TABLE IF NOT EXISTS "public"."business_parties" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "phone" "text",
    "email" "text",
    "address" "text",
    "party_type" "text" DEFAULT 'customer'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "business_parties_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "business_parties_party_type_check" CHECK (("party_type" = ANY (ARRAY['customer'::"text", 'recipient'::"text", 'ordered_by'::"text", 'other'::"text"])))
);


ALTER TABLE "public"."business_parties" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."business_parties_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."business_parties_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."business_parties_id_seq" OWNED BY "public"."business_parties"."id";


CREATE TABLE IF NOT EXISTS "public"."cargo_companies" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "parent_tenant_id" bigint,
    "name" "text" NOT NULL,
    "code" "text" NOT NULL,
    "phone" "text",
    "email" "text",
    "address" "text",
    "notes" "text",
    "wallet_entity_id" bigint,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    CONSTRAINT "cargo_companies_code_not_blank" CHECK (("length"(TRIM(BOTH FROM "code")) > 0)),
    CONSTRAINT "cargo_companies_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0))
);


ALTER TABLE "public"."cargo_companies" OWNER TO "postgres";


COMMENT ON COLUMN "public"."cargo_companies"."is_default" IS 'True for the tenant system default cargo company (code DEFAULT). At most one per tenant_id.';


CREATE SEQUENCE IF NOT EXISTS "public"."cargo_companies_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."cargo_companies_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."cargo_companies_id_seq" OWNED BY "public"."cargo_companies"."id";


CREATE TABLE IF NOT EXISTS "public"."cart_items" (
    "id" bigint NOT NULL,
    "cart_id" bigint NOT NULL,
    "product_id" bigint,
    "name" "text" NOT NULL,
    "image_url" "text",
    "price_gbp" numeric(12,2),
    "quantity" integer DEFAULT 1 NOT NULL,
    "minimum_quantity" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "price_bdt" numeric(12,2),
    "minimum_sell_price_bdt" numeric(12,2),
    CONSTRAINT "cart_items_minimum_quantity_check" CHECK (("minimum_quantity" > 0)),
    CONSTRAINT "cart_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."cart_items" OWNER TO "postgres";


COMMENT ON TABLE "public"."cart_items" IS 'Shopping cart line items. Stores snapshot values plus optional product reference.';


CREATE SEQUENCE IF NOT EXISTS "public"."cart_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."cart_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."cart_items_id_seq" OWNED BY "public"."cart_items"."id";


CREATE TABLE IF NOT EXISTS "public"."carts" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "store_id" bigint,
    "customer_group_id" bigint,
    "can_see_price" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."carts" OWNER TO "postgres";


COMMENT ON TABLE "public"."carts" IS 'Shopping cart header table. Stores tenant, store, customer group and visibility settings.';


CREATE SEQUENCE IF NOT EXISTS "public"."carts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."carts_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."carts_id_seq" OWNED BY "public"."carts"."id";


CREATE TABLE IF NOT EXISTS "public"."comments" (
    "id" bigint NOT NULL,
    "item_id" bigint NOT NULL,
    "parent_comment_id" bigint,
    "user_email" "text" DEFAULT "public"."current_user_email"() NOT NULL,
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deleted_at" timestamp with time zone
);


ALTER TABLE "public"."comments" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."comments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."comments_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."comments_id_seq" OWNED BY "public"."comments"."id";


CREATE TABLE IF NOT EXISTS "public"."commerce_cart" (
    "id" bigint NOT NULL,
    "product_id" bigint,
    "tenant_id" bigint NOT NULL,
    "customer_group_id" bigint NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "inventory_item_id" bigint,
    "global_stock_id" bigint,
    CONSTRAINT "commerce_cart_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."commerce_cart" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."commerce_cart_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."commerce_cart_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."commerce_cart_id_seq" OWNED BY "public"."commerce_cart"."id";


CREATE TABLE IF NOT EXISTS "public"."commerce_inventory_product_summaries" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "product_id" bigint NOT NULL,
    "available_quantity" integer DEFAULT 0 NOT NULL,
    "reserved_quantity" integer DEFAULT 0 NOT NULL,
    "damaged_quantity" integer DEFAULT 0 NOT NULL,
    "stolen_quantity" integer DEFAULT 0 NOT NULL,
    "expired_quantity" integer DEFAULT 0 NOT NULL,
    "open_box_quantity" integer DEFAULT 0 NOT NULL,
    "usable_quantity" integer DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."commerce_inventory_product_summaries" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."commerce_inventory_product_summaries_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."commerce_inventory_product_summaries_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."commerce_inventory_product_summaries_id_seq" OWNED BY "public"."commerce_inventory_product_summaries"."id";


CREATE TABLE IF NOT EXISTS "public"."commerce_invoice_boxes" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "box_number" "text" NOT NULL,
    "weight" numeric(10,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "commerce_invoice_boxes_weight_check" CHECK (("weight" >= (0)::numeric))
);


ALTER TABLE "public"."commerce_invoice_boxes" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."commerce_invoice_boxes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."commerce_invoice_boxes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."commerce_invoice_boxes_id_seq" OWNED BY "public"."commerce_invoice_boxes"."id";


CREATE TABLE IF NOT EXISTS "public"."commerce_invoices" (
    "id" bigint NOT NULL,
    "order_id" bigint,
    "delivery_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "total_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "amount_paid" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "amount_due" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "is_customer_group_paid" boolean DEFAULT false NOT NULL,
    "delivered_by" "text",
    "tenant_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "wrapping_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "cod" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "billing_profile_id" bigint,
    "invoice_type" "text" DEFAULT 'retail'::"text" NOT NULL,
    "invoice_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "brand_name" "text",
    "brand_address" "text",
    "total_boxes" integer,
    "advance_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "previous_due" numeric(12,2) DEFAULT 0 NOT NULL,
    "thank_you_message" "text",
    "client_name" "text",
    "client_tr" "text",
    "print_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "recipient_name" "text",
    "recipient_phone" "text",
    "shipping_address" "text",
    "note" "text",
    CONSTRAINT "commerce_invoice_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'invoicing'::"text", 'issued'::"text", 'partially_paid'::"text", 'paid'::"text", 'overdue'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "commerce_invoices_discount_amount_check" CHECK (("discount_amount" >= (0)::numeric)),
    CONSTRAINT "commerce_invoices_invoice_type_check" CHECK (("invoice_type" = ANY (ARRAY['retail'::"text", 'wholesale'::"text"])))
);


ALTER TABLE "public"."commerce_invoices" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."commerce_invoices_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."commerce_invoices_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."commerce_invoices_id_seq" OWNED BY "public"."commerce_invoices"."id";


CREATE TABLE IF NOT EXISTS "public"."commerce_order_items" (
    "id" bigint NOT NULL,
    "order_id" bigint,
    "product_id" bigint NOT NULL,
    "image_url" "text",
    "cost_bdt" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "sell_price_bdt" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "recipient_price_bdt" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "invoice_id" bigint,
    "phone_invite_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "inventory_item_id" bigint,
    "shipment_item_id" bigint,
    "unit" "text" DEFAULT 'pcs'::"text" NOT NULL,
    "global_stock_id" bigint,
    CONSTRAINT "check_order_or_invoice_not_null" CHECK ((("order_id" IS NOT NULL) OR ("invoice_id" IS NOT NULL))),
    CONSTRAINT "commerce_order_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."commerce_order_items" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."commerce_order_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."commerce_order_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."commerce_order_items_id_seq" OWNED BY "public"."commerce_order_items"."id";


CREATE TABLE IF NOT EXISTS "public"."commerce_order_settings" (
    "tenant_id" bigint NOT NULL,
    "default_cod_percent" numeric(5,2) DEFAULT 0.00 NOT NULL,
    "default_delivery_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "default_wrapping_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "default_invoice_print_charge" numeric(12,2) DEFAULT 0.00 NOT NULL
);


ALTER TABLE "public"."commerce_order_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."commerce_orders" (
    "id" bigint NOT NULL,
    "recipient_name" "text" NOT NULL,
    "recipient_phone" "text",
    "shipping_address" "text",
    "shipment_payment" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "invoice_print_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "wrapping_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "cod" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "tenant_id" bigint NOT NULL,
    "order_placement_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "shipment_date" timestamp with time zone,
    "delivery_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "status" "public"."commerce_order_status" DEFAULT 'placed'::"public"."commerce_order_status" NOT NULL,
    "invoice_ids" bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "customer_group_id" bigint,
    "is_delivery_charge_inclusive" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."commerce_orders" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."commerce_orders_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."commerce_orders_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."commerce_orders_id_seq" OWNED BY "public"."commerce_orders"."id";


CREATE TABLE IF NOT EXISTS "public"."courier_remittance_batches" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "courier_service_id" "uuid" NOT NULL,
    "batch_no" "text" NOT NULL,
    "bank_trx_id" "text",
    "payment_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "gross_cod_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "courier_charges_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "net_deposited_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "variance_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "note" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "posted_at" timestamp with time zone,
    "posted_by" "uuid",
    CONSTRAINT "courier_remittance_batches_allocated_amount_check" CHECK (("allocated_amount" >= (0)::numeric)),
    CONSTRAINT "courier_remittance_batches_courier_charges_amount_check" CHECK (("courier_charges_amount" >= (0)::numeric)),
    CONSTRAINT "courier_remittance_batches_gross_cod_amount_check" CHECK (("gross_cod_amount" >= (0)::numeric)),
    CONSTRAINT "courier_remittance_batches_net_deposited_amount_check" CHECK (("net_deposited_amount" >= (0)::numeric)),
    CONSTRAINT "courier_remittance_batches_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'posted'::"text", 'voided'::"text"])))
);


ALTER TABLE "public"."courier_remittance_batches" OWNER TO "postgres";


ALTER TABLE "public"."courier_remittance_batches" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."courier_remittance_batches_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."courier_remittance_items" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "batch_id" bigint NOT NULL,
    "shop_order_id" bigint,
    "global_invoice_id" bigint,
    "tracking_number" "text",
    "awb_number" "text",
    "cod_collected_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "courier_charge_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "net_remitted_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "status" "text" DEFAULT 'matched'::"text" NOT NULL,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "courier_remittance_items_cod_collected_amount_check" CHECK (("cod_collected_amount" >= (0)::numeric)),
    CONSTRAINT "courier_remittance_items_courier_charge_amount_check" CHECK (("courier_charge_amount" >= (0)::numeric)),
    CONSTRAINT "courier_remittance_items_net_remitted_amount_check" CHECK (("net_remitted_amount" >= (0)::numeric)),
    CONSTRAINT "courier_remittance_items_status_check" CHECK (("status" = ANY (ARRAY['matched'::"text", 'unmatched'::"text", 'processed'::"text", 'error'::"text"])))
);


ALTER TABLE "public"."courier_remittance_items" OWNER TO "postgres";


ALTER TABLE "public"."courier_remittance_items" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."courier_remittance_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE SEQUENCE IF NOT EXISTS "public"."courier_wallet_entity_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."courier_wallet_entity_id_seq" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."courier_services" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" bigint,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "cod_fee_mode" "text" DEFAULT 'percent_of_collect'::"text" NOT NULL,
    "cod_fee_percent" numeric(5,2) DEFAULT 0.00,
    "cod_fee_flat_amount" numeric(12,2) DEFAULT 0.00,
    "cod_fee_notes" "text",
    "deduct_cod_from_margin_default" boolean DEFAULT false NOT NULL,
    "inside_dhaka_fee" numeric(12,2) DEFAULT 60.00 NOT NULL,
    "outside_dhaka_fee" numeric(12,2) DEFAULT 120.00 NOT NULL,
    "inside_dhaka_return_fee" numeric(12,2) DEFAULT 30.00,
    "outside_dhaka_return_fee" numeric(12,2) DEFAULT 60.00,
    "return_fee_mode" "text" DEFAULT 'flat'::"text" NOT NULL,
    "return_fee_percent" numeric(5,2) DEFAULT 0.00,
    "delivery_attempt_count" integer DEFAULT 2 NOT NULL,
    "hub_hold_days" integer DEFAULT 3 NOT NULL,
    "open_box_default_allowed" boolean DEFAULT false NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tracking_url_template" "text",
    "wallet_entity_id" bigint DEFAULT "nextval"('"public"."courier_wallet_entity_id_seq"'::"regclass") NOT NULL,
    CONSTRAINT "courier_services_cod_fee_mode_check" CHECK (("cod_fee_mode" = ANY (ARRAY['none'::"text", 'percent_of_collect'::"text", 'flat'::"text", 'tiered_manual'::"text"]))),
    CONSTRAINT "courier_services_return_fee_mode_check" CHECK (("return_fee_mode" = ANY (ARRAY['none'::"text", 'percent_of_forward'::"text", 'flat'::"text", 'tiered_manual'::"text"])))
);


ALTER TABLE "public"."courier_services" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."customer_group_member_grants_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."customer_group_member_grants_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."customer_group_member_grants_id_seq" OWNED BY "public"."customer_group_member_grants"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."customer_group_members_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."customer_group_members_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."customer_group_members_id_seq" OWNED BY "public"."customer_group_members"."id";


    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "tenant_id" bigint NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "accent_color" "text"
);


ALTER TABLE "public"."customer_groups" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."customer_groups_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."customer_groups_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."customer_groups_id_seq" OWNED BY "public"."customer_groups"."id";


CREATE TABLE IF NOT EXISTS "public"."customer_order_backlog_items" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "billing_profile_id" bigint NOT NULL,
    "product_id" bigint NOT NULL,
    "order_id" bigint,
    "order_item_id" bigint,
    "requested_quantity" integer NOT NULL,
    "fulfilled_quantity" integer DEFAULT 0 NOT NULL,
    "backlog_status" "text" DEFAULT 'open'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "customer_order_backlog_items_backlog_status_check" CHECK (("backlog_status" = ANY (ARRAY['open'::"text", 'partially_fulfilled'::"text", 'fulfilled'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "customer_order_backlog_items_fulfilled_quantity_check" CHECK (("fulfilled_quantity" >= 0)),
    CONSTRAINT "customer_order_backlog_items_requested_quantity_check" CHECK (("requested_quantity" > 0))
);


ALTER TABLE "public"."customer_order_backlog_items" OWNER TO "postgres";


ALTER TABLE "public"."customer_order_backlog_items" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."customer_order_backlog_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."entity_tags" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "tag_id" bigint NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."entity_tags" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."entity_tags_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."entity_tags_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."entity_tags_id_seq" OWNED BY "public"."entity_tags"."id";


CREATE TABLE IF NOT EXISTS "public"."gift_rule_items" (
    "id" bigint NOT NULL,
    "rule_id" bigint NOT NULL,
    "product_id" bigint NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "gift_rule_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."gift_rule_items" OWNER TO "postgres";


ALTER TABLE "public"."gift_rule_items" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."gift_rule_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."gift_rule_redemptions" (
    "id" bigint NOT NULL,
    "order_id" bigint NOT NULL,
    "rule_id" bigint NOT NULL,
    "redeemed_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."gift_rule_redemptions" OWNER TO "postgres";


ALTER TABLE "public"."gift_rule_redemptions" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."gift_rule_redemptions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."gift_rules" (
    "id" bigint NOT NULL,
    "name" character varying(255) NOT NULL,
    "customer_group_id" bigint,
    "cost_ownership" character varying(50) DEFAULT 'tenant'::character varying NOT NULL,
    "priority" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "gift_rules_cost_ownership_check" CHECK ((("cost_ownership")::"text" = ANY ((ARRAY['tenant'::character varying, 'middleman'::character varying, 'split'::character varying])::"text"[])))
);


ALTER TABLE "public"."gift_rules" OWNER TO "postgres";


ALTER TABLE "public"."gift_rules" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."gift_rules_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE TABLE IF NOT EXISTS "public"."global_currencies" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "country" "text" NOT NULL,
    "code" "text" NOT NULL,
    "symbol" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_system" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."global_currencies" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."global_currencies_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."global_currencies_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."global_currencies_id_seq" OWNED BY "public"."global_currencies"."id";


CREATE TABLE IF NOT EXISTS "public"."investor_balances" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "investor_id" bigint NOT NULL,
    "total_deposit" numeric(12,2) DEFAULT 0 NOT NULL,
    "total_withdrawal" numeric(12,2) DEFAULT 0 NOT NULL,
    "total_profit_payout" numeric(12,2) DEFAULT 0 NOT NULL,
    "total_invested_active" numeric(12,2) DEFAULT 0 NOT NULL,
    "available_balance" numeric(12,2) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "investor_balances_total_deposit_check" CHECK (("total_deposit" >= (0)::numeric)),
    CONSTRAINT "investor_balances_total_invested_active_check" CHECK (("total_invested_active" >= (0)::numeric)),
    CONSTRAINT "investor_balances_total_profit_payout_check" CHECK (("total_profit_payout" >= (0)::numeric)),
    CONSTRAINT "investor_balances_total_withdrawal_check" CHECK (("total_withdrawal" >= (0)::numeric))
);


ALTER TABLE "public"."investor_balances" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."investor_balances_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."investor_balances_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."investor_balances_id_seq" OWNED BY "public"."investor_balances"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."investor_transactions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."investor_transactions_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."investor_transactions_id_seq" OWNED BY "public"."investor_transactions"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."investors_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."investors_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."investors_id_seq" OWNED BY "public"."investors"."id";


CREATE TABLE IF NOT EXISTS "public"."invoice_boxes" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "box_number" "text" NOT NULL,
    "weight" numeric(10,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "invoice_boxes_weight_check" CHECK (("weight" >= (0)::numeric))
);


ALTER TABLE "public"."invoice_boxes" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."invoice_boxes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."invoice_boxes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."invoice_boxes_id_seq" OWNED BY "public"."invoice_boxes"."id";


CREATE TABLE IF NOT EXISTS "public"."item_assignees" (
    "id" bigint NOT NULL,
    "item_id" bigint NOT NULL,
    "user_email" "text" NOT NULL,
    "assigned_by_email" "text" DEFAULT "public"."current_user_email"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."item_assignees" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."item_assignees_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."item_assignees_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."item_assignees_id_seq" OWNED BY "public"."item_assignees"."id";


CREATE TABLE IF NOT EXISTS "public"."item_permissions" (
    "id" bigint NOT NULL,
    "item_id" bigint NOT NULL,
    "user_email" "text" NOT NULL,
    "role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "item_permissions_role_check" CHECK (("role" = ANY (ARRAY['owner'::"text", 'manager'::"text", 'editor'::"text", 'viewer'::"text", 'commenter'::"text"])))
);


ALTER TABLE "public"."item_permissions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."item_permissions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."item_permissions_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."item_permissions_id_seq" OWNED BY "public"."item_permissions"."id";


CREATE TABLE IF NOT EXISTS "public"."item_tags" (
    "id" bigint NOT NULL,
    "item_id" bigint NOT NULL,
    "tag_id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."item_tags" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."item_tags_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."item_tags_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."item_tags_id_seq" OWNED BY "public"."item_tags"."id";


CREATE TABLE IF NOT EXISTS "public"."items" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "parent_id" bigint,
    "type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "content" "text",
    "status" "text" DEFAULT 'todo'::"text" NOT NULL,
    "priority" "text" DEFAULT 'medium'::"text" NOT NULL,
    "created_by_email" "text" DEFAULT "public"."current_user_email"() NOT NULL,
    "due_date" timestamp with time zone,
    "start_date" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "archived_at" timestamp with time zone,
    "accessibility" "text" DEFAULT 'public'::"text" NOT NULL,
    "is_markdown" boolean DEFAULT false NOT NULL,
    CONSTRAINT "items_accessibility_check" CHECK (((("type" = 'note'::"text") AND ("accessibility" = ANY (ARRAY['public'::"text", 'private'::"text", 'restricted'::"text"]))) OR (("type" <> 'note'::"text") AND ("accessibility" = 'public'::"text")))),
    CONSTRAINT "items_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text", 'urgent'::"text"]))),
    CONSTRAINT "items_status_check" CHECK (("status" = ANY (ARRAY['todo'::"text", 'in_progress'::"text", 'review'::"text", 'done'::"text", 'blocked'::"text", 'archived'::"text"]))),
    CONSTRAINT "items_type_check" CHECK (("type" = ANY (ARRAY['project'::"text", 'module'::"text", 'submodule'::"text", 'task'::"text", 'note'::"text", 'discussion'::"text", 'bug'::"text", 'feature'::"text"])))
);


ALTER TABLE "public"."items" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."items_id_seq" OWNED BY "public"."items"."id";


CREATE TABLE IF NOT EXISTS "public"."koba_brands" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."koba_brands" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."koba_brands_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."koba_brands_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."koba_brands_id_seq" OWNED BY "public"."koba_brands"."id";


CREATE TABLE IF NOT EXISTS "public"."koba_cart_items" (
    "id" bigint NOT NULL,
    "cart_id" bigint NOT NULL,
    "koba_product_id" "uuid",
    "product_id" "text" NOT NULL,
    "product_code" "text",
    "barcode" "text",
    "name" "text" NOT NULL,
    "brand" "text",
    "image_url" "text",
    "case_size" integer DEFAULT 1 NOT NULL,
    "unit_price_gbp" numeric(12,2),
    "commission" numeric(12,2),
    "commission_percentage" numeric(5,2),
    "quantity" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "custom_price_gbp" numeric(12,2),
    CONSTRAINT "koba_cart_items_case_size_check" CHECK (("case_size" >= 1)),
    CONSTRAINT "koba_cart_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."koba_cart_items" OWNER TO "postgres";


COMMENT ON TABLE "public"."koba_cart_items" IS 'Line items in a koba cart. Stores full product snapshot for cart resilience.';


CREATE SEQUENCE IF NOT EXISTS "public"."koba_cart_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."koba_cart_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."koba_cart_items_id_seq" OWNED BY "public"."koba_cart_items"."id";


CREATE TABLE IF NOT EXISTS "public"."koba_carts" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "customer_group_id" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."koba_carts" OWNER TO "postgres";


COMMENT ON TABLE "public"."koba_carts" IS 'Active shopping carts for Koba retail, one per user+market+tenant.';


CREATE SEQUENCE IF NOT EXISTS "public"."koba_carts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."koba_carts_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."koba_carts_id_seq" OWNED BY "public"."koba_carts"."id";


CREATE TABLE IF NOT EXISTS "public"."koba_categories" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."koba_categories" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."koba_categories_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."koba_categories_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."koba_categories_id_seq" OWNED BY "public"."koba_categories"."id";


CREATE TABLE IF NOT EXISTS "public"."koba_order_items" (
    "id" bigint NOT NULL,
    "order_id" bigint NOT NULL,
    "product_id" "text" NOT NULL,
    "product_code" "text",
    "barcode" "text",
    "name" "text" NOT NULL,
    "brand" "text",
    "image_url" "text",
    "case_size" integer DEFAULT 1 NOT NULL,
    "unit_price_gbp" numeric(12,2),
    "commission" numeric(12,2),
    "commission_percentage" numeric(5,2),
    "quantity" integer DEFAULT 1 NOT NULL,
    "delivered_quantity" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "confirmed_quantity" integer,
    "custom_price_gbp" numeric(12,2),
    CONSTRAINT "koba_order_items_case_size_check" CHECK (("case_size" >= 1)),
    CONSTRAINT "koba_order_items_delivered_quantity_check" CHECK (("delivered_quantity" >= 0)),
    CONSTRAINT "koba_order_items_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."koba_order_items" OWNER TO "postgres";


COMMENT ON TABLE "public"."koba_order_items" IS 'Immutable line-item snapshot of a koba order.';


CREATE SEQUENCE IF NOT EXISTS "public"."koba_order_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."koba_order_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."koba_order_items_id_seq" OWNED BY "public"."koba_order_items"."id";


CREATE TABLE IF NOT EXISTS "public"."koba_orders" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "customer_group_id" bigint,
    "user_name" "text",
    "shipping_name" "text",
    "shipping_phone" "text",
    "shipping_district" "text",
    "shipping_thana" "text",
    "shipping_address" "text",
    "free_delivery" boolean DEFAULT false NOT NULL,
    "subtotal_gbp" numeric(12,2),
    "total_commission" numeric(12,2),
    "item_count" integer DEFAULT 0 NOT NULL,
    "status" "public"."koba_order_status" DEFAULT 'pending'::"public"."koba_order_status" NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "extra_profit_user" numeric(12,2) DEFAULT 0,
    "extra_profit_company" numeric(12,2) DEFAULT 0,
    "delivery_adjustment" numeric(12,2) DEFAULT 0,
    "cod_charge" numeric(12,2) DEFAULT 0,
    "packing_charge" numeric(12,2) DEFAULT 0,
    "invoice_charge" numeric(12,2) DEFAULT 0,
    "net_order_commission" numeric(12,2) DEFAULT 0
);


ALTER TABLE "public"."koba_orders" OWNER TO "postgres";


COMMENT ON TABLE "public"."koba_orders" IS 'Confirmed koba retail orders. Created from koba_carts via place_koba_order().';


CREATE SEQUENCE IF NOT EXISTS "public"."koba_orders_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."koba_orders_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."koba_orders_id_seq" OWNED BY "public"."koba_orders"."id";


CREATE TABLE IF NOT EXISTS "public"."koba_products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" bigint NOT NULL,
    "source_type" "text" NOT NULL,
    "source_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "sku" "text",
    "barcode" "text",
    "slug" "text",
    "permalink" "text",
    "description" "text",
    "stock_quantity" integer DEFAULT 0 NOT NULL,
    "in_stock" boolean DEFAULT true NOT NULL,
    "price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "regular_price" numeric(12,2),
    "sale_price" numeric(12,2),
    "currency" "text" DEFAULT 'GBP'::"text",
    "commission_percentage" numeric(5,2),
    "commission" numeric(12,2),
    "brand_id" bigint,
    "category_id" bigint,
    "image_url" "text",
    "raw_data" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "koba_products_source_type_check" CHECK (("source_type" = ANY (ARRAY['retail'::"text", 'wholesale'::"text"])))
);


ALTER TABLE "public"."koba_products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."koba_retail_settings" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "cod_charge_pct" numeric(5,2) DEFAULT 1.00,
    "gateway_charge_flat" numeric(12,2) DEFAULT 20.00,
    "packing_charge_flat" numeric(12,2) DEFAULT 37.00,
    "invoice_charge_flat" numeric(12,2) DEFAULT 1.00,
    "extra_profit_user_pct" numeric(5,2) DEFAULT 90.00,
    "extra_profit_company_pct" numeric(5,2) DEFAULT 10.00,
    "delivery_rates" "jsonb" DEFAULT '{"Dhaka": 100, "default": 110, "Dhaka Sub-Urban": 100}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."koba_retail_settings" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."koba_retail_settings_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."koba_retail_settings_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."koba_retail_settings_id_seq" OWNED BY "public"."koba_retail_settings"."id";


CREATE TABLE IF NOT EXISTS "public"."markets" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "code" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "is_system" boolean DEFAULT false NOT NULL,
    "region" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "markets_code_uppercase_check" CHECK (("code" = "upper"("code")))
);


ALTER TABLE "public"."markets" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."markets_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."markets_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."markets_id_seq" OWNED BY "public"."markets"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."membership_grants_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."membership_grants_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."membership_grants_id_seq" OWNED BY "public"."membership_grants"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."memberships_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."memberships_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."memberships_id_seq" OWNED BY "public"."memberships"."id";


CREATE TABLE IF NOT EXISTS "public"."merchant_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" bigint NOT NULL,
    "merchant_name" "text" NOT NULL,
    "store_name" "text",
    "phone_primary" "text" NOT NULL,
    "phone_secondary" "text",
    "pickup_address" "text" NOT NULL,
    "district" "text" DEFAULT 'Dhaka'::"text" NOT NULL,
    "thana" "text" NOT NULL,
    "notes" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."merchant_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."module_actions" (
    "id" bigint NOT NULL,
    "module_key" "text" NOT NULL,
    "action" "text" NOT NULL,
    "description" "text",
    "scope" "text" NOT NULL,
    "tenant_configurable" boolean DEFAULT true NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "module_actions_scope_check" CHECK (("scope" = ANY (ARRAY['app'::"text", 'shop'::"text", 'platform'::"text", 'investor'::"text"])))
);


ALTER TABLE "public"."module_actions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."module_actions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."module_actions_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."module_actions_id_seq" OWNED BY "public"."module_actions"."id";


CREATE TABLE IF NOT EXISTS "public"."modules" (
    "id" bigint NOT NULL,
    "key" "text" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "parent_module_key" "text"
);


ALTER TABLE "public"."modules" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."modules_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."modules_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."modules_id_seq" OWNED BY "public"."modules"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."order_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."order_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."order_items_id_seq" OWNED BY "public"."order_items"."id";


CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "customer_group_id" bigint NOT NULL,
    "cargo_rate" numeric(12,4),
    "conversion_rate" numeric(12,4),
    "profit_rate" numeric(12,4),
    "negotiate" boolean DEFAULT true NOT NULL,
    "status" "public"."order_status" DEFAULT 'customer_submit'::"public"."order_status" NOT NULL,
    "store_id" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "can_see_price" boolean DEFAULT false NOT NULL,
    "accent_color" "text",
    "invoice_id" bigint,
    "tenant_id" bigint NOT NULL,
    "tenant_order_id" bigint NOT NULL,
    "parent_tenant_id" bigint
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."orders_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."orders_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."orders_id_seq" OWNED BY "public"."orders"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."payment_allocations_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."payment_allocations_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."payment_allocations_id_seq" OWNED BY "public"."invoice_payments"."id";


CREATE TABLE IF NOT EXISTS "public"."payment_methods" (
    "id" bigint NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "category" "text" NOT NULL,
    "scope" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "is_system" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "payment_methods_category_check" CHECK (("category" = ANY (ARRAY['bd_mobile_wallet'::"text", 'bd_bank'::"text", 'bd_cash'::"text", 'card'::"text", 'international'::"text"]))),
    CONSTRAINT "payment_methods_code_uppercase_check" CHECK (("code" = "upper"("code"))),
    CONSTRAINT "payment_methods_scope_check" CHECK (("scope" = ANY (ARRAY['bd'::"text", 'international'::"text", 'both'::"text"])))
);


ALTER TABLE "public"."payment_methods" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."payment_methods_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."payment_methods_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."payment_methods_id_seq" OWNED BY "public"."payment_methods"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."payments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."payments_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."payments_id_seq" OWNED BY "public"."global_payments"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."product_brands_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."product_brands_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."product_brands_id_seq" OWNED BY "public"."product_brands"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."product_categories_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."product_categories_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."product_categories_id_seq" OWNED BY "public"."product_categories"."id";


CREATE TABLE IF NOT EXISTS "public"."product_sync_snapshots" (
    "id" bigint NOT NULL,
    "run_id" "text" NOT NULL,
    "captured_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "tenant_id" bigint,
    "vendor_code" "text" NOT NULL,
    "market_code" "text" NOT NULL,
    "product_id" bigint NOT NULL,
    "barcode" "text",
    "product_code" "text",
    "row_data" "jsonb" NOT NULL,
    "vendor_id" bigint
);


ALTER TABLE "public"."product_sync_snapshots" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."product_sync_snapshots_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."product_sync_snapshots_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."product_sync_snapshots_id_seq" OWNED BY "public"."product_sync_snapshots"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."products_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."products_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."products_id_seq" OWNED BY "public"."products"."id";


    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "store_id" bigint NOT NULL,
    "product_id" bigint,
    "price_bdt" numeric(12,2) NOT NULL,
    "minimum_sell_price_bdt" numeric(12,2) NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "inventory_item_id" bigint,
    "stock_override" integer,
    "global_stock_id" bigint,
    CONSTRAINT "store_product_prices_min_gte_price_chk" CHECK (("minimum_sell_price_bdt" >= "price_bdt")),
    CONSTRAINT "store_product_prices_positive_min_price_chk" CHECK (("minimum_sell_price_bdt" >= (0)::numeric)),
    CONSTRAINT "store_product_prices_positive_price_chk" CHECK (("price_bdt" >= (0)::numeric))
);


ALTER TABLE "public"."store_product_prices" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."store_product_prices_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."store_product_prices_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."store_product_prices_id_seq" OWNED BY "public"."store_product_prices"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."stores_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."stores_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."stores_id_seq" OWNED BY "public"."stores"."id";


CREATE TABLE IF NOT EXISTS "public"."system_role_templates" (
    "id" bigint NOT NULL,
    "scope" "text" NOT NULL,
    "role_slug" "text" NOT NULL,
    "module_key" "text" NOT NULL,
    "action" "text" NOT NULL,
    "allowed" boolean NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "system_role_templates_scope_check" CHECK (("scope" = ANY (ARRAY['app'::"text", 'shop'::"text"])))
);


ALTER TABLE "public"."system_role_templates" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."system_role_templates_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."system_role_templates_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."system_role_templates_id_seq" OWNED BY "public"."system_role_templates"."id";


CREATE TABLE IF NOT EXISTS "public"."tag_categories" (
    "id" bigint NOT NULL,
    "module_key" "text" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "cardinality" "text" NOT NULL,
    "is_system" boolean DEFAULT true NOT NULL,
    "tenant_id" bigint,
    "sort_order" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "tag_categories_cardinality_check" CHECK (("cardinality" = ANY (ARRAY['single'::"text", 'many'::"text"])))
);


ALTER TABLE "public"."tag_categories" OWNER TO "postgres";


ALTER TABLE "public"."tag_categories" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."tag_categories_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


CREATE SEQUENCE IF NOT EXISTS "public"."tags_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."tags_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."tags_id_seq" OWNED BY "public"."tags"."id";


CREATE TABLE IF NOT EXISTS "public"."tenant_module_submodules" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "parent_module_key" "text" NOT NULL,
    "submodule_key" "text" NOT NULL,
    "is_enabled" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."tenant_module_submodules" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."tenant_module_submodules_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."tenant_module_submodules_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."tenant_module_submodules_id_seq" OWNED BY "public"."tenant_module_submodules"."id";


CREATE TABLE IF NOT EXISTS "public"."tenant_modules" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "module_key" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."tenant_modules" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."tenant_modules_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."tenant_modules_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."tenant_modules_id_seq" OWNED BY "public"."tenant_modules"."id";


CREATE TABLE IF NOT EXISTS "public"."tenant_permission_versions" (
    "tenant_id" bigint NOT NULL,
    "version" bigint DEFAULT 1 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."tenant_permission_versions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."tenant_role_grants_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."tenant_role_grants_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."tenant_role_grants_id_seq" OWNED BY "public"."tenant_role_grants"."id";


CREATE SEQUENCE IF NOT EXISTS "public"."tenant_roles_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."tenant_roles_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."tenant_roles_id_seq" OWNED BY "public"."tenant_roles"."id";


CREATE TABLE IF NOT EXISTS "public"."tenant_scoped_counters" (
    "tenant_id" bigint NOT NULL,
    "scope" "text" NOT NULL,
    "last_value" bigint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "tenant_scoped_counters_last_value_check" CHECK (("last_value" >= 0)),
    CONSTRAINT "tenant_scoped_counters_scope_check" CHECK (("scope" = ANY (ARRAY['shipment'::"text", 'order'::"text"])))
);


ALTER TABLE "public"."tenant_scoped_counters" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tenants" (
    "id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "public_domain" "text",
    "parent_id" bigint,
    "preference" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "tenants_parent_id_check" CHECK ((("parent_id" IS NULL) OR ("parent_id" <> "id")))
);


ALTER TABLE "public"."tenants" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."tenants_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."tenants_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."tenants_id_seq" OWNED BY "public"."tenants"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_accounting_ledger" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "type" "public"."thrift_ledger_type" NOT NULL,
    "source" "public"."thrift_ledger_source" NOT NULL,
    "reference_id" bigint NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "inserted_by" "text" NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_accounting_ledger_amount_check" CHECK (("amount" >= (0)::numeric))
);


ALTER TABLE "public"."thrift_accounting_ledger" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_accounting_ledger_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_accounting_ledger_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_accounting_ledger_id_seq" OWNED BY "public"."thrift_accounting_ledger"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_barcodes" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "barcode_id" "text" NOT NULL,
    "status" "text" DEFAULT 'AVAILABLE'::"text" NOT NULL,
    "is_printed" smallint DEFAULT 0 NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_barcodes_is_printed_check" CHECK (("is_printed" = ANY (ARRAY[0, 1])))
);


ALTER TABLE "public"."thrift_barcodes" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_barcodes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_barcodes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_barcodes_id_seq" OWNED BY "public"."thrift_barcodes"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_boxes" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "weight" numeric(12,3),
    "received_weight" numeric(12,3),
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."thrift_boxes" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_boxes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_boxes_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_boxes_id_seq" OWNED BY "public"."thrift_boxes"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_categories" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "name" "text" NOT NULL,
    "description" "text",
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_global" boolean DEFAULT false NOT NULL,
    CONSTRAINT "thrift_categories_scope_check" CHECK (((("is_global" = true) AND ("tenant_id" IS NULL)) OR (("is_global" = false) AND ("tenant_id" IS NOT NULL))))
);


ALTER TABLE "public"."thrift_categories" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_categories_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_categories_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_categories_id_seq" OWNED BY "public"."thrift_categories"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_courier_providers" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "country_code" "text" DEFAULT 'BD'::"text" NOT NULL,
    "is_system" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 100 NOT NULL,
    "meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_courier_providers_code_nonempty" CHECK (("length"(TRIM(BOTH FROM "code")) > 0)),
    CONSTRAINT "thrift_courier_providers_name_nonempty" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "thrift_courier_providers_system_tenant_check" CHECK (((("is_system" = true) AND ("tenant_id" IS NULL)) OR (("is_system" = false) AND ("tenant_id" IS NOT NULL))))
);


ALTER TABLE "public"."thrift_courier_providers" OWNER TO "postgres";


COMMENT ON TABLE "public"."thrift_courier_providers" IS 'System (tenant_id null, is_system) BD catalog + tenant custom couriers for Online sales.';


COMMENT ON COLUMN "public"."thrift_courier_providers"."meta" IS 'JSONB extension bag for future extras (notes, website, support_phone, tracking_url_template). Not fee math.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_courier_providers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_courier_providers_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_courier_providers_id_seq" OWNED BY "public"."thrift_courier_providers"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_customers" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "phone_normalized" "text" NOT NULL,
    "address" "text",
    "notes" "text",
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "secondary_phone" "text",
    "address_parts" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "thrift_customers_phone_normalized_match_check" CHECK ((("phone_normalized" <> ''::"text") AND ("phone_normalized" = "public"."normalize_thrift_phone"("phone"))))
);


ALTER TABLE "public"."thrift_customers" OWNER TO "postgres";


COMMENT ON COLUMN "public"."thrift_customers"."secondary_phone" IS 'Optional alternate phone (not unique; primary phone_normalized remains upsert key).';


COMMENT ON COLUMN "public"."thrift_customers"."address_parts" IS 'BD location parts from static district/thana/postcode catalogs: { district, thana, post_code }. Freeform street stays in address.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_customers_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_customers_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_customers_id_seq" OWNED BY "public"."thrift_customers"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_invoice_counters" (
    "tenant_id" bigint NOT NULL,
    "year_month" "text" NOT NULL,
    "last_value" bigint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_invoice_counters_last_value_check" CHECK (("last_value" >= 0)),
    CONSTRAINT "thrift_invoice_counters_year_month_check" CHECK (("year_month" ~ '^\d{4}-\d{2}$'::"text"))
);


ALTER TABLE "public"."thrift_invoice_counters" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."thrift_invoice_items" (
    "id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "quantity" integer NOT NULL,
    "sold_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "platform_fees" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "shipping_cost_paid_by_shop" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "item_status" "public"."thrift_item_status" DEFAULT 'SOLD'::"public"."thrift_item_status" NOT NULL,
    "return_reason" "text",
    "return_cost_charged_to_customer" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "return_cost_paid_by_shop" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "return_action" "public"."thrift_return_action",
    "net_profit" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "landed_unit_cost_at_sale" numeric(12,2) DEFAULT 0.00 NOT NULL,
    CONSTRAINT "thrift_invoice_items_platform_fees_check" CHECK (("platform_fees" >= (0)::numeric)),
    CONSTRAINT "thrift_invoice_items_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "thrift_invoice_items_return_cost_charged_to_customer_check" CHECK (("return_cost_charged_to_customer" >= (0)::numeric)),
    CONSTRAINT "thrift_invoice_items_return_cost_paid_by_shop_check" CHECK (("return_cost_paid_by_shop" >= (0)::numeric)),
    CONSTRAINT "thrift_invoice_items_shipping_cost_paid_by_shop_check" CHECK (("shipping_cost_paid_by_shop" >= (0)::numeric)),
    CONSTRAINT "thrift_invoice_items_sold_price_check" CHECK (("sold_price" >= (0)::numeric))
);


ALTER TABLE "public"."thrift_invoice_items" OWNER TO "postgres";


COMMENT ON TABLE "public"."thrift_invoice_items" IS 'LEGACY ARCHIVE — read-only (P21). Active sales use thrift_sales_invoice_items.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_invoice_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_invoice_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_invoice_items_id_seq" OWNED BY "public"."thrift_invoice_items"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_invoices" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_number" "text" NOT NULL,
    "recipient_name" "text" NOT NULL,
    "address" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "transaction_method" "public"."thrift_transaction_method" NOT NULL,
    "delivery_status" "public"."thrift_delivery_status" DEFAULT 'PENDING'::"public"."thrift_delivery_status" NOT NULL,
    "payment_status" "public"."thrift_payment_status" DEFAULT 'UNPAID'::"public"."thrift_payment_status" NOT NULL,
    "cod_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "packing_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "invoice_print_charge" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "shipping_charge_customer" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "total_invoice_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_invoices_cod_charge_check" CHECK (("cod_charge" >= (0)::numeric)),
    CONSTRAINT "thrift_invoices_invoice_print_charge_check" CHECK (("invoice_print_charge" >= (0)::numeric)),
    CONSTRAINT "thrift_invoices_packing_charge_check" CHECK (("packing_charge" >= (0)::numeric)),
    CONSTRAINT "thrift_invoices_shipping_charge_customer_check" CHECK (("shipping_charge_customer" >= (0)::numeric)),
    CONSTRAINT "thrift_invoices_total_invoice_amount_check" CHECK (("total_invoice_amount" >= (0)::numeric))
);


ALTER TABLE "public"."thrift_invoices" OWNER TO "postgres";


COMMENT ON TABLE "public"."thrift_invoices" IS 'LEGACY ARCHIVE — read-only (P21). Active sales use thrift_sales_invoices.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_invoices_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_invoices_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_invoices_id_seq" OWNED BY "public"."thrift_invoices"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_pricings" (
    "id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "cost_of_goods_sold" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "target_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "listed_unit_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "extra_expense_cost" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "is_listed_price_manual" boolean DEFAULT false,
    "markup_rate_override" numeric,
    CONSTRAINT "thrift_pricings_cost_of_goods_sold_check" CHECK (("cost_of_goods_sold" >= (0)::numeric)),
    CONSTRAINT "thrift_pricings_extra_expense_cost_check" CHECK (("extra_expense_cost" >= (0)::numeric)),
    CONSTRAINT "thrift_pricings_listed_price_check" CHECK (("listed_unit_price" >= (0)::numeric)),
    CONSTRAINT "thrift_pricings_target_price_check" CHECK (("target_price" >= (0)::numeric))
);


ALTER TABLE "public"."thrift_pricings" OWNER TO "postgres";


COMMENT ON COLUMN "public"."thrift_pricings"."cost_of_goods_sold" IS 'DEPRECATED (P22) — do not use as sale/report COGS. Source of truth: compute_thrift_landed_unit_cost + thrift_sales_invoice_items.landed_unit_cost_at_sale. Column retained until Wave 2+ drop.';


COMMENT ON COLUMN "public"."thrift_pricings"."target_price" IS 'DEPRECATED (P22) — prefer listed_unit_price + engine suggested sell. Column retained until Wave 2+ drop.';


COMMENT ON COLUMN "public"."thrift_pricings"."extra_expense_cost" IS 'DEPRECATED (P22) — not used by costing engine. Column retained until Wave 2+ drop.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_pricings_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_pricings_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_pricings_id_seq" OWNED BY "public"."thrift_pricings"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_return_counters" (
    "tenant_id" bigint NOT NULL,
    "year_month" "text" NOT NULL,
    "last_value" bigint DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_return_counters_last_value_check" CHECK (("last_value" >= 0)),
    CONSTRAINT "thrift_return_counters_year_month_check" CHECK (("year_month" ~ '^\d{4}-\d{2}$'::"text"))
);


ALTER TABLE "public"."thrift_return_counters" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."thrift_sales_invoice_items" (
    "id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "stock_id" bigint,
    "sell_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "final_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "landed_unit_cost_at_sale" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "net_profit" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."thrift_sales_invoice_items" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_invoice_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_sales_invoice_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_sales_invoice_items_id_seq" OWNED BY "public"."thrift_sales_invoice_items"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_sales_invoices" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_number" "text" NOT NULL,
    "date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "payment_method" "text" DEFAULT 'CASH'::"text" NOT NULL,
    "payment_status" "text" DEFAULT 'PAID'::"text" NOT NULL,
    "total_invoice_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_by" "text" DEFAULT ''::"text" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "customer_name" "text",
    "customer_phone" "text",
    "status" "text" DEFAULT 'ACTIVE'::"text" NOT NULL,
    "reverted_at" timestamp with time zone,
    "reverted_by" "text",
    "revert_reason" "text",
    "revert_notes" "text",
    "sale_channel" "text" DEFAULT 'IN_STORE'::"text" NOT NULL,
    "customer_id" bigint,
    "customer_address" "text",
    "courier_cod_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "other_expense_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "courier_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "courier_paid_by" "text",
    "cod_expected" numeric(12,2),
    "cod_remitted_amount" numeric(12,2),
    "cod_remitted_at" timestamp with time zone,
    "cod_remittance_ref" "text",
    "delivery_status" "text",
    "courier_provider" "text",
    "cod_fee_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "cod_fee_paid_by" "text",
    "packing_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "packing_paid_by" "text",
    "return_courier_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "close_reason" "text",
    "economics_closed_at" timestamp with time zone,
    "courier_provider_id" bigint,
    "meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "customer_secondary_phone" "text",
    "customer_address_parts" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "advance_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "advance_note" "text",
    CONSTRAINT "thrift_sales_invoices_advance_amount_check" CHECK (("advance_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_close_reason_check" CHECK ((("close_reason" IS NULL) OR ("close_reason" = ANY (ARRAY['RTO'::"text", 'CUSTOMER_RETURN'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_cod_expected_check" CHECK ((("cod_expected" IS NULL) OR ("cod_expected" >= (0)::numeric))),
    CONSTRAINT "thrift_sales_invoices_cod_fee_amount_check" CHECK (("cod_fee_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_cod_fee_paid_by_check" CHECK ((("cod_fee_paid_by" IS NULL) OR ("cod_fee_paid_by" = ANY (ARRAY['CUSTOMER'::"text", 'SHOP'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_cod_fee_payer_consistency_check" CHECK (((("cod_fee_amount" > (0)::numeric) AND ("cod_fee_paid_by" IS NOT NULL)) OR (("cod_fee_amount" = (0)::numeric) AND ("cod_fee_paid_by" IS NULL)))),
    CONSTRAINT "thrift_sales_invoices_cod_remitted_amount_check" CHECK ((("cod_remitted_amount" IS NULL) OR ("cod_remitted_amount" >= (0)::numeric))),
    CONSTRAINT "thrift_sales_invoices_courier_amount_check" CHECK (("courier_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_courier_cod_amount_check" CHECK (("courier_cod_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_courier_paid_by_check" CHECK ((("courier_paid_by" IS NULL) OR ("courier_paid_by" = ANY (ARRAY['CUSTOMER'::"text", 'SHOP'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_courier_payer_amount_check" CHECK (((("courier_amount" > (0)::numeric) AND ("courier_paid_by" IS NOT NULL)) OR (("courier_amount" = (0)::numeric) AND ("courier_paid_by" IS NULL)))),
    CONSTRAINT "thrift_sales_invoices_delivery_status_check" CHECK ((("delivery_status" IS NULL) OR ("delivery_status" = ANY (ARRAY['PENDING'::"text", 'READY'::"text", 'IN_TRANSIT'::"text", 'DELIVERED'::"text", 'RETURNED'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_other_expense_amount_check" CHECK (("other_expense_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_packing_amount_check" CHECK (("packing_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_packing_paid_by_check" CHECK ((("packing_paid_by" IS NULL) OR ("packing_paid_by" = ANY (ARRAY['CUSTOMER'::"text", 'SHOP'::"text"])))),
    CONSTRAINT "thrift_sales_invoices_packing_payer_consistency_check" CHECK (((("packing_amount" > (0)::numeric) AND ("packing_paid_by" IS NOT NULL)) OR (("packing_amount" = (0)::numeric) AND ("packing_paid_by" IS NULL)))),
    CONSTRAINT "thrift_sales_invoices_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['PAID'::"text", 'COD_PENDING'::"text", 'PARTIALLY_REFUNDED'::"text", 'REFUNDED'::"text", 'WRITTEN_OFF'::"text", 'UNPAID'::"text"]))),
    CONSTRAINT "thrift_sales_invoices_return_courier_amount_check" CHECK (("return_courier_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_invoices_sale_channel_check" CHECK (("sale_channel" = ANY (ARRAY['IN_STORE'::"text", 'ONLINE'::"text"]))),
    CONSTRAINT "thrift_sales_invoices_status_check" CHECK (("status" = ANY (ARRAY['ACTIVE'::"text", 'PARTIALLY_RETURNED'::"text", 'RETURNED'::"text", 'STAFF_MISTAKE'::"text"])))
);


ALTER TABLE "public"."thrift_sales_invoices" OWNER TO "postgres";


COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_name" IS 'Customer full name for thrift invoice';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_phone" IS 'Customer phone number for thrift invoice';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."sale_channel" IS 'Hybrid desk channel: IN_STORE | ONLINE';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_id" IS 'Linked thrift_customers row when phone was present at sale';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_address" IS 'Sale-day address snapshot';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_cod_amount" IS 'DEPRECATED — use courier_amount. Retained for historical rows / reports.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."other_expense_amount" IS 'DEPRECATED — no longer written by create_thrift_sales_invoice.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_amount" IS 'Courier fee amount (>= 0). Offline always 0.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_paid_by" IS 'CUSTOMER | SHOP when courier_amount > 0; null when amount is 0.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."cod_expected" IS 'COD cash expected from courier (Online COD_PENDING). Null offline / paid-at-create.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."delivery_status" IS 'Parcel track for Online invoices. Null for Offline. Independent of payment_status.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_provider" IS 'Online optional courier company name; Offline null.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."cod_fee_amount" IS 'Courier COD service fee (staff-entered ৳), not a stored %.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."packing_amount" IS 'Packing / print charge.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."return_courier_amount" IS 'RTO / no-pickup return courier billed to shop (post-pay returns use thrift_sales_returns).';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."close_reason" IS 'RTO | CUSTOMER_RETURN when fully closed; null while open or partially returned.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."economics_closed_at" IS 'Last time thrift_sales_pnl_lines were written/updated for this invoice.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."courier_provider_id" IS 'Optional FK to thrift_courier_providers; name also snapshotted in courier_provider.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."meta" IS 'Optional Online extras (tracking_id, tracking_url). Not fee amounts.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_secondary_phone" IS 'Snapshot of customer secondary phone at create.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."customer_address_parts" IS 'Snapshot of address_parts at create: { district, thana, post_code }.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."advance_amount" IS 'Customer advance collected at create (online COD only). Deducted from cod_expected; non-refundable. Offline always 0.';


COMMENT ON COLUMN "public"."thrift_sales_invoices"."advance_note" IS 'Optional note for advance (e.g. payment ref). Null when unused.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_invoices_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_sales_invoices_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_sales_invoices_id_seq" OWNED BY "public"."thrift_sales_invoices"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_sales_pnl_lines" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "invoice_item_id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "inbound_shipment_id" bigint NOT NULL,
    "outcome" "text" NOT NULL,
    "return_id" bigint,
    "quantity" integer DEFAULT 1 NOT NULL,
    "sell_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_shop_delivery" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_shop_cod_fee" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_shop_packing" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_return_courier" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "allocated_fees_total" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "cogs_is_loss" boolean DEFAULT false NOT NULL,
    "event_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "event_date" "date" DEFAULT (("now"() AT TIME ZONE 'UTC'::"text"))::"date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_sales_pnl_lines_alloc_cod_check" CHECK (("allocated_shop_cod_fee" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_pnl_lines_alloc_delivery_check" CHECK (("allocated_shop_delivery" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_pnl_lines_alloc_packing_check" CHECK (("allocated_shop_packing" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_pnl_lines_alloc_return_check" CHECK (("allocated_return_courier" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_pnl_lines_fees_total_check" CHECK (("allocated_fees_total" = ((("allocated_shop_delivery" + "allocated_shop_cod_fee") + "allocated_shop_packing") + "allocated_return_courier"))),
    CONSTRAINT "thrift_sales_pnl_lines_outcome_check" CHECK (("outcome" = ANY (ARRAY['DELIVERED'::"text", 'RTO'::"text", 'CUSTOMER_RETURN'::"text"]))),
    CONSTRAINT "thrift_sales_pnl_lines_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "thrift_sales_pnl_lines_sell_amount_check" CHECK (("sell_amount" >= (0)::numeric))
);


ALTER TABLE "public"."thrift_sales_pnl_lines" OWNER TO "postgres";


COMMENT ON TABLE "public"."thrift_sales_pnl_lines" IS 'Per invoice-line economics fact for reports. COGS stays live via stock→inbound shipment.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_pnl_lines_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" OWNED BY "public"."thrift_sales_pnl_lines"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_sales_return_items" (
    "id" bigint NOT NULL,
    "return_id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_item_id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "condition" "text" NOT NULL,
    "refund_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_sales_return_items_condition_check" CHECK (("condition" = ANY (ARRAY['SELLABLE'::"text", 'DAMAGED'::"text"]))),
    CONSTRAINT "thrift_sales_return_items_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "thrift_sales_return_items_refund_amount_check" CHECK (("refund_amount" >= (0)::numeric))
);


ALTER TABLE "public"."thrift_sales_return_items" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_return_items_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_sales_return_items_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_sales_return_items_id_seq" OWNED BY "public"."thrift_sales_return_items"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_sales_returns" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "return_number" "text" NOT NULL,
    "status" "text" DEFAULT 'COMPLETED'::"text" NOT NULL,
    "refund_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "return_courier_amount" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "notes" "text",
    "created_by" "text" DEFAULT ''::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "thrift_sales_returns_courier_amount_check" CHECK (("return_courier_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_returns_refund_amount_check" CHECK (("refund_amount" >= (0)::numeric)),
    CONSTRAINT "thrift_sales_returns_status_check" CHECK (("status" = 'COMPLETED'::"text"))
);


ALTER TABLE "public"."thrift_sales_returns" OWNER TO "postgres";


COMMENT ON TABLE "public"."thrift_sales_returns" IS 'Post-pay / post-delivery returns (partial or full). Not used for RTO no-pickup.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_sales_returns_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_sales_returns_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_sales_returns_id_seq" OWNED BY "public"."thrift_sales_returns"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_settings" (
    "tenant_id" bigint NOT NULL,
    "default_origin_unit_price" numeric(12,2) DEFAULT 0.00 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "hand_tag_unit_cost" numeric,
    "hand_tag_unit_currency_id" bigint,
    "sticker_unit_cost" numeric,
    "sticker_unit_currency_id" bigint,
    "marketing_tag_config" "jsonb" DEFAULT '{"show_logo": true, "brand_name": "", "show_tag_size": true, "show_brand_name": true, "show_core_sizes": true, "show_listed_sell": true, "show_barcode_text": true, "show_additional_sizes": true}'::"jsonb" NOT NULL,
    "return_window_days" integer DEFAULT 30 NOT NULL,
    CONSTRAINT "thrift_settings_return_window_days_check" CHECK (("return_window_days" >= 0)),
    CONSTRAINT "thrift_stock_settings_default_purchase_price_check" CHECK (("default_origin_unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."thrift_settings" OWNER TO "postgres";


COMMENT ON COLUMN "public"."thrift_settings"."marketing_tag_config" IS 'Per-tenant marketing sticker layout settings.';


COMMENT ON COLUMN "public"."thrift_settings"."return_window_days" IS 'Customer RETURN eligibility window (days) from invoice date; 0 = no customer returns';


CREATE TABLE IF NOT EXISTS "public"."thrift_shelves" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "location_bay" "text",
    "shelf_code" "text" NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."thrift_shelves" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_shelves_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_shelves_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_shelves_id_seq" OWNED BY "public"."thrift_shelves"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_shipments" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "cargo_conversion_rate" numeric(12,4),
    "cargo_rate" numeric(12,4),
    "product_conversion_rate" numeric(12,4),
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "purchase_currency_id" bigint NOT NULL,
    "cost_currency_id" bigint NOT NULL,
    "total_cargo_weight_kg" numeric,
    "labor_total_cost" numeric,
    "transportation_total_cost" numeric,
    "default_markup_rate" numeric,
    "washing_total_cost" numeric,
    "marketing_tag_config" "jsonb" DEFAULT '{"show_logo": true, "brand_name": "", "show_brand_name": true, "show_core_sizes": true, "show_listed_sell": true, "show_barcode_text": true, "show_additional_sizes": true}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."thrift_shipments" OWNER TO "postgres";


COMMENT ON COLUMN "public"."thrift_shipments"."marketing_tag_config" IS 'Per-shipment marketing sticker layout: shop brand and field visibility.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_shipments_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_shipments_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_shipments_id_seq" OWNED BY "public"."thrift_shipments"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_stock_images" (
    "id" bigint NOT NULL,
    "stock_id" bigint NOT NULL,
    "image_url" "text" NOT NULL,
    "is_primary" boolean DEFAULT false NOT NULL,
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "drive_file_id" "text"
);


ALTER TABLE "public"."thrift_stock_images" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_stock_images_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_stock_images_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_stock_images_id_seq" OWNED BY "public"."thrift_stock_images"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_stock_measurements" (
    "stock_id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "bust_in" numeric(5,1),
    "waist_in" numeric(5,1),
    "hips_in" numeric(5,1),
    "length_in" numeric(5,1),
    "shoulder_width_in" numeric(5,1),
    "sleeve_length_in" numeric(5,1),
    "arm_circumference_in" numeric(5,1),
    "hem_width_in" numeric(5,1),
    "neck_opening_in" numeric(5,1),
    "sleeve_type" "text",
    "neckline" "text",
    "dress_style" "text",
    "fabric_stretch" "text",
    "lining" boolean,
    "closure_type" "text",
    "measurement_notes" "text",
    "inserted_by" "text" DEFAULT 'system'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."thrift_stock_measurements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."thrift_stocks" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "name" "text",
    "brand_name" "text",
    "category_id" bigint,
    "type_id" bigint,
    "section" "public"."thrift_section",
    "shelf_id" bigint,
    "color" "text",
    "size" "text",
    "condition" "public"."thrift_condition",
    "stock_type" "public"."thrift_stock_type" DEFAULT 'SINGLE'::"public"."thrift_stock_type" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "status" "public"."thrift_stock_status" DEFAULT 'AVAILABLE'::"public"."thrift_stock_status" NOT NULL,
    "note" "text",
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "box_id" bigint,
    "product_weight" numeric(12,3),
    "extra_weight" numeric(12,3),
    "origin_unit_price" numeric(12,2),
    "barcode" "text",
    "extra_origin_unit_price" numeric(12,2),
    "additional_charges_cost" numeric,
    "held_for_name" "text",
    "held_for_phone" "text",
    "held_for_phone_normalized" "text",
    "hold_note" "text",
    "held_by" "text",
    "held_at" timestamp with time zone,
    "hold_expires_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "deleted_by" "text",
    CONSTRAINT "thrift_stocks_extra_origin_purchase_expense_check" CHECK (("extra_origin_unit_price" >= (0)::numeric)),
    CONSTRAINT "thrift_stocks_extra_weight_check" CHECK (("extra_weight" >= (0)::numeric)),
    CONSTRAINT "thrift_stocks_origin_purchase_price_check" CHECK (("origin_unit_price" >= (0)::numeric)),
    CONSTRAINT "thrift_stocks_product_weight_check" CHECK (("product_weight" >= (0)::numeric)),
    CONSTRAINT "thrift_stocks_quantity_check" CHECK (("quantity" >= 0))
);


ALTER TABLE "public"."thrift_stocks" OWNER TO "postgres";


COMMENT ON COLUMN "public"."thrift_stocks"."name" IS 'Optional display name for the stock item.';


COMMENT ON COLUMN "public"."thrift_stocks"."held_for_phone_normalized" IS 'Digits-only hold key (normalize_thrift_phone). Required when status=RESERVED; sale convert requires invoice phone match.';


COMMENT ON COLUMN "public"."thrift_stocks"."hold_expires_at" IS 'Optional advisory expiry (v1). No auto-release job.';


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_stocks_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_stocks_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_stocks_id_seq" OWNED BY "public"."thrift_stocks"."id";


CREATE TABLE IF NOT EXISTS "public"."thrift_types" (
    "id" bigint NOT NULL,
    "tenant_id" bigint,
    "name" "text" NOT NULL,
    "description" "text",
    "inserted_by" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_global" boolean DEFAULT false NOT NULL,
    "icon" "text",
    CONSTRAINT "thrift_types_scope_check" CHECK (((("is_global" = true) AND ("tenant_id" IS NULL)) OR (("is_global" = false) AND ("tenant_id" IS NOT NULL))))
);


ALTER TABLE "public"."thrift_types" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."thrift_types_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."thrift_types_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."thrift_types_id_seq" OWNED BY "public"."thrift_types"."id";


CREATE TABLE IF NOT EXISTS "public"."units_of_measure" (
    "id" bigint NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "unit_type" "text" NOT NULL,
    "symbol" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "is_system" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "units_of_measure_code_uppercase_check" CHECK (("code" = "upper"("code"))),
    CONSTRAINT "units_of_measure_unit_type_check" CHECK (("unit_type" = ANY (ARRAY['weight'::"text", 'count'::"text", 'length'::"text", 'volume'::"text", 'packaging'::"text"])))
);


ALTER TABLE "public"."units_of_measure" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."units_of_measure_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."units_of_measure_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."units_of_measure_id_seq" OWNED BY "public"."units_of_measure"."id";


CREATE TABLE IF NOT EXISTS "public"."universal_wallet_ledger" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "operating_tenant_id" bigint NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" bigint NOT NULL,
    "type" "text" NOT NULL,
    "amount" numeric(15,4) NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "exchange_rate" numeric(15,6) DEFAULT 1.000000 NOT NULL,
    "base_amount" numeric(15,4) NOT NULL,
    "balance_after" numeric(15,4) NOT NULL,
    "source_type" "text" NOT NULL,
    "source_id" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "universal_wallet_ledger_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "universal_wallet_ledger_base_amount_check" CHECK (("base_amount" >= (0)::numeric)),
    CONSTRAINT "universal_wallet_ledger_exchange_rate_check" CHECK (("exchange_rate" > (0)::numeric)),
    CONSTRAINT "universal_wallet_ledger_type_check" CHECK (("type" = ANY (ARRAY['credit'::"text", 'debit'::"text"])))
);


ALTER TABLE "public"."universal_wallet_ledger" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wallet_accounts" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" bigint NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "available_balance" numeric(18,4) DEFAULT 0.0000 NOT NULL,
    "pending_balance" numeric(18,4) DEFAULT 0.0000 NOT NULL,
    "locked_balance" numeric(18,4) DEFAULT 0.0000 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "wallet_accounts_available_non_negative" CHECK ((("available_balance" >= (0)::numeric) OR ("entity_type" = 'tenant'::"text")))
);


ALTER TABLE "public"."wallet_accounts" OWNER TO "postgres";


ALTER TABLE "public"."wallet_accounts" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."wallet_accounts_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


ALTER TABLE ONLY "public"."activity_logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."activity_logs_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."batch_code_pc" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."batch_code_pc_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."business_parties" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."business_parties_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."cargo_companies" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."cargo_companies_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."cart_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."cart_items_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."carts" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."carts_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."comments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."comments_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."commerce_cart" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."commerce_cart_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."commerce_inventory_product_summaries" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."commerce_inventory_product_summaries_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."commerce_invoice_boxes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."commerce_invoice_boxes_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."commerce_invoices" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."commerce_invoices_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."commerce_order_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."commerce_order_items_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."commerce_orders" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."commerce_orders_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."customer_group_member_grants" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."customer_group_member_grants_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."customer_group_members" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."customer_group_members_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."customer_groups" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."customer_groups_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."entity_tags" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."entity_tags_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."global_currencies" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."global_currencies_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."global_payments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."payments_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."investor_balances" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."investor_balances_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."investor_transactions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."investor_transactions_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."investors" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."investors_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."invoice_boxes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."invoice_boxes_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."invoice_payments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."payment_allocations_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."item_assignees" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."item_assignees_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."item_permissions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."item_permissions_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."item_tags" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."item_tags_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."items_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."koba_brands" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."koba_brands_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."koba_cart_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."koba_cart_items_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."koba_carts" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."koba_carts_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."koba_categories" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."koba_categories_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."koba_order_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."koba_order_items_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."koba_orders" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."koba_orders_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."koba_retail_settings" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."koba_retail_settings_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."markets" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."markets_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."membership_grants" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."membership_grants_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."memberships" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."memberships_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."module_actions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."module_actions_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."modules" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."modules_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."order_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."order_items_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."orders" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."orders_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."payment_methods" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."payment_methods_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."product_brands" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."product_brands_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."product_categories" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."product_categories_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."product_sync_snapshots" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."product_sync_snapshots_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."products" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."products_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."store_access" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."store_access_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."store_product_prices" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."store_product_prices_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."stores" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."stores_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."system_role_templates" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."system_role_templates_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."tags" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."tags_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."tenant_module_submodules" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."tenant_module_submodules_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."tenant_modules" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."tenant_modules_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."tenant_role_grants" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."tenant_role_grants_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."tenant_roles" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."tenant_roles_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."tenants" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."tenants_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_accounting_ledger" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_accounting_ledger_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_barcodes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_barcodes_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_boxes" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_boxes_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_categories" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_categories_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_courier_providers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_courier_providers_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_customers" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_customers_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_invoice_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_invoice_items_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_invoices" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_invoices_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_pricings" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_pricings_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_sales_invoice_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_invoice_items_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_sales_invoices" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_invoices_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_sales_pnl_lines" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_pnl_lines_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_sales_return_items" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_return_items_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_sales_returns" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_sales_returns_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_shelves" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_shelves_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_shipments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_shipments_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_stock_images" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_stock_images_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_stocks" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_stocks_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."thrift_types" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."thrift_types_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."units_of_measure" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."units_of_measure_id_seq"'::"regclass");


ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."batch_code_pc"
    ADD CONSTRAINT "batch_code_pc_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."business_parties"
    ADD CONSTRAINT "business_parties_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."cargo_companies"
    ADD CONSTRAINT "cargo_companies_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_cart_product_unique" UNIQUE ("cart_id", "product_id");


ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."carts"
    ADD CONSTRAINT "carts_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."commerce_cart"
    ADD CONSTRAINT "commerce_cart_customer_inventory_item_unique" UNIQUE ("tenant_id", "customer_group_id", "inventory_item_id");


ALTER TABLE ONLY "public"."commerce_cart"
    ADD CONSTRAINT "commerce_cart_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."commerce_inventory_product_summaries"
    ADD CONSTRAINT "commerce_inventory_product_summaries_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."commerce_inventory_product_summaries"
    ADD CONSTRAINT "commerce_inventory_product_summaries_tenant_id_product_id_key" UNIQUE ("tenant_id", "product_id");


ALTER TABLE ONLY "public"."commerce_invoice_boxes"
    ADD CONSTRAINT "commerce_invoice_boxes_invoice_id_box_number_key" UNIQUE ("invoice_id", "box_number");


ALTER TABLE ONLY "public"."commerce_invoice_boxes"
    ADD CONSTRAINT "commerce_invoice_boxes_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."commerce_invoices"
    ADD CONSTRAINT "commerce_invoices_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."commerce_order_items"
    ADD CONSTRAINT "commerce_order_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."commerce_order_settings"
    ADD CONSTRAINT "commerce_order_settings_pkey" PRIMARY KEY ("tenant_id");


ALTER TABLE ONLY "public"."commerce_orders"
    ADD CONSTRAINT "commerce_orders_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."courier_remittance_batches"
    ADD CONSTRAINT "courier_remittance_batches_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."courier_remittance_items"
    ADD CONSTRAINT "courier_remittance_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."courier_services"
    ADD CONSTRAINT "courier_services_code_key" UNIQUE ("code");


ALTER TABLE ONLY "public"."courier_services"
    ADD CONSTRAINT "courier_services_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."customer_group_member_grants"
    ADD CONSTRAINT "customer_group_member_grants_cgm_module_action_unique" UNIQUE ("customer_group_member_id", "module_key", "action");


ALTER TABLE ONLY "public"."customer_group_member_grants"
    ADD CONSTRAINT "customer_group_member_grants_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."customer_group_members"
    ADD CONSTRAINT "customer_group_members_pkey" PRIMARY KEY ("id");


    ADD CONSTRAINT "customer_groups_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."customer_order_backlog_items"
    ADD CONSTRAINT "customer_order_backlog_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."entity_tags"
    ADD CONSTRAINT "entity_tags_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."entity_tags"
    ADD CONSTRAINT "entity_tags_tenant_id_tag_id_entity_type_entity_id_key" UNIQUE ("tenant_id", "tag_id", "entity_type", "entity_id");


ALTER TABLE ONLY "public"."gift_rule_items"
    ADD CONSTRAINT "gift_rule_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."gift_rule_redemptions"
    ADD CONSTRAINT "gift_rule_redemptions_order_rule_key" UNIQUE ("order_id", "rule_id");


ALTER TABLE ONLY "public"."gift_rule_redemptions"
    ADD CONSTRAINT "gift_rule_redemptions_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."gift_rules"
    ADD CONSTRAINT "gift_rules_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."investor_balances"
    ADD CONSTRAINT "investor_balances_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."investor_balances"
    ADD CONSTRAINT "investor_balances_tenant_id_investor_id_key" UNIQUE ("tenant_id", "investor_id");


ALTER TABLE ONLY "public"."investor_transactions"
    ADD CONSTRAINT "investor_transactions_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."investors"
    ADD CONSTRAINT "investors_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."invoice_boxes"
    ADD CONSTRAINT "invoice_boxes_invoice_id_box_number_key" UNIQUE ("invoice_id", "box_number");


ALTER TABLE ONLY "public"."invoice_boxes"
    ADD CONSTRAINT "invoice_boxes_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."item_assignees"
    ADD CONSTRAINT "item_assignees_item_id_user_email_key" UNIQUE ("item_id", "user_email");


ALTER TABLE ONLY "public"."item_assignees"
    ADD CONSTRAINT "item_assignees_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."item_permissions"
    ADD CONSTRAINT "item_permissions_item_id_user_email_key" UNIQUE ("item_id", "user_email");


ALTER TABLE ONLY "public"."item_permissions"
    ADD CONSTRAINT "item_permissions_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."item_tags"
    ADD CONSTRAINT "item_tags_item_id_tag_id_key" UNIQUE ("item_id", "tag_id");


ALTER TABLE ONLY "public"."item_tags"
    ADD CONSTRAINT "item_tags_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."items"
    ADD CONSTRAINT "items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."koba_brands"
    ADD CONSTRAINT "koba_brands_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."koba_cart_items"
    ADD CONSTRAINT "koba_cart_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."koba_carts"
    ADD CONSTRAINT "koba_carts_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."koba_categories"
    ADD CONSTRAINT "koba_categories_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."koba_order_items"
    ADD CONSTRAINT "koba_order_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."koba_orders"
    ADD CONSTRAINT "koba_orders_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."koba_products"
    ADD CONSTRAINT "koba_products_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."koba_retail_settings"
    ADD CONSTRAINT "koba_retail_settings_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."koba_retail_settings"
    ADD CONSTRAINT "koba_retail_settings_tenant_id_key" UNIQUE ("tenant_id");


ALTER TABLE ONLY "public"."markets"
    ADD CONSTRAINT "markets_code_key" UNIQUE ("code");


ALTER TABLE ONLY "public"."markets"
    ADD CONSTRAINT "markets_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."membership_grants"
    ADD CONSTRAINT "membership_grants_membership_module_action_unique" UNIQUE ("membership_id", "module_key", "action");


ALTER TABLE ONLY "public"."membership_grants"
    ADD CONSTRAINT "membership_grants_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."merchant_profiles"
    ADD CONSTRAINT "merchant_profiles_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."module_actions"
    ADD CONSTRAINT "module_actions_module_key_action_scope_unique" UNIQUE ("module_key", "action", "scope");


ALTER TABLE ONLY "public"."module_actions"
    ADD CONSTRAINT "module_actions_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_key_key" UNIQUE ("key");


ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."invoice_payments"
    ADD CONSTRAINT "payment_allocations_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."payment_methods"
    ADD CONSTRAINT "payment_methods_code_key" UNIQUE ("code");


ALTER TABLE ONLY "public"."payment_methods"
    ADD CONSTRAINT "payment_methods_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."global_payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."product_brands"
    ADD CONSTRAINT "product_brands_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."product_categories"
    ADD CONSTRAINT "product_categories_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."product_sync_snapshots"
    ADD CONSTRAINT "product_sync_snapshots_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");


    ADD CONSTRAINT "store_access_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."store_access"
    ADD CONSTRAINT "store_access_store_customer_group_unique" UNIQUE ("store_id", "customer_group_id");


ALTER TABLE ONLY "public"."store_product_prices"
    ADD CONSTRAINT "store_product_prices_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."store_product_prices"
    ADD CONSTRAINT "store_product_prices_unique_store_inventory_item" UNIQUE ("tenant_id", "store_id", "inventory_item_id");


ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."system_role_templates"
    ADD CONSTRAINT "system_role_templates_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."system_role_templates"
    ADD CONSTRAINT "system_role_templates_scope_slug_module_action_unique" UNIQUE ("scope", "role_slug", "module_key", "action");


ALTER TABLE ONLY "public"."tag_categories"
    ADD CONSTRAINT "tag_categories_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."tenant_module_submodules"
    ADD CONSTRAINT "tenant_module_submodules_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."tenant_module_submodules"
    ADD CONSTRAINT "tenant_module_submodules_tenant_id_submodule_key_key" UNIQUE ("tenant_id", "submodule_key");


ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_tenant_id_module_key_key" UNIQUE ("tenant_id", "module_key");


ALTER TABLE ONLY "public"."tenant_permission_versions"
    ADD CONSTRAINT "tenant_permission_versions_pkey" PRIMARY KEY ("tenant_id");


ALTER TABLE ONLY "public"."tenant_role_grants"
    ADD CONSTRAINT "tenant_role_grants_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."tenant_role_grants"
    ADD CONSTRAINT "tenant_role_grants_role_module_action_unique" UNIQUE ("tenant_role_id", "module_key", "action");


ALTER TABLE ONLY "public"."tenant_roles"
    ADD CONSTRAINT "tenant_roles_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."tenant_roles"
    ADD CONSTRAINT "tenant_roles_tenant_scope_slug_unique" UNIQUE ("tenant_id", "scope", "slug");


ALTER TABLE ONLY "public"."tenant_scoped_counters"
    ADD CONSTRAINT "tenant_scoped_counters_pkey" PRIMARY KEY ("tenant_id", "scope");


ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_slug_key" UNIQUE ("slug");


ALTER TABLE ONLY "public"."thrift_accounting_ledger"
    ADD CONSTRAINT "thrift_accounting_ledger_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_barcodes"
    ADD CONSTRAINT "thrift_barcodes_barcode_id_tenant_unique" UNIQUE ("tenant_id", "barcode_id");


ALTER TABLE ONLY "public"."thrift_barcodes"
    ADD CONSTRAINT "thrift_barcodes_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_boxes"
    ADD CONSTRAINT "thrift_boxes_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_categories"
    ADD CONSTRAINT "thrift_categories_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_courier_providers"
    ADD CONSTRAINT "thrift_courier_providers_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."global_currencies"
    ADD CONSTRAINT "thrift_currencies_code_key" UNIQUE ("code");


ALTER TABLE ONLY "public"."global_currencies"
    ADD CONSTRAINT "thrift_currencies_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_customers"
    ADD CONSTRAINT "thrift_customers_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_customers"
    ADD CONSTRAINT "thrift_customers_tenant_phone_normalized_key" UNIQUE ("tenant_id", "phone_normalized");


ALTER TABLE ONLY "public"."thrift_invoice_counters"
    ADD CONSTRAINT "thrift_invoice_counters_pkey" PRIMARY KEY ("tenant_id", "year_month");


ALTER TABLE ONLY "public"."thrift_invoice_items"
    ADD CONSTRAINT "thrift_invoice_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_invoices"
    ADD CONSTRAINT "thrift_invoices_number_tenant_unique" UNIQUE ("tenant_id", "invoice_number");


ALTER TABLE ONLY "public"."thrift_invoices"
    ADD CONSTRAINT "thrift_invoices_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_pricings"
    ADD CONSTRAINT "thrift_pricings_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_pricings"
    ADD CONSTRAINT "thrift_pricings_stock_id_key" UNIQUE ("stock_id");


ALTER TABLE ONLY "public"."thrift_return_counters"
    ADD CONSTRAINT "thrift_return_counters_pkey" PRIMARY KEY ("tenant_id", "year_month");


ALTER TABLE ONLY "public"."thrift_sales_invoice_items"
    ADD CONSTRAINT "thrift_sales_invoice_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_tenant_num_key" UNIQUE ("tenant_id", "invoice_number");


ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_invoice_item_key" UNIQUE ("invoice_item_id");


ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_invoice_item_key" UNIQUE ("invoice_item_id");


ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_sales_returns"
    ADD CONSTRAINT "thrift_sales_returns_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_sales_returns"
    ADD CONSTRAINT "thrift_sales_returns_tenant_number_key" UNIQUE ("tenant_id", "return_number");


ALTER TABLE ONLY "public"."thrift_shelves"
    ADD CONSTRAINT "thrift_shelves_code_tenant_unique" UNIQUE ("tenant_id", "shelf_code");


ALTER TABLE ONLY "public"."thrift_shelves"
    ADD CONSTRAINT "thrift_shelves_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_shipments"
    ADD CONSTRAINT "thrift_shipments_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_stock_images"
    ADD CONSTRAINT "thrift_stock_images_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_stock_measurements"
    ADD CONSTRAINT "thrift_stock_measurements_pkey" PRIMARY KEY ("stock_id");


ALTER TABLE ONLY "public"."thrift_settings"
    ADD CONSTRAINT "thrift_stock_settings_pkey" PRIMARY KEY ("tenant_id");


ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_barcode_tenant_unique" UNIQUE ("tenant_id", "barcode");


ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."thrift_types"
    ADD CONSTRAINT "thrift_types_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."units_of_measure"
    ADD CONSTRAINT "units_of_measure_code_key" UNIQUE ("code");


ALTER TABLE ONLY "public"."units_of_measure"
    ADD CONSTRAINT "units_of_measure_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."universal_wallet_ledger"
    ADD CONSTRAINT "universal_wallet_ledger_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."customer_order_backlog_items"
    ADD CONSTRAINT "uq_customer_backlog_item" UNIQUE ("tenant_id", "billing_profile_id", "product_id");


ALTER TABLE ONLY "public"."koba_brands"
    ADD CONSTRAINT "uq_koba_brands_name" UNIQUE ("tenant_id", "name");


ALTER TABLE ONLY "public"."koba_cart_items"
    ADD CONSTRAINT "uq_koba_cart_items_product" UNIQUE ("cart_id", "product_id");


ALTER TABLE ONLY "public"."koba_carts"
    ADD CONSTRAINT "uq_koba_carts_customer_group" UNIQUE ("tenant_id", "customer_group_id");


ALTER TABLE ONLY "public"."koba_categories"
    ADD CONSTRAINT "uq_koba_categories_name" UNIQUE ("tenant_id", "name");


ALTER TABLE ONLY "public"."koba_products"
    ADD CONSTRAINT "uq_koba_products_source" UNIQUE ("tenant_id", "source_type", "source_id");


    ADD CONSTRAINT "uq_tenant_courier_batch_no" UNIQUE ("tenant_id", "courier_service_id", "batch_no");


ALTER TABLE ONLY "public"."wallet_accounts"
    ADD CONSTRAINT "wallet_accounts_entity_currency_key" UNIQUE ("tenant_id", "entity_type", "entity_id", "currency_code");


ALTER TABLE ONLY "public"."wallet_accounts"
    ADD CONSTRAINT "wallet_accounts_pkey" PRIMARY KEY ("id");


CREATE INDEX "activity_logs_item_id_idx" ON "public"."activity_logs" USING "btree" ("item_id");


CREATE INDEX "batch_code_pc_batch_id_idx" ON "public"."batch_code_pc" USING "btree" ("batch_id");


CREATE INDEX "batch_code_pc_product_code_idx" ON "public"."batch_code_pc" USING "btree" ("product_code");


CREATE INDEX "batch_code_pc_shipment_id_idx" ON "public"."batch_code_pc" USING "btree" ("shipment_id");


CREATE INDEX "batch_code_pc_shipment_item_id_idx" ON "public"."batch_code_pc" USING "btree" ("shipment_item_id");


CREATE INDEX "business_parties_parent_tenant_id_idx" ON "public"."business_parties" USING "btree" ("parent_tenant_id");


CREATE INDEX "business_parties_tenant_id_idx" ON "public"."business_parties" USING "btree" ("tenant_id");


CREATE UNIQUE INDEX "cargo_companies_one_default_per_tenant_idx" ON "public"."cargo_companies" USING "btree" ("tenant_id") WHERE (("is_default" = true) AND ("tenant_id" IS NOT NULL));


CREATE INDEX "cargo_companies_parent_tenant_id_idx" ON "public"."cargo_companies" USING "btree" ("parent_tenant_id");


CREATE UNIQUE INDEX "cargo_companies_tenant_code_idx" ON "public"."cargo_companies" USING "btree" ("tenant_id", "upper"(TRIM(BOTH FROM "code"))) WHERE ("tenant_id" IS NOT NULL);


CREATE INDEX "cargo_companies_tenant_id_idx" ON "public"."cargo_companies" USING "btree" ("tenant_id");


CREATE INDEX "cart_items_cart_id_idx" ON "public"."cart_items" USING "btree" ("cart_id");


CREATE INDEX "cart_items_name_idx" ON "public"."cart_items" USING "btree" ("name");


CREATE INDEX "cart_items_product_id_idx" ON "public"."cart_items" USING "btree" ("product_id");


CREATE INDEX "carts_customer_group_id_idx" ON "public"."carts" USING "btree" ("customer_group_id");


CREATE INDEX "carts_store_id_idx" ON "public"."carts" USING "btree" ("store_id");


CREATE INDEX "carts_tenant_id_idx" ON "public"."carts" USING "btree" ("tenant_id");


CREATE INDEX "comments_item_id_idx" ON "public"."comments" USING "btree" ("item_id");


CREATE INDEX "comments_parent_comment_id_idx" ON "public"."comments" USING "btree" ("parent_comment_id");


CREATE INDEX "commerce_cart_customer_group_idx" ON "public"."commerce_cart" USING "btree" ("customer_group_id");


CREATE INDEX "commerce_cart_inventory_item_idx" ON "public"."commerce_cart" USING "btree" ("inventory_item_id");


CREATE INDEX "commerce_cart_product_idx" ON "public"."commerce_cart" USING "btree" ("product_id");


CREATE INDEX "commerce_cart_tenant_idx" ON "public"."commerce_cart" USING "btree" ("tenant_id");


CREATE INDEX "commerce_inventory_product_summaries_product_idx" ON "public"."commerce_inventory_product_summaries" USING "btree" ("product_id");


CREATE INDEX "commerce_inventory_product_summaries_tenant_idx" ON "public"."commerce_inventory_product_summaries" USING "btree" ("tenant_id");


CREATE INDEX "commerce_invoices_billing_profile_idx" ON "public"."commerce_invoices" USING "btree" ("billing_profile_id");


CREATE INDEX "commerce_invoices_order_idx" ON "public"."commerce_invoices" USING "btree" ("order_id");


CREATE INDEX "commerce_invoices_tenant_idx" ON "public"."commerce_invoices" USING "btree" ("tenant_id");


CREATE INDEX "commerce_order_items_global_stock_id_idx" ON "public"."commerce_order_items" USING "btree" ("global_stock_id");


CREATE INDEX "commerce_order_items_inventory_item_idx" ON "public"."commerce_order_items" USING "btree" ("inventory_item_id");


CREATE INDEX "commerce_order_items_invoice_idx" ON "public"."commerce_order_items" USING "btree" ("invoice_id");


CREATE INDEX "commerce_order_items_order_idx" ON "public"."commerce_order_items" USING "btree" ("order_id");


CREATE INDEX "commerce_order_items_product_idx" ON "public"."commerce_order_items" USING "btree" ("product_id");


CREATE INDEX "commerce_order_items_shipment_item_idx" ON "public"."commerce_order_items" USING "btree" ("shipment_item_id");


CREATE INDEX "commerce_orders_customer_group_idx" ON "public"."commerce_orders" USING "btree" ("customer_group_id");


CREATE INDEX "commerce_orders_status_idx" ON "public"."commerce_orders" USING "btree" ("status");


CREATE INDEX "commerce_orders_tenant_idx" ON "public"."commerce_orders" USING "btree" ("tenant_id");


CREATE INDEX "customer_group_members_email_active_idx" ON "public"."customer_group_members" USING "btree" ("lower"(TRIM(BOTH FROM "email")), "is_active");


CREATE INDEX "customer_group_members_email_idx" ON "public"."customer_group_members" USING "btree" ("lower"(TRIM(BOTH FROM "email")));


CREATE UNIQUE INDEX "customer_group_members_group_email_unique" ON "public"."customer_group_members" USING "btree" ("customer_group_id", "lower"(TRIM(BOTH FROM "email")));


CREATE INDEX "customer_group_members_group_id_idx" ON "public"."customer_group_members" USING "btree" ("customer_group_id");


CREATE INDEX "customer_group_members_tenant_role_id_idx" ON "public"."customer_group_members" USING "btree" ("tenant_role_id");


CREATE INDEX "customer_groups_tenant_id_idx" ON "public"."customer_groups" USING "btree" ("tenant_id");


CREATE INDEX "entity_tags_entity_idx" ON "public"."entity_tags" USING "btree" ("entity_type", "entity_id");


CREATE INDEX "entity_tags_tag_id_idx" ON "public"."entity_tags" USING "btree" ("tag_id");


CREATE INDEX "entity_tags_tenant_idx" ON "public"."entity_tags" USING "btree" ("tenant_id");


CREATE INDEX "idx_courier_remittance_batches_courier" ON "public"."courier_remittance_batches" USING "btree" ("courier_service_id");


CREATE INDEX "idx_courier_remittance_batches_status" ON "public"."courier_remittance_batches" USING "btree" ("tenant_id", "status");


CREATE INDEX "idx_courier_remittance_batches_tenant" ON "public"."courier_remittance_batches" USING "btree" ("tenant_id");


CREATE INDEX "idx_courier_remittance_items_batch" ON "public"."courier_remittance_items" USING "btree" ("batch_id");


CREATE INDEX "idx_courier_remittance_items_invoice" ON "public"."courier_remittance_items" USING "btree" ("global_invoice_id");


CREATE INDEX "idx_courier_remittance_items_order" ON "public"."courier_remittance_items" USING "btree" ("shop_order_id");


CREATE INDEX "idx_courier_remittance_items_tenant" ON "public"."courier_remittance_items" USING "btree" ("tenant_id");


CREATE INDEX "idx_courier_remittance_items_tracking" ON "public"."courier_remittance_items" USING "btree" ("tracking_number");


CREATE INDEX "idx_merchant_profiles_tenant" ON "public"."merchant_profiles" USING "btree" ("tenant_id");




CREATE INDEX "idx_thrift_customers_tenant_name" ON "public"."thrift_customers" USING "btree" ("tenant_id", "name");


CREATE INDEX "idx_thrift_customers_tenant_updated" ON "public"."thrift_customers" USING "btree" ("tenant_id", "updated_at" DESC);


CREATE INDEX "idx_thrift_sales_invoice_items_invoice" ON "public"."thrift_sales_invoice_items" USING "btree" ("invoice_id");


CREATE INDEX "idx_thrift_sales_invoice_items_stock" ON "public"."thrift_sales_invoice_items" USING "btree" ("stock_id");


CREATE INDEX "idx_thrift_sales_invoices_courier_provider" ON "public"."thrift_sales_invoices" USING "btree" ("courier_provider_id") WHERE ("courier_provider_id" IS NOT NULL);


CREATE INDEX "idx_thrift_sales_invoices_tenant_close_reason" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "close_reason") WHERE ("close_reason" IS NOT NULL);


CREATE INDEX "idx_thrift_sales_invoices_tenant_customer" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "customer_id") WHERE ("customer_id" IS NOT NULL);


CREATE INDEX "idx_thrift_sales_invoices_tenant_date" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "date" DESC);


CREATE INDEX "idx_thrift_sales_invoices_tenant_delivery_status" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "delivery_status") WHERE ("delivery_status" IS NOT NULL);


CREATE INDEX "idx_thrift_sales_invoices_tenant_status" ON "public"."thrift_sales_invoices" USING "btree" ("tenant_id", "status");


CREATE INDEX "idx_thrift_sales_pnl_lines_invoice" ON "public"."thrift_sales_pnl_lines" USING "btree" ("invoice_id");


CREATE INDEX "idx_thrift_sales_pnl_lines_outcome" ON "public"."thrift_sales_pnl_lines" USING "btree" ("tenant_id", "outcome");


CREATE INDEX "idx_thrift_sales_pnl_lines_shipment" ON "public"."thrift_sales_pnl_lines" USING "btree" ("tenant_id", "inbound_shipment_id", "event_date" DESC);


CREATE INDEX "idx_thrift_sales_pnl_lines_tenant_event_date" ON "public"."thrift_sales_pnl_lines" USING "btree" ("tenant_id", "event_date" DESC);


CREATE INDEX "idx_thrift_sales_return_items_return" ON "public"."thrift_sales_return_items" USING "btree" ("return_id");


CREATE INDEX "idx_thrift_sales_return_items_stock" ON "public"."thrift_sales_return_items" USING "btree" ("stock_id");


CREATE INDEX "idx_thrift_sales_returns_invoice" ON "public"."thrift_sales_returns" USING "btree" ("invoice_id");


CREATE INDEX "idx_thrift_sales_returns_tenant_created" ON "public"."thrift_sales_returns" USING "btree" ("tenant_id", "created_at" DESC);


CREATE INDEX "idx_thrift_stock_measurements_bust" ON "public"."thrift_stock_measurements" USING "btree" ("tenant_id", "bust_in");


CREATE INDEX "idx_thrift_stock_measurements_hips" ON "public"."thrift_stock_measurements" USING "btree" ("tenant_id", "hips_in");


CREATE INDEX "idx_thrift_stock_measurements_waist" ON "public"."thrift_stock_measurements" USING "btree" ("tenant_id", "waist_in");


CREATE INDEX "idx_universal_wallet_ledger_lookup" ON "public"."universal_wallet_ledger" USING "btree" ("tenant_id", "entity_type", "entity_id", "created_at" DESC, "id" DESC);


CREATE INDEX "idx_universal_wallet_ledger_source" ON "public"."universal_wallet_ledger" USING "btree" ("source_type", "source_id");


CREATE INDEX "idx_wallet_accounts_tenant_entity" ON "public"."wallet_accounts" USING "btree" ("tenant_id", "entity_type", "entity_id");


CREATE INDEX "investor_balances_investor_id_idx" ON "public"."investor_balances" USING "btree" ("investor_id");


CREATE INDEX "investor_balances_tenant_id_idx" ON "public"."investor_balances" USING "btree" ("tenant_id");


CREATE INDEX "investor_transactions_investor_id_idx" ON "public"."investor_transactions" USING "btree" ("investor_id");


CREATE INDEX "investor_transactions_tenant_id_idx" ON "public"."investor_transactions" USING "btree" ("tenant_id");


CREATE INDEX "investors_tenant_id_idx" ON "public"."investors" USING "btree" ("tenant_id");


CREATE INDEX "item_assignees_item_id_idx" ON "public"."item_assignees" USING "btree" ("item_id");


CREATE INDEX "item_assignees_user_email_idx" ON "public"."item_assignees" USING "btree" ("user_email");


CREATE INDEX "item_permissions_item_id_idx" ON "public"."item_permissions" USING "btree" ("item_id");


CREATE INDEX "item_permissions_user_email_idx" ON "public"."item_permissions" USING "btree" ("user_email");


CREATE INDEX "item_tags_item_id_idx" ON "public"."item_tags" USING "btree" ("item_id");


CREATE INDEX "item_tags_tag_id_idx" ON "public"."item_tags" USING "btree" ("tag_id");


CREATE INDEX "items_created_by_email_idx" ON "public"."items" USING "btree" ("created_by_email");


CREATE INDEX "items_parent_id_idx" ON "public"."items" USING "btree" ("parent_id");


CREATE INDEX "items_tenant_id_idx" ON "public"."items" USING "btree" ("tenant_id");


CREATE INDEX "koba_brands_tenant_idx" ON "public"."koba_brands" USING "btree" ("tenant_id");


CREATE INDEX "koba_cart_items_cart_id_idx" ON "public"."koba_cart_items" USING "btree" ("cart_id");


CREATE INDEX "koba_cart_items_product_id_idx" ON "public"."koba_cart_items" USING "btree" ("product_id");


CREATE INDEX "koba_carts_customer_group_id_idx" ON "public"."koba_carts" USING "btree" ("customer_group_id");


CREATE INDEX "koba_carts_tenant_idx" ON "public"."koba_carts" USING "btree" ("tenant_id");


CREATE INDEX "koba_categories_tenant_idx" ON "public"."koba_categories" USING "btree" ("tenant_id");


CREATE INDEX "koba_order_items_order_id_idx" ON "public"."koba_order_items" USING "btree" ("order_id");


CREATE INDEX "koba_order_items_product_id_idx" ON "public"."koba_order_items" USING "btree" ("product_id");


CREATE INDEX "koba_orders_customer_group_id_idx" ON "public"."koba_orders" USING "btree" ("customer_group_id");


CREATE INDEX "koba_orders_status_idx" ON "public"."koba_orders" USING "btree" ("status");


CREATE INDEX "koba_orders_tenant_idx" ON "public"."koba_orders" USING "btree" ("tenant_id");


CREATE INDEX "koba_orders_tenant_phone_idx" ON "public"."koba_orders" USING "btree" ("tenant_id", "shipping_phone") WHERE (("shipping_phone" IS NOT NULL) AND ("shipping_phone" <> ''::"text"));


CREATE INDEX "koba_products_barcode_idx" ON "public"."koba_products" USING "btree" ("barcode");


CREATE INDEX "koba_products_sku_idx" ON "public"."koba_products" USING "btree" ("sku");


CREATE INDEX "koba_products_source_type_idx" ON "public"."koba_products" USING "btree" ("source_type");


CREATE INDEX "koba_products_tenant_id_idx" ON "public"."koba_products" USING "btree" ("tenant_id");


CREATE INDEX "markets_code_idx" ON "public"."markets" USING "btree" ("code");


CREATE INDEX "markets_region_idx" ON "public"."markets" USING "btree" ("region");


CREATE INDEX "memberships_email_idx" ON "public"."memberships" USING "btree" ("lower"(TRIM(BOTH FROM "email")));


CREATE UNIQUE INDEX "memberships_email_tenant_unique" ON "public"."memberships" USING "btree" ("lower"(TRIM(BOTH FROM "email")), COALESCE("tenant_id", ('-1'::integer)::bigint));


CREATE INDEX "memberships_role_idx" ON "public"."memberships" USING "btree" ("role");


CREATE UNIQUE INDEX "memberships_superadmin_email_unique" ON "public"."memberships" USING "btree" ("lower"(TRIM(BOTH FROM "email"))) WHERE (("role" = 'superadmin'::"public"."app_role") AND ("tenant_id" IS NULL));


CREATE INDEX "memberships_tenant_id_idx" ON "public"."memberships" USING "btree" ("tenant_id");


CREATE INDEX "memberships_tenant_role_id_idx" ON "public"."memberships" USING "btree" ("tenant_role_id");


CREATE INDEX "modules_parent_module_key_idx" ON "public"."modules" USING "btree" ("parent_module_key");


CREATE INDEX "order_items_barcode_idx" ON "public"."order_items" USING "btree" ("barcode");


CREATE INDEX "order_items_name_idx" ON "public"."order_items" USING "btree" ("name");


CREATE INDEX "order_items_order_id_idx" ON "public"."order_items" USING "btree" ("order_id");


CREATE INDEX "order_items_product_code_idx" ON "public"."order_items" USING "btree" ("product_code");


CREATE INDEX "order_items_product_id_idx" ON "public"."order_items" USING "btree" ("product_id");


CREATE INDEX "order_items_shipment_id_idx" ON "public"."order_items" USING "btree" ("shipment_id");


CREATE INDEX "orders_customer_group_id_idx" ON "public"."orders" USING "btree" ("customer_group_id");


CREATE INDEX "orders_invoice_id_idx" ON "public"."orders" USING "btree" ("invoice_id");


CREATE INDEX "orders_name_idx" ON "public"."orders" USING "btree" ("name");


CREATE INDEX "orders_parent_tenant_id_idx" ON "public"."orders" USING "btree" ("parent_tenant_id");


CREATE INDEX "orders_status_idx" ON "public"."orders" USING "btree" ("status");


CREATE INDEX "orders_store_id_idx" ON "public"."orders" USING "btree" ("store_id");


CREATE INDEX "orders_tenant_id_idx" ON "public"."orders" USING "btree" ("tenant_id");


CREATE UNIQUE INDEX "orders_tenant_id_tenant_order_id_uidx" ON "public"."orders" USING "btree" ("tenant_id", "tenant_order_id");


CREATE INDEX "orders_tenant_order_id_idx" ON "public"."orders" USING "btree" ("tenant_order_id");


CREATE INDEX "payment_allocations_commerce_invoice_id_idx" ON "public"."invoice_payments" USING "btree" ("commerce_invoice_id");


CREATE INDEX "payment_allocations_global_invoice_id_idx" ON "public"."invoice_payments" USING "btree" ("global_invoice_id");


CREATE INDEX "payment_allocations_invoice_id_idx" ON "public"."invoice_payments" USING "btree" ("invoice_id");


CREATE INDEX "payment_allocations_payment_id_idx" ON "public"."invoice_payments" USING "btree" ("payment_id");


CREATE INDEX "payment_allocations_tenant_id_idx" ON "public"."invoice_payments" USING "btree" ("tenant_id");


CREATE INDEX "payment_methods_category_idx" ON "public"."payment_methods" USING "btree" ("category");


CREATE INDEX "payment_methods_scope_idx" ON "public"."payment_methods" USING "btree" ("scope");


CREATE INDEX "payments_billing_profile_id_idx" ON "public"."global_payments" USING "btree" ("billing_profile_id");


CREATE INDEX "payments_payment_date_idx" ON "public"."global_payments" USING "btree" ("payment_date");


CREATE INDEX "payments_tenant_id_idx" ON "public"."global_payments" USING "btree" ("tenant_id");


CREATE INDEX "product_brands_parent_tenant_id_idx" ON "public"."product_brands" USING "btree" ("parent_tenant_id");


CREATE INDEX "product_brands_tenant_id_idx" ON "public"."product_brands" USING "btree" ("tenant_id");


CREATE INDEX "product_brands_vendor_code_idx" ON "public"."product_brands" USING "btree" ("vendor_code");


CREATE INDEX "product_brands_vendor_id_idx" ON "public"."product_brands" USING "btree" ("vendor_id");


CREATE INDEX "product_brands_vendor_id_value_idx" ON "public"."product_brands" USING "btree" ("vendor_id", "value");


CREATE UNIQUE INDEX "product_brands_vendor_value_unique" ON "public"."product_brands" USING "btree" (COALESCE("upper"(TRIM(BOTH FROM "vendor_code")), ''::"text"), "value");


CREATE INDEX "product_categories_parent_tenant_id_idx" ON "public"."product_categories" USING "btree" ("parent_tenant_id");


CREATE INDEX "product_categories_tenant_id_idx" ON "public"."product_categories" USING "btree" ("tenant_id");


CREATE INDEX "product_categories_vendor_code_idx" ON "public"."product_categories" USING "btree" ("vendor_code");


CREATE INDEX "product_categories_vendor_id_idx" ON "public"."product_categories" USING "btree" ("vendor_id");


CREATE INDEX "product_categories_vendor_id_value_idx" ON "public"."product_categories" USING "btree" ("vendor_id", "value");


CREATE UNIQUE INDEX "product_categories_vendor_value_unique" ON "public"."product_categories" USING "btree" (COALESCE("upper"(TRIM(BOTH FROM "vendor_code")), ''::"text"), "value");


CREATE INDEX "product_sync_snapshots_expires_at_idx" ON "public"."product_sync_snapshots" USING "btree" ("expires_at");


CREATE INDEX "product_sync_snapshots_product_id_idx" ON "public"."product_sync_snapshots" USING "btree" ("product_id");


CREATE INDEX "product_sync_snapshots_run_id_idx" ON "public"."product_sync_snapshots" USING "btree" ("run_id");


CREATE INDEX "product_sync_snapshots_scope_idx" ON "public"."product_sync_snapshots" USING "btree" ("tenant_id", "vendor_code", "market_code");


CREATE INDEX "product_sync_snapshots_vendor_id_idx" ON "public"."product_sync_snapshots" USING "btree" ("vendor_id");


CREATE INDEX "products_barcode_idx" ON "public"."products" USING "btree" ("barcode");


CREATE INDEX "products_brand_idx" ON "public"."products" USING "btree" ("brand");


CREATE INDEX "products_category_idx" ON "public"."products" USING "btree" ("category");


CREATE INDEX "products_list_price_currency_id_idx" ON "public"."products" USING "btree" ("list_price_currency_id");


CREATE INDEX "products_market_code_idx" ON "public"."products" USING "btree" ("market_code");


CREATE INDEX "products_name_idx" ON "public"."products" USING "btree" ("name");


CREATE INDEX "products_parent_tenant_id_idx" ON "public"."products" USING "btree" ("parent_tenant_id");


CREATE INDEX "products_product_code_idx" ON "public"."products" USING "btree" ("product_code");


CREATE INDEX "products_reference_cost_currency_id_idx" ON "public"."products" USING "btree" ("reference_cost_currency_id");


CREATE INDEX "products_tenant_id_idx" ON "public"."products" USING "btree" ("tenant_id");


CREATE INDEX "products_vendor_code_idx" ON "public"."products" USING "btree" ("vendor_code");


CREATE INDEX "products_vendor_id_idx" ON "public"."products" USING "btree" ("vendor_id");


CREATE UNIQUE INDEX "uq_products_vendor_catalog_full_key" ON "public"."products" USING "btree" ("parent_tenant_id", "vendor_id", "market_code", "barcode", "product_code") WHERE (("vendor_id" IS NOT NULL) AND ("parent_tenant_id" IS NOT NULL) AND ("market_code" IS NOT NULL) AND (btrim(COALESCE("barcode", ''::"text")) <> ''::"text") AND (btrim(COALESCE("product_code", ''::"text")) <> ''::"text"));


CREATE INDEX "store_access_store_id_idx" ON "public"."store_access" USING "btree" ("store_id");


CREATE INDEX "store_product_prices_inventory_item_idx" ON "public"."store_product_prices" USING "btree" ("inventory_item_id");


CREATE INDEX "store_product_prices_product_id_idx" ON "public"."store_product_prices" USING "btree" ("product_id");


CREATE INDEX "store_product_prices_store_id_idx" ON "public"."store_product_prices" USING "btree" ("store_id");


CREATE INDEX "stores_tenant_id_idx" ON "public"."stores" USING "btree" ("tenant_id");


CREATE INDEX "stores_vendor_code_idx" ON "public"."stores" USING "btree" ("vendor_code");


CREATE INDEX "stores_vendor_id_idx" ON "public"."stores" USING "btree" ("vendor_id");


CREATE UNIQUE INDEX "tag_categories_system_unique" ON "public"."tag_categories" USING "btree" ("module_key", "code") WHERE ("tenant_id" IS NULL);


CREATE UNIQUE INDEX "tag_categories_tenant_unique" ON "public"."tag_categories" USING "btree" ("tenant_id", "module_key", "code") WHERE ("tenant_id" IS NOT NULL);


CREATE UNIQUE INDEX "tags_category_slug_unique" ON "public"."tags" USING "btree" ("category_id", "slug") WHERE ("category_id" IS NOT NULL);


CREATE INDEX "tags_created_by_email_idx" ON "public"."tags" USING "btree" ("created_by_email");


CREATE INDEX "tags_tenant_group_idx" ON "public"."tags" USING "btree" ("tenant_id", "group_name");


CREATE INDEX "tags_tenant_id_idx" ON "public"."tags" USING "btree" ("tenant_id");


CREATE UNIQUE INDEX "tags_tenant_slug_email_unique" ON "public"."tags" USING "btree" ("tenant_id", "slug", "created_by_email") WHERE ("tenant_id" IS NOT NULL);


CREATE INDEX "tenant_module_submodules_tenant_parent_idx" ON "public"."tenant_module_submodules" USING "btree" ("tenant_id", "parent_module_key");


CREATE INDEX "tenant_modules_module_key_idx" ON "public"."tenant_modules" USING "btree" ("module_key");


CREATE INDEX "tenant_modules_tenant_id_idx" ON "public"."tenant_modules" USING "btree" ("tenant_id");


CREATE UNIQUE INDEX "tenant_roles_one_active_admin_idx" ON "public"."tenant_roles" USING "btree" ("tenant_id", "scope") WHERE (("is_admin" = true) AND ("is_active" = true));


CREATE INDEX "tenant_scoped_counters_scope_idx" ON "public"."tenant_scoped_counters" USING "btree" ("scope");


CREATE INDEX "tenants_parent_id_idx" ON "public"."tenants" USING "btree" ("parent_id");


CREATE UNIQUE INDEX "tenants_public_domain_unique_idx" ON "public"."tenants" USING "btree" ("lower"(TRIM(BOTH FROM "public_domain"))) WHERE (NULLIF(TRIM(BOTH FROM "public_domain"), ''::"text") IS NOT NULL);


CREATE UNIQUE INDEX "thrift_categories_global_name_unique" ON "public"."thrift_categories" USING "btree" ("name") WHERE ("is_global" = true);


CREATE UNIQUE INDEX "thrift_categories_tenant_name_unique" ON "public"."thrift_categories" USING "btree" ("tenant_id", "name") WHERE ("is_global" = false);


CREATE UNIQUE INDEX "thrift_courier_providers_system_code_uidx" ON "public"."thrift_courier_providers" USING "btree" ("code") WHERE ("tenant_id" IS NULL);


CREATE UNIQUE INDEX "thrift_courier_providers_tenant_code_uidx" ON "public"."thrift_courier_providers" USING "btree" ("tenant_id", "code") WHERE ("tenant_id" IS NOT NULL);


CREATE INDEX "thrift_stock_images_stock_primary_idx" ON "public"."thrift_stock_images" USING "btree" ("stock_id") WHERE ("is_primary" = true);


CREATE INDEX "thrift_stocks_barcode_trgm_idx" ON "public"."thrift_stocks" USING "gin" ("barcode" "public"."gin_trgm_ops");


CREATE INDEX "thrift_stocks_brand_trgm_idx" ON "public"."thrift_stocks" USING "gin" ("brand_name" "public"."gin_trgm_ops");


CREATE INDEX "thrift_stocks_name_trgm_idx" ON "public"."thrift_stocks" USING "gin" ("name" "public"."gin_trgm_ops");


CREATE INDEX "thrift_stocks_tenant_condition_created_at_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "condition", "created_at" DESC);


CREATE INDEX "thrift_stocks_tenant_created_at_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "created_at" DESC);


CREATE INDEX "thrift_stocks_tenant_deleted_at_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "deleted_at") WHERE ("deleted_at" IS NULL);


CREATE INDEX "thrift_stocks_tenant_reserved_phone_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "held_for_phone_normalized") WHERE ("status" = 'RESERVED'::"public"."thrift_stock_status");


CREATE INDEX "thrift_stocks_tenant_status_created_at_idx" ON "public"."thrift_stocks" USING "btree" ("tenant_id", "status", "created_at" DESC);


CREATE UNIQUE INDEX "thrift_types_global_name_unique" ON "public"."thrift_types" USING "btree" ("name") WHERE ("is_global" = true);


CREATE UNIQUE INDEX "thrift_types_tenant_name_unique" ON "public"."thrift_types" USING "btree" ("tenant_id", "name") WHERE ("is_global" = false);


CREATE INDEX "units_of_measure_unit_type_idx" ON "public"."units_of_measure" USING "btree" ("unit_type");


CREATE UNIQUE INDEX "uq_courier_services_wallet_entity_id" ON "public"."courier_services" USING "btree" ("wallet_entity_id");


CREATE OR REPLACE TRIGGER "on_tenant_created_retail_settings" AFTER INSERT ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_tenant_retail_settings"();


CREATE OR REPLACE TRIGGER "set_koba_retail_settings_updated_at" BEFORE UPDATE ON "public"."koba_retail_settings" FOR EACH ROW EXECUTE FUNCTION "public"."handle_koba_retail_settings_updated_at"();


CREATE OR REPLACE TRIGGER "thrift_stocks_enforce_hold_metadata_trg" BEFORE INSERT OR UPDATE OF "status", "held_for_phone", "held_for_phone_normalized", "held_at" ON "public"."thrift_stocks" FOR EACH ROW EXECUTE FUNCTION "public"."thrift_stocks_enforce_hold_metadata"();


CREATE OR REPLACE TRIGGER "trg_after_tenant_insert" AFTER INSERT ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_seed_new_tenant"();


CREATE OR REPLACE TRIGGER "trg_assign_order_tenant_fields" BEFORE INSERT OR UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."assign_order_tenant_fields"();


CREATE OR REPLACE TRIGGER "trg_auto_enable_universal_wallet" AFTER INSERT ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."auto_enable_universal_wallet_for_new_tenant"();


CREATE OR REPLACE TRIGGER "trg_batch_code_pc_set_updated_at" BEFORE UPDATE ON "public"."batch_code_pc" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_before_customer_member_insert" BEFORE INSERT ON "public"."customer_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_assign_default_customer_role"();


CREATE OR REPLACE TRIGGER "trg_before_membership_insert" BEFORE INSERT ON "public"."memberships" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_assign_default_membership_role"();


CREATE OR REPLACE TRIGGER "trg_business_parties_set_updated_at" BEFORE UPDATE ON "public"."business_parties" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_cargo_companies_updated_at" BEFORE UPDATE ON "public"."cargo_companies" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_cart_items_set_updated_at" BEFORE UPDATE ON "public"."cart_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_carts_set_updated_at" BEFORE UPDATE ON "public"."carts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_cgm_bump_version" AFTER INSERT OR DELETE OR UPDATE ON "public"."customer_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_bump_cgm_version"();


CREATE OR REPLACE TRIGGER "trg_cgm_grants_bump_version" AFTER INSERT OR DELETE OR UPDATE ON "public"."customer_group_member_grants" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_bump_cgm_grant_tenant_version"();


CREATE OR REPLACE TRIGGER "trg_cgm_permission_guardrails" BEFORE INSERT OR UPDATE ON "public"."customer_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_cgm_permission_guardrails"();


CREATE OR REPLACE TRIGGER "trg_cgm_sync_tenant_role" BEFORE INSERT OR UPDATE ON "public"."customer_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_sync_cgm_tenant_role"();


CREATE OR REPLACE TRIGGER "trg_comments_updated_at" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_commerce_cart_updated_at" BEFORE UPDATE ON "public"."commerce_cart" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_commerce_invoice_boxes_set_updated_at" BEFORE UPDATE ON "public"."commerce_invoice_boxes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_commerce_invoices_updated_at" BEFORE UPDATE ON "public"."commerce_invoices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_commerce_order_items_updated_at" BEFORE UPDATE ON "public"."commerce_order_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_commerce_order_settings_updated_at" BEFORE UPDATE ON "public"."commerce_order_settings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_commerce_orders_updated_at" BEFORE UPDATE ON "public"."commerce_orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_customer_group_member_grants_updated_at" BEFORE UPDATE ON "public"."customer_group_member_grants" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_customer_group_members_email_rules" BEFORE INSERT OR UPDATE ON "public"."customer_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_customer_group_member_email_rules"();


CREATE OR REPLACE TRIGGER "trg_customer_group_members_updated_at" BEFORE UPDATE ON "public"."customer_group_members" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();




CREATE OR REPLACE TRIGGER "trg_global_currencies_protect_system_rows" BEFORE DELETE OR UPDATE ON "public"."global_currencies" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_system_global_currency_mutation"();


CREATE OR REPLACE TRIGGER "trg_global_currencies_updated_at" BEFORE UPDATE ON "public"."global_currencies" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_investor_balances_set_updated_at" BEFORE UPDATE ON "public"."investor_balances" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_investor_transactions_set_updated_at" BEFORE UPDATE ON "public"."investor_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_investors_set_updated_at" BEFORE UPDATE ON "public"."investors" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_invoice_boxes_set_updated_at" BEFORE UPDATE ON "public"."invoice_boxes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_items_updated_at" BEFORE UPDATE ON "public"."items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_koba_brands_updated_at" BEFORE UPDATE ON "public"."koba_brands" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_koba_cart_items_updated_at" BEFORE UPDATE ON "public"."koba_cart_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_koba_carts_updated_at" BEFORE UPDATE ON "public"."koba_carts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_koba_categories_updated_at" BEFORE UPDATE ON "public"."koba_categories" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_koba_order_items_updated_at" BEFORE UPDATE ON "public"."koba_order_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_koba_orders_updated_at" BEFORE UPDATE ON "public"."koba_orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_koba_products_updated_at" BEFORE UPDATE ON "public"."koba_products" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_markets_protect_system_rows" BEFORE DELETE OR UPDATE ON "public"."markets" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_system_market_mutation"();


CREATE OR REPLACE TRIGGER "trg_markets_updated_at" BEFORE UPDATE ON "public"."markets" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_membership_grants_bump_version" AFTER INSERT OR DELETE OR UPDATE ON "public"."membership_grants" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_bump_membership_grant_tenant_version"();


CREATE OR REPLACE TRIGGER "trg_membership_grants_updated_at" BEFORE UPDATE ON "public"."membership_grants" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_memberships_bump_version" AFTER INSERT OR DELETE OR UPDATE ON "public"."memberships" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_bump_membership_version"();


CREATE OR REPLACE TRIGGER "trg_memberships_guard_update" BEFORE UPDATE ON "public"."memberships" FOR EACH ROW EXECUTE FUNCTION "public"."guard_membership_update"();


CREATE OR REPLACE TRIGGER "trg_memberships_normalize_email" BEFORE INSERT OR UPDATE OF "email" ON "public"."memberships" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_membership_email"();


CREATE OR REPLACE TRIGGER "trg_memberships_permission_guardrails" BEFORE INSERT OR UPDATE ON "public"."memberships" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_memberships_permission_guardrails"();


CREATE OR REPLACE TRIGGER "trg_memberships_updated_at" BEFORE UPDATE ON "public"."memberships" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_module_actions_updated_at" BEFORE UPDATE ON "public"."module_actions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_modules_updated_at" BEFORE UPDATE ON "public"."modules" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_order_items_set_product_identity" BEFORE INSERT OR UPDATE OF "product_id" ON "public"."order_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_order_item_product_identity"();


CREATE OR REPLACE TRIGGER "trg_order_items_set_updated_at" BEFORE UPDATE ON "public"."order_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_orders_set_parent_tenant_id" BEFORE INSERT OR UPDATE OF "tenant_id" ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_order_parent_tenant_id"();


CREATE OR REPLACE TRIGGER "trg_orders_set_updated_at" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_payment_methods_protect_system_rows" BEFORE DELETE OR UPDATE ON "public"."payment_methods" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_system_payment_method_mutation"();


CREATE OR REPLACE TRIGGER "trg_payment_methods_updated_at" BEFORE UPDATE ON "public"."payment_methods" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_prevent_item_parent_cycles" BEFORE INSERT OR UPDATE OF "parent_id" ON "public"."items" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_item_parent_cycles"();


CREATE OR REPLACE TRIGGER "trg_product_brands_set_parent_tenant_id" BEFORE INSERT OR UPDATE OF "tenant_id" ON "public"."product_brands" FOR EACH ROW EXECUTE FUNCTION "public"."set_parent_tenant_id_from_tenant"();


CREATE OR REPLACE TRIGGER "trg_product_brands_set_updated_at" BEFORE UPDATE ON "public"."product_brands" FOR EACH ROW EXECUTE FUNCTION "public"."set_product_lookup_updated_at_timestamp"();


CREATE OR REPLACE TRIGGER "trg_product_brands_sync_tenant_id" BEFORE INSERT OR UPDATE OF "vendor_id" ON "public"."product_brands" FOR EACH ROW EXECUTE FUNCTION "public"."sync_lookup_tenant_id"();


CREATE OR REPLACE TRIGGER "trg_product_categories_set_parent_tenant_id" BEFORE INSERT OR UPDATE OF "tenant_id" ON "public"."product_categories" FOR EACH ROW EXECUTE FUNCTION "public"."set_parent_tenant_id_from_tenant"();


CREATE OR REPLACE TRIGGER "trg_product_categories_set_updated_at" BEFORE UPDATE ON "public"."product_categories" FOR EACH ROW EXECUTE FUNCTION "public"."set_product_lookup_updated_at_timestamp"();


CREATE OR REPLACE TRIGGER "trg_product_categories_sync_tenant_id" BEFORE INSERT OR UPDATE OF "vendor_id" ON "public"."product_categories" FOR EACH ROW EXECUTE FUNCTION "public"."sync_lookup_tenant_id"();


CREATE OR REPLACE TRIGGER "trg_products_set_parent_tenant_id" BEFORE INSERT OR UPDATE OF "tenant_id" ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."set_parent_tenant_id_from_tenant"();


CREATE OR REPLACE TRIGGER "trg_products_set_tenant_id" BEFORE INSERT ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."set_tenant_id_on_insert"();


CREATE OR REPLACE TRIGGER "trg_products_set_updated_at" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_release_thrift_barcode_on_stock_delete" AFTER DELETE ON "public"."thrift_stocks" FOR EACH ROW EXECUTE FUNCTION "public"."release_thrift_barcode_on_stock_delete"();




CREATE OR REPLACE TRIGGER "trg_store_product_prices_set_updated_at" BEFORE UPDATE ON "public"."store_product_prices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_stores_updated_at" BEFORE UPDATE ON "public"."stores" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_sync_investor_balance_investors" AFTER INSERT ON "public"."investors" FOR EACH ROW EXECUTE FUNCTION "public"."sync_investor_balance_from_investors"();


CREATE OR REPLACE TRIGGER "trg_sync_investor_balance_transactions" AFTER INSERT OR DELETE OR UPDATE ON "public"."investor_transactions" FOR EACH ROW EXECUTE FUNCTION "public"."sync_investor_balance_from_transactions"();




CREATE OR REPLACE TRIGGER "trg_tenant_module_submodules_updated_at" BEFORE UPDATE ON "public"."tenant_module_submodules" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_tenant_modules_bump_version" AFTER INSERT OR DELETE OR UPDATE ON "public"."tenant_modules" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_bump_tenant_modules_version"();


CREATE OR REPLACE TRIGGER "trg_tenant_modules_disable_guardrails" BEFORE UPDATE ON "public"."tenant_modules" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_tenant_modules_disable_guardrails"();


CREATE OR REPLACE TRIGGER "trg_tenant_modules_updated_at" BEFORE UPDATE ON "public"."tenant_modules" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_tenant_role_grants_bump_version" AFTER INSERT OR DELETE OR UPDATE ON "public"."tenant_role_grants" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_bump_grant_tenant_version"();


CREATE OR REPLACE TRIGGER "trg_tenant_role_grants_updated_at" BEFORE UPDATE ON "public"."tenant_role_grants" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_tenant_roles_bump_version" AFTER INSERT OR DELETE OR UPDATE ON "public"."tenant_roles" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_bump_role_tenant_version"();


CREATE OR REPLACE TRIGGER "trg_tenant_roles_guardrails" BEFORE DELETE OR UPDATE ON "public"."tenant_roles" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_tenant_role_guardrails"();


CREATE OR REPLACE TRIGGER "trg_tenant_roles_updated_at" BEFORE UPDATE ON "public"."tenant_roles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_tenant_scoped_counters_set_updated_at" BEFORE UPDATE ON "public"."tenant_scoped_counters" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_tenants_enforce_one_layer_hierarchy" BEFORE INSERT OR UPDATE OF "parent_id" ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_tenant_one_layer_hierarchy"();


CREATE OR REPLACE TRIGGER "trg_tenants_updated_at" BEFORE UPDATE ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_accounting_ledger_updated_at" BEFORE UPDATE ON "public"."thrift_accounting_ledger" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_barcodes_updated_at" BEFORE UPDATE ON "public"."thrift_barcodes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_boxes_updated_at" BEFORE UPDATE ON "public"."thrift_boxes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_categories_updated_at" BEFORE UPDATE ON "public"."thrift_categories" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_courier_providers_guard_system" BEFORE DELETE OR UPDATE ON "public"."thrift_courier_providers" FOR EACH ROW EXECUTE FUNCTION "public"."thrift_courier_providers_guard_system"();


CREATE OR REPLACE TRIGGER "trg_thrift_courier_providers_set_updated_at" BEFORE UPDATE ON "public"."thrift_courier_providers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_customers_updated_at" BEFORE UPDATE ON "public"."thrift_customers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_invoice_counters_set_updated_at" BEFORE UPDATE ON "public"."thrift_invoice_counters" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_invoice_items_profit" BEFORE INSERT OR UPDATE ON "public"."thrift_invoice_items" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_thrift_item_net_profit"();


CREATE OR REPLACE TRIGGER "trg_thrift_invoice_items_total" AFTER INSERT OR DELETE OR UPDATE ON "public"."thrift_invoice_items" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_thrift_invoice_total"();


CREATE OR REPLACE TRIGGER "trg_thrift_invoice_items_updated_at" BEFORE UPDATE ON "public"."thrift_invoice_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_invoices_updated_at" BEFORE UPDATE ON "public"."thrift_invoices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_pricings_updated_at" BEFORE UPDATE ON "public"."thrift_pricings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_return_counters_set_updated_at" BEFORE UPDATE ON "public"."thrift_return_counters" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_sales_pnl_lines_set_updated_at" BEFORE UPDATE ON "public"."thrift_sales_pnl_lines" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_sales_returns_set_updated_at" BEFORE UPDATE ON "public"."thrift_sales_returns" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_settings_updated_at" BEFORE UPDATE ON "public"."thrift_settings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_shelves_updated_at" BEFORE UPDATE ON "public"."thrift_shelves" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_shipments_updated_at" BEFORE UPDATE ON "public"."thrift_shipments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_stock_images_updated_at" BEFORE UPDATE ON "public"."thrift_stock_images" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_stock_loss_ledger" AFTER UPDATE ON "public"."thrift_stocks" FOR EACH ROW EXECUTE FUNCTION "public"."log_thrift_stock_loss_ledger"();


CREATE OR REPLACE TRIGGER "trg_thrift_stock_measurements_updated_at" BEFORE UPDATE ON "public"."thrift_stock_measurements" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_stocks_updated_at" BEFORE UPDATE ON "public"."thrift_stocks" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_thrift_types_updated_at" BEFORE UPDATE ON "public"."thrift_types" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


CREATE OR REPLACE TRIGGER "trg_units_of_measure_protect_system_rows" BEFORE DELETE OR UPDATE ON "public"."units_of_measure" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_system_unit_of_measure_mutation"();


CREATE OR REPLACE TRIGGER "trg_units_of_measure_updated_at" BEFORE UPDATE ON "public"."units_of_measure" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();


ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."items"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."business_parties"
    ADD CONSTRAINT "business_parties_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."business_parties"
    ADD CONSTRAINT "business_parties_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."cargo_companies"
    ADD CONSTRAINT "cargo_companies_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."cargo_companies"
    ADD CONSTRAINT "cargo_companies_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "public"."carts"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."cart_items"
    ADD CONSTRAINT "cart_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."carts"
    ADD CONSTRAINT "carts_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."carts"
    ADD CONSTRAINT "carts_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."items"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_parent_comment_id_fkey" FOREIGN KEY ("parent_comment_id") REFERENCES "public"."comments"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_cart"
    ADD CONSTRAINT "commerce_cart_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_cart"
    ADD CONSTRAINT "commerce_cart_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_cart"
    ADD CONSTRAINT "commerce_cart_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_inventory_product_summaries"
    ADD CONSTRAINT "commerce_inventory_product_summaries_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_inventory_product_summaries"
    ADD CONSTRAINT "commerce_inventory_product_summaries_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_invoice_boxes"
    ADD CONSTRAINT "commerce_invoice_boxes_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."commerce_invoices"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_invoice_boxes"
    ADD CONSTRAINT "commerce_invoice_boxes_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_invoices"
    ADD CONSTRAINT "commerce_invoices_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."commerce_invoices"
    ADD CONSTRAINT "commerce_invoices_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."commerce_orders"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_invoices"
    ADD CONSTRAINT "commerce_invoices_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_order_items"
    ADD CONSTRAINT "commerce_order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."commerce_orders"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_order_items"
    ADD CONSTRAINT "commerce_order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_order_settings"
    ADD CONSTRAINT "commerce_order_settings_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."commerce_orders"
    ADD CONSTRAINT "commerce_orders_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."commerce_orders"
    ADD CONSTRAINT "commerce_orders_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."courier_remittance_batches"
    ADD CONSTRAINT "courier_remittance_batches_courier_service_id_fkey" FOREIGN KEY ("courier_service_id") REFERENCES "public"."courier_services"("id") ON DELETE RESTRICT;


ALTER TABLE ONLY "public"."courier_remittance_batches"
    ADD CONSTRAINT "courier_remittance_batches_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."courier_remittance_batches"
    ADD CONSTRAINT "courier_remittance_batches_posted_by_fkey" FOREIGN KEY ("posted_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."courier_remittance_batches"
    ADD CONSTRAINT "courier_remittance_batches_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."courier_remittance_items"
    ADD CONSTRAINT "courier_remittance_items_batch_id_fkey" FOREIGN KEY ("batch_id") REFERENCES "public"."courier_remittance_batches"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."courier_remittance_items"
    ADD CONSTRAINT "courier_remittance_items_global_invoice_id_fkey" FOREIGN KEY ("global_invoice_id") REFERENCES "public"."sales_invoices"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."courier_remittance_items"
    ADD CONSTRAINT "courier_remittance_items_shop_order_id_fkey" FOREIGN KEY ("shop_order_id") REFERENCES "public"."shop_orders"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."courier_remittance_items"
    ADD CONSTRAINT "courier_remittance_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."courier_services"
    ADD CONSTRAINT "courier_services_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_group_member_grants"
    ADD CONSTRAINT "customer_group_member_grants_customer_group_member_id_fkey" FOREIGN KEY ("customer_group_member_id") REFERENCES "public"."customer_group_members"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_group_member_grants"
    ADD CONSTRAINT "customer_group_member_grants_module_key_fkey" FOREIGN KEY ("module_key") REFERENCES "public"."modules"("key") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_group_members"
    ADD CONSTRAINT "customer_group_members_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_group_members"
    ADD CONSTRAINT "customer_group_members_tenant_role_id_fkey" FOREIGN KEY ("tenant_role_id") REFERENCES "public"."tenant_roles"("id") ON DELETE RESTRICT;


    ADD CONSTRAINT "customer_groups_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_order_backlog_items"
    ADD CONSTRAINT "customer_order_backlog_items_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_order_backlog_items"
    ADD CONSTRAINT "customer_order_backlog_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."shop_orders"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."customer_order_backlog_items"
    ADD CONSTRAINT "customer_order_backlog_items_order_item_id_fkey" FOREIGN KEY ("order_item_id") REFERENCES "public"."shop_order_items"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."customer_order_backlog_items"
    ADD CONSTRAINT "customer_order_backlog_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."customer_order_backlog_items"
    ADD CONSTRAINT "customer_order_backlog_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."entity_tags"
    ADD CONSTRAINT "entity_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."entity_tags"
    ADD CONSTRAINT "entity_tags_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


    ADD CONSTRAINT "gift_rule_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."gift_rule_items"
    ADD CONSTRAINT "gift_rule_items_rule_id_fkey" FOREIGN KEY ("rule_id") REFERENCES "public"."gift_rules"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."gift_rule_redemptions"
    ADD CONSTRAINT "gift_rule_redemptions_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."shop_orders"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."gift_rule_redemptions"
    ADD CONSTRAINT "gift_rule_redemptions_rule_id_fkey" FOREIGN KEY ("rule_id") REFERENCES "public"."gift_rules"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."gift_rules"
    ADD CONSTRAINT "gift_rules_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."investor_balances"
    ADD CONSTRAINT "investor_balances_investor_id_fkey" FOREIGN KEY ("investor_id") REFERENCES "public"."investors"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."investor_balances"
    ADD CONSTRAINT "investor_balances_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."investor_transactions"
    ADD CONSTRAINT "investor_transactions_investor_id_fkey" FOREIGN KEY ("investor_id") REFERENCES "public"."investors"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."investor_transactions"
    ADD CONSTRAINT "investor_transactions_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."investors"
    ADD CONSTRAINT "investors_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."invoice_boxes"
    ADD CONSTRAINT "invoice_boxes_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."item_assignees"
    ADD CONSTRAINT "item_assignees_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."items"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."item_permissions"
    ADD CONSTRAINT "item_permissions_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."items"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."item_tags"
    ADD CONSTRAINT "item_tags_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."items"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."item_tags"
    ADD CONSTRAINT "item_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "public"."tags"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."items"
    ADD CONSTRAINT "items_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."items"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."items"
    ADD CONSTRAINT "items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."koba_brands"
    ADD CONSTRAINT "koba_brands_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."koba_cart_items"
    ADD CONSTRAINT "koba_cart_items_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "public"."koba_carts"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."koba_carts"
    ADD CONSTRAINT "koba_carts_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."koba_carts"
    ADD CONSTRAINT "koba_carts_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."koba_categories"
    ADD CONSTRAINT "koba_categories_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."koba_order_items"
    ADD CONSTRAINT "koba_order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."koba_orders"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."koba_orders"
    ADD CONSTRAINT "koba_orders_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."koba_orders"
    ADD CONSTRAINT "koba_orders_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."koba_products"
    ADD CONSTRAINT "koba_products_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "public"."koba_brands"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."koba_products"
    ADD CONSTRAINT "koba_products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."koba_categories"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."koba_products"
    ADD CONSTRAINT "koba_products_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."koba_retail_settings"
    ADD CONSTRAINT "koba_retail_settings_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."membership_grants"
    ADD CONSTRAINT "membership_grants_membership_id_fkey" FOREIGN KEY ("membership_id") REFERENCES "public"."memberships"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."membership_grants"
    ADD CONSTRAINT "membership_grants_module_key_fkey" FOREIGN KEY ("module_key") REFERENCES "public"."modules"("key") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_investor_id_fkey" FOREIGN KEY ("investor_id") REFERENCES "public"."investors"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_tenant_role_id_fkey" FOREIGN KEY ("tenant_role_id") REFERENCES "public"."tenant_roles"("id") ON DELETE RESTRICT;


ALTER TABLE ONLY "public"."merchant_profiles"
    ADD CONSTRAINT "merchant_profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."module_actions"
    ADD CONSTRAINT "module_actions_module_key_fkey" FOREIGN KEY ("module_key") REFERENCES "public"."modules"("key") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_parent_module_key_fkey" FOREIGN KEY ("parent_module_key") REFERENCES "public"."modules"("key") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."invoice_payments"
    ADD CONSTRAINT "payment_allocations_commerce_invoice_id_fkey" FOREIGN KEY ("commerce_invoice_id") REFERENCES "public"."commerce_invoices"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."invoice_payments"
    ADD CONSTRAINT "payment_allocations_global_invoice_id_fkey" FOREIGN KEY ("global_invoice_id") REFERENCES "public"."sales_invoices"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."invoice_payments"
    ADD CONSTRAINT "payment_allocations_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "public"."global_payments"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."invoice_payments"
    ADD CONSTRAINT "payment_allocations_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."global_payments"
    ADD CONSTRAINT "payments_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."global_payments"
    ADD CONSTRAINT "payments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."product_brands"
    ADD CONSTRAINT "product_brands_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."product_brands"
    ADD CONSTRAINT "product_brands_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."product_categories"
    ADD CONSTRAINT "product_categories_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."product_categories"
    ADD CONSTRAINT "product_categories_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_list_price_currency_id_fkey" FOREIGN KEY ("list_price_currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_market_code_fkey" FOREIGN KEY ("market_code") REFERENCES "public"."markets"("code") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_reference_cost_currency_id_fkey" FOREIGN KEY ("reference_cost_currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


    ADD CONSTRAINT "store_access_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."store_access"
    ADD CONSTRAINT "store_access_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."store_product_prices"
    ADD CONSTRAINT "store_product_prices_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."store_product_prices"
    ADD CONSTRAINT "store_product_prices_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."store_product_prices"
    ADD CONSTRAINT "store_product_prices_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."system_role_templates"
    ADD CONSTRAINT "system_role_templates_module_key_fkey" FOREIGN KEY ("module_key") REFERENCES "public"."modules"("key") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tag_categories"
    ADD CONSTRAINT "tag_categories_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."tag_categories"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tags"
    ADD CONSTRAINT "tags_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_module_submodules"
    ADD CONSTRAINT "tenant_module_submodules_parent_module_key_fkey" FOREIGN KEY ("parent_module_key") REFERENCES "public"."modules"("key") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_module_submodules"
    ADD CONSTRAINT "tenant_module_submodules_submodule_key_fkey" FOREIGN KEY ("submodule_key") REFERENCES "public"."modules"("key") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_module_submodules"
    ADD CONSTRAINT "tenant_module_submodules_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_module_key_fkey" FOREIGN KEY ("module_key") REFERENCES "public"."modules"("key") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_permission_versions"
    ADD CONSTRAINT "tenant_permission_versions_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_role_grants"
    ADD CONSTRAINT "tenant_role_grants_module_key_fkey" FOREIGN KEY ("module_key") REFERENCES "public"."modules"("key") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_role_grants"
    ADD CONSTRAINT "tenant_role_grants_tenant_role_id_fkey" FOREIGN KEY ("tenant_role_id") REFERENCES "public"."tenant_roles"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_roles"
    ADD CONSTRAINT "tenant_roles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenant_scoped_counters"
    ADD CONSTRAINT "tenant_scoped_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."thrift_accounting_ledger"
    ADD CONSTRAINT "thrift_accounting_ledger_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_barcodes"
    ADD CONSTRAINT "thrift_barcodes_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_boxes"
    ADD CONSTRAINT "thrift_boxes_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."thrift_shipments"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_boxes"
    ADD CONSTRAINT "thrift_boxes_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_categories"
    ADD CONSTRAINT "thrift_categories_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_courier_providers"
    ADD CONSTRAINT "thrift_courier_providers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_customers"
    ADD CONSTRAINT "thrift_customers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_invoice_counters"
    ADD CONSTRAINT "thrift_invoice_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_invoice_items"
    ADD CONSTRAINT "thrift_invoice_items_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."thrift_invoices"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_invoice_items"
    ADD CONSTRAINT "thrift_invoice_items_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id");


ALTER TABLE ONLY "public"."thrift_invoices"
    ADD CONSTRAINT "thrift_invoices_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_pricings"
    ADD CONSTRAINT "thrift_pricings_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_return_counters"
    ADD CONSTRAINT "thrift_return_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_invoice_items"
    ADD CONSTRAINT "thrift_sales_invoice_items_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."thrift_sales_invoices"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_invoice_items"
    ADD CONSTRAINT "thrift_sales_invoice_items_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."thrift_sales_invoice_items"
    ADD CONSTRAINT "thrift_sales_invoice_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_courier_provider_id_fkey" FOREIGN KEY ("courier_provider_id") REFERENCES "public"."thrift_courier_providers"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."thrift_customers"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."thrift_sales_invoices"
    ADD CONSTRAINT "thrift_sales_invoices_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_inbound_shipment_id_fkey" FOREIGN KEY ("inbound_shipment_id") REFERENCES "public"."thrift_shipments"("id") ON DELETE RESTRICT;


ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."thrift_sales_invoices"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_invoice_item_id_fkey" FOREIGN KEY ("invoice_item_id") REFERENCES "public"."thrift_sales_invoice_items"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "public"."thrift_sales_returns"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE RESTRICT;


ALTER TABLE ONLY "public"."thrift_sales_pnl_lines"
    ADD CONSTRAINT "thrift_sales_pnl_lines_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_invoice_item_id_fkey" FOREIGN KEY ("invoice_item_id") REFERENCES "public"."thrift_sales_invoice_items"("id") ON DELETE RESTRICT;


ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "public"."thrift_sales_returns"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE RESTRICT;


ALTER TABLE ONLY "public"."thrift_sales_return_items"
    ADD CONSTRAINT "thrift_sales_return_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_returns"
    ADD CONSTRAINT "thrift_sales_returns_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."thrift_sales_invoices"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_sales_returns"
    ADD CONSTRAINT "thrift_sales_returns_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_settings"
    ADD CONSTRAINT "thrift_settings_hand_tag_unit_currency_id_fkey" FOREIGN KEY ("hand_tag_unit_currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."thrift_settings"
    ADD CONSTRAINT "thrift_settings_sticker_unit_currency_id_fkey" FOREIGN KEY ("sticker_unit_currency_id") REFERENCES "public"."global_currencies"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."thrift_settings"
    ADD CONSTRAINT "thrift_settings_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_shelves"
    ADD CONSTRAINT "thrift_shelves_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_shipments"
    ADD CONSTRAINT "thrift_shipments_cost_currency_id_fkey" FOREIGN KEY ("cost_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."thrift_shipments"
    ADD CONSTRAINT "thrift_shipments_purchase_currency_id_fkey" FOREIGN KEY ("purchase_currency_id") REFERENCES "public"."global_currencies"("id");


ALTER TABLE ONLY "public"."thrift_shipments"
    ADD CONSTRAINT "thrift_shipments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_stock_images"
    ADD CONSTRAINT "thrift_stock_images_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_stock_measurements"
    ADD CONSTRAINT "thrift_stock_measurements_stock_id_fkey" FOREIGN KEY ("stock_id") REFERENCES "public"."thrift_stocks"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_box_id_fkey" FOREIGN KEY ("box_id") REFERENCES "public"."thrift_boxes"("id") ON DELETE SET NULL;


ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."thrift_categories"("id");


ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_shelf_id_fkey" FOREIGN KEY ("shelf_id") REFERENCES "public"."thrift_shelves"("id");


ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "public"."thrift_shipments"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."thrift_stocks"
    ADD CONSTRAINT "thrift_stocks_type_id_fkey" FOREIGN KEY ("type_id") REFERENCES "public"."thrift_types"("id");


ALTER TABLE ONLY "public"."thrift_types"
    ADD CONSTRAINT "thrift_types_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."universal_wallet_ledger"
    ADD CONSTRAINT "universal_wallet_ledger_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."wallet_accounts"
    ADD CONSTRAINT "wallet_accounts_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");


CREATE POLICY "Allow authenticated users to read permission versions" ON "public"."tenant_permission_versions" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "Authenticated users can select tenant merchant profiles" ON "public"."merchant_profiles" FOR SELECT TO "authenticated" USING ((("tenant_id" = ( SELECT ("current_setting"('app.current_tenant_id'::"text", true))::bigint AS "current_setting")) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."tenant_id" = "merchant_profiles"."tenant_id") AND ("m"."is_active" = true))))));


CREATE POLICY "Members can delete merchant profiles" ON "public"."merchant_profiles" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."tenant_id" = "merchant_profiles"."tenant_id") AND ("m"."is_active" = true)))));


CREATE POLICY "Members can insert merchant profiles" ON "public"."merchant_profiles" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."tenant_id" = "merchant_profiles"."tenant_id") AND ("m"."is_active" = true)))));


CREATE POLICY "Members can update merchant profiles" ON "public"."merchant_profiles" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."tenant_id" = "merchant_profiles"."tenant_id") AND ("m"."is_active" = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."tenant_id" = "merchant_profiles"."tenant_id") AND ("m"."is_active" = true)))));


CREATE POLICY "Members can view thrift sales invoice items" ON "public"."thrift_sales_invoice_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_sales_invoice_items"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "Members can view thrift sales invoices for their tenant" ON "public"."thrift_sales_invoices" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_sales_invoices"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "Staff and Admins can insert thrift sales invoice items" ON "public"."thrift_sales_invoice_items" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_sales_invoice_items"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['superadmin'::"public"."app_role", 'admin'::"public"."app_role", 'manager'::"public"."app_role", 'staff'::"public"."app_role", 'cashier'::"public"."app_role"]))))));


CREATE POLICY "Staff and Admins can insert thrift sales invoices" ON "public"."thrift_sales_invoices" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_sales_invoices"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['superadmin'::"public"."app_role", 'admin'::"public"."app_role", 'manager'::"public"."app_role", 'staff'::"public"."app_role", 'cashier'::"public"."app_role"]))))));


CREATE POLICY "Staff and Admins can update thrift sales invoices" ON "public"."thrift_sales_invoices" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_sales_invoices"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['superadmin'::"public"."app_role", 'admin'::"public"."app_role", 'manager'::"public"."app_role", 'staff'::"public"."app_role", 'cashier'::"public"."app_role"]))))));


CREATE POLICY "Users can read retail settings for their tenant" ON "public"."koba_retail_settings" FOR SELECT TO "authenticated" USING (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."tenant_id" = "koba_retail_settings"."tenant_id") AND ("m"."is_active" = true))))));


CREATE POLICY "Users can update retail settings for their tenant" ON "public"."koba_retail_settings" FOR UPDATE TO "authenticated" USING (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id"))) WITH CHECK (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id")));


ALTER TABLE "public"."activity_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "activity_logs_insert" ON "public"."activity_logs" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."items"
  WHERE ("items"."id" = "activity_logs"."item_id"))));


CREATE POLICY "activity_logs_select" ON "public"."activity_logs" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."items"
  WHERE ("items"."id" = "activity_logs"."item_id"))));


ALTER TABLE "public"."batch_code_pc" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."business_parties" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "business_parties_select" ON "public"."business_parties" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "business_parties"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))) OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));


CREATE POLICY "business_parties_write" ON "public"."business_parties" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'vendor'::"text", 'edit'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'vendor'::"text", 'edit'::"text"));


ALTER TABLE "public"."cargo_companies" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cargo_companies_delete_policy" ON "public"."cargo_companies" FOR DELETE USING ((("tenant_id" = "public"."current_tenant_id"()) OR ("parent_tenant_id" = "public"."current_tenant_id"())));


CREATE POLICY "cargo_companies_insert_policy" ON "public"."cargo_companies" FOR INSERT WITH CHECK ((("tenant_id" = "public"."current_tenant_id"()) OR ("parent_tenant_id" = "public"."current_tenant_id"())));


CREATE POLICY "cargo_companies_select_policy" ON "public"."cargo_companies" FOR SELECT USING ((("tenant_id" IS NULL) OR ("tenant_id" = "public"."current_tenant_id"()) OR ("parent_tenant_id" = "public"."current_tenant_id"())));


CREATE POLICY "cargo_companies_update_policy" ON "public"."cargo_companies" FOR UPDATE USING ((("tenant_id" = "public"."current_tenant_id"()) OR ("parent_tenant_id" = "public"."current_tenant_id"())));


ALTER TABLE "public"."cart_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cart_items_delete" ON "public"."cart_items" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "cart_items_insert_public" ON "public"."cart_items" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "cart_items_select" ON "public"."cart_items" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "cart_items_update" ON "public"."cart_items" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);


ALTER TABLE "public"."carts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "carts_delete" ON "public"."carts" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "carts_insert_public" ON "public"."carts" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "carts_select" ON "public"."carts" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "carts_update" ON "public"."carts" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);




CREATE POLICY "comments_insert" ON "public"."comments" FOR INSERT TO "authenticated" WITH CHECK (("public"."get_effective_item_role"("item_id", "public"."current_user_email"()) = ANY (ARRAY['owner'::"text", 'manager'::"text", 'editor'::"text", 'commenter'::"text"])));


CREATE POLICY "comments_select" ON "public"."comments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."items"
  WHERE ("items"."id" = "comments"."item_id"))));


CREATE POLICY "comments_update" ON "public"."comments" FOR UPDATE TO "authenticated" USING ((("user_email" = "public"."current_user_email"()) OR ("public"."get_effective_item_role"("item_id", "public"."current_user_email"()) = ANY (ARRAY['owner'::"text", 'manager'::"text"]))));


ALTER TABLE "public"."commerce_cart" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commerce_cart_delete" ON "public"."commerce_cart" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "commerce_cart_insert" ON "public"."commerce_cart" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "commerce_cart_select" ON "public"."commerce_cart" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "commerce_cart_update" ON "public"."commerce_cart" FOR UPDATE TO "authenticated" USING (true);


ALTER TABLE "public"."commerce_inventory_product_summaries" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commerce_inventory_product_summaries_select" ON "public"."commerce_inventory_product_summaries" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."stores" "s"
  WHERE (("s"."tenant_id" = "commerce_inventory_product_summaries"."tenant_id") AND "public"."can_customer_access_store"("s"."id"))))));


ALTER TABLE "public"."commerce_invoice_boxes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commerce_invoice_boxes_delete" ON "public"."commerce_invoice_boxes" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "commerce_invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "commerce_invoice_boxes_insert" ON "public"."commerce_invoice_boxes" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "commerce_invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "commerce_invoice_boxes_select" ON "public"."commerce_invoice_boxes" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "commerce_invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "commerce_invoice_boxes_update" ON "public"."commerce_invoice_boxes" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "commerce_invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "commerce_invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


ALTER TABLE "public"."commerce_invoices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commerce_invoices_delete" ON "public"."commerce_invoices" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "commerce_invoices_insert" ON "public"."commerce_invoices" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "commerce_invoices_select" ON "public"."commerce_invoices" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "commerce_invoices_update" ON "public"."commerce_invoices" FOR UPDATE TO "authenticated" USING (true);


ALTER TABLE "public"."commerce_order_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commerce_order_items_delete" ON "public"."commerce_order_items" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "commerce_order_items_insert" ON "public"."commerce_order_items" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "commerce_order_items_select" ON "public"."commerce_order_items" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "commerce_order_items_update" ON "public"."commerce_order_items" FOR UPDATE TO "authenticated" USING (true);


ALTER TABLE "public"."commerce_order_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commerce_order_settings_delete" ON "public"."commerce_order_settings" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "commerce_order_settings_insert" ON "public"."commerce_order_settings" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "commerce_order_settings_select" ON "public"."commerce_order_settings" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "commerce_order_settings_update" ON "public"."commerce_order_settings" FOR UPDATE TO "authenticated" USING (true);


ALTER TABLE "public"."commerce_orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commerce_orders_delete" ON "public"."commerce_orders" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "commerce_orders_insert" ON "public"."commerce_orders" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "commerce_orders_select" ON "public"."commerce_orders" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "commerce_orders_update" ON "public"."commerce_orders" FOR UPDATE TO "authenticated" USING (true);


ALTER TABLE "public"."courier_services" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "courier_services_delete_policy" ON "public"."courier_services" FOR DELETE TO "authenticated" USING (("public"."is_superadmin"() OR ("public"."membership_has_module_action"("public"."current_tenant_id"(), 'shop_shipping'::"text", 'configure'::"text") AND (("tenant_id" IS NULL) OR ("tenant_id" = "public"."current_tenant_id"())))));


CREATE POLICY "courier_services_insert_policy" ON "public"."courier_services" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_superadmin"() OR ("public"."membership_has_module_action"("public"."current_tenant_id"(), 'shop_shipping'::"text", 'configure'::"text") AND (("tenant_id" IS NULL) OR ("tenant_id" = "public"."current_tenant_id"())))));


CREATE POLICY "courier_services_select_policy" ON "public"."courier_services" FOR SELECT TO "authenticated" USING ((("tenant_id" IS NULL) OR "public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "courier_services"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));


CREATE POLICY "courier_services_update_policy" ON "public"."courier_services" FOR UPDATE TO "authenticated" USING (("public"."is_superadmin"() OR ("public"."membership_has_module_action"("public"."current_tenant_id"(), 'shop_shipping'::"text", 'configure'::"text") AND (("tenant_id" IS NULL) OR ("tenant_id" = "public"."current_tenant_id"()))))) WITH CHECK (("public"."is_superadmin"() OR ("public"."membership_has_module_action"("public"."current_tenant_id"(), 'shop_shipping'::"text", 'configure'::"text") AND (("tenant_id" IS NULL) OR ("tenant_id" = "public"."current_tenant_id"())))));


ALTER TABLE "public"."courier_remittance_batches" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "courier_remittance_batches_tenant_isolation" ON "public"."courier_remittance_batches" TO "authenticated" USING (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "courier_remittance_batches"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))))) WITH CHECK (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "courier_remittance_batches"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));


ALTER TABLE "public"."courier_remittance_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "courier_remittance_items_tenant_isolation" ON "public"."courier_remittance_items" TO "authenticated" USING (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "courier_remittance_items"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))))) WITH CHECK (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "courier_remittance_items"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));


ALTER TABLE "public"."customer_group_member_grants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_group_members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "customer_group_members_delete" ON "public"."customer_group_members" FOR DELETE TO "authenticated" USING ("public"."can_manage_customer_group_member"("customer_group_id"));


CREATE POLICY "customer_group_members_insert" ON "public"."customer_group_members" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_customer_group_member"("customer_group_id"));


CREATE POLICY "customer_group_members_select" ON "public"."customer_group_members" FOR SELECT TO "authenticated" USING ("public"."can_manage_customer_group_member"("customer_group_id"));


CREATE POLICY "customer_group_members_update" ON "public"."customer_group_members" FOR UPDATE TO "authenticated" USING ("public"."can_manage_customer_group_member"("customer_group_id")) WITH CHECK ("public"."can_manage_customer_group_member"("customer_group_id"));




CREATE POLICY "customer_groups_insert" ON "public"."customer_groups" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_customer_group"("tenant_id"));


CREATE POLICY "customer_groups_select" ON "public"."customer_groups" FOR SELECT TO "authenticated" USING (("public"."can_manage_customer_group"("tenant_id") OR "public"."is_tenant_staff"("tenant_id")));


CREATE POLICY "customer_groups_update" ON "public"."customer_groups" FOR UPDATE TO "authenticated" USING ("public"."can_manage_customer_group"("tenant_id")) WITH CHECK ("public"."can_manage_customer_group"("tenant_id"));


ALTER TABLE "public"."customer_order_backlog_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "customer_order_backlog_items_tenant_isolation" ON "public"."customer_order_backlog_items" USING (("tenant_id" = ("current_setting"('app.current_tenant_id'::"text", true))::bigint));


ALTER TABLE "public"."entity_tags" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entity_tags_all" ON "public"."entity_tags" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));


CREATE POLICY "entity_tags_select" ON "public"."entity_tags" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("tenant_id") OR "public"."has_active_tenant_membership"("tenant_id")));


ALTER TABLE "public"."gift_rule_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "gift_rule_items_all_staff" ON "public"."gift_rule_items" USING (("auth"."role"() = 'authenticated'::"text"));


CREATE POLICY "gift_rule_items_select" ON "public"."gift_rule_items" FOR SELECT USING (true);


ALTER TABLE "public"."gift_rule_redemptions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "gift_rule_redemptions_all_staff" ON "public"."gift_rule_redemptions" USING (("auth"."role"() = 'authenticated'::"text"));


CREATE POLICY "gift_rule_redemptions_select" ON "public"."gift_rule_redemptions" FOR SELECT USING (true);


ALTER TABLE "public"."gift_rules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "gift_rules_all_staff" ON "public"."gift_rules" USING (("auth"."role"() = 'authenticated'::"text"));


CREATE POLICY "gift_rules_select" ON "public"."gift_rules" FOR SELECT USING (true);


ALTER TABLE "public"."global_currencies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."global_payments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."investor_balances" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "investor_balances_delete" ON "public"."investor_balances" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investor_balances"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "investor_balances_insert" ON "public"."investor_balances" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investor_balances"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "investor_balances_select" ON "public"."investor_balances" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investor_balances"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "investor_balances_update" ON "public"."investor_balances" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investor_balances"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investor_balances"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


ALTER TABLE "public"."investor_transactions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "investor_transactions_delete" ON "public"."investor_transactions" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investor_transactions"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "investor_transactions_insert" ON "public"."investor_transactions" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investor_transactions"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "investor_transactions_select" ON "public"."investor_transactions" FOR SELECT TO "authenticated" USING (("public"."investor_tenant_can_view"("tenant_id") OR ("public"."auth_investor_id"() = "investor_id")));


CREATE POLICY "investor_transactions_update" ON "public"."investor_transactions" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investor_transactions"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investor_transactions"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


ALTER TABLE "public"."investors" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "investors_delete" ON "public"."investors" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investors"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "investors_insert" ON "public"."investors" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investors"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "investors_select" ON "public"."investors" FOR SELECT TO "authenticated" USING (("public"."investor_tenant_can_view"("tenant_id") OR ("public"."auth_investor_id"() = "id")));


CREATE POLICY "investors_update" ON "public"."investors" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investors"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "investors"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


ALTER TABLE "public"."invoice_boxes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "invoice_boxes_delete" ON "public"."invoice_boxes" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "invoice_boxes_insert" ON "public"."invoice_boxes" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "invoice_boxes_select" ON "public"."invoice_boxes" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "invoice_boxes_update" ON "public"."invoice_boxes" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


ALTER TABLE "public"."invoice_payments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."item_assignees" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "item_assignees_all" ON "public"."item_assignees" TO "authenticated" USING (("public"."get_effective_item_role"("item_id", "public"."current_user_email"()) = ANY (ARRAY['owner'::"text", 'manager'::"text"])));


CREATE POLICY "item_assignees_select" ON "public"."item_assignees" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."items"
  WHERE ("items"."id" = "item_assignees"."item_id"))));


ALTER TABLE "public"."item_permissions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "item_permissions_all" ON "public"."item_permissions" TO "authenticated" USING (("public"."get_effective_item_role"("item_id", "public"."current_user_email"()) = ANY (ARRAY['owner'::"text", 'manager'::"text"])));


CREATE POLICY "item_permissions_select" ON "public"."item_permissions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."items"
  WHERE ("items"."id" = "item_permissions"."item_id"))));


ALTER TABLE "public"."item_tags" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "item_tags_all" ON "public"."item_tags" TO "authenticated" USING (("public"."get_effective_item_role"("item_id", "public"."current_user_email"()) = ANY (ARRAY['owner'::"text", 'manager'::"text", 'editor'::"text"])));


CREATE POLICY "item_tags_select" ON "public"."item_tags" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."items"
  WHERE ("items"."id" = "item_tags"."item_id"))));


ALTER TABLE "public"."items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "items_delete" ON "public"."items" FOR DELETE TO "authenticated" USING (("public"."get_effective_item_role"("id", "public"."current_user_email"()) = ANY (ARRAY['owner'::"text", 'manager'::"text"])));


CREATE POLICY "items_insert" ON "public"."items" FOR INSERT TO "authenticated" WITH CHECK (((("parent_id" IS NULL) AND (("tenant_id" IS NULL) OR ("public"."has_active_tenant_membership"("tenant_id") AND "public"."membership_has_module_action"("tenant_id", 'tasks'::"text", 'create'::"text")))) OR (("parent_id" IS NOT NULL) AND ("public"."get_effective_item_role"("parent_id", "public"."current_user_email"()) = ANY (ARRAY['owner'::"text", 'manager'::"text", 'editor'::"text"])))));


CREATE POLICY "items_select" ON "public"."items" FOR SELECT TO "authenticated" USING (("public"."get_effective_item_role"("id", "public"."current_user_email"()) IS NOT NULL));


CREATE POLICY "items_update" ON "public"."items" FOR UPDATE TO "authenticated" USING (("public"."get_effective_item_role"("id", "public"."current_user_email"()) = ANY (ARRAY['owner'::"text", 'manager'::"text", 'editor'::"text"]))) WITH CHECK (("public"."get_effective_item_role"("id", "public"."current_user_email"()) = ANY (ARRAY['owner'::"text", 'manager'::"text", 'editor'::"text"])));


ALTER TABLE "public"."koba_brands" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "koba_brands_admin_all" ON "public"."koba_brands" TO "authenticated" USING (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id"))) WITH CHECK (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id")));


ALTER TABLE "public"."koba_cart_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "koba_cart_items_delete" ON "public"."koba_cart_items" FOR DELETE TO "authenticated" USING ("public"."koba_cart_allowed"("cart_id"));


CREATE POLICY "koba_cart_items_insert" ON "public"."koba_cart_items" FOR INSERT TO "authenticated" WITH CHECK ("public"."koba_cart_allowed"("cart_id"));


CREATE POLICY "koba_cart_items_select" ON "public"."koba_cart_items" FOR SELECT TO "authenticated" USING ("public"."koba_cart_allowed"("cart_id"));


CREATE POLICY "koba_cart_items_update" ON "public"."koba_cart_items" FOR UPDATE TO "authenticated" USING ("public"."koba_cart_allowed"("cart_id")) WITH CHECK ("public"."koba_cart_allowed"("cart_id"));


ALTER TABLE "public"."koba_carts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "koba_carts_delete" ON "public"."koba_carts" FOR DELETE TO "authenticated" USING ("public"."koba_context_access_allowed"("tenant_id", "customer_group_id"));


CREATE POLICY "koba_carts_insert" ON "public"."koba_carts" FOR INSERT TO "authenticated" WITH CHECK ("public"."koba_context_access_allowed"("tenant_id", "customer_group_id"));


CREATE POLICY "koba_carts_select" ON "public"."koba_carts" FOR SELECT TO "authenticated" USING ("public"."koba_context_access_allowed"("tenant_id", "customer_group_id"));


CREATE POLICY "koba_carts_update" ON "public"."koba_carts" FOR UPDATE TO "authenticated" USING ("public"."koba_context_access_allowed"("tenant_id", "customer_group_id")) WITH CHECK ("public"."koba_context_access_allowed"("tenant_id", "customer_group_id"));


ALTER TABLE "public"."koba_categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "koba_categories_admin_all" ON "public"."koba_categories" TO "authenticated" USING (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id"))) WITH CHECK (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id")));


ALTER TABLE "public"."koba_order_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "koba_order_items_delete" ON "public"."koba_order_items" FOR DELETE TO "authenticated" USING ("public"."koba_order_allowed"("order_id"));


CREATE POLICY "koba_order_items_insert" ON "public"."koba_order_items" FOR INSERT TO "authenticated" WITH CHECK ("public"."koba_order_allowed"("order_id"));


CREATE POLICY "koba_order_items_select" ON "public"."koba_order_items" FOR SELECT TO "authenticated" USING ("public"."koba_order_allowed"("order_id"));


CREATE POLICY "koba_order_items_update" ON "public"."koba_order_items" FOR UPDATE TO "authenticated" USING ("public"."koba_order_allowed"("order_id")) WITH CHECK ("public"."koba_order_allowed"("order_id"));


ALTER TABLE "public"."koba_orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "koba_orders_delete" ON "public"."koba_orders" FOR DELETE TO "authenticated" USING (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id")));


CREATE POLICY "koba_orders_insert" ON "public"."koba_orders" FOR INSERT TO "authenticated" WITH CHECK ("public"."koba_context_access_allowed"("tenant_id", "customer_group_id"));


CREATE POLICY "koba_orders_select" ON "public"."koba_orders" FOR SELECT TO "authenticated" USING ("public"."koba_context_access_allowed"("tenant_id", "customer_group_id"));


CREATE POLICY "koba_orders_update" ON "public"."koba_orders" FOR UPDATE TO "authenticated" USING ("public"."koba_context_access_allowed"("tenant_id", "customer_group_id")) WITH CHECK ("public"."koba_context_access_allowed"("tenant_id", "customer_group_id"));


ALTER TABLE "public"."koba_products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "koba_products_admin_all" ON "public"."koba_products" TO "authenticated" USING (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id"))) WITH CHECK (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id")));


CREATE POLICY "koba_products_tenant_member_read" ON "public"."koba_products" FOR SELECT TO "authenticated" USING (("public"."is_superadmin"() OR "public"."is_tenant_admin"("tenant_id") OR ("tenant_id" = "public"."current_tenant_id"())));


ALTER TABLE "public"."koba_retail_settings" ENABLE ROW LEVEL SECURITY;




ALTER TABLE "public"."markets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "members_can_view_tenants" ON "public"."tenants" FOR SELECT TO "authenticated" USING (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "tenants"."id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));


ALTER TABLE "public"."membership_grants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."memberships" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "memberships_delete" ON "public"."memberships" FOR DELETE TO "authenticated" USING ("public"."can_update_membership_row"("tenant_id", "role"));


CREATE POLICY "memberships_insert" ON "public"."memberships" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_assign_membership_role"("tenant_id", "role"));


CREATE POLICY "memberships_select" ON "public"."memberships" FOR SELECT TO "authenticated" USING (("public"."is_superadmin"() OR "public"."has_active_tenant_membership"("tenant_id")));


CREATE POLICY "memberships_select_own" ON "public"."memberships" FOR SELECT TO "authenticated" USING (("lower"(TRIM(BOTH FROM "email")) = "public"."current_user_email"()));


CREATE POLICY "memberships_update" ON "public"."memberships" FOR UPDATE TO "authenticated" USING ("public"."can_update_membership_row"("tenant_id", "role")) WITH CHECK ("public"."can_assign_membership_role"("tenant_id", "role"));


ALTER TABLE "public"."merchant_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."module_actions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "module_actions_select_all" ON "public"."module_actions" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "module_actions_write_superadmin" ON "public"."module_actions" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());


ALTER TABLE "public"."modules" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "order_items_delete" ON "public"."order_items" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "order_items_insert" ON "public"."order_items" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "order_items_select" ON "public"."order_items" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "order_items_update" ON "public"."order_items" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);


ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "orders_delete" ON "public"."orders" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "orders_insert" ON "public"."orders" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "orders_select" ON "public"."orders" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "orders_update" ON "public"."orders" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);


CREATE POLICY "payment_allocations_delete" ON "public"."invoice_payments" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."global_payments" "p"
  WHERE (("p"."id" = "invoice_payments"."payment_id") AND "public"."membership_has_module_action"("p"."tenant_id", 'payments'::"text", 'void'::"text")))));


CREATE POLICY "payment_allocations_insert" ON "public"."invoice_payments" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."global_payments" "p"
  WHERE (("p"."id" = "invoice_payments"."payment_id") AND "public"."membership_has_module_action"("p"."tenant_id", 'payments'::"text", 'allocate_payment'::"text")))));


CREATE POLICY "payment_allocations_select" ON "public"."invoice_payments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_payments"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "payment_allocations_update" ON "public"."invoice_payments" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."global_payments" "p"
  WHERE (("p"."id" = "invoice_payments"."payment_id") AND "public"."membership_has_module_action"("p"."tenant_id", 'payments'::"text", 'allocate_payment'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."global_payments" "p"
  WHERE (("p"."id" = "invoice_payments"."payment_id") AND "public"."membership_has_module_action"("p"."tenant_id", 'payments'::"text", 'allocate_payment'::"text")))));


ALTER TABLE "public"."payment_methods" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payments_delete" ON "public"."global_payments" FOR DELETE TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'payments'::"text", 'void'::"text"));


CREATE POLICY "payments_insert" ON "public"."global_payments" FOR INSERT TO "authenticated" WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'payments'::"text", 'collect_payment'::"text"));


CREATE POLICY "payments_select" ON "public"."global_payments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_payments"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "payments_update" ON "public"."global_payments" FOR UPDATE TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'payments'::"text", 'allocate_payment'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'payments'::"text", 'allocate_payment'::"text"));


ALTER TABLE "public"."product_brands" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "product_brands_delete_authenticated" ON "public"."product_brands" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "product_brands_insert_authenticated" ON "public"."product_brands" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "product_brands_read_authenticated" ON "public"."product_brands" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("product_brands"."tenant_id" = "m"."tenant_id")))) OR (("parent_tenant_id" IS NOT NULL) AND "public"."user_can_manage_parent_tenant"("parent_tenant_id"))));


CREATE POLICY "product_brands_update_authenticated" ON "public"."product_brands" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);


ALTER TABLE "public"."product_categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "product_categories_delete_authenticated" ON "public"."product_categories" FOR DELETE TO "authenticated" USING (true);


CREATE POLICY "product_categories_insert_authenticated" ON "public"."product_categories" FOR INSERT TO "authenticated" WITH CHECK (true);


CREATE POLICY "product_categories_read_authenticated" ON "public"."product_categories" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("product_categories"."tenant_id" = "m"."tenant_id")))) OR (("parent_tenant_id" IS NOT NULL) AND "public"."user_can_manage_parent_tenant"("parent_tenant_id"))));


CREATE POLICY "product_categories_update_authenticated" ON "public"."product_categories" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products_delete" ON "public"."products" FOR DELETE TO "authenticated" USING ("public"."can_manage_products"("tenant_id"));


CREATE POLICY "products_insert" ON "public"."products" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_products"("tenant_id"));


CREATE POLICY "products_select" ON "public"."products" FOR SELECT TO "authenticated" USING (("public"."can_view_products_internal"("tenant_id") OR "public"."can_view_products_customer"("tenant_id") OR (("parent_tenant_id" IS NOT NULL) AND "public"."user_can_manage_parent_tenant"("parent_tenant_id"))));


CREATE POLICY "products_update" ON "public"."products" FOR UPDATE TO "authenticated" USING ("public"."can_manage_products"("tenant_id")) WITH CHECK ("public"."can_manage_products"("tenant_id"));


CREATE POLICY "select_global_currencies" ON "public"."global_currencies" FOR SELECT TO "authenticated" USING (("is_active" = true));


CREATE POLICY "select_thrift_barcodes" ON "public"."thrift_barcodes" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_barcodes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_boxes" ON "public"."thrift_boxes" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_categories" ON "public"."thrift_categories" FOR SELECT TO "authenticated" USING ((("is_global" = true) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_categories"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));


CREATE POLICY "select_thrift_customers" ON "public"."thrift_customers" FOR SELECT TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'thrift_customers'::"text", 'view'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'view'::"text")));


CREATE POLICY "select_thrift_invoice_items" ON "public"."thrift_invoice_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."thrift_invoices" "i"
     JOIN "public"."memberships" "m" ON (("m"."tenant_id" = "i"."tenant_id")))
  WHERE (("i"."id" = "thrift_invoice_items"."invoice_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_invoices" ON "public"."thrift_invoices" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_invoices"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_ledger" ON "public"."thrift_accounting_ledger" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_accounting_ledger"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_pricings" ON "public"."thrift_pricings" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."thrift_stocks" "s"
     JOIN "public"."memberships" "m" ON (("m"."tenant_id" = "s"."tenant_id")))
  WHERE (("s"."id" = "thrift_pricings"."stock_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_settings" ON "public"."thrift_settings" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_settings"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_shelves" ON "public"."thrift_shelves" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_shelves"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_shipments" ON "public"."thrift_shipments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_shipments"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_stock_images" ON "public"."thrift_stock_images" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."thrift_stocks" "s"
     JOIN "public"."memberships" "m" ON (("m"."tenant_id" = "s"."tenant_id")))
  WHERE (("s"."id" = "thrift_stock_images"."stock_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_stock_measurements" ON "public"."thrift_stock_measurements" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_stock_measurements"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_stocks" ON "public"."thrift_stocks" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_stocks"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));


CREATE POLICY "select_thrift_types" ON "public"."thrift_types" FOR SELECT TO "authenticated" USING ((("is_global" = true) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_types"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));




CREATE POLICY "store_access_select" ON "public"."store_access" FOR SELECT TO "authenticated" USING (true);


ALTER TABLE "public"."store_product_prices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "store_product_prices_delete" ON "public"."store_product_prices" FOR DELETE TO "authenticated" USING ("public"."has_active_tenant_membership"("tenant_id"));


CREATE POLICY "store_product_prices_insert" ON "public"."store_product_prices" FOR INSERT TO "authenticated" WITH CHECK ("public"."has_active_tenant_membership"("tenant_id"));


CREATE POLICY "store_product_prices_select" ON "public"."store_product_prices" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("tenant_id") OR "public"."can_customer_access_store"("store_id")));


CREATE POLICY "store_product_prices_update" ON "public"."store_product_prices" FOR UPDATE TO "authenticated" USING ("public"."has_active_tenant_membership"("tenant_id")) WITH CHECK ("public"."has_active_tenant_membership"("tenant_id"));


ALTER TABLE "public"."stores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stores_modify" ON "public"."stores" TO "authenticated" USING (false) WITH CHECK (false);


CREATE POLICY "stores_select" ON "public"."stores" FOR SELECT TO "authenticated" USING (("public"."can_manage_store"("tenant_id") OR "public"."can_customer_access_store"("id")));


CREATE POLICY "superadmin_can_manage_markets" ON "public"."markets" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());


CREATE POLICY "superadmin_can_manage_modules" ON "public"."modules" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());


CREATE POLICY "superadmin_can_manage_payment_methods" ON "public"."payment_methods" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());


CREATE POLICY "superadmin_can_manage_tenant_modules" ON "public"."tenant_modules" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());


CREATE POLICY "superadmin_can_manage_tenants" ON "public"."tenants" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());


CREATE POLICY "superadmin_can_manage_units_of_measure" ON "public"."units_of_measure" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());


ALTER TABLE "public"."system_role_templates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "system_role_templates_select_all" ON "public"."system_role_templates" FOR SELECT TO "authenticated" USING (true);


CREATE POLICY "system_role_templates_write_superadmin" ON "public"."system_role_templates" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());


ALTER TABLE "public"."tag_categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tag_categories_delete" ON "public"."tag_categories" FOR DELETE TO "authenticated" USING ((("is_system" = false) AND ("tenant_id" IS NOT NULL) AND "public"."has_active_tenant_membership"("tenant_id")));


CREATE POLICY "tag_categories_insert" ON "public"."tag_categories" FOR INSERT TO "authenticated" WITH CHECK ((("is_system" = false) AND ("tenant_id" IS NOT NULL) AND "public"."has_active_tenant_membership"("tenant_id")));


CREATE POLICY "tag_categories_select" ON "public"."tag_categories" FOR SELECT TO "authenticated" USING ((("is_system" = true) OR ("tenant_id" IS NULL) OR (("tenant_id" IS NOT NULL) AND "public"."has_active_tenant_membership"("tenant_id"))));


CREATE POLICY "tag_categories_update" ON "public"."tag_categories" FOR UPDATE TO "authenticated" USING ((("is_system" = false) AND ("tenant_id" IS NOT NULL) AND "public"."has_active_tenant_membership"("tenant_id")));


ALTER TABLE "public"."tags" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tags_delete" ON "public"."tags" FOR DELETE TO "authenticated" USING (((COALESCE("is_system", false) = false) AND (("created_by_email" = "public"."current_user_email"()) OR (("tenant_id" IS NOT NULL) AND "public"."is_tenant_admin"("tenant_id")))));


CREATE POLICY "tags_insert" ON "public"."tags" FOR INSERT TO "authenticated" WITH CHECK (((COALESCE("is_system", false) = false) AND (("created_by_email" = "public"."current_user_email"()) OR (("tenant_id" IS NOT NULL) AND "public"."is_tenant_admin"("tenant_id")))));


CREATE POLICY "tags_select" ON "public"."tags" FOR SELECT TO "authenticated" USING ((("is_system" = true) OR ("tenant_id" IS NULL) OR (("tenant_id" IS NOT NULL) AND "public"."has_active_tenant_membership"("tenant_id")) OR ("created_by_email" = "public"."current_user_email"())));


CREATE POLICY "tags_update" ON "public"."tags" FOR UPDATE TO "authenticated" USING (((COALESCE("is_system", false) = false) AND (("created_by_email" = "public"."current_user_email"()) OR (("tenant_id" IS NOT NULL) AND "public"."is_tenant_admin"("tenant_id"))))) WITH CHECK ((COALESCE("is_system", false) = false));


ALTER TABLE "public"."tenant_module_submodules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tenant_module_submodules_superadmin_all" ON "public"."tenant_module_submodules" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());


ALTER TABLE "public"."tenant_modules" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tenant_permission_versions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tenant_role_grants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tenant_roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_accounting_ledger" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_barcodes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_boxes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_courier_providers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "thrift_courier_providers_delete" ON "public"."thrift_courier_providers" FOR DELETE TO "authenticated" USING ((("is_system" = false) AND ("tenant_id" IS NOT NULL) AND ("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'delete'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_settings'::"text", 'edit'::"text"))));


CREATE POLICY "thrift_courier_providers_insert" ON "public"."thrift_courier_providers" FOR INSERT TO "authenticated" WITH CHECK ((("is_system" = false) AND ("tenant_id" IS NOT NULL) AND ("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'create'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_settings'::"text", 'edit'::"text"))));


CREATE POLICY "thrift_courier_providers_select" ON "public"."thrift_courier_providers" FOR SELECT TO "authenticated" USING (((("tenant_id" IS NULL) AND ("is_system" = true) AND (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))) OR (("tenant_id" IS NOT NULL) AND ("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'view'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_settings'::"text", 'view'::"text")))));


CREATE POLICY "thrift_courier_providers_update" ON "public"."thrift_courier_providers" FOR UPDATE TO "authenticated" USING ((("is_system" = false) AND ("tenant_id" IS NOT NULL) AND ("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'create'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_settings'::"text", 'edit'::"text")))) WITH CHECK ((("is_system" = false) AND ("tenant_id" IS NOT NULL) AND ("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'create'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_settings'::"text", 'edit'::"text"))));


ALTER TABLE "public"."thrift_customers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_invoice_counters" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_invoice_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_invoices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_pricings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_return_counters" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_sales_invoice_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_sales_invoices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_sales_pnl_lines" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "thrift_sales_pnl_lines_delete" ON "public"."thrift_sales_pnl_lines" FOR DELETE TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'staff_mistake'::"text"));


CREATE POLICY "thrift_sales_pnl_lines_insert" ON "public"."thrift_sales_pnl_lines" FOR INSERT TO "authenticated" WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'create'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'return'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'edit'::"text")));


CREATE POLICY "thrift_sales_pnl_lines_select" ON "public"."thrift_sales_pnl_lines" FOR SELECT TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'view'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_reports'::"text", 'view'::"text")));


CREATE POLICY "thrift_sales_pnl_lines_update" ON "public"."thrift_sales_pnl_lines" FOR UPDATE TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'return'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'create'::"text"))) WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'return'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'create'::"text")));


ALTER TABLE "public"."thrift_sales_return_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "thrift_sales_return_items_insert" ON "public"."thrift_sales_return_items" FOR INSERT TO "authenticated" WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'return'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'force_return'::"text")));


CREATE POLICY "thrift_sales_return_items_select" ON "public"."thrift_sales_return_items" FOR SELECT TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'view'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_reports'::"text", 'view'::"text")));


ALTER TABLE "public"."thrift_sales_returns" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "thrift_sales_returns_insert" ON "public"."thrift_sales_returns" FOR INSERT TO "authenticated" WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'return'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'force_return'::"text")));


CREATE POLICY "thrift_sales_returns_select" ON "public"."thrift_sales_returns" FOR SELECT TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'view'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_reports'::"text", 'view'::"text")));


CREATE POLICY "thrift_sales_returns_update" ON "public"."thrift_sales_returns" FOR UPDATE TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'return'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'force_return'::"text"))) WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'return'::"text") OR "public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'force_return'::"text")));


ALTER TABLE "public"."thrift_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_shelves" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_shipments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_stock_images" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_stock_measurements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_stocks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."thrift_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."units_of_measure" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."universal_wallet_ledger" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "universal_wallet_ledger_select" ON "public"."universal_wallet_ledger" FOR SELECT TO "authenticated" USING (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "universal_wallet_ledger"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));


ALTER TABLE "public"."wallet_accounts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "wallet_accounts_authenticated_policy" ON "public"."wallet_accounts" TO "authenticated" USING (true) WITH CHECK (true);


CREATE POLICY "write_thrift_barcodes" ON "public"."thrift_barcodes" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_barcode'::"text", 'edit'::"text"));


CREATE POLICY "write_thrift_boxes" ON "public"."thrift_boxes" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_box'::"text", 'edit'::"text"));


CREATE POLICY "write_thrift_categories" ON "public"."thrift_categories" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_category'::"text", 'edit'::"text"));


CREATE POLICY "write_thrift_customers" ON "public"."thrift_customers" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'edit'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'thrift_sales'::"text", 'edit'::"text"));


CREATE POLICY "write_thrift_ledger" ON "public"."thrift_accounting_ledger" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_accounting_ledger"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "write_thrift_pricings" ON "public"."thrift_pricings" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."thrift_stocks" "s"
  WHERE (("s"."id" = "thrift_pricings"."stock_id") AND "public"."membership_has_module_action"("s"."tenant_id", 'thrift_stock'::"text", 'edit'::"text")))));


CREATE POLICY "write_thrift_settings" ON "public"."thrift_settings" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "thrift_settings"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));


CREATE POLICY "write_thrift_shelves" ON "public"."thrift_shelves" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_shelf'::"text", 'edit'::"text"));


CREATE POLICY "write_thrift_shipments" ON "public"."thrift_shipments" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_shipment'::"text", 'edit'::"text"));


CREATE POLICY "write_thrift_stock_images" ON "public"."thrift_stock_images" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."thrift_stocks" "s"
  WHERE (("s"."id" = "thrift_stock_images"."stock_id") AND "public"."membership_has_module_action"("s"."tenant_id", 'thrift_stock'::"text", 'edit'::"text")))));


CREATE POLICY "write_thrift_stock_measurements" ON "public"."thrift_stock_measurements" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_stock'::"text", 'edit'::"text"));


CREATE POLICY "write_thrift_stocks" ON "public"."thrift_stocks" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_stock'::"text", 'edit'::"text"));


CREATE POLICY "write_thrift_types" ON "public"."thrift_types" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'thrift_type'::"text", 'edit'::"text"));


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";


GRANT ALL ON FUNCTION "public"."add_item_to_cart"("p_tenant_id" bigint, "p_store_id" bigint, "p_customer_group_id" bigint, "p_can_see_price" boolean, "p_product_id" bigint, "p_name" "text", "p_image_url" "text", "p_price_bdt" numeric, "p_minimum_sell_price_bdt" numeric, "p_quantity" integer, "p_minimum_quantity" integer) TO "authenticated";


GRANT ALL ON FUNCTION "public"."add_item_to_commerce_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_global_stock_id" bigint, "p_quantity" integer) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_payments" TO "anon";
GRANT ALL ON TABLE "public"."invoice_payments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_payments" TO "service_role";


GRANT ALL ON FUNCTION "public"."add_payment_allocation"("p_tenant_id" bigint, "p_payment_id" bigint, "p_invoice_id" bigint, "p_amount" numeric) TO "authenticated";


GRANT ALL ON FUNCTION "public"."allocate_payment_to_global_invoice"("p_tenant_id" bigint, "p_payment_id" bigint, "p_global_invoice_id" bigint, "p_amount" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."allocate_payment_to_global_invoice"("p_tenant_id" bigint, "p_payment_id" bigint, "p_global_invoice_id" bigint, "p_amount" numeric) TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tags" TO "anon";
GRANT ALL ON TABLE "public"."tags" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tags" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_group_members" TO "anon";
GRANT ALL ON TABLE "public"."customer_group_members" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_group_members" TO "service_role";


GRANT ALL ON FUNCTION "public"."assign_customer_group_member_role"("p_cgm_id" bigint, "p_tenant_role_id" bigint) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."memberships" TO "anon";
GRANT ALL ON TABLE "public"."memberships" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."memberships" TO "service_role";


GRANT ALL ON FUNCTION "public"."assign_membership_role"("p_membership_id" bigint, "p_tenant_role_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."auth_investor_id"() TO "authenticated";


GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."order_items" TO "service_role";


GRANT ALL ON FUNCTION "public"."bulk_update_order_item_offers"("p_items" "jsonb") TO "authenticated";


GRANT ALL ON FUNCTION "public"."bulk_update_order_items"("p_items" "jsonb") TO "authenticated";


GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_locations"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_shelf_id" bigint, "p_box_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_locations"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_shelf_id" bigint, "p_box_id" bigint) TO "service_role";


GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_statuses"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_statuses"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_status" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."can_assign_membership_role"("p_target_tenant_id" bigint, "p_target_role" "public"."app_role") TO "authenticated";






GRANT ALL ON FUNCTION "public"."can_insert_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_store_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_manage_customer_group"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_manage_customer_group_member"("p_customer_group_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_manage_membership"("p_target_tenant_id" bigint, "p_target_role" "public"."app_role") TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_manage_products"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_update_membership_row"("p_existing_tenant_id" bigint, "p_existing_role" "public"."app_role") TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_view_products_customer"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_view_products_internal"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_view_tenant_modules"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."cart_exists"("p_cart_id" bigint) TO "authenticated";




GRANT ALL ON FUNCTION "public"."check_store_price_access"("p_store_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."compute_thrift_landed_unit_cost"("p_stock_id" bigint) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."confirm_courier_remittance_to_tenant"("p_order_id" bigint, "p_courier_charge" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."confirm_courier_remittance_to_tenant"("p_order_id" bigint, "p_courier_charge" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."confirm_courier_remittance_to_tenant"("p_order_id" bigint, "p_courier_charge" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text") TO "service_role";


GRANT ALL ON TABLE "public"."global_payments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_payments" TO "service_role";


GRANT ALL ON FUNCTION "public"."create_billing_profile_payment_with_allocations"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payment_date" "date", "p_method" "text", "p_reference" "text", "p_note" "text", "p_allocations" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_billing_profile_payment_with_allocations"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payment_date" "date", "p_method" "text", "p_reference" "text", "p_note" "text", "p_allocations" "jsonb") TO "service_role";


REVOKE ALL ON FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_notes" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_notes" "text") TO "service_role";




GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stores" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stores" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stores" TO "service_role";


GRANT ALL ON FUNCTION "public"."create_store"("p_name" "text", "p_vendor_code" "text", "p_tenant_id" bigint) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."store_access" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."store_access" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."store_access" TO "service_role";


GRANT ALL ON FUNCTION "public"."create_store_access"("p_store_id" bigint, "p_customer_group_id" bigint, "p_status" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."create_store_access"("p_store_id" bigint, "p_customer_group_id" bigint, "p_status" boolean, "p_see_price" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."create_tenant_for_superadmin"("p_name" "text", "p_slug" "text", "p_is_active" boolean, "p_public_domain" "text", "p_parent_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."create_tenant_module_for_superadmin"("p_tenant_id" bigint, "p_module_key" "text", "p_is_active" boolean) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_roles" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_roles" TO "service_role";


GRANT ALL ON FUNCTION "public"."create_tenant_role"("p_tenant_id" bigint, "p_scope" "text", "p_name" "text", "p_slug" "text", "p_is_admin" boolean) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") TO "service_role";


REVOKE ALL ON FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") TO "service_role";


REVOKE ALL ON FUNCTION "public"."current_customer_group_id"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_customer_group_id"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."current_tenant_id"() TO "authenticated";




GRANT ALL ON FUNCTION "public"."delete_membership_grant"("p_membership_id" bigint, "p_module_key" "text", "p_action" "text") TO "authenticated";




GRANT ALL ON FUNCTION "public"."delete_store_access"("p_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."delete_tenant_for_superadmin"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."delete_tenant_module_for_superadmin"("p_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."delete_tenant_role"("p_role_id" bigint) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) TO "service_role";


GRANT ALL ON FUNCTION "public"."dispense_middleman_payout"("p_billing_profile_id" bigint, "p_amount" numeric, "p_method" "text", "p_trx_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."dispense_middleman_payout"("p_billing_profile_id" bigint, "p_amount" numeric, "p_method" "text", "p_trx_id" "text") TO "service_role";


REVOKE ALL ON FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) TO "service_role";


GRANT ALL ON FUNCTION "public"."find_active_tenant_by_public_domain"("p_public_domain" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."find_active_tenant_by_slug"("p_slug" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."find_active_tenant_by_slug"("p_slug" "text") TO "authenticated";




REVOKE ALL ON FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "service_role";


REVOKE ALL ON FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "service_role";


GRANT ALL ON FUNCTION "public"."get_active_module_keys_for_tenant"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_app_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_membership_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_cart"("p_cart_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_cart_details"("p_cart_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_courier_unremitted_financial_summary"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_courier_unremitted_financial_summary"("p_tenant_id" bigint) TO "service_role";




GRANT ALL ON FUNCTION "public"."get_effective_item_role"("p_item_id" bigint, "p_user_email" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_investor_allocation_detail"("p_tenant_id" bigint, "p_investor_id" bigint, "p_global_shipment_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_investor_bootstrap_context"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_investor_capital_report"("p_tenant_id" bigint, "p_investor_id" bigint, "p_start_date" "date", "p_end_date" "date") TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_investor_dashboard_summary"("p_tenant_id" bigint, "p_investor_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_investor_portfolio_summary"("p_investor_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_item_details"("p_item_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_koba_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_koba_cart"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "service_role";


GRANT ALL ON FUNCTION "public"."get_koba_customer_profile"("p_tenant_id" bigint, "p_phone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_koba_customer_profile"("p_tenant_id" bigint, "p_phone" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."get_koba_customers_list"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_koba_customers_list"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "service_role";




GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."products" TO "service_role";


GRANT ALL ON FUNCTION "public"."get_product_for_tenant"("p_id" bigint, "p_tenant_id" bigint) TO "authenticated";




GRANT ALL ON FUNCTION "public"."get_store_access_admin_v2"("p_store_id" bigint, "p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_store_product_brands"("p_store_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_store_product_categories"("p_store_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_stores_admin"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_stores_for_customer"() TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_stores_for_customer_v2"("p_tenant_id" bigint) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."get_tag_by_slug"("p_category_id" bigint, "p_module_key" "text", "p_code" "text", "p_slug" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_tag_by_slug"("p_category_id" bigint, "p_module_key" "text", "p_code" "text", "p_slug" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_tenant_details_by_membership"("p_tenant_id" bigint, "p_email" "text", "p_role" "public"."app_role") TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_tenant_module_by_id"("p_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_tenant_permission_version"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_tenant_role_detail"("p_role_id" bigint) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."get_thrift_dashboard_metrics"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_thrift_dashboard_metrics"("p_tenant_id" bigint) TO "service_role";


REVOKE ALL ON FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) TO "service_role";


GRANT ALL ON FUNCTION "public"."get_tenant_cash_in_report"("p_tenant_id" bigint, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_tenant_cash_in_report"("p_tenant_id" bigint, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "service_role";


GRANT ALL ON FUNCTION "public"."get_wallet_account_balances"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_wallet_account_balances"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."get_wallet_dashboard_summary"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_wallet_dashboard_summary"("p_tenant_id" bigint) TO "service_role";


GRANT ALL ON FUNCTION "public"."get_wallet_entity_statement"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_wallet_entity_statement"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "service_role";


GRANT ALL ON FUNCTION "public"."global_search_tasks"("p_query" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."has_module_action"("p_tenant_id" bigint, "p_module_key" "text", "p_action" "text") TO "authenticated";


REVOKE ALL ON FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) TO "service_role";


GRANT ALL ON FUNCTION "public"."investor_tenant_can_view"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."is_child_tenant"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."is_customer_group_admin_or_negotiator"("p_customer_group_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."is_customer_group_member"("p_customer_group_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."is_parent_company"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."is_tenant_staff"("p_tenant_id" bigint) TO "authenticated";




GRANT ALL ON FUNCTION "public"."list_child_tenant_ids"("p_parent_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_child_tenant_refs"(bigint[]) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_commerce_global_stock_for_store"("p_tenant_id" bigint, "p_store_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_configurable_module_actions"("p_scope" "text", "p_tenant_id" bigint) TO "authenticated";




GRANT ALL ON FUNCTION "public"."list_customer_order_backlog_items"("p_tenant_id" bigint, "p_billing_profile_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_global_currencies"() TO "service_role";


GRANT ALL ON FUNCTION "public"."list_investor_allocations"("p_tenant_id" bigint, "p_investor_id" bigint, "p_limit" integer, "p_offset" integer) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_investor_profiles"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_investor_transactions"("p_tenant_id" bigint, "p_investor_id" bigint, "p_limit" integer, "p_offset" integer) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."list_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."list_items_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_type" "text", "p_status" "text", "p_priority" "text", "p_assignee" "text", "p_my_tasks_email" "text", "p_include_parents" boolean, "p_tag_id" bigint, "p_date_field" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_items_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_type" "text", "p_status" "text", "p_priority" "text", "p_assignee" "text", "p_my_tasks_email" "text", "p_include_parents" boolean, "p_tag_id" bigint, "p_date_field" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."list_items_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_type" "text", "p_status" "text", "p_priority" "text", "p_assignee" "text", "p_my_tasks_email" "text", "p_include_parents" boolean, "p_tag_id" bigint, "p_date_field" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone) TO "service_role";


GRANT ALL ON FUNCTION "public"."list_koba_brands_for_tenant"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_koba_brands_for_tenant"("p_tenant_id" bigint) TO "service_role";


GRANT ALL ON FUNCTION "public"."list_koba_categories_for_tenant"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_koba_categories_for_tenant"("p_tenant_id" bigint) TO "service_role";


GRANT ALL ON FUNCTION "public"."list_koba_orders"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_page" integer, "p_page_size" integer, "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_koba_orders"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_page" integer, "p_page_size" integer, "p_status" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."list_koba_retail_products"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_brand_id" bigint, "p_category_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_koba_retail_products"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_brand_id" bigint, "p_category_id" bigint) TO "service_role";




GRANT ALL ON FUNCTION "public"."list_membership_ids_with_overrides"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_my_admin_tenants"() TO "authenticated";




GRANT ALL ON TABLE "public"."product_brands" TO "authenticated";
GRANT ALL ON TABLE "public"."product_brands" TO "service_role";


GRANT ALL ON FUNCTION "public"."list_product_brands_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text", "p_vendor_id" bigint) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_categories" TO "anon";
GRANT ALL ON TABLE "public"."product_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."product_categories" TO "service_role";


GRANT ALL ON FUNCTION "public"."list_product_categories_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text", "p_vendor_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_products_paginated"("p_tenant_id" bigint, "p_search" "text", "p_search_field" "text", "p_category" "text", "p_brand" "text", "p_vendor_code" "text", "p_market_code" "text", "p_is_available" boolean, "p_sort_by" "text", "p_sort_dir" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";




REVOKE ALL ON FUNCTION "public"."list_tag_categories"("p_module_key" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_tag_categories"("p_module_key" "text") TO "authenticated";


REVOKE ALL ON FUNCTION "public"."list_tags_for_category"("p_category_id" bigint, "p_module_key" "text", "p_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_tags_for_category"("p_category_id" bigint, "p_module_key" "text", "p_code" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_tenant_module_submodules_for_superadmin"("p_tenant_id" bigint, "p_parent_module_key" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_tenant_modules_by_tenant"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_tenant_role_grants"("p_tenant_role_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_tenant_roles"("p_tenant_id" bigint, "p_scope" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_tenant_viewers"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_tenants_by_membership"("p_tenant_id" bigint, "p_email" "text", "p_role" "public"."app_role") TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_tenants_for_superadmin"() TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_thrift_barcodes_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_is_printed" smallint, "p_status" "text") TO "authenticated";


REVOKE ALL ON FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_payment_status" "text", "p_status" "text", "p_delivery_status" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_payment_status" "text", "p_status" "text", "p_delivery_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_payment_status" "text", "p_status" "text", "p_delivery_status" "text") TO "service_role";


REVOKE ALL ON FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) TO "service_role";


GRANT ALL ON FUNCTION "public"."list_thrift_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text", "p_condition" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_units_of_measure"() TO "authenticated";




GRANT ALL ON FUNCTION "public"."membership_has_module_action"("p_tenant_id" bigint, "p_module_key" "text", "p_action" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."next_tenant_scoped_counter"("p_tenant_id" bigint, "p_scope" "text") TO "authenticated";


REVOKE ALL ON FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."parent_tenant_has_module_action"("p_parent_tenant_id" bigint, "p_module_key" "text", "p_action" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."place_commerce_order"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_shipment_payment" numeric, "p_invoice_print_charge" numeric, "p_wrapping_charge" numeric, "p_cod" numeric, "p_delivery_charge" numeric, "p_is_delivery_charge_inclusive" boolean, "p_items" "jsonb") TO "authenticated";


GRANT ALL ON FUNCTION "public"."place_koba_order"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_shipping_name" "text", "p_shipping_phone" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_shipping_address" "text", "p_free_delivery" boolean, "p_extra_profit_user" numeric, "p_extra_profit_company" numeric, "p_delivery_adjustment" numeric, "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_charge" numeric, "p_net_order_commission" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."place_koba_order"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_shipping_name" "text", "p_shipping_phone" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_shipping_address" "text", "p_free_delivery" boolean, "p_extra_profit_user" numeric, "p_extra_profit_company" numeric, "p_delivery_adjustment" numeric, "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_charge" numeric, "p_net_order_commission" numeric) TO "service_role";


GRANT ALL ON FUNCTION "public"."post_global_invoice"("p_invoice_id" bigint) TO "service_role";


GRANT ALL ON FUNCTION "public"."process_courier_bulk_remittance_batch"("p_batch_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."reconcile_single_order_remittance"("p_order_id" bigint, "p_courier_charge" numeric) TO "service_role";


GRANT ALL ON TABLE "public"."investor_transactions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."investor_transactions" TO "service_role";


GRANT ALL ON FUNCTION "public"."record_investor_capital_adjustment"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."record_investor_capital_in"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_investor_capital_in"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."record_investor_withdrawal_paid"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_investor_withdrawal_paid"("p_tenant_id" bigint, "p_investor_id" bigint, "p_amount" numeric, "p_date" "date", "p_method" "public"."investor_payment_method", "p_note" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."record_ledger_transaction"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text", "p_exchange_rate" numeric, "p_source_type" "text", "p_source_id" "text", "p_metadata" "jsonb", "p_target_bucket" "text", "p_allow_overdraft" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_ledger_transaction"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text", "p_exchange_rate" numeric, "p_source_type" "text", "p_source_id" "text", "p_metadata" "jsonb", "p_target_bucket" "text", "p_allow_overdraft" boolean) TO "service_role";


GRANT ALL ON FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone, "p_remittance_ref" "text", "p_notes" "text", "p_outcome" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone, "p_remittance_ref" "text", "p_notes" "text", "p_outcome" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."refresh_commerce_inventory_product_summaries"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."refresh_commerce_inventory_product_summary_single"("p_tenant_id" bigint, "p_product_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_extra_origin_purchase_expense" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_extra_expense_cost" numeric, "p_inserted_by" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_inserted_by" "text", "p_origin_unit_price" numeric, "p_extra_origin_unit_price" numeric, "p_listed_unit_price" numeric, "p_extra_origin_purchase_expense" numeric) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) TO "service_role";




GRANT ALL ON FUNCTION "public"."resolve_tenant_for_entry"("p_slug" "text", "p_hostname" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_tenant_for_entry"("p_slug" "text", "p_hostname" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."resolve_thrift_barcode"("p_tenant_id" bigint, "p_scanned_value" "text") TO "authenticated";


REVOKE ALL ON FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) TO "service_role";


REVOKE ALL ON FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) TO "service_role";


GRANT ALL ON FUNCTION "public"."seed_tenant_roles_and_grants"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."set_tenant_id_on_insert"() TO "authenticated";


GRANT ALL ON FUNCTION "public"."set_tenant_module_submodule_for_superadmin"("p_tenant_id" bigint, "p_parent_module_key" "text", "p_submodule_key" "text", "p_is_enabled" boolean) TO "authenticated";




GRANT ALL ON FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") TO "authenticated";


GRANT ALL ON FUNCTION "public"."staff_start_catalog_procurement"("p_order_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text", "p_notes" "text", "p_metadata" "jsonb") TO "service_role";


GRANT ALL ON FUNCTION "public"."unpost_global_invoice"("p_invoice_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."unpost_global_invoice"("p_invoice_id" bigint) TO "service_role";




GRANT ALL ON FUNCTION "public"."update_payment_allocation_amount"("p_tenant_id" bigint, "p_allocation_id" bigint, "p_amount" numeric) TO "authenticated";




GRANT ALL ON FUNCTION "public"."update_store_access"("p_id" bigint, "p_status" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."update_store_access_fields"("p_id" bigint, "p_status" boolean, "p_see_price" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."update_tenant_for_superadmin"("p_tenant_id" bigint, "p_name" "text", "p_slug" "text", "p_is_active" boolean, "p_public_domain" "text", "p_parent_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."update_tenant_module_for_superadmin"("p_id" bigint, "p_tenant_id" bigint, "p_module_key" "text", "p_is_active" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."update_tenant_preference_for_admin"("p_tenant_id" bigint, "p_preference" "jsonb") TO "authenticated";


GRANT ALL ON FUNCTION "public"."update_tenant_role"("p_role_id" bigint, "p_name" "text", "p_is_admin" boolean) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_group_member_grants" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_group_member_grants" TO "service_role";


GRANT ALL ON FUNCTION "public"."upsert_customer_group_member_grant"("p_cgm_id" bigint, "p_module_key" "text", "p_action" "text", "p_effect" "text") TO "authenticated";


GRANT ALL ON TABLE "public"."investors" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."investors" TO "service_role";


GRANT ALL ON FUNCTION "public"."upsert_investor_profile"("p_id" bigint, "p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_email" "text", "p_address" "text", "p_is_active" boolean, "p_currency_code" "text", "p_notes" "text") TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."membership_grants" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."membership_grants" TO "service_role";


GRANT ALL ON FUNCTION "public"."upsert_membership_grant"("p_membership_id" bigint, "p_module_key" "text", "p_action" "text", "p_effect" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."upsert_recipient_profile_and_address"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_phone_secondary" "text", "p_address" "text", "p_district" "text", "p_thana" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."upsert_recipient_profile_by_phone"("p_tenant_id" bigint, "p_name" "text", "p_phone" "text", "p_secondary_phone" "text", "p_address" "text", "p_district" "text", "p_thana" "text") TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_role_grants" TO "service_role";


GRANT ALL ON FUNCTION "public"."upsert_tenant_role_grant"("p_tenant_role_id" bigint, "p_module_key" "text", "p_action" "text", "p_allowed" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."user_can_access_tenant_fetch"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."user_can_manage_parent_tenant"("p_parent_tenant_id" bigint) TO "authenticated";




GRANT ALL ON FUNCTION "public"."void_global_invoice"("p_invoice_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."void_global_invoice"("p_invoice_id" bigint) TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."activity_logs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."activity_logs" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."activity_logs" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."activity_logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."activity_logs_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."activity_logs_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."batch_code_pc" TO "anon";
GRANT ALL ON TABLE "public"."batch_code_pc" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."batch_code_pc" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."batch_code_pc_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."batch_code_pc_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."batch_code_pc_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."business_parties" TO "anon";
GRANT ALL ON TABLE "public"."business_parties" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."business_parties" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."business_parties_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."business_parties_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."business_parties_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."cargo_companies" TO "anon";
GRANT ALL ON TABLE "public"."cargo_companies" TO "authenticated";
GRANT ALL ON TABLE "public"."cargo_companies" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."cargo_companies_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."cargo_companies_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."cargo_companies_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."cart_items" TO "anon";
GRANT ALL ON TABLE "public"."cart_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."cart_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."cart_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."cart_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."cart_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."carts" TO "anon";
GRANT ALL ON TABLE "public"."carts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."carts" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."carts_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."carts_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."carts_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."comments" TO "anon";
GRANT ALL ON TABLE "public"."comments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."comments" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."comments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."comments_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."comments_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_cart" TO "anon";
GRANT ALL ON TABLE "public"."commerce_cart" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_cart" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."commerce_cart_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."commerce_cart_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."commerce_cart_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_inventory_product_summaries" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_inventory_product_summaries" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_inventory_product_summaries" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."commerce_inventory_product_summaries_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."commerce_inventory_product_summaries_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."commerce_inventory_product_summaries_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_invoice_boxes" TO "anon";
GRANT ALL ON TABLE "public"."commerce_invoice_boxes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_invoice_boxes" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."commerce_invoice_boxes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."commerce_invoice_boxes_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."commerce_invoice_boxes_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_invoices" TO "anon";
GRANT ALL ON TABLE "public"."commerce_invoices" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_invoices" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."commerce_invoices_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."commerce_invoices_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."commerce_invoices_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_order_items" TO "anon";
GRANT ALL ON TABLE "public"."commerce_order_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_order_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."commerce_order_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."commerce_order_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."commerce_order_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_order_settings" TO "anon";
GRANT ALL ON TABLE "public"."commerce_order_settings" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_order_settings" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_orders" TO "anon";
GRANT ALL ON TABLE "public"."commerce_orders" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."commerce_orders" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."commerce_orders_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."commerce_orders_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."commerce_orders_id_seq" TO "service_role";


GRANT ALL ON TABLE "public"."courier_remittance_batches" TO "authenticated";
GRANT ALL ON TABLE "public"."courier_remittance_batches" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."courier_remittance_batches_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."courier_remittance_batches_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."courier_remittance_batches_id_seq" TO "service_role";


GRANT ALL ON TABLE "public"."courier_remittance_items" TO "authenticated";
GRANT ALL ON TABLE "public"."courier_remittance_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."courier_remittance_items_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."courier_remittance_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."courier_remittance_items_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."courier_wallet_entity_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."courier_wallet_entity_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."courier_wallet_entity_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."courier_services" TO "anon";
GRANT ALL ON TABLE "public"."courier_services" TO "authenticated";
GRANT ALL ON TABLE "public"."courier_services" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."customer_group_member_grants_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."customer_group_member_grants_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."customer_group_member_grants_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."customer_group_members_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."customer_group_members_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."customer_group_members_id_seq" TO "service_role";


GRANT ALL ON TABLE "public"."customer_groups" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_groups" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."customer_groups_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."customer_groups_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."customer_groups_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_order_backlog_items" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_order_backlog_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_order_backlog_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."customer_order_backlog_items_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."customer_order_backlog_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."customer_order_backlog_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entity_tags" TO "anon";
GRANT ALL ON TABLE "public"."entity_tags" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."entity_tags" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."entity_tags_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."entity_tags_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."entity_tags_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."gift_rule_items" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."gift_rule_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."gift_rule_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."gift_rule_items_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."gift_rule_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."gift_rule_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."gift_rule_redemptions" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."gift_rule_redemptions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."gift_rule_redemptions" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."gift_rule_redemptions_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."gift_rule_redemptions_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."gift_rule_redemptions_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."gift_rules" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."gift_rules" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."gift_rules" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."gift_rules_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."gift_rules_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."gift_rules_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_currencies" TO "anon";
GRANT ALL ON TABLE "public"."global_currencies" TO "authenticated";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_currencies" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."global_currencies_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_currencies_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_currencies_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."investor_balances" TO "anon";
GRANT ALL ON TABLE "public"."investor_balances" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."investor_balances" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."investor_balances_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."investor_balances_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."investor_balances_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."investor_transactions_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."investor_transactions_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."investor_transactions_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."investors_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."investors_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."investors_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_boxes" TO "anon";
GRANT ALL ON TABLE "public"."invoice_boxes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_boxes" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."invoice_boxes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."invoice_boxes_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."invoice_boxes_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."item_assignees" TO "anon";
GRANT ALL ON TABLE "public"."item_assignees" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."item_assignees" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."item_assignees_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."item_assignees_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."item_assignees_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."item_permissions" TO "anon";
GRANT ALL ON TABLE "public"."item_permissions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."item_permissions" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."item_permissions_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."item_permissions_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."item_permissions_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."item_tags" TO "anon";
GRANT ALL ON TABLE "public"."item_tags" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."item_tags" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."item_tags_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."item_tags_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."item_tags_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."items" TO "anon";
GRANT ALL ON TABLE "public"."items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."koba_brands" TO "anon";
GRANT ALL ON TABLE "public"."koba_brands" TO "authenticated";
GRANT ALL ON TABLE "public"."koba_brands" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."koba_brands_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."koba_brands_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."koba_brands_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."koba_cart_items" TO "anon";
GRANT ALL ON TABLE "public"."koba_cart_items" TO "authenticated";
GRANT ALL ON TABLE "public"."koba_cart_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."koba_cart_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."koba_cart_items_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."koba_cart_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."koba_carts" TO "anon";
GRANT ALL ON TABLE "public"."koba_carts" TO "authenticated";
GRANT ALL ON TABLE "public"."koba_carts" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."koba_carts_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."koba_carts_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."koba_carts_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."koba_categories" TO "anon";
GRANT ALL ON TABLE "public"."koba_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."koba_categories" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."koba_categories_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."koba_categories_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."koba_categories_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."koba_order_items" TO "anon";
GRANT ALL ON TABLE "public"."koba_order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."koba_order_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."koba_order_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."koba_order_items_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."koba_order_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."koba_orders" TO "anon";
GRANT ALL ON TABLE "public"."koba_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."koba_orders" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."koba_orders_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."koba_orders_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."koba_orders_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."koba_products" TO "anon";
GRANT ALL ON TABLE "public"."koba_products" TO "authenticated";
GRANT ALL ON TABLE "public"."koba_products" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."koba_retail_settings" TO "anon";
GRANT ALL ON TABLE "public"."koba_retail_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."koba_retail_settings" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."koba_retail_settings_id_seq" TO "anon";
GRANT USAGE,UPDATE ON SEQUENCE "public"."koba_retail_settings_id_seq" TO "authenticated";
GRANT USAGE,UPDATE ON SEQUENCE "public"."koba_retail_settings_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."markets" TO "anon";
GRANT ALL ON TABLE "public"."markets" TO "authenticated";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."markets" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."markets_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."markets_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."markets_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."membership_grants_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."membership_grants_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."membership_grants_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."memberships_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."memberships_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."memberships_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."merchant_profiles" TO "anon";
GRANT ALL ON TABLE "public"."merchant_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."merchant_profiles" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."module_actions" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."module_actions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."module_actions" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."module_actions_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."module_actions_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."module_actions_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."modules" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."modules" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."modules" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."modules_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."modules_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."modules_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."order_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."order_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."order_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."orders" TO "anon";
GRANT ALL ON TABLE "public"."orders" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."orders" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."orders_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."orders_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."orders_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."payment_allocations_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."payment_allocations_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."payment_allocations_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."payment_methods" TO "anon";
GRANT ALL ON TABLE "public"."payment_methods" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."payment_methods" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."payment_methods_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."payment_methods_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."payment_methods_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."payments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."payments_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."payments_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."product_brands_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."product_brands_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."product_brands_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."product_categories_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."product_categories_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."product_categories_id_seq" TO "service_role";


GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_sync_snapshots" TO "service_role";


GRANT ALL ON SEQUENCE "public"."product_sync_snapshots_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."products_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."products_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."products_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."store_access_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."store_access_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."store_product_prices" TO "anon";
GRANT ALL ON TABLE "public"."store_product_prices" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."store_product_prices" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."store_product_prices_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."store_product_prices_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."store_product_prices_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."stores_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."stores_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."stores_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."system_role_templates" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."system_role_templates" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."system_role_templates" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."system_role_templates_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."system_role_templates_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."system_role_templates_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tag_categories" TO "anon";
GRANT ALL ON TABLE "public"."tag_categories" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tag_categories" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."tag_categories_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."tag_categories_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."tag_categories_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."tags_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."tags_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."tags_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_module_submodules" TO "anon";
GRANT ALL ON TABLE "public"."tenant_module_submodules" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_module_submodules" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."tenant_module_submodules_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."tenant_module_submodules_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."tenant_module_submodules_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_modules" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_modules" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_modules" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."tenant_modules_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."tenant_modules_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."tenant_modules_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_permission_versions" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_permission_versions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_permission_versions" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."tenant_role_grants_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."tenant_role_grants_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."tenant_role_grants_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."tenant_roles_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."tenant_roles_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."tenant_roles_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_scoped_counters" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_scoped_counters" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenant_scoped_counters" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenants" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenants" TO "authenticated";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."tenants" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."tenants_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."tenants_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."tenants_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_accounting_ledger" TO "anon";
GRANT ALL ON TABLE "public"."thrift_accounting_ledger" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_accounting_ledger" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_accounting_ledger_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_accounting_ledger_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_accounting_ledger_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_barcodes" TO "anon";
GRANT ALL ON TABLE "public"."thrift_barcodes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_barcodes" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_barcodes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_barcodes_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_barcodes_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_boxes" TO "anon";
GRANT ALL ON TABLE "public"."thrift_boxes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_boxes" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_boxes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_boxes_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_boxes_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_categories" TO "anon";
GRANT ALL ON TABLE "public"."thrift_categories" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_categories" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_categories_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_categories_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_categories_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_courier_providers" TO "anon";
GRANT ALL ON TABLE "public"."thrift_courier_providers" TO "authenticated";
GRANT ALL ON TABLE "public"."thrift_courier_providers" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_courier_providers_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_courier_providers_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_courier_providers_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_customers" TO "anon";
GRANT ALL ON TABLE "public"."thrift_customers" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_customers" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_customers_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_customers_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_customers_id_seq" TO "service_role";


GRANT ALL ON TABLE "public"."thrift_invoice_counters" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_invoice_items" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_invoice_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_invoice_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_invoice_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_invoice_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_invoice_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_invoices" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_invoices" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_invoices" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_invoices_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_invoices_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_invoices_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_pricings" TO "anon";
GRANT ALL ON TABLE "public"."thrift_pricings" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_pricings" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_pricings_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_pricings_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_pricings_id_seq" TO "service_role";


GRANT ALL ON TABLE "public"."thrift_return_counters" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_sales_invoice_items" TO "anon";
GRANT ALL ON TABLE "public"."thrift_sales_invoice_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_sales_invoice_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_sales_invoice_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_sales_invoice_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_sales_invoice_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_sales_invoices" TO "anon";
GRANT ALL ON TABLE "public"."thrift_sales_invoices" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_sales_invoices" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_sales_invoices_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_sales_invoices_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_sales_invoices_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_sales_pnl_lines" TO "anon";
GRANT ALL ON TABLE "public"."thrift_sales_pnl_lines" TO "authenticated";
GRANT ALL ON TABLE "public"."thrift_sales_pnl_lines" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_sales_return_items" TO "anon";
GRANT ALL ON TABLE "public"."thrift_sales_return_items" TO "authenticated";
GRANT ALL ON TABLE "public"."thrift_sales_return_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_sales_return_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_sales_return_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_sales_return_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_sales_returns" TO "anon";
GRANT ALL ON TABLE "public"."thrift_sales_returns" TO "authenticated";
GRANT ALL ON TABLE "public"."thrift_sales_returns" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_sales_returns_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_sales_returns_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_sales_returns_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_settings" TO "anon";
GRANT ALL ON TABLE "public"."thrift_settings" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_settings" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_shelves" TO "anon";
GRANT ALL ON TABLE "public"."thrift_shelves" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_shelves" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_shelves_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_shelves_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_shelves_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_shipments" TO "anon";
GRANT ALL ON TABLE "public"."thrift_shipments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_shipments" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_shipments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_shipments_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_shipments_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_stock_images" TO "anon";
GRANT ALL ON TABLE "public"."thrift_stock_images" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_stock_images" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_stock_images_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_stock_images_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_stock_images_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_stock_measurements" TO "anon";
GRANT ALL ON TABLE "public"."thrift_stock_measurements" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_stock_measurements" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_stocks" TO "anon";
GRANT ALL ON TABLE "public"."thrift_stocks" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_stocks" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_stocks_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_stocks_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_stocks_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_types" TO "anon";
GRANT ALL ON TABLE "public"."thrift_types" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."thrift_types" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."thrift_types_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."thrift_types_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."thrift_types_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."units_of_measure" TO "anon";
GRANT ALL ON TABLE "public"."units_of_measure" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."units_of_measure" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."units_of_measure_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."units_of_measure_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."units_of_measure_id_seq" TO "service_role";


GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."universal_wallet_ledger" TO "authenticated";
GRANT ALL ON TABLE "public"."universal_wallet_ledger" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."wallet_accounts" TO "anon";
GRANT ALL ON TABLE "public"."wallet_accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."wallet_accounts" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."wallet_accounts_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."wallet_accounts_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."wallet_accounts_id_seq" TO "service_role";


ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT UPDATE ON SEQUENCES TO "service_role";


ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";


ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";


