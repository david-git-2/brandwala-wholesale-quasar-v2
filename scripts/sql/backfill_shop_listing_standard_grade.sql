-- Backfill shop_product_listings.grade_tag_id to warehouse "Standard" grade.
--
-- When to run:
--   • After backend:pull-prod-data / backend:restore-dumps (prod rows have NULL grade_tag_id)
--   • On production before deploying migrations 20270906140000+ (grade-based catalog)
--
-- How to run on production:
--   Supabase Dashboard → SQL Editor → New query → paste this file → Run
--
-- Safe to re-run: UPDATE only touches rows where grade_tag_id IS NULL.

-- ---------------------------------------------------------------------------
-- 1. Preview (optional — read-only)
-- ---------------------------------------------------------------------------
SELECT
  count(*) AS total_listings,
  count(*) FILTER (WHERE grade_tag_id IS NULL) AS null_grade_listings,
  public.default_stock_grade_tag_id() AS standard_grade_tag_id,
  (
    SELECT jsonb_build_object('id', t.id, 'slug', t.slug, 'name', t.name)
    FROM public.tags t
    WHERE t.id = public.default_stock_grade_tag_id()
  ) AS standard_grade_tag
FROM public.shop_product_listings;

-- ---------------------------------------------------------------------------
-- 2. Dedupe null-grade drafts (keep one row per shop + product)
-- ---------------------------------------------------------------------------
WITH ranked AS (
  SELECT
    l.id,
    row_number() OVER (
      PARTITION BY l.shop_id, l.product_id
      ORDER BY l.is_active DESC, l.id ASC
    ) AS rn
  FROM public.shop_product_listings l
  WHERE l.grade_tag_id IS NULL
)
DELETE FROM public.shop_product_listings spl
USING ranked r
WHERE spl.id = r.id
  AND r.rn > 1;

-- Drop null-grade row when a standard-grade listing already exists for same shop + product
DELETE FROM public.shop_product_listings l
WHERE l.grade_tag_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.shop_product_listings l2
    WHERE l2.shop_id = l.shop_id
      AND l2.product_id = l.product_id
      AND l2.grade_tag_id = public.default_stock_grade_tag_id()
  );

-- ---------------------------------------------------------------------------
-- 3. Backfill: assign Standard grade
-- ---------------------------------------------------------------------------
UPDATE public.shop_product_listings
SET
  grade_tag_id = public.default_stock_grade_tag_id(),
  updated_at = now()
WHERE grade_tag_id IS NULL;

-- ---------------------------------------------------------------------------
-- 4. Verify (optional — read-only)
-- ---------------------------------------------------------------------------
SELECT
  count(*) FILTER (WHERE grade_tag_id IS NULL) AS remaining_null_grade,
  count(*) AS total_listings
FROM public.shop_product_listings;

-- How many active listings would pass browse_shop_catalog_for_customer (grade-based RPC)
SELECT count(*) AS catalog_visible_listings
FROM public.shop_product_listings l
JOIN public.shops s ON s.id = l.shop_id
JOIN public.products p ON p.id = l.product_id
LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
WHERE l.is_active = true
  AND p.is_available = true
  AND coalesce(p.hazardous, false) = false
  AND coalesce(l.grade_tag_id, gs.grade_tag_id) IS NOT NULL
  AND (
    l.display_quantity_override IS NOT NULL AND l.display_quantity_override > 0
    OR public.shop_product_grade_available_units(
      s.tenant_id,
      p.id,
      coalesce(l.grade_tag_id, gs.grade_tag_id)
    ) > 0
  );

-- Listings still hidden (no display override and zero grade stock) — fix manually if needed
SELECT
  l.id AS listing_id,
  s.slug AS shop_slug,
  p.id AS product_id,
  p.name AS product_name,
  l.display_quantity_override,
  public.shop_product_grade_available_units(
    s.tenant_id,
    p.id,
    coalesce(l.grade_tag_id, gs.grade_tag_id)
  ) AS available_units
FROM public.shop_product_listings l
JOIN public.shops s ON s.id = l.shop_id
JOIN public.products p ON p.id = l.product_id
LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
WHERE l.is_active = true
  AND p.is_available = true
  AND coalesce(p.hazardous, false) = false
  AND coalesce(l.grade_tag_id, gs.grade_tag_id) IS NOT NULL
  AND NOT (
    l.display_quantity_override IS NOT NULL AND l.display_quantity_override > 0
    OR public.shop_product_grade_available_units(
      s.tenant_id,
      p.id,
      coalesce(l.grade_tag_id, gs.grade_tag_id)
    ) > 0
  )
ORDER BY l.id;
