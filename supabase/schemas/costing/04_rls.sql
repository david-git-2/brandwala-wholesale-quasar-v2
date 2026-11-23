-- Costing domain rls (extracted from public.sql)

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

GRANT ALL ON FUNCTION "public"."apply_costing_item_calculations"() TO "anon";

GRANT ALL ON FUNCTION "public"."apply_costing_item_calculations"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."apply_costing_item_calculations"() TO "service_role";

GRANT ALL ON FUNCTION "public"."calculate_costing_item_type_surcharge_gbp"("p_item_type" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."calculate_costing_item_type_surcharge_gbp"("p_item_type" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."calculate_costing_item_type_surcharge_gbp"("p_item_type" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."can_admin_manage_costing_file"("p_tenant_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."can_admin_manage_costing_file"("p_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."can_admin_manage_costing_file"("p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."can_customer_access_costing_file"("p_customer_group_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."can_customer_access_costing_file"("p_customer_group_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."can_customer_access_costing_file"("p_customer_group_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."can_manage_costing_file_viewers"("p_tenant_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."can_manage_costing_file_viewers"("p_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."can_manage_costing_file_viewers"("p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."can_manage_costing_item"("p_file_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."can_manage_costing_item"("p_file_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."can_manage_costing_item"("p_file_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."can_staff_access_costing_file"("p_tenant_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."can_staff_access_costing_file"("p_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."can_staff_access_costing_file"("p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."can_tenant_view_costing_file_viewer"("p_tenant_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."can_tenant_view_costing_file_viewer"("p_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."can_tenant_view_costing_file_viewer"("p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."can_view_costing_file"("p_costing_file_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."can_view_costing_file"("p_costing_file_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."can_view_costing_file"("p_costing_file_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."can_view_costing_file_items"("p_costing_file_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."can_view_costing_file_items"("p_costing_file_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."can_view_costing_file_items"("p_costing_file_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."can_view_costing_item"("p_file_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."can_view_costing_item"("p_file_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."can_view_costing_item"("p_file_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."count_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."count_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."count_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."create_costing_file"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_name" "text", "p_market" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."create_costing_file"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_name" "text", "p_market" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_costing_file"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_name" "text", "p_market" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."create_costing_file"("p_customer_group_id" bigint, "p_market" "text", "p_name" "text", "p_status" "public"."costing_file_status", "p_tenant_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."create_costing_file"("p_customer_group_id" bigint, "p_market" "text", "p_name" "text", "p_status" "public"."costing_file_status", "p_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_costing_file"("p_customer_group_id" bigint, "p_market" "text", "p_name" "text", "p_status" "public"."costing_file_status", "p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer) TO "anon";

GRANT ALL ON FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer) TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer, "p_item_type" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer, "p_item_type" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer, "p_item_type" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."current_costing_item_actor_role"("p_costing_file_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."current_costing_item_actor_role"("p_costing_file_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."current_costing_item_actor_role"("p_costing_file_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."enforce_costing_file_item_update_rules"() TO "anon";

GRANT ALL ON FUNCTION "public"."enforce_costing_file_item_update_rules"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."enforce_costing_file_item_update_rules"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_costing_file_by_id"("p_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."get_costing_file_by_id"("p_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_costing_file_by_id"("p_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."grant_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."grant_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."grant_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."is_assigned_costing_file_viewer"("p_costing_file_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."is_assigned_costing_file_viewer"("p_costing_file_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."is_assigned_costing_file_viewer"("p_costing_file_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."is_internal_costing_file_creator"("p_tenant_id" bigint, "p_email" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."is_internal_costing_file_creator"("p_tenant_id" bigint, "p_email" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."is_internal_costing_file_creator"("p_tenant_id" bigint, "p_email" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."list_costing_file_items"("p_costing_file_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."list_costing_file_items"("p_costing_file_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_costing_file_items"("p_costing_file_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_costing_file_viewers"("p_costing_file_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."list_costing_file_viewers"("p_costing_file_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_costing_file_viewers"("p_costing_file_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_page" integer, "p_page_size" integer) TO "anon";

GRANT ALL ON FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_page" integer, "p_page_size" integer) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_page" integer, "p_page_size" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."normalize_costing_file_item_fields"() TO "anon";

GRANT ALL ON FUNCTION "public"."normalize_costing_file_item_fields"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."normalize_costing_file_item_fields"() TO "service_role";

GRANT ALL ON FUNCTION "public"."normalize_costing_file_market"() TO "anon";

GRANT ALL ON FUNCTION "public"."normalize_costing_file_market"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."normalize_costing_file_market"() TO "service_role";

GRANT ALL ON FUNCTION "public"."normalize_costing_file_status_po_placed"() TO "anon";

GRANT ALL ON FUNCTION "public"."normalize_costing_file_status_po_placed"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."normalize_costing_file_status_po_placed"() TO "service_role";

GRANT ALL ON FUNCTION "public"."refresh_costing_file_item_calculations_for_file"() TO "anon";

GRANT ALL ON FUNCTION "public"."refresh_costing_file_item_calculations_for_file"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."refresh_costing_file_item_calculations_for_file"() TO "service_role";

GRANT ALL ON FUNCTION "public"."resolve_costing_file_creator_label"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_created_by_email" "text") TO "anon";

GRANT ALL ON FUNCTION "public"."resolve_costing_file_creator_label"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_created_by_email" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."resolve_costing_file_creator_label"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_created_by_email" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."revoke_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."revoke_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."revoke_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_costing_file"("p_id" bigint, "p_name" "text", "p_market" "text", "p_customer_group_id" bigint) TO "anon";

GRANT ALL ON FUNCTION "public"."update_costing_file"("p_id" bigint, "p_name" "text", "p_market" "text", "p_customer_group_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_costing_file"("p_id" bigint, "p_name" "text", "p_market" "text", "p_customer_group_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_customer_profit"("p_id" bigint, "p_customer_profit_rate" numeric) TO "anon";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_customer_profit"("p_id" bigint, "p_customer_profit_rate" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_customer_profit"("p_id" bigint, "p_customer_profit_rate" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) TO "anon";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_item_type" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) TO "anon";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_item_type" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_item_type" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_offer"("p_id" bigint, "p_auxiliary_price_gbp" numeric, "p_item_price_gbp" numeric, "p_cargo_rate" numeric, "p_costing_price_gbp" numeric, "p_costing_price_bdt" integer, "p_offer_price_override_bdt" integer) TO "anon";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_offer"("p_id" bigint, "p_auxiliary_price_gbp" numeric, "p_item_price_gbp" numeric, "p_cargo_rate" numeric, "p_costing_price_gbp" numeric, "p_costing_price_bdt" integer, "p_offer_price_override_bdt" integer) TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_offer"("p_id" bigint, "p_auxiliary_price_gbp" numeric, "p_item_price_gbp" numeric, "p_cargo_rate" numeric, "p_costing_price_gbp" numeric, "p_costing_price_bdt" integer, "p_offer_price_override_bdt" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_status"("p_id" bigint, "p_status" "public"."costing_file_item_status") TO "anon";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_status"("p_id" bigint, "p_status" "public"."costing_file_item_status") TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_costing_file_item_status"("p_id" bigint, "p_status" "public"."costing_file_item_status") TO "service_role";

GRANT ALL ON FUNCTION "public"."update_costing_file_items_customer_profit"("p_costing_file_id" bigint, "p_customer_profit_rate" numeric) TO "anon";

GRANT ALL ON FUNCTION "public"."update_costing_file_items_customer_profit"("p_costing_file_id" bigint, "p_customer_profit_rate" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_costing_file_items_customer_profit"("p_costing_file_id" bigint, "p_customer_profit_rate" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_costing_file_pricing"("p_id" bigint, "p_cargo_rate_1kg" numeric, "p_cargo_rate_2kg" numeric, "p_conversion_rate" numeric, "p_admin_profit_rate" numeric) TO "anon";

GRANT ALL ON FUNCTION "public"."update_costing_file_pricing"("p_id" bigint, "p_cargo_rate_1kg" numeric, "p_cargo_rate_2kg" numeric, "p_conversion_rate" numeric, "p_admin_profit_rate" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_costing_file_pricing"("p_id" bigint, "p_cargo_rate_1kg" numeric, "p_cargo_rate_2kg" numeric, "p_conversion_rate" numeric, "p_admin_profit_rate" numeric) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_costing_file_status"("p_id" bigint, "p_status" "public"."costing_file_status") TO "anon";

GRANT ALL ON FUNCTION "public"."update_costing_file_status"("p_id" bigint, "p_status" "public"."costing_file_status") TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_costing_file_status"("p_id" bigint, "p_status" "public"."costing_file_status") TO "service_role";

GRANT ALL ON FUNCTION "public"."validate_costing_file_customer_group"() TO "anon";

GRANT ALL ON FUNCTION "public"."validate_costing_file_customer_group"() TO "authenticated";

GRANT ALL ON FUNCTION "public"."validate_costing_file_customer_group"() TO "service_role";

GRANT ALL ON TABLE "public"."costing_file_items" TO "anon";

GRANT ALL ON TABLE "public"."costing_file_items" TO "authenticated";

GRANT ALL ON TABLE "public"."costing_file_items" TO "service_role";

GRANT ALL ON SEQUENCE "public"."costing_file_items_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."costing_file_items_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."costing_file_items_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."costing_file_viewers" TO "anon";

GRANT ALL ON TABLE "public"."costing_file_viewers" TO "authenticated";

GRANT ALL ON TABLE "public"."costing_file_viewers" TO "service_role";

GRANT ALL ON SEQUENCE "public"."costing_file_viewers_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."costing_file_viewers_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."costing_file_viewers_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."costing_files" TO "anon";

GRANT ALL ON TABLE "public"."costing_files" TO "authenticated";

GRANT ALL ON TABLE "public"."costing_files" TO "service_role";

GRANT ALL ON SEQUENCE "public"."costing_files_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."costing_files_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."costing_files_id_seq" TO "service_role";
