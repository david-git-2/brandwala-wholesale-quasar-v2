-- Extracted from supabase/schemas/public.sql (procurement/stock/costing). Move-only.

CREATE OR REPLACE TRIGGER "trg_assign_tenant_shipment_id" BEFORE INSERT OR UPDATE ON "public"."shipments" FOR EACH ROW EXECUTE FUNCTION "public"."assign_tenant_shipment_id"();



CREATE OR REPLACE TRIGGER "trg_costing_file_items_apply_calculations" BEFORE INSERT OR UPDATE ON "public"."costing_file_items" FOR EACH ROW EXECUTE FUNCTION "public"."apply_costing_item_calculations"();



CREATE OR REPLACE TRIGGER "trg_costing_file_items_enforce_update_rules" BEFORE UPDATE ON "public"."costing_file_items" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_costing_file_item_update_rules"();



CREATE OR REPLACE TRIGGER "trg_costing_file_items_normalize_fields" BEFORE INSERT OR UPDATE ON "public"."costing_file_items" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_costing_file_item_fields"();



CREATE OR REPLACE TRIGGER "trg_costing_file_items_updated_at" BEFORE UPDATE ON "public"."costing_file_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_costing_file_viewers_updated_at" BEFORE UPDATE ON "public"."costing_file_viewers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_costing_files_normalize_market" BEFORE INSERT OR UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_costing_file_market"();



CREATE OR REPLACE TRIGGER "trg_costing_files_normalize_status_po_placed" BEFORE INSERT OR UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_costing_file_status_po_placed"();



CREATE OR REPLACE TRIGGER "trg_costing_files_refresh_item_calculations" AFTER UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."refresh_costing_file_item_calculations_for_file"();



CREATE OR REPLACE TRIGGER "trg_costing_files_updated_at" BEFORE UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_costing_files_validate_customer_group" BEFORE INSERT OR UPDATE ON "public"."costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."validate_costing_file_customer_group"();



CREATE OR REPLACE TRIGGER "trg_global_shipment_boxes_updated_at" BEFORE UPDATE ON "public"."global_shipment_boxes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_global_shipment_cost_entries_updated_at" BEFORE UPDATE ON "public"."global_shipment_cost_entries" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_global_shipment_sections_updated_at" BEFORE UPDATE ON "public"."global_shipment_sections" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_global_shipment_items_guard_landed_cost" BEFORE INSERT OR UPDATE ON "public"."global_shipment_items" FOR EACH ROW EXECUTE FUNCTION "public"."trg_global_shipment_items_guard_landed_cost"();



CREATE OR REPLACE TRIGGER "trg_global_shipment_items_reactive_cost" AFTER UPDATE OF "purchase_price" ON "public"."global_shipment_items" FOR EACH ROW EXECUTE FUNCTION "public"."trg_reactive_adjust_child_listing_cost"();



CREATE OR REPLACE TRIGGER "trg_global_shipment_items_updated_at" BEFORE UPDATE ON "public"."global_shipment_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_global_shipments_updated_at" BEFORE UPDATE ON "public"."global_shipments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_global_stock_types_updated_at" BEFORE UPDATE ON "public"."global_stock_types" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_global_stocks_updated_at" BEFORE UPDATE ON "public"."global_stocks" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_pbc_files_auto_tenant_id" BEFORE INSERT OR UPDATE OF "billing_profile_id" ON "public"."product_based_costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_pbc_files_auto_tenant_id"();



CREATE OR REPLACE TRIGGER "trg_pbc_items_auto_backlog" AFTER INSERT OR DELETE OR UPDATE OF "quantity", "confirmed_quantity", "product_id", "price_gbp" ON "public"."product_based_costing_items" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_auto_upsert_pbc_backlog"();



CREATE OR REPLACE TRIGGER "trg_product_based_costing_files_set_updated_at" BEFORE UPDATE ON "public"."product_based_costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_product_based_costing_files_sync_vendor_reference_fields" BEFORE INSERT OR UPDATE ON "public"."product_based_costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."sync_vendor_reference_fields"();



CREATE OR REPLACE TRIGGER "trg_product_based_costing_items_set_updated_at" BEFORE UPDATE ON "public"."product_based_costing_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_product_based_costing_items_sync_vendor_reference_fields" BEFORE INSERT OR UPDATE ON "public"."product_based_costing_items" FOR EACH ROW EXECUTE FUNCTION "public"."sync_vendor_reference_fields"();



CREATE OR REPLACE TRIGGER "trg_product_brands_sync_vendor_reference_fields" BEFORE INSERT OR UPDATE ON "public"."product_brands" FOR EACH ROW EXECUTE FUNCTION "public"."sync_vendor_reference_fields"();



CREATE OR REPLACE TRIGGER "trg_product_categories_sync_vendor_reference_fields" BEFORE INSERT OR UPDATE ON "public"."product_categories" FOR EACH ROW EXECUTE FUNCTION "public"."sync_vendor_reference_fields"();



CREATE OR REPLACE TRIGGER "trg_product_sync_snapshots_sync_vendor_reference_fields" BEFORE INSERT OR UPDATE ON "public"."product_sync_snapshots" FOR EACH ROW EXECUTE FUNCTION "public"."sync_vendor_reference_fields"();



CREATE OR REPLACE TRIGGER "trg_products_sync_tenant_from_vendor" BEFORE INSERT OR UPDATE OF "vendor_id" ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."sync_product_tenant_from_vendor"();



CREATE OR REPLACE TRIGGER "trg_products_sync_vendor_reference_fields" BEFORE INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."sync_vendor_reference_fields"();



