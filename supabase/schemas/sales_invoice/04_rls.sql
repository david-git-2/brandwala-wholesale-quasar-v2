CREATE OR REPLACE TRIGGER "trg_billing_profiles_set_updated_at" BEFORE UPDATE ON "public"."billing_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_recipient_profiles_set_updated_at" BEFORE UPDATE ON "public"."recipient_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_invoice_brands_set_updated_at" BEFORE UPDATE ON "public"."invoice_brands" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_global_invoices_default_issued_by" BEFORE INSERT ON "public"."sales_invoices" FOR EACH ROW EXECUTE FUNCTION "public"."global_invoices_default_issued_by_tenant_id"();

CREATE OR REPLACE TRIGGER "trg_global_invoices_set_updated_at" BEFORE UPDATE ON "public"."sales_invoices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_validate_global_invoice_profiles_insert_update" BEFORE INSERT OR UPDATE ON "public"."sales_invoices" FOR EACH ROW EXECUTE FUNCTION "public"."trg_validate_global_invoice_profiles"();

CREATE OR REPLACE TRIGGER "trg_global_invoice_items_set_updated_at" BEFORE UPDATE ON "public"."sales_invoice_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_global_return_items_set_updated_at" BEFORE UPDATE ON "public"."sales_return_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_customer_groups_auto_billing_profile" AFTER INSERT ON "public"."customer_groups" FOR EACH ROW EXECUTE FUNCTION "public"."trg_auto_create_billing_profile_for_customer_group"();

CREATE OR REPLACE TRIGGER "trg_shop_orders_sync_collection_source" BEFORE INSERT OR UPDATE OF "global_invoice_id" ON "public"."shop_orders" FOR EACH ROW EXECUTE FUNCTION "public"."sync_shop_order_collection_source_from_invoice"();



-- Enable Row Level Security

ALTER TABLE "public"."billing_profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."recipient_profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."invoice_brands" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."sales_invoices" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."sales_invoice_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."sales_return_items" ENABLE ROW LEVEL SECURITY;



-- Policies

CREATE POLICY "billing_profiles_select" ON "public"."billing_profiles" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "billing_profiles"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));

CREATE POLICY "billing_profiles_write" ON "public"."billing_profiles" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'billing_profile'::"text", 'edit'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'billing_profile'::"text", 'edit'::"text"));


CREATE POLICY "recipient_profiles_select" ON "public"."recipient_profiles" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "recipient_profiles"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));

CREATE POLICY "recipient_profiles_write" ON "public"."recipient_profiles" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text"));


CREATE POLICY "invoice_brands_delete" ON "public"."invoice_brands" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_brands"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));

CREATE POLICY "invoice_brands_insert" ON "public"."invoice_brands" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_brands"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));

CREATE POLICY "invoice_brands_select" ON "public"."invoice_brands" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_brands"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));

CREATE POLICY "invoice_brands_update" ON "public"."invoice_brands" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_brands"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_brands"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."role" = ANY (ARRAY['admin'::"public"."app_role", 'staff'::"public"."app_role"]))))));

CREATE POLICY "invoice_brands_write" ON "public"."invoice_brands" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'invoice_brand'::"text", 'edit'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'invoice_brand'::"text", 'edit'::"text"));


CREATE POLICY "global_invoices_select" ON "public"."sales_invoices" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("issued_by_tenant_id") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "global_invoices_write" ON "public"."sales_invoices" TO "authenticated" USING (("public"."membership_has_module_action"("issued_by_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("issued_by_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));


CREATE POLICY "global_invoice_items_all" ON "public"."sales_invoice_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."sales_invoices" "gi"
  WHERE ("gi"."id" = "sales_invoice_items"."invoice_id")))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sales_invoices" "gi"
  WHERE ("gi"."id" = "sales_invoice_items"."invoice_id"))));


CREATE POLICY "global_return_items_all" ON "public"."sales_return_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."sales_invoices" "gi"
  WHERE ("gi"."id" = "sales_return_items"."invoice_id")))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sales_invoices" "gi"
  WHERE ("gi"."id" = "sales_return_items"."invoice_id"))));



-- Grants on Tables and Views

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."billing_profiles" TO "anon";
GRANT ALL ON TABLE "public"."billing_profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."billing_profiles" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."recipient_profiles" TO "anon";
GRANT ALL ON TABLE "public"."recipient_profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."recipient_profiles" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_brands" TO "anon";
GRANT ALL ON TABLE "public"."invoice_brands" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_brands" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales_invoices" TO "anon";
GRANT ALL ON TABLE "public"."sales_invoices" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_invoices" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales_invoice_items" TO "anon";
GRANT ALL ON TABLE "public"."sales_invoice_items" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_invoice_items" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales_return_items" TO "anon";
GRANT ALL ON TABLE "public"."sales_return_items" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_return_items" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_invoices" TO "service_role";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_invoice_items" TO "service_role";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_return_items" TO "service_role";



