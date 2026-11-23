-- Thrift domain rls (extracted from public.sql)

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

GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_locations"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_shelf_id" bigint, "p_box_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_locations"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_shelf_id" bigint, "p_box_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_locations"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_shelf_id" bigint, "p_box_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_statuses"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_status" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_statuses"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_status" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."bulk_update_thrift_stock_statuses"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_status" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."calculate_thrift_invoice_total"() TO "anon";

GRANT ALL ON FUNCTION "public"."calculate_thrift_invoice_total"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."calculate_thrift_invoice_total"() TO "service_role";

GRANT ALL ON FUNCTION "public"."calculate_thrift_item_net_profit"() TO "anon";

GRANT ALL ON FUNCTION "public"."calculate_thrift_item_net_profit"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."calculate_thrift_item_net_profit"() TO "service_role";

GRANT ALL ON FUNCTION "public"."ceil_thrift_retail_price"("p_price" numeric) TO "anon";

GRANT ALL ON FUNCTION "public"."ceil_thrift_retail_price"("p_price" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."ceil_thrift_retail_price"("p_price" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."compute_thrift_landed_unit_cost"("p_stock_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."compute_thrift_landed_unit_cost"("p_stock_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."compute_thrift_landed_unit_cost"("p_stock_id" bigint) TO "service_role";

REVOKE ALL ON FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") TO "service_role";

REVOKE ALL ON FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") TO "service_role";

REVOKE ALL ON FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) TO "anon";

GRANT ALL ON FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) TO "authenticated";

GRANT ALL ON FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) TO "service_role";

GRANT ALL ON FUNCTION "public"."generate_thrift_barcodes"("p_tenant_id" bigint, "p_quantity" integer, "p_inserted_by" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."generate_thrift_barcodes"("p_tenant_id" bigint, "p_quantity" integer, "p_inserted_by" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."generate_thrift_barcodes"("p_tenant_id" bigint, "p_quantity" integer, "p_inserted_by" "text") TO "service_role";

REVOKE ALL ON FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "anon";

GRANT ALL ON FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "authenticated";

GRANT ALL ON FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "service_role";

REVOKE ALL ON FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "anon";

GRANT ALL ON FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "authenticated";

GRANT ALL ON FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) TO "service_role";

REVOKE ALL ON FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_thrift_dashboard_metrics"("p_tenant_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."get_thrift_dashboard_metrics"("p_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_thrift_dashboard_metrics"("p_tenant_id" bigint) TO "service_role";

REVOKE ALL ON FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) TO "service_role";

REVOKE ALL ON FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) TO "anon";

GRANT ALL ON FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) TO "authenticated";

GRANT ALL ON FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_thrift_barcodes_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_is_printed" smallint, "p_status" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."list_thrift_barcodes_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_is_printed" smallint, "p_status" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_thrift_barcodes_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_is_printed" smallint, "p_status" "text") TO "service_role";

REVOKE ALL ON FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_payment_status" "text", "p_status" "text", "p_delivery_status" "text") FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_payment_status" "text", "p_status" "text", "p_delivery_status" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_payment_status" "text", "p_status" "text", "p_delivery_status" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_payment_status" "text", "p_status" "text", "p_delivery_status" "text") TO "service_role";

REVOKE ALL ON FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) TO "anon";

GRANT ALL ON FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_thrift_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text", "p_condition" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."list_thrift_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text", "p_condition" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_thrift_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text", "p_condition" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."log_thrift_stock_loss_ledger"() TO "anon";

GRANT ALL ON FUNCTION "public"."log_thrift_stock_loss_ledger"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."log_thrift_stock_loss_ledger"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."mark_thrift_items_as_sold"("p_tenant_id" bigint, "p_invoice_number" "text", "p_recipient_name" "text", "p_address" "text", "p_phone" "text", "p_transaction_method" "public"."thrift_transaction_method", "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_print_charge" numeric, "p_shipping_charge_customer" numeric, "p_inserted_by" "text", "p_items" "jsonb") FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."mark_thrift_items_as_sold"("p_tenant_id" bigint, "p_invoice_number" "text", "p_recipient_name" "text", "p_address" "text", "p_phone" "text", "p_transaction_method" "public"."thrift_transaction_method", "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_print_charge" numeric, "p_shipping_charge_customer" numeric, "p_inserted_by" "text", "p_items" "jsonb") TO "anon";

