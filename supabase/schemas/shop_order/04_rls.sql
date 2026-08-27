-- Extracted from supabase/schemas/public.sql (shop_order). Move-only.

CREATE POLICY "cg_profiles_select_tenant_member" ON "public"."customer_group_shop_profiles" FOR SELECT USING (("tenant_id" IN ( SELECT "tm"."tenant_id"
   FROM "public"."memberships" "tm"
  WHERE (("lower"(TRIM(BOTH FROM "tm"."email")) = "public"."current_user_email"()) AND ("tm"."is_active" = true)))));


CREATE POLICY "cg_profiles_superadmin_all" ON "public"."customer_group_shop_profiles" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'superadmin'::"public"."app_role") AND ("m"."is_active" = true)))));


CREATE POLICY "cg_profiles_write_tenant_admin_staff" ON "public"."customer_group_shop_profiles" USING (("tenant_id" IN ( SELECT "m"."tenant_id"
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"])) AND ("m"."is_active" = true)))));


ALTER TABLE "public"."comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_group_shop_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_groups" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "listings_select_tenant_member" ON "public"."shop_product_listings" FOR SELECT USING (("tenant_id" IN ( SELECT "tm"."tenant_id"
   FROM "public"."memberships" "tm"
  WHERE (("lower"(TRIM(BOTH FROM "tm"."email")) = "public"."current_user_email"()) AND ("tm"."is_active" = true)))));


CREATE POLICY "listings_superadmin_all" ON "public"."shop_product_listings" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'superadmin'::"public"."app_role") AND ("m"."is_active" = true)))));


CREATE POLICY "listings_write_tenant_admin_staff" ON "public"."shop_product_listings" USING (("tenant_id" IN ( SELECT "m"."tenant_id"
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"])) AND ("m"."is_active" = true)))));


ALTER TABLE "public"."shop_cart_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shop_cart_items_customer_owner" ON "public"."shop_cart_items" USING ((EXISTS ( SELECT 1
   FROM "public"."shop_carts" "c"
  WHERE (("c"."id" = "shop_cart_items"."cart_id") AND "public"."is_cart_owner"("c"."customer_group_id", "c"."tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."shop_carts" "c"
  WHERE (("c"."id" = "shop_cart_items"."cart_id") AND "public"."is_cart_owner"("c"."customer_group_id", "c"."tenant_id")))));


CREATE POLICY "shop_cart_items_staff_view" ON "public"."shop_cart_items" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."shop_carts" "c"
  WHERE (("c"."id" = "shop_cart_items"."cart_id") AND "public"."is_tenant_staff"("c"."tenant_id")))));


ALTER TABLE "public"."shop_carts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shop_carts_customer_owner" ON "public"."shop_carts" USING ("public"."is_cart_owner"("customer_group_id", "tenant_id")) WITH CHECK ("public"."is_cart_owner"("customer_group_id", "tenant_id"));


CREATE POLICY "shop_carts_staff_view" ON "public"."shop_carts" FOR SELECT USING ("public"."is_tenant_staff"("tenant_id"));


ALTER TABLE "public"."shop_categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shop_categories_select_policy" ON "public"."shop_categories" FOR SELECT TO "authenticated" USING ((("is_active" = true) OR "public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "shop_categories"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));


CREATE POLICY "shop_categories_service_role_policy" ON "public"."shop_categories" TO "service_role" USING (true) WITH CHECK (true);


CREATE POLICY "shop_categories_staff_manage_policy" ON "public"."shop_categories" TO "authenticated" USING (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "shop_categories"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role", 'superadmin'::"public"."app_role"]))))))) WITH CHECK (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "shop_categories"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role", 'superadmin'::"public"."app_role"])))))));


CREATE POLICY "shop_cg_access_select_tenant_member" ON "public"."shop_customer_group_access" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."shops" "s"
     JOIN "public"."memberships" "tm" ON (("tm"."tenant_id" = "s"."tenant_id")))
  WHERE (("s"."id" = "shop_customer_group_access"."shop_id") AND ("lower"(TRIM(BOTH FROM "tm"."email")) = "public"."current_user_email"()) AND ("tm"."is_active" = true)))));


