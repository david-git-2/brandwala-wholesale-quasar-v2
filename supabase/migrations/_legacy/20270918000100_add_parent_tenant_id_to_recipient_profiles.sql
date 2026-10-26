-- Migration: 20270918000100_add_parent_tenant_id_to_recipient_profiles.sql
-- Add parent_tenant_id column to recipient_profiles with auto-population trigger and index

-- 1. Add parent_tenant_id column if not exists
ALTER TABLE "public"."recipient_profiles"
  ADD COLUMN IF NOT EXISTS "parent_tenant_id" bigint REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

-- 2. Backfill existing rows
UPDATE "public"."recipient_profiles" r
SET "parent_tenant_id" = COALESCE(t.parent_id, t.id, 15)
FROM "public"."tenants" t
WHERE r.tenant_id = t.id AND r.parent_tenant_id IS NULL;

UPDATE "public"."recipient_profiles"
SET "parent_tenant_id" = 15
WHERE "parent_tenant_id" IS NULL;

-- 3. Create index for parent_tenant_id queries
CREATE INDEX IF NOT EXISTS "recipient_profiles_parent_tenant_id_idx"
  ON "public"."recipient_profiles" USING btree ("parent_tenant_id");

-- 4. Attach trigger to keep parent_tenant_id synced
DROP TRIGGER IF EXISTS "trg_recipient_profiles_set_parent_tenant_id" ON "public"."recipient_profiles";
CREATE TRIGGER "trg_recipient_profiles_set_parent_tenant_id"
  BEFORE INSERT OR UPDATE OF "tenant_id" ON "public"."recipient_profiles"
  FOR EACH ROW EXECUTE FUNCTION "public"."set_parent_tenant_id_from_tenant"();
