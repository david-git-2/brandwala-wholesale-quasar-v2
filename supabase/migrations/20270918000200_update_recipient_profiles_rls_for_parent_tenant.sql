-- Migration: 20270918000200_update_recipient_profiles_rls_for_parent_tenant.sql
-- Update recipient_profiles RLS policies to support parent tenant access

DROP POLICY IF EXISTS "recipient_profiles_select" ON "public"."recipient_profiles";
DROP POLICY IF EXISTS "recipient_profiles_write" ON "public"."recipient_profiles";
DROP POLICY IF EXISTS "recipient_profiles_insert" ON "public"."recipient_profiles";
DROP POLICY IF EXISTS "recipient_profiles_update" ON "public"."recipient_profiles";
DROP POLICY IF EXISTS "recipient_profiles_delete" ON "public"."recipient_profiles";

CREATE POLICY "recipient_profiles_select" ON "public"."recipient_profiles"
  FOR SELECT TO "authenticated" USING (
    "public"."has_active_tenant_membership"("tenant_id")
    OR ("parent_tenant_id" IS NOT NULL AND (
      "public"."has_active_tenant_membership"("parent_tenant_id")
      OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")
    ))
  );

CREATE POLICY "recipient_profiles_write" ON "public"."recipient_profiles"
  TO "authenticated" USING (
    "public"."membership_has_module_action"("tenant_id", 'recipient_profile'::text, 'edit'::text)
    OR "public"."membership_has_module_action"("tenant_id", 'customer'::text, 'edit'::text)
    OR ("parent_tenant_id" IS NOT NULL AND (
      "public"."membership_has_module_action"("parent_tenant_id", 'recipient_profile'::text, 'edit'::text)
      OR "public"."membership_has_module_action"("parent_tenant_id", 'customer'::text, 'edit'::text)
      OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")
    ))
  ) WITH CHECK (
    "public"."membership_has_module_action"("tenant_id", 'recipient_profile'::text, 'edit'::text)
    OR "public"."membership_has_module_action"("tenant_id", 'customer'::text, 'edit'::text)
    OR ("parent_tenant_id" IS NOT NULL AND (
      "public"."membership_has_module_action"("parent_tenant_id", 'recipient_profile'::text, 'edit'::text)
      OR "public"."membership_has_module_action"("parent_tenant_id", 'customer'::text, 'edit'::text)
      OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")
    ))
  );

GRANT ALL ON TABLE "public"."recipient_profiles" TO "anon", "authenticated", "service_role";
GRANT ALL ON SEQUENCE "public"."recipient_profiles_id_seq" TO "anon", "authenticated", "service_role";
