-- bills_pays: triggers, foreign keys, RLS policies, grants.

CREATE OR REPLACE TRIGGER "trg_billing_profiles_admin_email_unique_per_tenant" BEFORE INSERT OR UPDATE ON "public"."billing_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_billing_profile_admin_email_unique_per_tenant"();

CREATE OR REPLACE TRIGGER "trg_billing_profiles_normalize_phone" BEFORE INSERT OR UPDATE OF "phone" ON "public"."billing_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."trg_billing_profiles_normalize_phone"();

CREATE OR REPLACE TRIGGER "trg_billing_profiles_set_updated_at" BEFORE UPDATE ON "public"."billing_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_billing_profiles_sync_parent_tenant" BEFORE INSERT OR UPDATE OF "tenant_id", "parent_tenant_id" ON "public"."billing_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."trg_billing_profiles_sync_parent_tenant"();

CREATE OR REPLACE TRIGGER "trg_billing_profiles_sync_profile" AFTER INSERT OR UPDATE ON "public"."billing_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_profile_from_billing_profile"();

CREATE OR REPLACE TRIGGER "trg_cargo_companies_sync_profile" AFTER INSERT OR UPDATE ON "public"."cargo_companies" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_profile_from_cargo_company"();

CREATE OR REPLACE TRIGGER "trg_courier_services_sync_profile" AFTER INSERT OR UPDATE ON "public"."courier_services" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_profile_from_courier_service"();

CREATE OR REPLACE TRIGGER "trg_customer_groups_auto_billing_profile" AFTER INSERT ON "public"."customer_groups" FOR EACH ROW EXECUTE FUNCTION "public"."trg_auto_create_billing_profile_for_customer_group"();

CREATE OR REPLACE TRIGGER "trg_customer_groups_sync_profile" AFTER UPDATE OF "accent_color", "is_active", "deleted_at" ON "public"."customer_groups" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_profile_from_customer_group"();

CREATE OR REPLACE TRIGGER "trg_global_invoice_items_set_updated_at" BEFORE UPDATE ON "public"."bill_lines" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_global_invoices_default_issued_by" BEFORE INSERT ON "public"."bills" FOR EACH ROW EXECUTE FUNCTION "public"."global_invoices_default_issued_by_tenant_id"();

CREATE OR REPLACE TRIGGER "trg_global_invoices_set_updated_at" BEFORE UPDATE ON "public"."bills" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_global_return_items_set_updated_at" BEFORE UPDATE ON "public"."sales_return_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_invoice_brands_set_updated_at" BEFORE UPDATE ON "public"."invoice_brands" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_profiles_set_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_recipient_profiles_set_parent_tenant_id" BEFORE INSERT OR UPDATE OF "tenant_id" ON "public"."recipient_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_parent_tenant_id_from_tenant"();

CREATE OR REPLACE TRIGGER "trg_recipient_profiles_set_updated_at" BEFORE UPDATE ON "public"."recipient_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_sales_invoice_counters_set_updated_at" BEFORE UPDATE ON "public"."sales_invoice_counters" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_shop_orders_sync_collection_source" BEFORE INSERT OR UPDATE OF "global_invoice_id" ON "public"."shop_orders" FOR EACH ROW EXECUTE FUNCTION "public"."sync_shop_order_collection_source_from_invoice"();

CREATE OR REPLACE TRIGGER "trg_tenants_sync_profile" AFTER INSERT OR UPDATE OF "name", "is_active" ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_profile_from_tenant"();

CREATE OR REPLACE TRIGGER "trg_validate_global_invoice_profiles_insert_update" BEFORE INSERT OR UPDATE ON "public"."bills" FOR EACH ROW EXECUTE FUNCTION "public"."trg_validate_global_invoice_profiles"();

CREATE OR REPLACE TRIGGER "trg_vendors_sync_profile" AFTER INSERT OR UPDATE ON "public"."vendors" FOR EACH ROW EXECUTE FUNCTION "public"."trg_sync_profile_from_vendor"();