CREATE POLICY "shop_cg_access_superadmin_all" ON "public"."shop_customer_group_access" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'superadmin'::"public"."app_role") AND ("m"."is_active" = true)))));


CREATE POLICY "shop_cg_access_write_tenant_admin_staff" ON "public"."shop_customer_group_access" USING ((EXISTS ( SELECT 1
   FROM "public"."shops" "s"
  WHERE (("s"."id" = "shop_customer_group_access"."shop_id") AND "public"."membership_has_module_action"("s"."tenant_id", 'shop_permissions'::"text", 'configure'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."shops" "s"
  WHERE (("s"."id" = "shop_customer_group_access"."shop_id") AND "public"."membership_has_module_action"("s"."tenant_id", 'shop_permissions'::"text", 'configure'::"text")))));


ALTER TABLE "public"."shop_customer_group_access" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shop_order_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shop_order_items_customer_owner" ON "public"."shop_order_items" USING ((EXISTS ( SELECT 1
   FROM "public"."shop_orders" "o"
  WHERE (("o"."id" = "shop_order_items"."order_id") AND "public"."is_cart_owner"("o"."customer_group_id", "o"."tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."shop_orders" "o"
  WHERE (("o"."id" = "shop_order_items"."order_id") AND "public"."is_cart_owner"("o"."customer_group_id", "o"."tenant_id")))));


CREATE POLICY "shop_order_items_staff_all" ON "public"."shop_order_items" USING ((EXISTS ( SELECT 1
   FROM "public"."shop_orders" "o"
  WHERE (("o"."id" = "shop_order_items"."order_id") AND "public"."is_tenant_staff"("o"."tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."shop_orders" "o"
  WHERE (("o"."id" = "shop_order_items"."order_id") AND "public"."is_tenant_staff"("o"."tenant_id")))));


ALTER TABLE "public"."shop_orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shop_orders_customer_owner" ON "public"."shop_orders" USING ("public"."is_cart_owner"("customer_group_id", "tenant_id")) WITH CHECK ("public"."is_cart_owner"("customer_group_id", "tenant_id"));


CREATE POLICY "shop_orders_staff_all" ON "public"."shop_orders" USING ("public"."is_tenant_staff"("tenant_id")) WITH CHECK ("public"."is_tenant_staff"("tenant_id"));


ALTER TABLE "public"."dropship_order_settlements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "dropship_order_settlements_staff_all" ON "public"."dropship_order_settlements" USING ("public"."is_tenant_staff"("tenant_id")) WITH CHECK ("public"."is_tenant_staff"("tenant_id"));


ALTER TABLE "public"."dropship_settlement_charge_lines" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "dropship_settlement_charge_lines_staff_all" ON "public"."dropship_settlement_charge_lines" USING ((EXISTS ( SELECT 1
   FROM "public"."dropship_order_settlements" "s"
  WHERE (("s"."id" = "dropship_settlement_charge_lines"."settlement_id") AND "public"."is_tenant_staff"("s"."tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."dropship_order_settlements" "s"
  WHERE (("s"."id" = "dropship_settlement_charge_lines"."settlement_id") AND "public"."is_tenant_staff"("s"."tenant_id")))));


ALTER TABLE "public"."shop_pricing_rules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shop_pricing_rules_select" ON "public"."shop_pricing_rules" FOR SELECT USING (("tenant_id" IN ( SELECT "tm"."tenant_id"
   FROM "public"."memberships" "tm"
  WHERE (("lower"(TRIM(BOTH FROM "tm"."email")) = "public"."current_user_email"()) AND ("tm"."is_active" = true)))));


CREATE POLICY "shop_pricing_rules_write" ON "public"."shop_pricing_rules" USING ("public"."user_can_manage_shop_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_shop_tenant"("tenant_id"));


ALTER TABLE "public"."shop_product_listings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shop_product_offers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shop_product_offers_all_staff" ON "public"."shop_product_offers" USING (("auth"."role"() = 'authenticated'::"text"));


CREATE POLICY "shop_product_offers_select" ON "public"."shop_product_offers" FOR SELECT USING (true);


ALTER TABLE "public"."shop_stock_reservations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shop_stock_reservations_customer_owner" ON "public"."shop_stock_reservations" USING ((EXISTS ( SELECT 1
   FROM ("public"."shop_cart_items" "ci"
     JOIN "public"."shop_carts" "c" ON (("c"."id" = "ci"."cart_id")))
  WHERE (("ci"."id" = "shop_stock_reservations"."cart_item_id") AND "public"."is_cart_owner"("c"."customer_group_id", "c"."tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."shop_cart_items" "ci"
     JOIN "public"."shop_carts" "c" ON (("c"."id" = "ci"."cart_id")))
  WHERE (("ci"."id" = "shop_stock_reservations"."cart_item_id") AND "public"."is_cart_owner"("c"."customer_group_id", "c"."tenant_id")))));


CREATE POLICY "shop_stock_reservations_staff_view" ON "public"."shop_stock_reservations" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."shop_cart_items" "ci"
     JOIN "public"."shop_carts" "c" ON (("c"."id" = "ci"."cart_id")))
  WHERE (("ci"."id" = "shop_stock_reservations"."cart_item_id") AND "public"."is_tenant_staff"("c"."tenant_id")))));


ALTER TABLE "public"."shops" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shops_delete_tenant_admin" ON "public"."shops" FOR DELETE USING ("public"."membership_has_module_action"("tenant_id", 'shop_config'::"text", 'delete'::"text"));


CREATE POLICY "shops_insert_tenant_admin_staff" ON "public"."shops" FOR INSERT WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'shop_config'::"text", 'create'::"text"));