CREATE OR REPLACE TRIGGER "trg_shipment_investments_set_updated_at" BEFORE UPDATE ON "public"."shipment_investments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_shipment_items_recalc_transaction_rate" AFTER INSERT OR DELETE OR UPDATE OF "price_gbp", "quantity" ON "public"."shipment_items" FOR EACH ROW EXECUTE FUNCTION "public"."trg_shipment_items_recalc_transaction_rate"();



CREATE OR REPLACE TRIGGER "trg_shipment_items_set_updated_at" BEFORE UPDATE ON "public"."shipment_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_shipments_recalc_transaction_rate" AFTER UPDATE OF "product_conversion_rate", "cargo_conversion_rate", "cargo_rate", "received_weight", "shipment_type" ON "public"."shipments" FOR EACH ROW EXECUTE FUNCTION "public"."trg_shipments_recalc_transaction_rate"();



CREATE OR REPLACE TRIGGER "trg_shipments_set_updated_at" BEFORE UPDATE ON "public"."shipments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_shipments_sync_vendor_reference_fields" BEFORE INSERT OR UPDATE ON "public"."shipments" FOR EACH ROW EXECUTE FUNCTION "public"."sync_vendor_reference_fields"();



CREATE OR REPLACE TRIGGER "trg_stock_locations_updated_at" BEFORE UPDATE ON "public"."stock_locations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_stores_sync_vendor_reference_fields" BEFORE INSERT OR UPDATE ON "public"."stores" FOR EACH ROW EXECUTE FUNCTION "public"."sync_vendor_reference_fields"();



CREATE OR REPLACE TRIGGER "trg_sync_global_shipment_header_aliases" BEFORE INSERT OR UPDATE ON "public"."global_shipments" FOR EACH ROW EXECUTE FUNCTION "public"."sync_global_shipment_header_aliases"();



CREATE OR REPLACE TRIGGER "trg_sync_investor_balance_shipments" AFTER INSERT OR DELETE OR UPDATE ON "public"."shipment_investments" FOR EACH ROW EXECUTE FUNCTION "public"."sync_investor_balance_from_shipment_investments"();



CREATE OR REPLACE TRIGGER "trg_vendors_normalize_fields" BEFORE INSERT OR UPDATE ON "public"."vendors" FOR EACH ROW EXECUTE FUNCTION "public"."normalize_vendor_fields"();



CREATE OR REPLACE TRIGGER "trg_vendors_set_parent_tenant_id" BEFORE INSERT OR UPDATE OF "tenant_id" ON "public"."vendors" FOR EACH ROW EXECUTE FUNCTION "public"."set_parent_tenant_id_from_tenant"();



CREATE OR REPLACE TRIGGER "trg_vendors_updated_at" BEFORE UPDATE ON "public"."vendors" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE POLICY "Tenant members can delete product_based_costing_backlog_items" ON "public"."product_based_costing_backlog_items" FOR DELETE TO "authenticated" USING (("public"."can_admin_manage_costing_file"("tenant_id") OR "public"."can_staff_access_costing_file"("tenant_id")));



CREATE POLICY "Tenant members can insert product_based_costing_backlog_items" ON "public"."product_based_costing_backlog_items" FOR INSERT TO "authenticated" WITH CHECK (("public"."can_admin_manage_costing_file"("tenant_id") OR "public"."can_staff_access_costing_file"("tenant_id")));



CREATE POLICY "Tenant members can select product_based_costing_backlog_items" ON "public"."product_based_costing_backlog_items" FOR SELECT TO "authenticated" USING (("public"."can_admin_manage_costing_file"("tenant_id") OR "public"."can_staff_access_costing_file"("tenant_id")));



CREATE POLICY "Tenant members can update product_based_costing_backlog_items" ON "public"."product_based_costing_backlog_items" FOR UPDATE TO "authenticated" USING (("public"."can_admin_manage_costing_file"("tenant_id") OR "public"."can_staff_access_costing_file"("tenant_id")));



ALTER TABLE "public"."costing_file_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "costing_file_items_delete" ON "public"."costing_file_items" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."costing_files" "cf"
  WHERE (("cf"."id" = "costing_file_items"."costing_file_id") AND ("public"."can_admin_manage_costing_file"("cf"."tenant_id") OR "public"."can_staff_access_costing_file"("cf"."tenant_id") OR (("cf"."status" = 'draft'::"public"."costing_file_status") AND "public"."can_customer_access_costing_file"("cf"."customer_group_id")))))));



CREATE POLICY "costing_file_items_insert" ON "public"."costing_file_items" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."costing_files" "cf"
  WHERE (("cf"."id" = "costing_file_items"."costing_file_id") AND ("public"."can_admin_manage_costing_file"("cf"."tenant_id") OR "public"."can_staff_access_costing_file"("cf"."tenant_id") OR (("cf"."status" = 'draft'::"public"."costing_file_status") AND "public"."can_customer_access_costing_file"("cf"."customer_group_id")))))));



CREATE POLICY "costing_file_items_select" ON "public"."costing_file_items" FOR SELECT TO "authenticated" USING ("public"."can_view_costing_file_items"("costing_file_id"));



CREATE POLICY "costing_file_items_update" ON "public"."costing_file_items" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."costing_files" "cf"
  WHERE (("cf"."id" = "costing_file_items"."costing_file_id") AND ("public"."can_admin_manage_costing_file"("cf"."tenant_id") OR "public"."can_staff_access_costing_file"("cf"."tenant_id") OR "public"."can_customer_access_costing_file"("cf"."customer_group_id")))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."costing_files" "cf"
  WHERE (("cf"."id" = "costing_file_items"."costing_file_id") AND ("public"."can_admin_manage_costing_file"("cf"."tenant_id") OR "public"."can_staff_access_costing_file"("cf"."tenant_id") OR "public"."can_customer_access_costing_file"("cf"."customer_group_id"))))));