ALTER TABLE ONLY "public"."billing_profiles"
    ADD CONSTRAINT "billing_profiles_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."billing_profiles"
    ADD CONSTRAINT "billing_profiles_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."billing_profiles"
    ADD CONSTRAINT "billing_profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."bill_lines"
    ADD CONSTRAINT "global_invoice_items_assigned_child_tenant_id_fkey" FOREIGN KEY ("assigned_child_tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."bill_lines"
    ADD CONSTRAINT "global_invoice_items_global_stock_id_fkey" FOREIGN KEY ("global_stock_id") REFERENCES "public"."global_stocks"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."bill_lines"
    ADD CONSTRAINT "global_invoice_items_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."bills"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."bill_lines"
    ADD CONSTRAINT "global_invoice_items_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."bill_lines"
    ADD CONSTRAINT "global_invoice_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."bill_lines"
    ADD CONSTRAINT "global_invoice_items_shipment_item_id_fkey" FOREIGN KEY ("shipment_item_id") REFERENCES "public"."global_shipment_items"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "global_invoices_issued_by_tenant_id_fkey" FOREIGN KEY ("issued_by_tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "global_invoices_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "global_invoices_recipient_profile_id_fkey" FOREIGN KEY ("recipient_profile_id") REFERENCES "public"."recipient_profiles"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."pay_instruments"
    ADD CONSTRAINT "global_payment_instruments_bd_bank_id_fkey" FOREIGN KEY ("bd_bank_id") REFERENCES "public"."bd_banks"("id");

ALTER TABLE ONLY "public"."pay_instruments"
    ADD CONSTRAINT "global_payment_instruments_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "public"."pays"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pay_instruments"
    ADD CONSTRAINT "global_payment_instruments_payment_method_code_fkey" FOREIGN KEY ("payment_method_code") REFERENCES "public"."payment_methods"("code");

ALTER TABLE ONLY "public"."pays"
    ADD CONSTRAINT "global_payments_customer_group_id_fkey" FOREIGN KEY ("customer_group_id") REFERENCES "public"."customer_groups"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."pays"
    ADD CONSTRAINT "global_payments_shop_order_id_fkey" FOREIGN KEY ("shop_order_id") REFERENCES "public"."shop_orders"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_global_stock_id_fkey" FOREIGN KEY ("global_stock_id") REFERENCES "public"."global_stocks"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."bills"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_invoice_item_id_fkey" FOREIGN KEY ("invoice_item_id") REFERENCES "public"."bill_lines"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."sales_return_items"
    ADD CONSTRAINT "global_return_items_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."invoice_brands"
    ADD CONSTRAINT "invoice_brands_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."invoice_write_offs"
    ADD CONSTRAINT "invoice_write_offs_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."invoice_write_offs"
    ADD CONSTRAINT "invoice_write_offs_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."bills"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."invoice_write_offs"
    ADD CONSTRAINT "invoice_write_offs_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."invoice_write_offs"
    ADD CONSTRAINT "invoice_write_offs_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "public"."pays"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."invoice_write_offs"
    ADD CONSTRAINT "invoice_write_offs_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pay_allocations"
    ADD CONSTRAINT "payment_allocations_global_invoice_id_fkey" FOREIGN KEY ("global_invoice_id") REFERENCES "public"."bills"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pay_allocations"
    ADD CONSTRAINT "payment_allocations_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "public"."pays"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pay_allocations"
    ADD CONSTRAINT "payment_allocations_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pays"
    ADD CONSTRAINT "payments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."pays"
    ADD CONSTRAINT "pays_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE RESTRICT;

ALTER TABLE ONLY "public"."recipient_profiles"
    ADD CONSTRAINT "recipient_profiles_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."recipient_profiles"
    ADD CONSTRAINT "recipient_profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."bill_charges"
    ADD CONSTRAINT "sales_invoice_charges_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."bills"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."bill_charges"
    ADD CONSTRAINT "sales_invoice_charges_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."sales_invoice_counters"
    ADD CONSTRAINT "sales_invoice_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "sales_invoices_shop_order_id_fkey" FOREIGN KEY ("shop_order_id") REFERENCES "public"."shop_orders"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."cashbook_entries"
    ADD CONSTRAINT "universal_wallet_ledger_operating_tenant_id_fkey" FOREIGN KEY ("operating_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."cashbook_entries"
    ADD CONSTRAINT "universal_wallet_ledger_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."cashbook_entries"
    ADD CONSTRAINT "universal_wallet_ledger_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."cashbook_accounts"
    ADD CONSTRAINT "wallet_accounts_parent_tenant_id_fkey" FOREIGN KEY ("parent_tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."cashbook_accounts"
    ADD CONSTRAINT "wallet_accounts_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");

ALTER TABLE "public"."bill_charges" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."bill_lines" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."billing_profiles" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "billing_profiles_select" ON "public"."billing_profiles" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "billing_profiles"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));

CREATE POLICY "billing_profiles_write" ON "public"."billing_profiles" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'billing_profile'::"text", 'edit'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'billing_profile'::"text", 'edit'::"text"));

