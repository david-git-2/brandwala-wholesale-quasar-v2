-- Phase 10: rename books-scope RPCs; fix wallet triggers/views/RLS.
ALTER FUNCTION public.resolve_parent_tenant_id(bigint) RENAME TO resolve_books_tenant_id;
ALTER FUNCTION public.user_can_manage_parent_tenant(bigint) RENAME TO user_can_manage_books_tenant;
ALTER FUNCTION public.can_manage_products_for_parent(bigint) RENAME TO can_manage_products_for_books_tenant;
ALTER FUNCTION public.can_view_products_for_parent(bigint) RENAME TO can_view_products_for_books_tenant;
ALTER FUNCTION public.set_products_catalog_parent_tenant_id() RENAME TO set_products_catalog_books_tenant_id;

-- Deprecated wrappers (one release): old names forward to books_* RPCs for in-DB callers not redeployed in this migration.
CREATE OR REPLACE FUNCTION public.resolve_parent_tenant_id(p_tenant_id bigint) RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public
    AS $$ SELECT public.resolve_books_tenant_id(p_tenant_id); $$;

CREATE OR REPLACE FUNCTION public.user_can_manage_parent_tenant(p_tenant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public
    AS $$ SELECT public.user_can_manage_books_tenant(p_tenant_id); $$;

CREATE OR REPLACE FUNCTION public.can_manage_products_for_parent(p_tenant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public
    AS $$ SELECT public.can_manage_products_for_books_tenant(p_tenant_id); $$;

CREATE OR REPLACE FUNCTION public.can_view_products_for_parent(p_tenant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO public
    AS $$ SELECT public.can_view_products_for_books_tenant(p_tenant_id); $$;


DROP VIEW IF EXISTS public.global_invoice_items CASCADE;
DROP VIEW IF EXISTS public.global_return_items CASCADE;
DROP VIEW IF EXISTS public.v_kernel_bill_summaries CASCADE;

CREATE OR REPLACE VIEW "public"."global_invoice_items" WITH ("security_invoker"='false') AS
 SELECT "id",
    "tenant_id",

    "invoice_id",
    (("line_meta" -> 'stock_ref'::"text") ->> 'global_stock_id'::"text")::bigint AS "global_stock_id",
    "shipment_item_id",
    "product_id",
    "name_snapshot",
    "barcode_snapshot",
    "product_code_snapshot",
    "quantity",
    "sell_price_amount",
    "line_discount_amount",
    "line_total_amount",
    "return_quantity",
    "created_at",
    "updated_at",
    "assigned_child_tenant_id",
    "line_meta",
    "line_kind",
    "currency_code",
    "books_amount"
   FROM "public"."bill_lines";;

CREATE OR REPLACE VIEW "public"."global_return_items" WITH ("security_invoker"='false') AS
 SELECT "id",

    "tenant_id",
    "invoice_id",
    "invoice_item_id",
    "global_stock_id",
    "quantity",
    "return_charge_amount",
    "note",
    "created_at",
    "updated_at"
   FROM "public"."sales_return_items";;

CREATE OR REPLACE VIEW public.v_kernel_bill_summaries
WITH (security_invoker = true)
AS
SELECT
  b.id AS bill_id,
  b.tenant_id,
  b.issued_by_tenant_id,
  b.source_type,
  b.source_id,
  b.source_key,
  b.document_kind,
  b.invoice_type,
  b.invoice_no,
  b.invoice_date,
  CASE
    WHEN b.invoice_status = 'voided'::public.global_invoice_status THEN 'voided'
    WHEN b.invoice_status IN (
      'draft'::public.global_invoice_status,
      'proforma_generated'::public.global_invoice_status
    ) THEN 'draft'
    WHEN b.invoice_status = 'issued'::public.global_invoice_status THEN 'issued'
    ELSE 'draft'
  END AS lifecycle_status,
  b.payment_status::text AS settlement_status,
  coalesce(b.txn_currency_code, b.currency_code, 'BDT') AS txn_currency_code,
  coalesce(b.txn_total_amount, b.total_amount) AS txn_total_amount,
  coalesce(b.currency_code, 'BDT') AS currency_code,
  b.total_amount,
  CASE
    WHEN b.document_kind = 'standard'::public.bill_document_kind
      AND b.invoice_status = 'issued'::public.global_invoice_status
    THEN coalesce(oc.open_books, b.due_amount, 0)
    ELSE coalesce(b.due_amount, 0)
  END AS open_books,
  CASE
    WHEN b.document_kind = 'standard'::public.bill_document_kind
      AND b.invoice_status = 'issued'::public.global_invoice_status
    THEN coalesce(oc.open_txn, oc.open_books, b.due_amount, 0)
    ELSE coalesce(b.due_amount, 0)
  END AS open_txn,
  b.due_date,
  b.from_profile_id,
  b.to_profile_id,
  b.profile_id,
  b.parent_bill_id
FROM public.bills b
LEFT JOIN LATERAL public._kernel_bill_open_components(coalesce(b.parent_bill_id, b.id)) oc ON true;;

-- Targeted function bodies (8)

CREATE OR REPLACE FUNCTION "public"."_undo_wallet_ledger_row_before_delete"("p_row" "public"."cashbook_entries") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bucket text;
begin
  v_bucket := coalesce(p_row.metadata->>'target_bucket', 'available');

  update public.cashbook_accounts wa
  set
    available_balance = case
      when v_bucket = 'available' and p_row.type = 'credit' then wa.available_balance - p_row.amount
      when v_bucket = 'available' and p_row.type = 'debit' then wa.available_balance + p_row.amount
      else wa.available_balance
    end,
    pending_balance = case
      when v_bucket = 'pending' and p_row.type = 'credit' then wa.pending_balance - p_row.amount
      when v_bucket = 'pending' and p_row.type = 'debit' then wa.pending_balance + p_row.amount
      else wa.pending_balance
    end,
    locked_balance = case
      when v_bucket = 'locked' and p_row.type = 'credit' then wa.locked_balance - p_row.amount
      when v_bucket = 'locked' and p_row.type = 'debit' then wa.locked_balance + p_row.amount
      else wa.locked_balance
    end,
    updated_at = now()
  where wa.tenant_id = p_row.tenant_id
    and wa.entity_type = p_row.entity_type
    and wa.entity_id = p_row.entity_id
    and wa.currency_code = p_row.currency_code;
end;
$$;;

CREATE OR REPLACE FUNCTION "public"."can_manage_products_for_books_tenant"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    p_tenant_id is not null
    and (
      public.can_manage_products(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        join public.tenants t on t.id = m.tenant_id
        where m.is_active = true
          and lower(trim(m.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_tenant_id
          and public.membership_has_module_action(m.tenant_id, 'products', 'edit')
      )
    );
$$;;

CREATE OR REPLACE FUNCTION "public"."can_view_products_for_books_tenant"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    p_tenant_id is not null
    and (
      public.can_view_products_internal(p_tenant_id)
      or public.can_view_products_customer(p_tenant_id)
      or public.user_can_manage_books_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        join public.tenants t on t.id = m.tenant_id
        where m.is_active = true
          and lower(trim(m.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_tenant_id
          and public.membership_has_module_action(m.tenant_id, 'products', 'view')
      )
      or exists (
        select 1
        from public.customer_group_members cgm
        join public.customer_groups cg on cg.id = cgm.customer_group_id
        join public.tenants t on t.id = cg.tenant_id
        where cgm.is_active = true
          and cg.is_active = true
          and lower(trim(cgm.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_tenant_id
      )
    );
$$;;

CREATE OR REPLACE FUNCTION "public"."resolve_books_tenant_id"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    (select t.parent_id from public.tenants t where t.id = p_tenant_id),
    p_tenant_id
  );
$$;;

CREATE OR REPLACE FUNCTION "public"."set_products_catalog_books_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.tenant_id is not null then
    new.tenant_id := public.resolve_books_tenant_id(new.tenant_id);
  elsif new.inserted_by_tenant_id is not null then
    new.tenant_id := public.resolve_books_tenant_id(new.inserted_by_tenant_id);
  end if;

  return new;
end;
$$;;

CREATE OR REPLACE FUNCTION "public"."sync_lookup_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_books_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.tenant_id
    into v_books_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_books_tenant_id is not null then
      new.tenant_id := public.resolve_books_tenant_id(v_books_tenant_id);
    end if;
  end if;

  return new;
end;
$$;;

CREATE OR REPLACE FUNCTION "public"."sync_product_tenant_from_vendor"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_books_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.tenant_id
    into v_books_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_books_tenant_id is not null then
      new.tenant_id := public.resolve_books_tenant_id(v_books_tenant_id);
    end if;
  end if;

  return new;
end;
$$;;

CREATE OR REPLACE FUNCTION "public"."user_can_manage_books_tenant"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and public.membership_email_matches_current_user(m.email)
      and m.is_active = true
      and (
        m.role = 'owner'::public.app_role
        or public.has_module_action(p_tenant_id, 'procurement_stock', 'manage')
      )
  );
$$;;

DROP TRIGGER IF EXISTS trg_products_set_parent_tenant_id ON public.products;

CREATE OR REPLACE TRIGGER "trg_products_set_books_tenant_id" BEFORE INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."set_products_catalog_books_tenant_id"();;

-- RLS
DROP POLICY IF EXISTS "batch_code_items_all" ON public.batch_code_items;

CREATE POLICY "batch_code_items_all" ON "public"."batch_code_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."batch_code_lists" "l"
  WHERE (("l"."id" = "batch_code_items"."list_id") AND "public"."user_can_manage_books_tenant"("l"."tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."batch_code_lists" "l"
  WHERE (("l"."id" = "batch_code_items"."list_id") AND "public"."user_can_manage_books_tenant"("l"."tenant_id")))));;
DROP POLICY IF EXISTS "batch_code_items_select" ON public.batch_code_items;

CREATE POLICY "batch_code_items_select" ON "public"."batch_code_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."batch_code_lists" "l"
  WHERE (("l"."id" = "batch_code_items"."list_id") AND ("public"."user_can_manage_books_tenant"("l"."tenant_id") OR (EXISTS ( SELECT 1
           FROM "public"."memberships" "m"
          WHERE (("m"."tenant_id" = "l"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))))))));;
DROP POLICY IF EXISTS "global_shipment_items_all" ON public.global_shipment_items;

CREATE POLICY "global_shipment_items_all" ON "public"."global_shipment_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."global_shipments" "gs"
  WHERE (("gs"."id" = "global_shipment_items"."shipment_id") AND "public"."user_can_manage_books_tenant"("gs"."tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."global_shipments" "gs"
  WHERE (("gs"."id" = "global_shipment_items"."shipment_id") AND "public"."user_can_manage_books_tenant"("gs"."tenant_id")))));;
DROP POLICY IF EXISTS "global_shipment_items_select" ON public.global_shipment_items;

CREATE POLICY "global_shipment_items_select" ON "public"."global_shipment_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."global_shipments" "gs"
  WHERE ("gs"."id" = "global_shipment_items"."shipment_id"))));;