ALTER TABLE "public"."costing_file_viewers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "costing_file_viewers_delete" ON "public"."costing_file_viewers" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."costing_files" "cf"
  WHERE (("cf"."id" = "costing_file_viewers"."costing_file_id") AND "public"."can_manage_costing_file_viewers"("cf"."tenant_id")))));



CREATE POLICY "costing_file_viewers_insert" ON "public"."costing_file_viewers" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."costing_files" "cf"
  WHERE (("cf"."id" = "costing_file_viewers"."costing_file_id") AND "public"."can_manage_costing_file_viewers"("cf"."tenant_id")))));



CREATE POLICY "costing_file_viewers_select" ON "public"."costing_file_viewers" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."costing_files" "cf"
  WHERE (("cf"."id" = "costing_file_viewers"."costing_file_id") AND "public"."can_manage_costing_file_viewers"("cf"."tenant_id")))));



ALTER TABLE "public"."costing_files" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "costing_files_delete" ON "public"."costing_files" FOR DELETE TO "authenticated" USING (("public"."can_admin_manage_costing_file"("tenant_id") OR (("status" = 'draft'::"public"."costing_file_status") AND "public"."can_customer_access_costing_file"("customer_group_id"))));



CREATE POLICY "costing_files_insert" ON "public"."costing_files" FOR INSERT TO "authenticated" WITH CHECK (("public"."can_admin_manage_costing_file"("tenant_id") OR "public"."can_staff_access_costing_file"("tenant_id") OR "public"."can_customer_access_costing_file"("customer_group_id")));



CREATE POLICY "costing_files_select" ON "public"."costing_files" FOR SELECT TO "authenticated" USING ("public"."can_view_costing_file"("id"));



CREATE POLICY "costing_files_update" ON "public"."costing_files" FOR UPDATE TO "authenticated" USING (("public"."can_admin_manage_costing_file"("tenant_id") OR "public"."can_staff_access_costing_file"("tenant_id"))) WITH CHECK (("public"."can_admin_manage_costing_file"("tenant_id") OR "public"."can_staff_access_costing_file"("tenant_id")));



ALTER TABLE "public"."global_shipment_boxes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "global_shipment_boxes_all" ON "public"."global_shipment_boxes" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));



CREATE POLICY "global_shipment_boxes_select" ON "public"."global_shipment_boxes" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipment_boxes"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));



ALTER TABLE "public"."global_shipment_cost_entries" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "global_shipment_cost_entries_all" ON "public"."global_shipment_cost_entries" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));



CREATE POLICY "global_shipment_cost_entries_select" ON "public"."global_shipment_cost_entries" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipment_cost_entries"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));



ALTER TABLE "public"."global_shipment_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "global_shipment_items_all" ON "public"."global_shipment_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."global_shipments" "gs"
  WHERE (("gs"."id" = "global_shipment_items"."shipment_id") AND "public"."user_can_manage_parent_tenant"("gs"."parent_tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."global_shipments" "gs"
  WHERE (("gs"."id" = "global_shipment_items"."shipment_id") AND "public"."user_can_manage_parent_tenant"("gs"."parent_tenant_id")))));



CREATE POLICY "global_shipment_items_select" ON "public"."global_shipment_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."global_shipments" "gs"
  WHERE ("gs"."id" = "global_shipment_items"."shipment_id"))));



ALTER TABLE "public"."global_shipment_sections" ENABLE ROW LEVEL SECURITY;



CREATE POLICY "global_shipment_sections_all" ON "public"."global_shipment_sections" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));



CREATE POLICY "global_shipment_sections_select" ON "public"."global_shipment_sections" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipment_sections"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));



ALTER TABLE "public"."global_shipments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "global_shipments_all" ON "public"."global_shipments" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));



CREATE POLICY "global_shipments_select" ON "public"."global_shipments" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipments"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));



ALTER TABLE "public"."global_stock_types" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "global_stock_types_all" ON "public"."global_stock_types" TO "authenticated" USING (("public"."is_superadmin"() OR ("parent_tenant_id" IS NULL) OR "public"."user_can_manage_parent_tenant"("parent_tenant_id"))) WITH CHECK (("public"."is_superadmin"() OR ("parent_tenant_id" IS NULL) OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));



CREATE POLICY "global_stock_types_select" ON "public"."global_stock_types" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."global_stocks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "global_stocks_all" ON "public"."global_stocks" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));



ALTER TABLE "public"."product_based_costing_backlog_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_based_costing_files" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "product_based_costing_files_delete" ON "public"."product_based_costing_files" FOR DELETE TO "authenticated" USING ("public"."can_manage_costing"("tenant_id"));



CREATE POLICY "product_based_costing_files_insert" ON "public"."product_based_costing_files" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_costing"("tenant_id"));



CREATE POLICY "product_based_costing_files_select" ON "public"."product_based_costing_files" FOR SELECT TO "authenticated" USING ("public"."can_view_costing_internal"("tenant_id"));



CREATE POLICY "product_based_costing_files_update" ON "public"."product_based_costing_files" FOR UPDATE TO "authenticated" USING ("public"."can_manage_costing"("tenant_id")) WITH CHECK ("public"."can_manage_costing"("tenant_id"));