CREATE POLICY "shops_select_customer_group" ON "public"."shops" FOR SELECT USING ((("is_active" = true) AND "public"."customer_can_select_shop"("id", "tenant_id")));


CREATE POLICY "shops_select_tenant_member" ON "public"."shops" FOR SELECT USING (("tenant_id" IN ( SELECT "tm"."tenant_id"
   FROM "public"."memberships" "tm"
  WHERE (("lower"(TRIM(BOTH FROM "tm"."email")) = "public"."current_user_email"()) AND ("tm"."is_active" = true)))));


CREATE POLICY "shops_superadmin_all" ON "public"."shops" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'superadmin'::"public"."app_role") AND ("m"."is_active" = true)))));


CREATE POLICY "shops_update_tenant_admin_staff" ON "public"."shops" FOR UPDATE USING ("public"."membership_has_module_action"("tenant_id", 'shop_config'::"text", 'edit'::"text"));




GRANT ALL ON FUNCTION "public"."add_to_shop_cart"("p_shop_id" bigint, "p_product_id" bigint, "p_global_stock_allocation_id" bigint, "p_quantity" integer, "p_customer_sell_price_amount" numeric, "p_customer_sell_price_currency_id" bigint, "p_global_stock_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."advance_dropship_order_status"("p_order_id" bigint, "p_target_status" "public"."shop_order_status", "p_remittance_ref" "text", "p_bank_trx_id" "text") TO "authenticated";


REVOKE ALL ON FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text", "p_category" "text", "p_brand" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text", "p_category" "text", "p_brand" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
REVOKE ALL ON FUNCTION "public"."search_shop_catalog_for_customer"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."search_shop_catalog_for_customer"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
REVOKE ALL ON FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) TO "authenticated";
REVOKE ALL ON FUNCTION "public"."list_related_shop_catalog_products_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_related_shop_catalog_products_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_limit" integer) TO "authenticated";


GRANT ALL ON FUNCTION "public"."bulk_apply_shop_markup"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_listing_ids" bigint[]) TO "authenticated";