ALTER TABLE "public"."bills" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."cashbook_accounts" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."cashbook_entries" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "global_invoice_items_all" ON "public"."bill_lines" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."bills" "gi"
  WHERE ("gi"."id" = "bill_lines"."invoice_id")))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."bills" "gi"
  WHERE ("gi"."id" = "bill_lines"."invoice_id"))));

CREATE POLICY "global_invoices_select" ON "public"."bills" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("issued_by_tenant_id") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "global_invoices_write" ON "public"."bills" TO "authenticated" USING (("public"."membership_has_module_action"("issued_by_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("issued_by_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "global_return_items_all" ON "public"."sales_return_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."bills" "gi"
  WHERE ("gi"."id" = "sales_return_items"."invoice_id")))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."bills" "gi"
  WHERE ("gi"."id" = "sales_return_items"."invoice_id"))));

ALTER TABLE "public"."invoice_brands" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "invoice_brands_delete" ON "public"."invoice_brands" FOR DELETE TO "authenticated" USING (("public"."membership_has_module_action"("parent_tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "invoice_brands_insert" ON "public"."invoice_brands" FOR INSERT TO "authenticated" WITH CHECK (("public"."membership_has_module_action"("parent_tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "invoice_brands_select" ON "public"."invoice_brands" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("parent_tenant_id") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "invoice_brands_update" ON "public"."invoice_brands" FOR UPDATE TO "authenticated" USING (("public"."membership_has_module_action"("parent_tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("parent_tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

ALTER TABLE "public"."invoice_write_offs" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "invoice_write_offs_select" ON "public"."invoice_write_offs" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_write_offs"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "invoice_write_offs"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "invoice_write_offs_write" ON "public"."invoice_write_offs" TO "authenticated" USING (("public"."membership_has_module_action"("parent_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'global_invoice'::"text", 'edit'::"text"))) WITH CHECK (("public"."membership_has_module_action"("parent_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'global_invoice'::"text", 'edit'::"text")));

ALTER TABLE "public"."pay_allocations" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."pay_instruments" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payment_allocations_delete" ON "public"."pay_allocations" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."pays" "p"
  WHERE (("p"."id" = "pay_allocations"."payment_id") AND "public"."membership_has_module_action"("p"."tenant_id", 'payments'::"text", 'void'::"text")))));

CREATE POLICY "payment_allocations_insert" ON "public"."pay_allocations" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."pays" "p"
  WHERE (("p"."id" = "pay_allocations"."payment_id") AND "public"."membership_has_module_action"("p"."tenant_id", 'payments'::"text", 'allocate_payment'::"text")))));

CREATE POLICY "payment_allocations_select" ON "public"."pay_allocations" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "pay_allocations"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));

CREATE POLICY "payment_allocations_update" ON "public"."pay_allocations" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."pays" "p"
  WHERE (("p"."id" = "pay_allocations"."payment_id") AND "public"."membership_has_module_action"("p"."tenant_id", 'payments'::"text", 'allocate_payment'::"text"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."pays" "p"
  WHERE (("p"."id" = "pay_allocations"."payment_id") AND "public"."membership_has_module_action"("p"."tenant_id", 'payments'::"text", 'allocate_payment'::"text")))));

CREATE POLICY "payments_delete" ON "public"."pays" FOR DELETE TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'payments'::"text", 'void'::"text"));

CREATE POLICY "payments_insert" ON "public"."pays" FOR INSERT TO "authenticated" WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'payments'::"text", 'collect_payment'::"text"));