ALTER TABLE "public"."product_based_costing_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "product_based_costing_items_delete" ON "public"."product_based_costing_items" FOR DELETE TO "authenticated" USING ("public"."can_manage_costing_item"("product_based_costing_file_id"));



CREATE POLICY "product_based_costing_items_insert" ON "public"."product_based_costing_items" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_costing_item"("product_based_costing_file_id"));



CREATE POLICY "product_based_costing_items_select" ON "public"."product_based_costing_items" FOR SELECT TO "authenticated" USING ("public"."can_view_costing_item"("product_based_costing_file_id"));



CREATE POLICY "product_based_costing_items_update" ON "public"."product_based_costing_items" FOR UPDATE TO "authenticated" USING ("public"."can_manage_costing_item"("product_based_costing_file_id")) WITH CHECK ("public"."can_manage_costing_item"("product_based_costing_file_id"));



ALTER TABLE "public"."shipment_investments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shipment_investments_delete" ON "public"."shipment_investments" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "shipment_investments"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));



CREATE POLICY "shipment_investments_insert" ON "public"."shipment_investments" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "shipment_investments"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));



CREATE POLICY "shipment_investments_select" ON "public"."shipment_investments" FOR SELECT TO "authenticated" USING (("public"."investor_tenant_can_view"("tenant_id") OR ("public"."auth_investor_id"() = "investor_id")));



CREATE POLICY "shipment_investments_update" ON "public"."shipment_investments" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "shipment_investments"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "shipment_investments"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));



ALTER TABLE "public"."shipment_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shipment_items_delete" ON "public"."shipment_items" FOR DELETE TO "authenticated" USING ("public"."can_manage_shipment_by_id"("shipment_id"));



CREATE POLICY "shipment_items_insert" ON "public"."shipment_items" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_shipment_by_id"("shipment_id"));



CREATE POLICY "shipment_items_select" ON "public"."shipment_items" FOR SELECT TO "authenticated" USING ("public"."can_manage_shipment_by_id"("shipment_id"));



CREATE POLICY "shipment_items_update" ON "public"."shipment_items" FOR UPDATE TO "authenticated" USING ("public"."can_manage_shipment_by_id"("shipment_id")) WITH CHECK ("public"."can_manage_shipment_by_id"("shipment_id"));



ALTER TABLE "public"."shipment_progress_flow_stages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shipment_progress_flow_stages_all" ON "public"."shipment_progress_flow_stages" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."shipment_progress_flows" "f"
  WHERE (("f"."id" = "shipment_progress_flow_stages"."flow_id") AND "public"."user_can_manage_parent_tenant"("f"."tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."shipment_progress_flows" "f"
  WHERE (("f"."id" = "shipment_progress_flow_stages"."flow_id") AND "public"."user_can_manage_parent_tenant"("f"."tenant_id")))));



ALTER TABLE "public"."shipment_progress_flows" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shipment_progress_flows_all" ON "public"."shipment_progress_flows" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));



ALTER TABLE "public"."shipments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shipments_delete" ON "public"."shipments" FOR DELETE TO "authenticated" USING ("public"."can_manage_shipment"("tenant_id"));



CREATE POLICY "shipments_insert" ON "public"."shipments" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_shipment"("tenant_id"));



CREATE POLICY "shipments_select" ON "public"."shipments" FOR SELECT TO "authenticated" USING ("public"."can_manage_shipment"("tenant_id"));



CREATE POLICY "shipments_update" ON "public"."shipments" FOR UPDATE TO "authenticated" USING ("public"."can_manage_shipment"("tenant_id")) WITH CHECK ("public"."can_manage_shipment"("tenant_id"));



ALTER TABLE "public"."stock_locations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stock_locations_all" ON "public"."stock_locations" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));



CREATE POLICY "stock_locations_select" ON "public"."stock_locations" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "stock_locations"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));



ALTER TABLE "public"."vendors" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "vendors_delete" ON "public"."vendors" FOR DELETE TO "authenticated" USING ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id"))))));



CREATE POLICY "vendors_insert" ON "public"."vendors" FOR INSERT TO "authenticated" WITH CHECK ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id"))))));



CREATE POLICY "vendors_select" ON "public"."vendors" FOR SELECT TO "authenticated" USING ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id")))) OR (("parent_tenant_id" IS NOT NULL) AND "public"."user_can_manage_parent_tenant"("parent_tenant_id"))));



CREATE POLICY "vendors_update" ON "public"."vendors" FOR UPDATE TO "authenticated" USING ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id")))))) WITH CHECK ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id"))))));



REVOKE ALL ON FUNCTION "public"."_assert_parent_warehouse_tenant"("p_parent_tenant_id" bigint) FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."_can_view_stock_locations"("p_parent_tenant_id" bigint) FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."_stock_location_is_leaf"("p_id" bigint) FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."_validate_stock_location_nesting"("p_kind" "public"."stock_location_kind", "p_parent_location_id" bigint, "p_parent_tenant_id" bigint) FROM PUBLIC;



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipment_items" TO "anon";
GRANT ALL ON TABLE "public"."global_shipment_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipment_items" TO "service_role";



