-- BP3: retire billing_profiles; customer bill-to lives on profiles.

ALTER TYPE public.collection_source_type ADD VALUE IF NOT EXISTS 'profile';

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS customer_group_id bigint,
  ADD COLUMN IF NOT EXISTS operating_tenant_id bigint;

UPDATE public.profiles p
SET
  customer_group_id = bp.customer_group_id,
  operating_tenant_id = bp.tenant_id,
  accent_color = coalesce(p.accent_color, bp.color)
FROM public.billing_profiles bp
WHERE p.id = bp.id;

INSERT INTO public.profiles (
  id,
  parent_tenant_id,
  profile_type,
  subject_id,
  name,
  email,
  phone,
  phone_country_code,
  address,
  is_phone_unique,
  accent_color,
  is_active,
  customer_group_id,
  operating_tenant_id,
  created_at,
  updated_at
)
OVERRIDING SYSTEM VALUE
SELECT
  bp.id,
  bp.parent_tenant_id,
  'customer'::public.profile_party_type,
  bp.id,
  bp.name,
  bp.email,
  bp.phone,
  bp.phone_country_code,
  bp.address,
  bp.is_phone_unique,
  bp.color,
  true,
  bp.customer_group_id,
  bp.tenant_id,
  bp.created_at,
  bp.updated_at
FROM public.billing_profiles bp
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = bp.id);

-- shop_order
ALTER TABLE public.shop_orders DROP CONSTRAINT IF EXISTS shop_orders_billing_profile_id_fkey;
ALTER TABLE public.shop_orders RENAME COLUMN billing_profile_id TO profile_id;
ALTER TABLE public.shop_orders
  ADD CONSTRAINT shop_orders_profile_id_fkey
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.customer_demand_bucket_items DROP CONSTRAINT IF EXISTS customer_demand_bucket_items_billing_profile_id_fkey;
ALTER TABLE public.customer_demand_bucket_items RENAME COLUMN billing_profile_id TO profile_id;
ALTER TABLE public.customer_demand_bucket_items
  ADD CONSTRAINT customer_demand_bucket_items_profile_id_fkey
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.dropship_order_settlements DROP CONSTRAINT IF EXISTS dropship_order_settlements_billing_profile_id_fkey;
ALTER TABLE public.dropship_order_settlements RENAME COLUMN billing_profile_id TO profile_id;
ALTER TABLE public.dropship_order_settlements
  ADD CONSTRAINT dropship_order_settlements_profile_id_fkey
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- procurement
ALTER TABLE public.product_based_costing_backlog_items DROP CONSTRAINT IF EXISTS product_based_costing_backlog_items_billing_profile_id_fkey;
ALTER TABLE public.product_based_costing_backlog_items RENAME COLUMN billing_profile_id TO profile_id;
ALTER TABLE public.product_based_costing_backlog_items
  ADD CONSTRAINT product_based_costing_backlog_items_profile_id_fkey
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.product_based_costing_files DROP CONSTRAINT IF EXISTS product_based_costing_files_billing_profile_id_fkey;
ALTER TABLE public.product_based_costing_files RENAME COLUMN billing_profile_id TO profile_id;
ALTER TABLE public.product_based_costing_files
  ADD CONSTRAINT product_based_costing_files_profile_id_fkey
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- customer order backlog (public)
ALTER TABLE public.customer_order_backlog_items DROP CONSTRAINT IF EXISTS customer_order_backlog_items_billing_profile_id_fkey;
ALTER TABLE public.customer_order_backlog_items RENAME COLUMN billing_profile_id TO profile_id;
ALTER TABLE public.customer_order_backlog_items
  ADD CONSTRAINT customer_order_backlog_items_profile_id_fkey
  FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

DROP TRIGGER IF EXISTS trg_billing_profiles_admin_email_unique_per_tenant ON public.billing_profiles;
DROP TRIGGER IF EXISTS trg_billing_profiles_normalize_phone ON public.billing_profiles;
DROP TRIGGER IF EXISTS trg_billing_profiles_set_updated_at ON public.billing_profiles;
DROP TRIGGER IF EXISTS trg_billing_profiles_sync_parent_tenant ON public.billing_profiles;
DROP TRIGGER IF EXISTS trg_billing_profiles_sync_profile ON public.billing_profiles;
DROP TRIGGER IF EXISTS trg_customer_groups_auto_billing_profile ON public.customer_groups;

DROP TABLE IF EXISTS public.billing_profiles;

DROP SEQUENCE IF EXISTS public.billing_profiles_id_seq;

CREATE INDEX IF NOT EXISTS profiles_customer_group_id_idx
  ON public.profiles (customer_group_id)
  WHERE profile_type = 'customer'::public.profile_party_type;

CREATE INDEX IF NOT EXISTS profiles_operating_tenant_id_idx
  ON public.profiles (operating_tenant_id)
  WHERE profile_type = 'customer'::public.profile_party_type;

DROP INDEX IF EXISTS public.billing_profiles_parent_phone_uidx;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_customer_parent_phone_uidx
  ON public.profiles (parent_tenant_id, phone_country_code, phone)
  WHERE profile_type = 'customer'::public.profile_party_type
    AND phone IS NOT NULL
    AND btrim(phone) <> ''
    AND is_phone_unique;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_customer_group_id_fkey;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_customer_group_id_fkey
  FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE CASCADE;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_operating_tenant_id_fkey;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_operating_tenant_id_fkey
  FOREIGN KEY (operating_tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

DROP FUNCTION IF EXISTS public.billing_profile_valid_for_issuer(bigint, bigint);
DROP FUNCTION IF EXISTS public.resolve_billing_profile_for_customer_group(bigint, bigint);
DROP FUNCTION IF EXISTS public.trg_sync_profile_from_billing_profile();
DROP FUNCTION IF EXISTS public.trg_auto_create_billing_profile_for_customer_group();
DROP FUNCTION IF EXISTS public.trg_billing_profiles_normalize_phone();
DROP FUNCTION IF EXISTS public.trg_billing_profiles_sync_parent_tenant();
DROP FUNCTION IF EXISTS public.enforce_billing_profile_admin_email_unique_per_tenant();
