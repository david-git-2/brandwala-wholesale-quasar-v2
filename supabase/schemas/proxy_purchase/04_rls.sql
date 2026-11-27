-- Proxy purchase people group RLS + grants

ALTER TABLE "public"."pp_people_group" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."pp_people_group_member" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pp_people_group_select" ON "public"."pp_people_group"
    FOR SELECT TO "authenticated"
    USING ("public"."has_active_tenant_membership"("tenant_id"));

CREATE POLICY "pp_people_group_member_select" ON "public"."pp_people_group_member"
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