GRANT ALL ON FUNCTION "public"."mark_thrift_items_as_sold"("p_tenant_id" bigint, "p_invoice_number" "text", "p_recipient_name" "text", "p_address" "text", "p_phone" "text", "p_transaction_method" "public"."thrift_transaction_method", "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_print_charge" numeric, "p_shipping_charge_customer" numeric, "p_inserted_by" "text", "p_items" "jsonb") TO "authenticated";

GRANT ALL ON FUNCTION "public"."mark_thrift_items_as_sold"("p_tenant_id" bigint, "p_invoice_number" "text", "p_recipient_name" "text", "p_address" "text", "p_phone" "text", "p_transaction_method" "public"."thrift_transaction_method", "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_print_charge" numeric, "p_shipping_charge_customer" numeric, "p_inserted_by" "text", "p_items" "jsonb") TO "service_role";

REVOKE ALL ON FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone, "p_remittance_ref" "text", "p_notes" "text", "p_outcome" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone, "p_remittance_ref" "text", "p_notes" "text", "p_outcome" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone, "p_remittance_ref" "text", "p_notes" "text", "p_outcome" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_extra_origin_purchase_expense" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_extra_expense_cost" numeric, "p_inserted_by" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_extra_origin_purchase_expense" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_extra_expense_cost" numeric, "p_inserted_by" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_extra_origin_purchase_expense" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_extra_expense_cost" numeric, "p_inserted_by" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_inserted_by" "text", "p_origin_unit_price" numeric, "p_extra_origin_unit_price" numeric, "p_listed_unit_price" numeric, "p_extra_origin_purchase_expense" numeric) TO "anon";

GRANT ALL ON FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_inserted_by" "text", "p_origin_unit_price" numeric, "p_extra_origin_unit_price" numeric, "p_listed_unit_price" numeric, "p_extra_origin_purchase_expense" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_inserted_by" "text", "p_origin_unit_price" numeric, "p_extra_origin_unit_price" numeric, "p_listed_unit_price" numeric, "p_extra_origin_purchase_expense" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."release_thrift_barcode_on_stock_delete"() TO "anon";