CREATE POLICY "payments_select" ON "public"."pays" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "pays"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))));

CREATE POLICY "payments_update" ON "public"."pays" FOR UPDATE TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'payments'::"text", 'allocate_payment'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'payments'::"text", 'allocate_payment'::"text"));

ALTER TABLE "public"."pays" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("parent_tenant_id") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "profiles"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND "m"."is_active")))));

CREATE POLICY "profiles_write" ON "public"."profiles" TO "authenticated" USING ("public"."membership_has_module_action"("parent_tenant_id", 'billing_profile'::"text", 'edit'::"text")) WITH CHECK ("public"."membership_has_module_action"("parent_tenant_id", 'billing_profile'::"text", 'edit'::"text"));

ALTER TABLE "public"."recipient_profiles" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recipient_profiles_select" ON "public"."recipient_profiles" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("tenant_id") OR (("parent_tenant_id" IS NOT NULL) AND ("public"."has_active_tenant_membership"("parent_tenant_id") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")))));

CREATE POLICY "recipient_profiles_write" ON "public"."recipient_profiles" TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'customer'::"text", 'edit'::"text") OR (("parent_tenant_id" IS NOT NULL) AND ("public"."membership_has_module_action"("parent_tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("parent_tenant_id", 'customer'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id"))))) WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'customer'::"text", 'edit'::"text") OR (("parent_tenant_id" IS NOT NULL) AND ("public"."membership_has_module_action"("parent_tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("parent_tenant_id", 'customer'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")))));

CREATE POLICY "sales_invoice_charges_all" ON "public"."bill_charges" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."bills" "gi"
  WHERE ("gi"."id" = "bill_charges"."invoice_id")))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."bills" "gi"
  WHERE ("gi"."id" = "bill_charges"."invoice_id"))));

ALTER TABLE "public"."sales_invoice_counters" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."sales_return_items" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "superadmin_can_manage_global_payment_instruments" ON "public"."pay_instruments" TO "authenticated" USING ("public"."is_superadmin"()) WITH CHECK ("public"."is_superadmin"());