DROP POLICY IF EXISTS "products_delete" ON public.products;

CREATE POLICY "products_delete" ON "public"."products" FOR DELETE TO "authenticated" USING ("public"."can_manage_products_for_books_tenant"("tenant_id"));;
DROP POLICY IF EXISTS "products_insert" ON public.products;

CREATE POLICY "products_insert" ON "public"."products" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_products_for_books_tenant"("tenant_id"));;
DROP POLICY IF EXISTS "products_select" ON public.products;

CREATE POLICY "products_select" ON "public"."products" FOR SELECT TO "authenticated" USING ("public"."can_view_products_for_books_tenant"("tenant_id"));;
DROP POLICY IF EXISTS "products_update" ON public.products;

CREATE POLICY "products_update" ON "public"."products" FOR UPDATE TO "authenticated" USING ("public"."can_manage_products_for_books_tenant"("tenant_id")) WITH CHECK ("public"."can_manage_products_for_books_tenant"("tenant_id"));;
DROP POLICY IF EXISTS "recipient_profiles_select" ON public.recipient_profiles;

CREATE POLICY "recipient_profiles_select" ON "public"."recipient_profiles" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("tenant_id") OR "public"."user_can_manage_books_tenant"("tenant_id")));;
DROP POLICY IF EXISTS "recipient_profiles_write" ON public.recipient_profiles;

CREATE POLICY "recipient_profiles_write" ON "public"."recipient_profiles" TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'customer'::"text", 'edit'::"text") OR "public"."user_can_manage_books_tenant"("tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'customer'::"text", 'edit'::"text") OR "public"."user_can_manage_books_tenant"("tenant_id")));;
