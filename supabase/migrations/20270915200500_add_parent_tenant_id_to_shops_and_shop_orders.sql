-- Migration: Add nullable parent_tenant_id to shops and shop_orders

-- 1. Add parent_tenant_id column to shops
ALTER TABLE "public"."shops"
  ADD COLUMN IF NOT EXISTS "parent_tenant_id" bigint REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

-- 2. Add parent_tenant_id column to shop_orders
ALTER TABLE "public"."shop_orders"
  ADD COLUMN IF NOT EXISTS "parent_tenant_id" bigint REFERENCES "public"."tenants"("id") ON DELETE SET NULL;

-- 3. Backfill existing rows from tenants.parent_id
UPDATE "public"."shops" s
SET "parent_tenant_id" = t.parent_id
FROM "public"."tenants" t
WHERE s.tenant_id = t.id AND t.parent_id IS NOT NULL AND s.parent_tenant_id IS NULL;

UPDATE "public"."shop_orders" o
SET "parent_tenant_id" = t.parent_id
FROM "public"."tenants" t
WHERE o.tenant_id = t.id AND t.parent_id IS NOT NULL AND o.parent_tenant_id IS NULL;

-- 4. Create trigger function to auto-populate parent_tenant_id from tenant_id
CREATE OR REPLACE FUNCTION "public"."set_shop_parent_tenant_id"() RETURNS "trigger"
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_parent_id bigint;
begin
  if new.tenant_id is not null then
    select parent_id into v_parent_id
    from public.tenants
    where id = new.tenant_id;

    new.parent_tenant_id := v_parent_id;
  else
    new.parent_tenant_id := null;
  end if;
  return new;
end;
$$;

ALTER FUNCTION "public"."set_shop_parent_tenant_id"() OWNER TO "postgres";

-- 5. Attach triggers to shops and shop_orders
DROP TRIGGER IF EXISTS "trg_shops_set_parent_tenant_id" ON "public"."shops";
CREATE TRIGGER "trg_shops_set_parent_tenant_id"
  BEFORE INSERT OR UPDATE OF "tenant_id" ON "public"."shops"
  FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_parent_tenant_id"();

DROP TRIGGER IF EXISTS "trg_shop_orders_set_parent_tenant_id" ON "public"."shop_orders";
CREATE TRIGGER "trg_shop_orders_set_parent_tenant_id"
  BEFORE INSERT OR UPDATE OF "tenant_id" ON "public"."shop_orders"
  FOR EACH ROW EXECUTE FUNCTION "public"."set_shop_parent_tenant_id"();

-- 6. Indexes for parent_tenant_id queries
CREATE INDEX IF NOT EXISTS "idx_shops_parent_tenant_id" ON "public"."shops" USING btree ("parent_tenant_id");
CREATE INDEX IF NOT EXISTS "idx_shop_orders_parent_tenant_id" ON "public"."shop_orders" USING btree ("parent_tenant_id");
CREATE INDEX IF NOT EXISTS "idx_shop_orders_parent_tenant_created_at" ON "public"."shop_orders" USING btree ("parent_tenant_id", "created_at" DESC);