GRANT ALL ON FUNCTION "public"."add_child_line_to_parent_shipment"("p_parent_shipment_id" bigint, "p_source_type" "text", "p_source_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."add_pbc_backlog_to_costing_file"("p_file_id" bigint, "p_backlog_ids" bigint[]) TO "authenticated";



GRANT ALL ON FUNCTION "public"."add_pbc_backlog_to_file"("p_file_id" bigint, "p_backlog_ids" bigint[]) TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipment_items" TO "anon";
GRANT ALL ON TABLE "public"."shipment_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipment_items" TO "service_role";



GRANT ALL ON FUNCTION "public"."add_shipment_item_from_product"("p_shipment_id" bigint, "p_product_id" bigint, "p_quantity" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."add_shipment_item_manual"("p_shipment_id" bigint, "p_name" "text", "p_quantity" integer, "p_barcode" "text", "p_product_code" "text", "p_product_id" bigint, "p_image_url" "text", "p_product_weight" numeric, "p_package_weight" numeric, "p_price_gbp" numeric, "p_receiving_splits" "jsonb", "p_cost_bdt" numeric) TO "authenticated";



GRANT ALL ON FUNCTION "public"."add_shipment_item_manual"("p_shipment_id" bigint, "p_name" "text", "p_quantity" integer, "p_barcode" "text", "p_product_code" "text", "p_product_id" bigint, "p_image_url" "text", "p_product_weight" numeric, "p_package_weight" numeric, "p_price_gbp" numeric, "p_received_quantity" integer, "p_damaged_quantity" integer, "p_stolen_quantity" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."add_stock_movement_line"("p_movement_id" bigint, "p_stock_id" bigint, "p_quantity" numeric, "p_from_location_id" bigint, "p_to_location_id" bigint, "p_from_availability" "public"."stock_availability", "p_to_availability" "public"."stock_availability", "p_from_grade_tag_id" bigint, "p_to_grade_tag_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."apply_global_shipment_purchase_balance"("p_shipment_id" bigint, "p_adjustments" "jsonb", "p_transaction_rate" numeric) TO "authenticated";



GRANT ALL ON FUNCTION "public"."apply_global_shipment_weight_balance"("p_shipment_id" bigint, "p_adjustments" "jsonb", "p_transaction_rate" numeric) TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipment_progress_flows" TO "anon";
GRANT ALL ON TABLE "public"."shipment_progress_flows" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipment_progress_flows" TO "service_role";



GRANT ALL ON FUNCTION "public"."archive_shipment_progress_flow"("p_flow_id" bigint, "p_archive" boolean) TO "authenticated";



GRANT ALL ON FUNCTION "public"."archive_shipment_progress_flow_stage"("p_flow_stage_id" bigint, "p_archive" boolean) TO "authenticated";



GRANT ALL ON FUNCTION "public"."archive_shipment_progress_tag"("p_tag_id" bigint, "p_archive" boolean) TO "authenticated";



GRANT ALL ON FUNCTION "public"."assign_shipment_to_child"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_shipment_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."bulk_add_global_shipment_items"("p_shipment_id" bigint, "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bulk_add_global_shipment_items"("p_shipment_id" bigint, "p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."bulk_add_shipment_items_from_product_ids"("p_shipment_id" bigint, "p_items" "jsonb") TO "authenticated";



GRANT ALL ON FUNCTION "public"."bulk_allocate_shipment_stock"("p_parent_tenant_id" bigint, "p_shipment_id" bigint, "p_child_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."bulk_delete_shipment_items_by_product_id"("p_shipment_id" bigint, "p_items" "jsonb") TO "authenticated";



GRANT ALL ON FUNCTION "public"."bulk_update_global_shipment_items"("p_shipment_id" bigint, "p_updates" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."bulk_update_global_shipment_items"("p_shipment_id" bigint, "p_updates" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."can_admin_manage_costing_file"("p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_customer_access_costing_file"("p_customer_group_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_manage_costing"("p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_manage_costing_file_viewers"("p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_manage_costing_item"("p_file_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_manage_shipment"("p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_manage_shipment_by_id"("p_shipment_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_staff_access_costing_file"("p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_view_costing_file"("p_costing_file_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_view_costing_file_items"("p_costing_file_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_view_costing_internal"("p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."can_view_costing_item"("p_file_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."count_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."count_search_stock_network"("p_context_tenant_id" bigint, "p_mode" "text", "p_search" "text", "p_search_field" "text", "p_product_id" bigint, "p_status" "text", "p_shipment_id" bigint, "p_exclude_zero_qty" boolean) TO "authenticated";



GRANT ALL ON FUNCTION "public"."create_and_post_stock_movement"("p_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer, "p_to_location_id" bigint, "p_to_availability" "public"."stock_availability", "p_to_grade_tag_id" bigint, "p_movement_type" "public"."stock_movement_type", "p_notes" "text", "p_reference_type" "text", "p_reference_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_and_post_stock_movement"("p_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer, "p_to_location_id" bigint, "p_to_availability" "public"."stock_availability", "p_to_grade_tag_id" bigint, "p_movement_type" "public"."stock_movement_type", "p_notes" "text", "p_reference_type" "text", "p_reference_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_costing_file"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_name" "text", "p_market" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."create_costing_file"("p_customer_group_id" bigint, "p_market" "text", "p_name" "text", "p_status" "public"."costing_file_status", "p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer, "p_item_type" "text") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipments" TO "anon";
GRANT ALL ON TABLE "public"."shipments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipments" TO "service_role";



GRANT ALL ON FUNCTION "public"."create_shipment"("p_name" "text", "p_tenant_id" bigint, "p_shipment_type" "text") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipments" TO "anon";
GRANT ALL ON TABLE "public"."global_shipments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipments" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipment_sections" TO "anon";
GRANT ALL ON TABLE "public"."global_shipment_sections" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipment_sections" TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_shipment_draft"("p_parent_tenant_id" bigint, "p_name" "text", "p_type" "public"."global_shipment_type", "p_vendor_id" bigint, "p_cargo_company_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_shipment_draft"("p_parent_tenant_id" bigint, "p_name" "text", "p_type" "public"."global_shipment_type", "p_vendor_id" bigint, "p_cargo_company_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_shipment_draft"("p_parent_tenant_id" bigint, "p_name" "text", "p_type" "public"."global_shipment_type", "p_vendor_id" bigint, "p_cargo_company_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_shipment_progress_flow"("p_tenant_id" bigint, "p_name" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."create_shipment_progress_flow_stage"("p_flow_id" bigint, "p_name" "text", "p_color" "text", "p_sort_order" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."create_shipment_progress_tag"("p_tenant_id" bigint, "p_name" "text", "p_color" "text", "p_sort_order" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."create_stock_movement"("p_tenant_id" bigint, "p_movement_type" "public"."stock_movement_type", "p_notes" "text", "p_reference_type" "text", "p_reference_id" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_website" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_website" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."current_costing_item_actor_role"("p_costing_file_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."default_pickable_stock_location_id"("p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."default_putaway_stock_location_id"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."default_putaway_stock_location_id"("p_tenant_id" bigint) TO "service_role";



REVOKE ALL ON FUNCTION "public"."default_returns_stock_location_id"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."default_returns_stock_location_id"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."default_returns_stock_location_id"("p_tenant_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."default_stock_grade_tag_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."default_stock_grade_tag_id"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_global_shipment_cost_entry"("p_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_global_shipment_cost_entry"("p_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."delete_global_stock_allocation"("p_allocation_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."delete_shipment"("p_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."delete_shipment_item_quantity"("p_id" bigint, "p_quantity" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."delete_shipment_order"("p_id" bigint) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."delete_stock_location"("p_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_stock_location"("p_id" bigint) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."ensure_default_stock_location"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ensure_default_stock_location"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_default_stock_location"("p_tenant_id" bigint) TO "service_role";



REVOKE ALL ON FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) TO "service_role";



REVOKE ALL ON FUNCTION "public"."ensure_global_shipment_cost_entries_from_header"("p_shipment_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ensure_global_shipment_cost_entries_from_header"("p_shipment_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."ensure_shipment_progress_tags"("p_tenant_id" bigint) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."finalize_global_shipment"("p_shipment_id" bigint, "p_stock_rows" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."finalize_global_shipment"("p_shipment_id" bigint, "p_stock_rows" "jsonb") TO "authenticated";



GRANT ALL ON FUNCTION "public"."generate_shipment_tracking_token"("p_shipment_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."get_available_stock"("p_stock_id" bigint, "p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."get_costing_file_by_id"("p_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."get_shipment_pnl"("p_tenant_id" bigint, "p_shipment_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_shipment_pnl"("p_tenant_id" bigint, "p_shipment_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_shipment_pnl"("p_tenant_id" bigint, "p_shipment_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_shipment_public_status"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_shipment_public_status"("p_token" "text") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vendors" TO "anon";
GRANT ALL ON TABLE "public"."vendors" TO "authenticated";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vendors" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_vendor_for_tenant"("p_id" bigint, "p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."global_stock_atp_qty"("p_global_stock_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."global_stock_hold_qty"("p_global_stock_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."grant_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."is_assigned_costing_file_viewer"("p_costing_file_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."is_internal_costing_file_creator"("p_tenant_id" bigint, "p_email" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."is_vendor_code_available"("p_code" "text", "p_exclude_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_allocatable_stock_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_shipment_id" bigint, "p_stock_type_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_child_stock_atp"("p_child_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_costing_file_items"("p_costing_file_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_costing_file_viewers"("p_costing_file_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_page" integer, "p_page_size" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_global_inventory_items_with_stock"("p_page" integer, "p_page_size" integer, "p_sort_by" "text", "p_sort_order" "text", "p_filters" "jsonb") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipment_cost_entries" TO "anon";
GRANT ALL ON TABLE "public"."global_shipment_cost_entries" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipment_cost_entries" TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_global_shipment_cost_entries"("p_shipment_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_global_shipment_cost_entries"("p_shipment_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_global_shipments_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_global_stock_allocations_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_child_tenant_id" bigint, "p_stock_type_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_global_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_stock_type_id" bigint, "p_is_sellable" boolean, "p_shipment_status" "text", "p_hide_zero_stock" boolean, "p_location_id" bigint, "p_availability" "public"."stock_availability") TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_global_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_stock_type_id" bigint, "p_is_sellable" boolean, "p_shipment_status" "text", "p_hide_zero_stock" boolean, "p_location_id" bigint, "p_availability" "public"."stock_availability", "p_shipment_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_inventory_items_with_stock"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_sort_by" "text", "p_sort_order" "text", "p_filters" "jsonb") TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_pbc_backlog_items"("p_tenant_id" bigint, "p_billing_profile_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_product_based_costing_files"("p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text", "p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_shipment_items_for_shipments"("p_shipment_ids" bigint[]) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_shipment_payee_settlements"("p_shipment_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_shipment_progress_flow_stages"("p_flow_id" bigint, "p_include_archived" boolean) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_shipment_progress_flows"("p_tenant_id" bigint, "p_include_archived" boolean) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_shipment_progress_tags"("p_tenant_id" bigint, "p_include_archived" boolean) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_shipments_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_shipments_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."list_shipments_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_locations" TO "anon";
GRANT ALL ON TABLE "public"."stock_locations" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_locations" TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_stock_locations"("p_parent_tenant_id" bigint, "p_include_inactive" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_stock_locations"("p_parent_tenant_id" bigint, "p_include_inactive" boolean) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_stock_movements"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_vendor_markets"() TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_vendors_for_tenant"("p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."migrate_legacy_inventory_to_global_stock"("p_tenant_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."pay_settle_shipment_costs"("p_shipment_id" bigint, "p_cost_entry_ids" bigint[]) TO "authenticated";



GRANT ALL ON FUNCTION "public"."post_stock_movement"("p_movement_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."recalculate_product_based_costing_file_offer_prices"("p_file_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."recalculate_product_based_costing_file_offer_prices"("p_file_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."record_vendor_grn_payable"("p_tenant_id" bigint, "p_vendor_id" bigint, "p_amount" numeric, "p_source_id" "text", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_vendor_grn_payable"("p_tenant_id" bigint, "p_vendor_id" bigint, "p_amount" numeric, "p_source_id" "text", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."record_vendor_payment_outflow"("p_tenant_id" bigint, "p_vendor_id" bigint, "p_amount" numeric, "p_payment_method" "text", "p_reference" "text", "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_vendor_payment_outflow"("p_tenant_id" bigint, "p_vendor_id" bigint, "p_amount" numeric, "p_payment_method" "text", "p_reference" "text", "p_note" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_shipment_inventory_accounting"("p_tenant_id" bigint, "p_shipment_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."refresh_shipment_investor_profits"("p_global_shipment_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_shipment_investor_profits"("p_global_shipment_id" bigint) TO "service_role";



GRANT ALL ON FUNCTION "public"."reorder_shipment_progress_flow_stages"("p_flow_id" bigint, "p_flow_stage_ids" bigint[]) TO "authenticated";



GRANT ALL ON FUNCTION "public"."reorder_shipment_progress_tags"("p_tenant_id" bigint, "p_tag_ids" bigint[]) TO "authenticated";



GRANT ALL ON FUNCTION "public"."resolve_costing_file_creator_label"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_created_by_email" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."return_shipment_to_vendor"("p_shipment_id" bigint, "p_items_qty" "jsonb", "p_outcome" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."revise_global_shipment_costs"("p_shipment_id" bigint, "p_entries" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."revise_global_shipment_costs"("p_shipment_id" bigint, "p_entries" "jsonb") TO "authenticated";



GRANT ALL ON FUNCTION "public"."revoke_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."revoke_shipment_tracking_token"("p_shipment_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."search_stock_network"("p_context_tenant_id" bigint, "p_mode" "text", "p_search" "text", "p_search_field" "text", "p_product_id" bigint, "p_status" "text", "p_shipment_id" bigint, "p_exclude_zero_qty" boolean, "p_limit" integer, "p_offset" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."set_default_shipment_progress_flow"("p_flow_id" bigint) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."set_default_stock_location"("p_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_default_stock_location"("p_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."set_global_shipment_progress_tag"("p_shipment_id" bigint, "p_tag_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."set_shipment_progress_flow"("p_shipment_id" bigint, "p_flow_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."set_shipment_progress_stage"("p_shipment_id" bigint, "p_tag_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."settle_shipment_payee"("p_shipment_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_action" "text", "p_amount" numeric, "p_exchange_rate" numeric) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."stamp_global_shipment_landed_costs"("p_shipment_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."stamp_global_shipment_landed_costs"("p_shipment_id" bigint) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."stock_grade_tag_id_for_slug"("p_slug" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."stock_grade_tag_id_for_slug"("p_slug" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."stock_grade_tag_id_for_slug"("p_slug" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_costing_file"("p_id" bigint, "p_name" "text", "p_market" "text", "p_customer_group_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_costing_file_item_customer_profit"("p_id" bigint, "p_customer_profit_rate" numeric) TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_item_type" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_costing_file_item_offer"("p_id" bigint, "p_auxiliary_price_gbp" numeric, "p_item_price_gbp" numeric, "p_cargo_rate" numeric, "p_costing_price_gbp" numeric, "p_costing_price_bdt" integer, "p_offer_price_override_bdt" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_costing_file_item_status"("p_id" bigint, "p_status" "public"."costing_file_item_status") TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_costing_file_items_customer_profit"("p_costing_file_id" bigint, "p_customer_profit_rate" numeric) TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_costing_file_pricing"("p_id" bigint, "p_cargo_rate_1kg" numeric, "p_cargo_rate_2kg" numeric, "p_conversion_rate" numeric, "p_admin_profit_rate" numeric) TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_costing_file_status"("p_id" bigint, "p_status" "public"."costing_file_status") TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_global_shipment_items_order"("p_items" "jsonb") TO "authenticated";



GRANT ALL ON FUNCTION "public"."reorder_shipment_sections"("p_shipment_id" bigint, "p_section_ids" bigint[]) TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_shipment"("p_id" bigint, "p_field" "text", "p_value" "text") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipment_investments" TO "anon";
GRANT ALL ON TABLE "public"."shipment_investments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipment_investments" TO "service_role";



GRANT ALL ON FUNCTION "public"."update_shipment_investment_cost_share"("p_shipment_investment_id" bigint, "p_cost_share_pct" numeric) TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_shipment_progress_flow"("p_flow_id" bigint, "p_name" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_shipment_progress_flow_stage"("p_flow_stage_id" bigint, "p_name" "text", "p_color" "text") TO "authenticated";



GRANT ALL ON FUNCTION "public"."update_shipment_progress_tag"("p_tag_id" bigint, "p_name" "text", "p_color" "text", "p_sort_order" integer) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_type" "public"."global_shipment_cost_type", "p_amount" numeric, "p_exchange_rate" numeric, "p_currency_id" bigint, "p_payment_source" "text", "p_entity_type" "text", "p_entity_id" bigint, "p_allocation" "text", "p_metadata" "jsonb", "p_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_type" "public"."global_shipment_cost_type", "p_amount" numeric, "p_exchange_rate" numeric, "p_currency_id" bigint, "p_payment_source" "text", "p_entity_type" "text", "p_entity_id" bigint, "p_allocation" "text", "p_metadata" "jsonb", "p_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."upsert_global_stock_allocation"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer) TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_based_costing_backlog_items" TO "anon";
GRANT ALL ON TABLE "public"."product_based_costing_backlog_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_based_costing_backlog_items" TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_pbc_backlog_from_item"("p_costing_item_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."upsert_shipment_investment"("p_id" bigint, "p_tenant_id" bigint, "p_global_shipment_id" bigint, "p_investor_id" bigint, "p_cost_share_pct" numeric) TO "authenticated";



REVOKE ALL ON FUNCTION "public"."upsert_stock_location"("p_parent_tenant_id" bigint, "p_code" "text", "p_name" "text", "p_kind" "public"."stock_location_kind", "p_is_pickable" boolean, "p_sort_order" integer, "p_is_active" boolean, "p_is_default" boolean, "p_id" bigint, "p_parent_location_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."upsert_stock_location"("p_parent_tenant_id" bigint, "p_code" "text", "p_name" "text", "p_kind" "public"."stock_location_kind", "p_is_pickable" boolean, "p_sort_order" integer, "p_is_active" boolean, "p_is_default" boolean, "p_id" bigint, "p_parent_location_id" bigint) TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."costing_file_items" TO "anon";
GRANT ALL ON TABLE "public"."costing_file_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."costing_file_items" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."costing_file_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."costing_file_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."costing_file_items_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."costing_file_viewers" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."costing_file_viewers" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."costing_file_viewers" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."costing_file_viewers_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."costing_file_viewers_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."costing_file_viewers_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."costing_files" TO "anon";
GRANT ALL ON TABLE "public"."costing_files" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."costing_files" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."costing_files_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."costing_files_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."costing_files_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipment_boxes" TO "anon";
GRANT ALL ON TABLE "public"."global_shipment_boxes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_shipment_boxes" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."global_shipment_boxes_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_shipment_boxes_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_shipment_boxes_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."global_shipment_cost_entries_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_shipment_cost_entries_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_shipment_cost_entries_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."global_shipment_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_shipment_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_shipment_items_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."global_shipments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_shipments_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_shipments_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_stock_types" TO "anon";
GRANT ALL ON TABLE "public"."global_stock_types" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_stock_types" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."global_stock_types_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_stock_types_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_stock_types_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_stocks" TO "anon";
GRANT ALL ON TABLE "public"."global_stocks" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_stocks" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."global_stocks_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_stocks_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_stocks_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."product_based_costing_backlog_items_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."product_based_costing_backlog_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."product_based_costing_backlog_items_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_based_costing_files" TO "anon";
GRANT ALL ON TABLE "public"."product_based_costing_files" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_based_costing_files" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."product_based_costing_files_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."product_based_costing_files_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."product_based_costing_files_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_based_costing_items" TO "anon";
GRANT ALL ON TABLE "public"."product_based_costing_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_based_costing_items" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."product_based_costing_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."product_based_costing_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."product_based_costing_items_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."shipment_investments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."shipment_investments_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shipment_investments_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."shipment_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."shipment_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shipment_items_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipment_progress_flow_stages" TO "anon";
GRANT ALL ON TABLE "public"."shipment_progress_flow_stages" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shipment_progress_flow_stages" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."shipment_progress_flow_stages_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."shipment_progress_flow_stages_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shipment_progress_flow_stages_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."shipment_progress_flows_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."shipment_progress_flows_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shipment_progress_flows_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."shipments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."shipments_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shipments_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."stock_locations_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."stock_locations_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."stock_locations_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_movement_lines" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_movement_lines" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_movement_lines" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."stock_movement_lines_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."stock_movement_lines_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."stock_movement_lines_id_seq" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_movements" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_movements" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_movements" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."stock_movements_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."stock_movements_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."stock_movements_id_seq" TO "service_role";



GRANT UPDATE ON SEQUENCE "public"."vendors_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."vendors_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."vendors_id_seq" TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_landed_unit_cost"("p_shipment_item_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."get_allocation_reconciliation"("p_stock_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_child_allocation_summary"("p_stock_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "public"."list_child_procurement_lines"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_shipment_overview_details"("p_shipment_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."bulk_delete_global_shipment_items"("p_shipment_id" bigint, "p_item_ids" bigint[]) TO "authenticated";





CREATE POLICY "batch_code_pc_delete" ON "public"."batch_code_pc" FOR DELETE TO "authenticated" USING ("public"."can_manage_shipment_by_id"("shipment_id"));



CREATE POLICY "batch_code_pc_insert" ON "public"."batch_code_pc" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_shipment_by_id"("shipment_id"));



CREATE POLICY "batch_code_pc_select" ON "public"."batch_code_pc" FOR SELECT TO "authenticated" USING ("public"."can_manage_shipment_by_id"("shipment_id"));



CREATE POLICY "batch_code_pc_update" ON "public"."batch_code_pc" FOR UPDATE TO "authenticated" USING ("public"."can_manage_shipment_by_id"("shipment_id")) WITH CHECK ("public"."can_manage_shipment_by_id"("shipment_id"));