CREATE POLICY "universal_wallet_ledger_select" ON "public"."cashbook_entries" FOR SELECT TO "authenticated" USING (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "cashbook_entries"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "wallet_accounts_authenticated_policy" ON "public"."cashbook_accounts" TO "authenticated" USING (true) WITH CHECK (true);

GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."cashbook_entries" TO "authenticated";

GRANT ALL ON TABLE "public"."cashbook_entries" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."bill_lines" TO "anon";

GRANT ALL ON TABLE "public"."bill_lines" TO "authenticated";

GRANT ALL ON TABLE "public"."bill_lines" TO "service_role";

GRANT ALL ON FUNCTION "public"."add_global_invoice_item"("p_invoice_id" bigint, "p_global_stock_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_line_discount_amount" numeric, "p_recipient_price_amount" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."add_global_invoice_item"("p_invoice_id" bigint, "p_global_stock_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_line_discount_amount" numeric, "p_recipient_price_amount" numeric) TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales_return_items" TO "anon";

GRANT ALL ON TABLE "public"."sales_return_items" TO "authenticated";

GRANT ALL ON TABLE "public"."sales_return_items" TO "service_role";

GRANT ALL ON FUNCTION "public"."add_global_return_item"("p_invoice_id" bigint, "p_invoice_item_id" bigint, "p_quantity" numeric, "p_return_charge_amount" numeric, "p_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."add_global_return_item"("p_invoice_id" bigint, "p_invoice_item_id" bigint, "p_quantity" numeric, "p_return_face_amount" numeric, "p_return_accounting_amount" numeric, "p_return_charge_amount" numeric, "p_note" "text", "p_to_grade_tag_id" bigint, "p_to_availability" "public"."stock_availability") TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pay_allocations" TO "anon";

GRANT ALL ON TABLE "public"."pay_allocations" TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pay_allocations" TO "service_role";

GRANT ALL ON FUNCTION "public"."allocate_payment_to_global_invoice"("p_tenant_id" bigint, "p_payment_id" bigint, "p_global_invoice_id" bigint, "p_amount" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."allocate_payment_to_global_invoice"("p_tenant_id" bigint, "p_payment_id" bigint, "p_global_invoice_id" bigint, "p_amount" numeric) TO "anon";

GRANT ALL ON FUNCTION "public"."allocate_payment_to_global_invoice"("p_tenant_id" bigint, "p_payment_id" bigint, "p_global_invoice_id" bigint, "p_amount" numeric) TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."bills" TO "anon";

GRANT ALL ON TABLE "public"."bills" TO "authenticated";

GRANT ALL ON TABLE "public"."bills" TO "service_role";

GRANT ALL ON FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."apply_global_invoice_target_total"("p_invoice_id" bigint, "p_target_total" numeric, "p_dry_run" boolean) TO "authenticated";

GRANT ALL ON FUNCTION "public"."billing_profile_valid_for_issuer"("p_billing_profile_id" bigint, "p_issued_by_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."build_dropship_tenant_b2b_invoice_payload"("p_order_id" bigint, "p_invoice_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."canonicalize_dropship_order_wallet_source_ids"("p_order_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."convert_wholesale_draft_to_retail"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_dropship_invoice"("p_order_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_dual_invoice_from_dropship_order"("p_order_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") TO "authenticated";

GRANT ALL ON FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."create_sales_invoice_from_payload"("p_tenant_id" bigint, "p_payload" "jsonb") TO "authenticated";

GRANT ALL ON FUNCTION "public"."dispense_middleman_payout_from_tenant"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payout_method" "text", "p_reference_notes" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."dispense_middleman_payout_from_tenant"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payout_method" "text", "p_reference_notes" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."ensure_dropship_invoice_billed_entry"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."ensure_dropship_invoice_billed_entry"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."ensure_dropship_tenant_b2b_invoice_at_delivered"("p_order_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."generate_sales_invoice_number"("p_tenant_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_date" "date") TO "authenticated";

GRANT ALL ON FUNCTION "public"."generate_sales_invoice_number"("p_tenant_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") TO "authenticated";

REVOKE ALL ON FUNCTION "public"."get_sales_invoice_dashboard_metrics"("p_tenant_id" bigint) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."get_sales_invoice_dashboard_metrics"("p_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_wallet_account_balances"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_wallet_account_balances"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."get_wallet_dashboard_summary"("p_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_wallet_dashboard_summary"("p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_wallet_detail_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_wallet_entity_statement"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "authenticated";

GRANT ALL ON FUNCTION "public"."get_wallet_entity_statement"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) TO "service_role";

GRANT ALL ON FUNCTION "public"."insert_global_payment_instruments"("p_payment_id" bigint, "p_instruments" "jsonb") TO "authenticated";

GRANT ALL ON FUNCTION "public"."insert_global_payment_instruments"("p_payment_id" bigint, "p_instruments" "jsonb") TO "service_role";

GRANT ALL ON FUNCTION "public"."issue_dropship_tenant_b2b_invoice"("p_tenant_id" bigint, "p_order_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."issue_wholesale_invoice"("p_invoice_id" bigint, "p_items" "jsonb") TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_customer_group_receipts"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_customer_group_receipts"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_customer_groups_payment_summary"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer, "p_only_with_due" boolean) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_customer_groups_payment_summary"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer, "p_only_with_due" boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_customer_groups_payout_summary"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_customer_group_id" bigint, "p_only_with_payable" boolean) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_customer_groups_payout_summary"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_customer_group_id" bigint, "p_only_with_payable" boolean) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_invoice_payment_history"("p_tenant_id" bigint, "p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_invoice_payment_history"("p_tenant_id" bigint, "p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."list_wallet_entities_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_search" "text", "p_limit" integer, "p_offset" integer, "p_currency_code" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."list_wallet_ledger_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_search" "text", "p_operating_tenant_id" bigint, "p_limit" integer, "p_offset" integer) TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pays" TO "anon";

GRANT ALL ON TABLE "public"."pays" TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pays" TO "service_role";

REVOKE ALL ON FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_received_on" "date", "p_note" "text", "p_reference" "text", "p_source" "text", "p_instruments" "jsonb", "p_allocations" "jsonb", "p_shop_order_id" bigint) FROM PUBLIC;

GRANT ALL ON FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_received_on" "date", "p_note" "text", "p_reference" "text", "p_source" "text", "p_instruments" "jsonb", "p_allocations" "jsonb", "p_shop_order_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_received_on" "date", "p_note" "text", "p_reference" "text", "p_source" "text", "p_instruments" "jsonb", "p_allocations" "jsonb", "p_shop_order_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."post_global_invoice"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."post_global_invoice"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."post_sales_invoice"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."post_sales_invoice"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."process_wholesale_invoice_return"("p_invoice_id" bigint, "p_items" "jsonb", "p_return_charge_amount" numeric, "p_refund_method" "text", "p_payout_account_id" bigint, "p_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."process_wholesale_invoice_return"("p_invoice_id" bigint, "p_items" "jsonb", "p_return_charge_amount" numeric, "p_refund_method" "text", "p_payout_account_id" bigint, "p_note" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."recipient_profile_valid_for_issuer"("p_recipient_profile_id" bigint, "p_issued_by_tenant_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."recompute_global_invoice_payment_status"("p_global_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."recompute_global_invoice_totals"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."record_ledger_transaction"("p_parent_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text", "p_exchange_rate" numeric, "p_source_type" "text", "p_source_id" "text", "p_metadata" "jsonb", "p_target_bucket" "text", "p_allow_overdraft" boolean) TO "authenticated";

GRANT ALL ON FUNCTION "public"."record_recipient_invoice_collection"("p_global_invoice_id" bigint, "p_amount" numeric, "p_payment_date" "date", "p_method" "text", "p_reference" "text", "p_note" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."record_recipient_invoice_collection"("p_global_invoice_id" bigint, "p_amount" numeric, "p_payment_date" "date", "p_method" "text", "p_reference" "text", "p_note" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."remove_global_invoice_item"("p_invoice_item_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."resolve_billing_profile_for_customer_group"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."reverse_wallet_ledger_entry_for_staff"("p_tenant_id" bigint, "p_ledger_entry_id" "uuid", "p_reason" "text", "p_reference_id" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."search_sales_invoice_stock"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";

GRANT ALL ON FUNCTION "public"."search_sales_invoice_stock"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) TO "service_role";

GRANT ALL ON FUNCTION "public"."sync_dropship_tenant_b2b_invoice_from_order"("p_order_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."sync_sales_invoice_charges_from_header"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text", "p_notes" "text", "p_metadata" "jsonb") TO "authenticated";

GRANT ALL ON FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text", "p_notes" "text", "p_metadata" "jsonb") TO "service_role";

GRANT ALL ON FUNCTION "public"."unpost_global_invoice"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."unpost_global_invoice"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."unpost_sales_invoice"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."unpost_sales_invoice"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."update_global_invoice_header"("p_invoice_id" bigint, "p_discount_amount" numeric, "p_shipping_charge" numeric, "p_cod_charge" numeric, "p_wrapping_charge" numeric, "p_print_charge" numeric, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_note" "text", "p_invoice_no" "text", "p_invoice_date" "date") TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_global_invoice_item"("p_item_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_recipient_price_amount" numeric) TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_payment_instrument_details"("p_tenant_id" bigint, "p_instrument_id" bigint, "p_reference" "text", "p_bd_bank_id" bigint, "p_cheque_number" "text", "p_cheque_date" "date") TO "authenticated";

GRANT ALL ON FUNCTION "public"."update_payment_instrument_details"("p_tenant_id" bigint, "p_instrument_id" bigint, "p_reference" "text", "p_bd_bank_id" bigint, "p_cheque_number" "text", "p_cheque_date" "date") TO "service_role";

GRANT ALL ON FUNCTION "public"."update_sales_invoice_from_payload"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_payload" "jsonb") TO "authenticated";

GRANT ALL ON FUNCTION "public"."upsert_profile_for_party"("p_parent_tenant_id" bigint, "p_profile_type" "public"."profile_party_type", "p_subject_id" bigint, "p_name" "text", "p_email" "text", "p_phone" "text", "p_phone_country_code" "text", "p_address" "text", "p_is_phone_unique" boolean, "p_accent_color" "text", "p_is_active" boolean, "p_deleted_at" timestamp with time zone) TO "authenticated";

GRANT ALL ON FUNCTION "public"."void_customer_receipt"("p_tenant_id" bigint, "p_payment_id" bigint, "p_reason" "text") TO "authenticated";

GRANT ALL ON FUNCTION "public"."void_customer_receipt"("p_tenant_id" bigint, "p_payment_id" bigint, "p_reason" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."void_global_invoice"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."void_global_invoice"("p_invoice_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."void_sales_invoice"("p_invoice_id" bigint) TO "authenticated";

GRANT ALL ON FUNCTION "public"."void_sales_invoice"("p_invoice_id" bigint) TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."bill_charges" TO "anon";

GRANT ALL ON TABLE "public"."bill_charges" TO "authenticated";

GRANT ALL ON TABLE "public"."bill_charges" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."billing_profiles" TO "anon";

GRANT ALL ON TABLE "public"."billing_profiles" TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."billing_profiles" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."billing_profiles_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."billing_profiles_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."billing_profiles_id_seq" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."cashbook_accounts" TO "anon";

GRANT ALL ON TABLE "public"."cashbook_accounts" TO "authenticated";

GRANT ALL ON TABLE "public"."cashbook_accounts" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."global_invoice_items" TO "anon";

GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."global_invoice_items" TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE "public"."global_invoice_items" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."global_invoice_items_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."global_invoice_items_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."global_invoice_items_id_seq" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."global_invoices_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."global_invoices_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."global_invoices_id_seq" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pay_instruments" TO "anon";

GRANT ALL ON TABLE "public"."pay_instruments" TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."pay_instruments" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."global_payment_instruments_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."global_payment_instruments_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."global_payment_instruments_id_seq" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_return_items" TO "anon";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_return_items" TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."global_return_items" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."global_return_items_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."global_return_items_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."global_return_items_id_seq" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_brands" TO "anon";

GRANT ALL ON TABLE "public"."invoice_brands" TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_brands" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."invoice_brands_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."invoice_brands_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."invoice_brands_id_seq" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_write_offs" TO "anon";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_write_offs" TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_write_offs" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."invoice_write_offs_id_seq" TO "anon";

GRANT UPDATE ON SEQUENCE "public"."invoice_write_offs_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."invoice_write_offs_id_seq" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."payment_allocations_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."payment_allocations_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."payment_allocations_id_seq" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."payments_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."payments_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."payments_id_seq" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "anon";

GRANT ALL ON TABLE "public"."profiles" TO "authenticated";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."profiles_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."profiles_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."profiles_id_seq" TO "service_role";

GRANT ALL ON TABLE "public"."recipient_profiles" TO "anon";

GRANT ALL ON TABLE "public"."recipient_profiles" TO "authenticated";

GRANT ALL ON TABLE "public"."recipient_profiles" TO "service_role";

GRANT ALL ON SEQUENCE "public"."recipient_profiles_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."recipient_profiles_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."recipient_profiles_id_seq" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."sales_invoice_charges_id_seq" TO "anon";

GRANT ALL ON SEQUENCE "public"."sales_invoice_charges_id_seq" TO "authenticated";

GRANT ALL ON SEQUENCE "public"."sales_invoice_charges_id_seq" TO "service_role";

GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales_invoice_counters" TO "anon";

GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales_invoice_counters" TO "authenticated";

GRANT ALL ON TABLE "public"."sales_invoice_counters" TO "service_role";

GRANT UPDATE ON SEQUENCE "public"."wallet_accounts_id_seq" TO "anon";

GRANT UPDATE ON SEQUENCE "public"."wallet_accounts_id_seq" TO "authenticated";

GRANT UPDATE ON SEQUENCE "public"."wallet_accounts_id_seq" TO "service_role";

ALTER TABLE ONLY "public"."courier_remittance_items"
    ADD CONSTRAINT "courier_remittance_items_global_invoice_id_fkey" FOREIGN KEY ("global_invoice_id") REFERENCES "public"."bills"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."customer_order_backlog_items"
    ADD CONSTRAINT "customer_order_backlog_items_billing_profile_id_fkey" FOREIGN KEY ("billing_profile_id") REFERENCES "public"."billing_profiles"("id") ON DELETE CASCADE;
