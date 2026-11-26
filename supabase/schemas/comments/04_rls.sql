-- Comments kernel RLS

ALTER TABLE "public"."comments" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comments_select" ON "public"."comments" FOR SELECT TO "authenticated" USING ("public"."has_active_tenant_membership"("tenant_id"));

GRANT ALL ON TABLE "public"."comments" TO "anon";
GRANT ALL ON TABLE "public"."comments" TO "authenticated";
GRANT ALL ON TABLE "public"."comments" TO "service_role";

GRANT ALL ON SEQUENCE "public"."comments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."comments_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."comments_id_seq" TO "service_role";

GRANT ALL ON FUNCTION "public"."list_comments"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."list_comments"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_comments"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."add_comment"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" "text", "p_body" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_comment"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" "text", "p_body" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_comment"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" "text", "p_body" "text") TO "service_role";

GRANT ALL ON FUNCTION "public"."soft_delete_comment"("p_tenant_id" bigint, "p_comment_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."soft_delete_comment"("p_tenant_id" bigint, "p_comment_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."soft_delete_comment"("p_tenant_id" bigint, "p_comment_id" bigint) TO "service_role";