GRANT ALL ON FUNCTION "public"."release_thrift_barcode_on_stock_delete"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."release_thrift_barcode_on_stock_delete"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."resolve_thrift_barcode"("p_tenant_id" bigint, "p_scanned_value" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."resolve_thrift_barcode"("p_tenant_id" bigint, "p_scanned_value" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."resolve_thrift_barcode"("p_tenant_id" bigint, "p_scanned_value" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."resolve_thrift_barcode_id_internal"("p_tenant_id" bigint, "p_scanned_value" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."resolve_thrift_barcode_id_internal"("p_tenant_id" bigint, "p_scanned_value" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."resolve_thrift_barcode_id_internal"("p_tenant_id" bigint, "p_scanned_value" "text") TO "service_role";

REVOKE ALL ON FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) TO "anon";

GRANT ALL ON FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) TO "service_role";

REVOKE ALL ON FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) TO "anon";

GRANT ALL ON FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) TO "authenticated";

GRANT ALL ON FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."thrift_barcode_sequence_sort_key"("p_barcode_id" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."thrift_barcode_sequence_sort_key"("p_barcode_id" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."thrift_barcode_sequence_sort_key"("p_barcode_id" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."thrift_courier_providers_guard_system"() TO "anon";

GRANT ALL ON FUNCTION "public"."thrift_courier_providers_guard_system"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."thrift_courier_providers_guard_system"() TO "service_role";

GRANT ALL ON FUNCTION "public"."thrift_stocks_enforce_hold_metadata"() TO "anon";

GRANT ALL ON FUNCTION "public"."thrift_stocks_enforce_hold_metadata"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."thrift_stocks_enforce_hold_metadata"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") TO "service_role";

GRANT ALL ON TABLE "public"."thrift_accounting_ledger" TO "anon";

GRANT ALL ON TABLE "public"."thrift_accounting_ledger" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_accounting_ledger" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_accounting_ledger_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_accounting_ledger_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_accounting_ledger_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_barcodes" TO "anon";

GRANT ALL ON TABLE "public"."thrift_barcodes" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_barcodes" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_barcodes_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_barcodes_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_barcodes_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_boxes" TO "anon";

GRANT ALL ON TABLE "public"."thrift_boxes" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_boxes" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_boxes_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_boxes_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_boxes_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_categories" TO "anon";

GRANT ALL ON TABLE "public"."thrift_categories" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_categories" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_categories_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_categories_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_categories_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_courier_providers" TO "anon";

GRANT ALL ON TABLE "public"."thrift_courier_providers" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_courier_providers" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_courier_providers_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_courier_providers_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_courier_providers_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_customers" TO "anon";

GRANT ALL ON TABLE "public"."thrift_customers" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_customers" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_customers_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_customers_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_customers_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_invoice_counters" TO "anon";

GRANT ALL ON TABLE "public"."thrift_invoice_counters" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_invoice_counters" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_invoice_items" TO "anon";

GRANT ALL ON TABLE "public"."thrift_invoice_items" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_invoice_items" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_invoice_items_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_invoice_items_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_invoice_items_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_invoices" TO "anon";

GRANT ALL ON TABLE "public"."thrift_invoices" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_invoices" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_invoices_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_invoices_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_invoices_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_pricings" TO "anon";

GRANT ALL ON TABLE "public"."thrift_pricings" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_pricings" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_pricings_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_pricings_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_pricings_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_return_counters" TO "anon";

GRANT ALL ON TABLE "public"."thrift_return_counters" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_return_counters" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_sales_invoice_items" TO "anon";

GRANT ALL ON TABLE "public"."thrift_sales_invoice_items" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_sales_invoice_items" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_sales_invoice_items_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_sales_invoice_items_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_sales_invoice_items_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_sales_invoices" TO "anon";

GRANT ALL ON TABLE "public"."thrift_sales_invoices" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_sales_invoices" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_sales_invoices_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_sales_invoices_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_sales_invoices_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_sales_pnl_lines" TO "anon";

GRANT ALL ON TABLE "public"."thrift_sales_pnl_lines" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_sales_pnl_lines" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_sales_pnl_lines_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_sales_return_items" TO "anon";

GRANT ALL ON TABLE "public"."thrift_sales_return_items" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_sales_return_items" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_sales_return_items_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_sales_return_items_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_sales_return_items_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_sales_returns" TO "anon";

GRANT ALL ON TABLE "public"."thrift_sales_returns" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_sales_returns" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_sales_returns_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_sales_returns_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_sales_returns_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_settings" TO "anon";

GRANT ALL ON TABLE "public"."thrift_settings" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_settings" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_shelves" TO "anon";

GRANT ALL ON TABLE "public"."thrift_shelves" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_shelves" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_shelves_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_shelves_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_shelves_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_shipments" TO "anon";

GRANT ALL ON TABLE "public"."thrift_shipments" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_shipments" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_shipments_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_shipments_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_shipments_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_stock_images" TO "anon";

GRANT ALL ON TABLE "public"."thrift_stock_images" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_stock_images" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_stock_images_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_stock_images_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_stock_images_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_stock_measurements" TO "anon";

GRANT ALL ON TABLE "public"."thrift_stock_measurements" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_stock_measurements" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_stocks" TO "anon";

GRANT ALL ON TABLE "public"."thrift_stocks" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_stocks" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_stocks_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_stocks_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_stocks_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."thrift_types" TO "anon";

GRANT ALL ON TABLE "public"."thrift_types" TO "authenticated";

GRANT ALL ON TABLE "public"."thrift_types" TO "service_role";

GRANT ALL ON SEQUENCE "public"."thrift_types_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."thrift_types_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."thrift_types_id_seq" TO "service_role";
