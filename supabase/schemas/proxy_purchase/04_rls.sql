-- Proxy purchase people group RLS + grants

ALTER TABLE "public"."pp_people_group" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."pp_people_group_member" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."pp_shipment" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."pp_purchase_requests" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."pp_order_lines" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pp_people_group_select" ON "public"."pp_people_group"
    FOR SELECT TO "authenticated"
    USING ("public"."has_active_tenant_membership"("tenant_id"));

CREATE POLICY "pp_people_group_member_select" ON "public"."pp_people_group_member"
    FOR SELECT TO "authenticated"
    USING ("public"."has_active_tenant_membership"("tenant_id"));

CREATE POLICY "pp_shipment_select" ON "public"."pp_shipment"
    FOR SELECT TO "authenticated"
    USING ("public"."has_active_tenant_membership"("tenant_id"));

CREATE POLICY "pp_purchase_requests_select" ON "public"."pp_purchase_requests"
    FOR SELECT TO "authenticated"
    USING ("public"."has_active_tenant_membership"("tenant_id"));

CREATE POLICY "pp_order_lines_select" ON "public"."pp_order_lines"
    FOR SELECT TO "authenticated"
    USING ("public"."has_active_tenant_membership"("tenant_id"));

GRANT ALL ON TABLE "public"."pp_people_group" TO "anon";
GRANT ALL ON TABLE "public"."pp_people_group" TO "authenticated";
GRANT ALL ON TABLE "public"."pp_people_group" TO "service_role";

GRANT ALL ON TABLE "public"."pp_people_group_member" TO "anon";
GRANT ALL ON TABLE "public"."pp_people_group_member" TO "authenticated";
GRANT ALL ON TABLE "public"."pp_people_group_member" TO "service_role";

GRANT ALL ON SEQUENCE "public"."pp_people_group_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pp_people_group_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pp_people_group_id_seq" TO "service_role";

GRANT ALL ON SEQUENCE "public"."pp_people_group_member_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pp_people_group_member_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pp_people_group_member_id_seq" TO "service_role";

GRANT ALL ON FUNCTION "public"."list_pp_people_groups"("p_tenant_id" bigint, "p_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."list_pp_people_groups"("p_tenant_id" bigint, "p_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_pp_people_groups"("p_tenant_id" bigint, "p_type" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."create_pp_people_group"("p_tenant_id" bigint, "p_name" "text", "p_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_pp_people_group"("p_tenant_id" bigint, "p_name" "text", "p_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_pp_people_group"("p_tenant_id" bigint, "p_name" "text", "p_type" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."list_pp_people_group_members"("p_tenant_id" bigint, "p_people_group_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."list_pp_people_group_members"("p_tenant_id" bigint, "p_people_group_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_pp_people_group_members"("p_tenant_id" bigint, "p_people_group_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."create_pp_people_group_member"("p_tenant_id" bigint, "p_people_group_id" bigint, "p_name" "text", "p_email" "text", "p_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_pp_people_group_member"("p_tenant_id" bigint, "p_people_group_id" bigint, "p_name" "text", "p_email" "text", "p_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_pp_people_group_member"("p_tenant_id" bigint, "p_people_group_id" bigint, "p_name" "text", "p_email" "text", "p_role" "text") TO "service_role";

GRANT ALL ON TABLE "public"."pp_shipment" TO "anon";
GRANT ALL ON TABLE "public"."pp_shipment" TO "authenticated";
GRANT ALL ON TABLE "public"."pp_shipment" TO "service_role";

GRANT ALL ON SEQUENCE "public"."pp_shipment_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pp_shipment_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pp_shipment_id_seq" TO "service_role";

GRANT ALL ON FUNCTION "public"."list_pp_shipments"("p_tenant_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."list_pp_shipments"("p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_pp_shipments"("p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."create_pp_shipment"("p_tenant_id" bigint, "p_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_pp_shipment"("p_tenant_id" bigint, "p_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_pp_shipment"("p_tenant_id" bigint, "p_name" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."check_proxy_login_access"("p_email" "text", "p_tenant_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."check_proxy_login_access"("p_email" "text", "p_tenant_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_proxy_login_access"("p_email" "text", "p_tenant_id" bigint) TO "service_role";

GRANT ALL ON FUNCTION "public"."get_proxy_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_people_group_member_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_proxy_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_people_group_member_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_proxy_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_people_group_member_id" bigint) TO "service_role";

GRANT ALL ON TABLE "public"."pp_purchase_requests" TO "anon";
GRANT ALL ON TABLE "public"."pp_purchase_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."pp_purchase_requests" TO "service_role";

GRANT ALL ON TABLE "public"."pp_order_lines" TO "anon";
GRANT ALL ON TABLE "public"."pp_order_lines" TO "authenticated";
GRANT ALL ON TABLE "public"."pp_order_lines" TO "service_role";

GRANT ALL ON SEQUENCE "public"."pp_purchase_requests_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pp_purchase_requests_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pp_purchase_requests_id_seq" TO "service_role";

GRANT ALL ON SEQUENCE "public"."pp_order_lines_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pp_order_lines_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pp_order_lines_id_seq" TO "service_role";

GRANT ALL ON FUNCTION "public"."create_pp_purchase_request_draft"(bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."get_pp_purchase_request"(bigint, bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."list_pp_purchase_requests"(bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."list_pp_purchase_requests_for_customer"(bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."list_pp_order_lines_for_request"(bigint, bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."list_pp_order_lines"(bigint, bigint, bigint, bigint, bigint, text[], text[]) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."list_pp_order_lines_staff_filter_options"(bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."_pp_order_line_url_host"(text) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."list_pp_order_lines_for_customer"(bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."list_pp_order_lines_for_supplier"(bigint, bigint, text[], text[]) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."_pp_resolve_proxy_supplier_member"(bigint, bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."_pp_order_line_to_json"("public"."pp_order_lines", "text") TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."add_pp_order_line"(bigint, bigint, text, numeric, text) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."update_pp_order_line"(bigint, bigint, bigint, text, numeric, text) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."delete_pp_order_line"(bigint, bigint, bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."update_pp_order_line_staff"(bigint, bigint, text, numeric, text, text, text, text, numeric, bigint, bigint, boolean, text, numeric, numeric) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."update_pp_order_line_supplier"(bigint, bigint, bigint, numeric, text) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."add_pp_order_line_staff"(bigint, bigint, text, numeric, text, text, text, text, numeric, bigint, bigint, boolean, text, numeric, numeric) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."delete_pp_order_line_staff"(bigint, bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."_pp_normalize_bucket_instructions"(jsonb) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."update_pp_purchase_request_instructions"(bigint, bigint, jsonb) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."post_pp_purchase_request"(bigint, bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."delete_pp_purchase_request_draft"(bigint, bigint) TO "anon", "authenticated", "service_role";