-- Grants on Sequences

GRANT UPDATE ON SEQUENCE "public"."billing_profiles_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."billing_profiles_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."billing_profiles_id_seq" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."recipient_profiles_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."recipient_profiles_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."recipient_profiles_id_seq" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."invoice_brands_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."invoice_brands_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."invoice_brands_id_seq" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."global_invoices_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_invoices_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_invoices_id_seq" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."global_invoice_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_invoice_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_invoice_items_id_seq" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."global_return_items_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."global_return_items_id_seq" TO "authenticated";
GRANT UPDATE ON SEQUENCE "public"."global_return_items_id_seq" TO "service_role";



-- Grants on Functions

GRANT ALL ON FUNCTION "public"."add_global_invoice_item"("p_invoice_id" bigint, "p_global_stock_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_line_discount_amount" numeric, "p_recipient_price_amount" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."add_global_return_item"("p_invoice_id" bigint, "p_invoice_item_id" bigint, "p_quantity" numeric, "p_return_charge_amount" numeric, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_global_return_item"("p_invoice_id" bigint, "p_invoice_item_id" bigint, "p_quantity" numeric, "p_return_face_amount" numeric, "p_return_accounting_amount" numeric, "p_return_charge_amount" numeric, "p_note" "text", "p_to_grade_tag_id" bigint, "p_to_availability" "public"."stock_availability") TO "authenticated";

GRANT ALL ON FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."apply_global_invoice_target_total"("p_invoice_id" bigint, "p_target_total" numeric, "p_dry_run" boolean) TO "authenticated";

GRANT ALL ON FUNCTION "public"."convert_wholesale_draft_to_retail"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."dispense_middleman_payout_from_tenant"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payout_method" "text", "p_reference_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."dispense_middleman_payout_from_tenant"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payout_method" "text", "p_reference_notes" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."ensure_dropship_invoice_billed_entry"("p_invoice_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_dropship_invoice_billed_entry"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."post_sales_invoice"("p_invoice_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."post_sales_invoice"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."recompute_global_invoice_payment_status"("p_global_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."record_recipient_invoice_collection"("p_global_invoice_id" bigint, "p_amount" numeric, "p_payment_date" "date", "p_method" "text", "p_reference" "text", "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_recipient_invoice_collection"("p_global_invoice_id" bigint, "p_amount" numeric, "p_payment_date" "date", "p_method" "text", "p_reference" "text", "p_note" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."remove_global_invoice_item"("p_invoice_item_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."resolve_billing_profile_for_customer_group"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."unpost_sales_invoice"("p_invoice_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."unpost_sales_invoice"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_global_invoice_header"("p_invoice_id" bigint, "p_discount_amount" numeric, "p_shipping_charge" numeric, "p_cod_charge" numeric, "p_wrapping_charge" numeric, "p_print_charge" numeric, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_note" "text", "p_invoice_no" "text", "p_invoice_date" "date") TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_global_invoice_item"("p_item_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_recipient_price_amount" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."void_sales_invoice"("p_invoice_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."void_sales_invoice"("p_invoice_id" bigint) TO "service_role";

GRANT SELECT ON TABLE "public"."sales_invoice_counters" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_invoice_counters" TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."generate_sales_invoice_number"("p_tenant_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_date" "date") TO "authenticated";
GRANT EXECUTE ON FUNCTION "public"."generate_sales_invoice_number"("p_tenant_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."search_sales_invoice_stock"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_sales_invoice_stock"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."process_wholesale_invoice_return"("p_invoice_id" bigint, "p_items" jsonb, "p_return_charge_amount" numeric, "p_refund_method" "text", "p_payout_account_id" bigint, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_wholesale_invoice_return"("p_invoice_id" bigint, "p_items" jsonb, "p_return_charge_amount" numeric, "p_refund_method" "text", "p_payout_account_id" bigint, "p_note" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."collect_wholesale_invoice_payment"("p_invoice_id" bigint, "p_cash_amount" numeric, "p_cash_method" "text", "p_wallet_amount" numeric, "p_settlement_amount" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."collect_wholesale_invoice_payment"("p_invoice_id" bigint, "p_cash_amount" numeric, "p_cash_method" "text", "p_wallet_amount" numeric, "p_settlement_amount" numeric) TO "service_role";