GRANT ALL ON FUNCTION "public"."bulk_apply_shop_markup"("p_shop_id" bigint, "p_markup_amount" numeric, "p_markup_type" "text", "p_target_price" "text", "p_listing_ids" bigint[]) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_act_on_parent_tenant_stock"("p_parent_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_customer_access_shop"("p_shop_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_customer_negotiate_on_shop"("p_shop_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."can_customer_see_shop_price"("p_shop_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."check_shop_login_access"("p_email" "text", "p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."confirm_dropship_delivered_costing"("p_order_id" bigint, "p_cod_amount" numeric, "p_delivery_charge" numeric, "p_courier_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."confirm_dropship_delivered_costing"("p_order_id" bigint, "p_cod_amount" numeric, "p_delivery_charge" numeric, "p_courier_notes" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."confirm_shop_order"("p_order_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."create_dropship_invoice"("p_order_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_note" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."create_dual_invoice_from_dropship_order"("p_order_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_note" "text") TO "authenticated";


REVOKE ALL ON FUNCTION "public"."customer_can_select_shop"("p_shop_id" bigint, "p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."customer_can_select_shop"("p_shop_id" bigint, "p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."customer_counter_offer"("p_order_id" bigint, "p_items" "jsonb") TO "authenticated";


GRANT ALL ON FUNCTION "public"."delete_shop"("p_shop_id" bigint, "p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."delete_shop_order"("p_order_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."delete_shop_product_listing"("p_listing_id" bigint, "p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."fetch_customer_shop_categories"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."finalize_dropship_return"("p_order_id" bigint, "p_items" "jsonb", "p_actual_return_charge" numeric, "p_deduct_from_middle_man" boolean, "p_override_reason" "text", "p_return_ref" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finalize_dropship_return"("p_order_id" bigint, "p_items" "jsonb", "p_actual_return_charge" numeric, "p_deduct_from_middle_man" boolean, "p_override_reason" "text", "p_return_ref" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."fulfill_shop_order_to_invoice"("p_order_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."generate_shop_order_number"("p_tenant_id" bigint, "p_shop_id" bigint) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."get_customer_shop_order"("p_tenant_id" bigint, "p_order_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_customer_shop_order"("p_tenant_id" bigint, "p_order_id" bigint) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."get_customer_dashboard_summary"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_customer_dashboard_summary"("p_tenant_id" bigint) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."get_shop_order_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_shop_order_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) TO "authenticated";
REVOKE ALL ON FUNCTION "public"."get_dropship_order_detail_v2"("p_tenant_id" bigint, "p_order_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_dropship_order_detail_v2"("p_tenant_id" bigint, "p_order_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_dropship_management_order"("p_tenant_id" bigint, "p_order_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_dropship_settlement_draft"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_dropship_order_delivered"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."issue_dropship_tenant_b2b_invoice"("p_tenant_id" bigint, "p_order_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_dropship_tenant_b2b_invoice_at_delivered"("p_order_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_dropship_courier_bank_transfer"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_dropship_reseller_profit"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_dropship_shop_readiness"("p_shop_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_dropship_finance_hub_data"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_dropship_wallet_reconciliation_report"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dropship_wallet_reconciliation_report"("p_tenant_id" bigint) TO "service_role";


GRANT ALL ON FUNCTION "public"."get_my_dropship_wallet_summary"() TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_or_create_shop_cart"("p_shop_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dropship_shop_cart"("p_shop_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dropship_review_cart"("p_shop_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_dropship_order_from_cart"("p_shop_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_shipping_post_code" "text", "p_billing_profile_id" bigint, "p_is_prepaid" boolean, "p_delivery_instructions" "text", "p_cod_charge_amount" numeric, "p_delivery_charge_amount" numeric, "p_print_charge_amount" numeric, "p_packing_charge_amount" numeric, "p_discount_amount" numeric, "p_recipient_pays_delivery" boolean, "p_recipient_pays_cod" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_shop_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_customer_group_member_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_shop_effective_grants"("p_tenant_id" bigint, "p_customer_group_member_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."get_shop_permissions_for_customer"("p_shop_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_allocations_for_shop_pick"("p_tenant_id" bigint, "p_shop_id" bigint) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."list_customer_active_carts"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_customer_active_carts"("p_tenant_id" bigint) TO "authenticated";


REVOKE ALL ON FUNCTION "public"."list_customer_shop_orders"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status_bucket" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_customer_shop_orders"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status_bucket" "text") TO "authenticated";


REVOKE ALL ON FUNCTION "public"."list_customer_shops"("p_tenant_id" bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_customer_shops"("p_tenant_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status" "text", "p_search" "text", "p_statuses" "text"[]) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_listable_stock_for_shop"("p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_allocated_stock_for_shop"("p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_my_dropship_wallet_ledger"("p_limit" integer, "p_offset" integer) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_procurement_shop_order_lines"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_shop_product_listings"("p_shop_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_shop_storefront_listings_for_admin"("p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_shop_storefront_listing_price_calculation"("p_shop_id" bigint, "p_listing_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."mark_dropship_order_returned"("p_order_id" bigint, "p_actual_return_charge" numeric, "p_deduct_from_middle_man" boolean, "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_dropship_order_returned"("p_order_id" bigint, "p_actual_return_charge" numeric, "p_deduct_from_middle_man" boolean, "p_reason" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."place_shop_order_for_procurement"("p_order_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."process_dropship_courier_remittance_uwl"("p_order_id" bigint, "p_net_amount" numeric, "p_courier_charge" numeric, "p_remittance_ref" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_dropship_courier_remittance_uwl"("p_order_id" bigint, "p_net_amount" numeric, "p_courier_charge" numeric, "p_remittance_ref" "text") TO "service_role";


GRANT ALL ON FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text", "p_payment_date" "date", "p_method" "text", "p_note" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text", "p_payment_date" "date", "p_method" "text", "p_note" "text", "p_courier_charge" numeric) TO "authenticated";


GRANT ALL ON FUNCTION "public"."remove_shop_cart_item"("p_cart_item_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."staff_counter_offer"("p_order_id" bigint, "p_items" "jsonb") TO "authenticated";


GRANT ALL ON FUNCTION "public"."staff_price_shop_order"("p_order_id" bigint, "p_items" "jsonb", "p_profit_basis" "text", "p_fx_rate" numeric, "p_cargo_rate" numeric, "p_profit_pct" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_catalog_order_item_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_item_id" bigint, "p_payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_catalog_order_rates_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_shop_order_charges_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_shop_order_status_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."staff_finalize_catalog_prices"("p_order_id" bigint, "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."staff_start_catalog_procurement"("p_order_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."staff_set_catalog_delivered_qty"("p_order_id" bigint, "p_items" "jsonb") TO "authenticated";


GRANT ALL ON FUNCTION "public"."submit_shop_order_from_cart"("p_cart_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_billing_profile_id" bigint, "p_is_prepaid" boolean, "p_delivery_instructions" "text", "p_cod_charge_amount" numeric, "p_delivery_charge_amount" numeric, "p_print_charge_amount" numeric, "p_packing_charge_amount" numeric, "p_discount_amount" numeric) TO "authenticated";


GRANT ALL ON FUNCTION "public"."update_dropship_consignment"("p_order_id" bigint, "p_cod_collect_amount" numeric, "p_package_weight_band" "text", "p_item_category" "text", "p_parcel_description" "text", "p_courier_order_ref" "text", "p_delivery_zone" "text", "p_sender_name" "text", "p_pickup_phone" "text", "p_pickup_address" "text", "p_payout_account_type" "text", "p_payout_account_info" "text", "p_allow_open_box" boolean, "p_delivery_instruction_notes" "text", "p_courier_service_id" "uuid", "p_courier_tracking_number" "text", "p_courier_awb_number" "text", "p_courier_consignment_id" "text", "p_tracking_url" "text", "p_courier_cost_amount" numeric, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_phone_secondary" "text", "p_shipping_address" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_delivery_charge_amount" numeric, "p_cod_charge_amount" numeric) TO "authenticated";


GRANT ALL ON FUNCTION "public"."update_shop_cart_item_price"("p_cart_item_id" bigint, "p_price" numeric) TO "authenticated";


GRANT ALL ON FUNCTION "public"."update_shop_cart_item_qty"("p_cart_item_id" bigint, "p_quantity" integer) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_group_shop_profiles" TO "anon";
GRANT ALL ON TABLE "public"."customer_group_shop_profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_group_shop_profiles" TO "service_role";


GRANT ALL ON FUNCTION "public"."upsert_customer_group_shop_profile"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_is_active" boolean, "p_default_can_browse" boolean, "p_default_can_see_buy_price" boolean, "p_default_can_see_sell_price" boolean, "p_default_can_add_to_cart" boolean, "p_default_can_place_order" boolean, "p_default_can_negotiate" boolean, "p_default_can_view_quantity" boolean, "p_default_can_set_dropship_price" boolean) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shops" TO "anon";
GRANT ALL ON TABLE "public"."shops" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shops" TO "service_role";


GRANT ALL ON FUNCTION "public"."upsert_shop"("p_tenant_id" bigint, "p_name" "text", "p_slug" "text", "p_order_mode" "public"."shop_order_mode_enum", "p_is_negotiable" boolean, "p_show_stock_quantity" boolean, "p_is_active" boolean, "p_shop_type" "public"."shop_type_enum", "p_vendor_code" "text", "p_id" bigint, "p_default_currency_id" bigint, "p_global_stock_type_id" bigint, "p_allow_delivery" boolean, "p_buy_currency_id" bigint, "p_sell_currency_id" bigint, "p_pricing_method" "text", "p_markup_percentage" numeric, "p_quantity_display_mode" "text", "p_default_print_charge_amount" numeric, "p_default_packing_charge_amount" numeric, "p_deduct_charges_from_margin" boolean, "p_vendor_filters" "jsonb", "p_deduct_print_from_margin" boolean, "p_deduct_packing_from_margin" boolean, "p_description" "text", "p_category_ids" bigint[]) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_customer_group_access" TO "anon";
GRANT ALL ON TABLE "public"."shop_customer_group_access" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_customer_group_access" TO "service_role";


GRANT ALL ON FUNCTION "public"."upsert_shop_customer_group_access"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_status" boolean, "p_can_browse" boolean, "p_can_see_buy_price" boolean, "p_can_see_sell_price" boolean, "p_can_add_to_cart" boolean, "p_can_place_order" boolean, "p_can_negotiate" boolean, "p_can_view_quantity" boolean, "p_can_set_dropship_price" boolean, "p_price_tier_code" "text", "p_credit_limit_amount" numeric, "p_credit_limit_currency_id" bigint) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_pricing_rules" TO "anon";
GRANT ALL ON TABLE "public"."shop_pricing_rules" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_pricing_rules" TO "service_role";


GRANT ALL ON FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean, "p_default_show_quantity" boolean) TO "authenticated";


GRANT ALL ON FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean, "p_default_show_quantity" boolean, "p_default_add_quantity" integer) TO "authenticated";


GRANT ALL ON FUNCTION "public"."upsert_shop_pricing_rule"("p_shop_id" bigint, "p_markup_percentage" numeric, "p_is_auto_publish" boolean, "p_default_show_quantity" boolean, "p_default_add_quantity" integer, "p_dropship_markup_percentage" numeric) TO "authenticated";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_product_listings" TO "anon";
GRANT ALL ON TABLE "public"."shop_product_listings" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_product_listings" TO "service_role";


GRANT ALL ON FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric, "p_minimum_sell_price_currency_id" bigint, "p_show_quantity" boolean, "p_display_quantity_override" integer, "p_is_active" boolean, "p_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric, "p_minimum_sell_price_currency_id" bigint, "p_show_quantity" boolean, "p_display_quantity_override" integer, "p_is_active" boolean, "p_id" bigint, "p_is_price_locked" boolean, "p_is_quantity_locked" boolean, "p_quantity_override_type" "text") TO "authenticated";


GRANT ALL ON FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric, "p_minimum_sell_price_currency_id" bigint, "p_show_quantity" boolean, "p_display_quantity_override" integer, "p_is_active" boolean, "p_id" bigint, "p_is_price_locked" boolean, "p_is_quantity_locked" boolean, "p_quantity_override_type" "text", "p_global_stock_id" bigint, "p_product_id" bigint) TO "authenticated";


GRANT ALL ON FUNCTION "public"."user_can_manage_shop_tenant"("p_tenant_id" bigint) TO "authenticated";


GRANT UPDATE ON SEQUENCE "public"."customer_group_shop_profiles_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."customer_group_shop_profiles_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."customer_group_shop_profiles_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_cart_items" TO "anon";
GRANT ALL ON TABLE "public"."shop_cart_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_cart_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shop_cart_items_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shop_cart_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shop_cart_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_carts" TO "anon";
GRANT ALL ON TABLE "public"."shop_carts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_carts" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shop_carts_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shop_carts_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shop_carts_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_categories" TO "anon";
GRANT ALL ON TABLE "public"."shop_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."shop_categories" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shop_categories_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shop_categories_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shop_categories_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shop_customer_group_access_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shop_customer_group_access_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shop_customer_group_access_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_order_items" TO "anon";
GRANT ALL ON TABLE "public"."shop_order_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_order_items" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shop_order_items_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shop_order_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shop_order_items_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_orders" TO "anon";
GRANT ALL ON TABLE "public"."shop_orders" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_orders" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shop_orders_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shop_orders_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shop_orders_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shop_pricing_rules_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shop_pricing_rules_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shop_pricing_rules_id_seq" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shop_product_listings_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shop_product_listings_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shop_product_listings_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_product_offers" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_product_offers" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_product_offers" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shop_product_offers_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shop_product_offers_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shop_product_offers_id_seq" TO "service_role";


GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_stock_reservations" TO "anon";
GRANT ALL ON TABLE "public"."shop_stock_reservations" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_stock_reservations" TO "service_role";


GRANT UPDATE ON SEQUENCE "public"."shops_id_seq" TO "anon";
GRANT UPDATE ON SEQUENCE "public"."shops_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."shops_id_seq" TO "service_role";


ALTER TABLE "public"."customer_demand_bucket_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "customer_demand_bucket_items_tenant_isolation" ON "public"."customer_demand_bucket_items" USING (("tenant_id" = (NULLIF("current_setting"('app.current_tenant_id'::"text", true), ''::"text"))::bigint));


GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE "public"."customer_demand_bucket_items" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_demand_bucket_items" TO "service_role";


GRANT USAGE,SELECT ON SEQUENCE "public"."customer_demand_bucket_items_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."customer_demand_bucket_items_id_seq" TO "service_role";


GRANT ALL ON FUNCTION "public"."can_access_demand_bucket_profile"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_staff_only" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_demand_bucket_item"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_product_id" bigint, "p_source_type" "public"."demand_bucket_source_type", "p_source_id" bigint, "p_snapshot" "jsonb", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_demand_bucket_items"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_status" "public"."demand_bucket_status", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pop_demand_bucket_item"("p_bucket_item_id" bigint, "p_popped_into_type" "text", "p_popped_into_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pop_demand_bucket_items"("p_bucket_item_ids" bigint[], "p_popped_into_type" "text", "p_popped_into_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_demand_bucket_item"("p_bucket_item_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."purge_popped_demand_bucket_items"("p_tenant_id" bigint, "p_retention_days" integer) TO "authenticated";

