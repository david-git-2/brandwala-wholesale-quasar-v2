-- Consume still deletes the backlog row. Deleting the costing line used to
-- wipe leftover demand even when the quote was still pending/offered and
-- nothing had been ordered (accidental add-then-delete).
-- Restore from OLD when: no sibling line, file is a quote, ordered_qty = 0,
-- and open qty > 0. Confirmed-or-later files, or lines with ordered qty, still clear.

CREATE OR REPLACE FUNCTION public.trg_fn_auto_upsert_pbc_backlog()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_tenant_id bigint;
  v_other_id bigint;
  v_ordered_qty numeric;
  v_open_qty numeric;
  v_prod RECORD;
  v_price_gbp numeric;
  v_name text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.product_id IS NOT NULL AND OLD.product_based_costing_file_id IS NOT NULL THEN
      SELECT * INTO v_file
      FROM public.product_based_costing_files
      WHERE id = OLD.product_based_costing_file_id;

      IF v_file.id IS NOT NULL THEN
        v_tenant_id := v_file.tenant_id;
        IF v_tenant_id IS NULL AND v_file.billing_profile_id IS NOT NULL THEN
          SELECT tenant_id INTO v_tenant_id
          FROM public.billing_profiles
          WHERE id = v_file.billing_profile_id;
        END IF;

        SELECT pci.id INTO v_other_id
        FROM public.product_based_costing_items pci
        INNER JOIN public.product_based_costing_files pcf
          ON pcf.id = pci.product_based_costing_file_id
        WHERE pci.product_id = OLD.product_id
          AND pcf.billing_profile_id IS NOT DISTINCT FROM v_file.billing_profile_id
        ORDER BY pci.updated_at DESC NULLS LAST, pci.id DESC
        LIMIT 1;

        IF v_other_id IS NOT NULL THEN
          PERFORM public.upsert_pbc_backlog_from_item(v_other_id);
        ELSIF v_tenant_id IS NOT NULL AND v_file.billing_profile_id IS NOT NULL THEN
          v_ordered_qty := coalesce(OLD.ordered_quantity, 0);
          v_open_qty := coalesce(OLD.confirmed_quantity, OLD.quantity, 0) - v_ordered_qty;

          IF coalesce(v_file.status, 'pending') IN ('pending', 'offered')
             AND v_ordered_qty <= 0
             AND v_open_qty > 0
          THEN
            SELECT
              p.name,
              p.image_url,
              p.list_price_amount,
              p.product_weight,
              p.package_weight,
              p.barcode,
              p.product_code,
              gc.code AS list_price_currency_code
            INTO v_prod
            FROM public.products p
            LEFT JOIN public.global_currencies gc ON gc.id = p.list_price_currency_id
            WHERE p.id = OLD.product_id;

            v_name := coalesce(OLD.name, v_prod.name);
            v_price_gbp := coalesce(
              OLD.price_gbp,
              CASE
                WHEN v_prod.list_price_currency_code IS NULL OR v_prod.list_price_currency_code = 'GBP'
                  THEN v_prod.list_price_amount
                ELSE NULL
              END
            );

            IF v_name IS NOT NULL THEN
              INSERT INTO public.product_based_costing_backlog_items (
                tenant_id,
                billing_profile_id,
                product_id,
                open_quantity,
                name,
                image_url,
                barcode,
                product_code,
                price_gbp,
                product_weight,
                package_weight,
                last_costing_file_id,
                last_costing_item_id,
                updated_at
              )
              VALUES (
                v_tenant_id,
                v_file.billing_profile_id,
                OLD.product_id,
                round(v_open_qty)::integer,
                v_name,
                coalesce(OLD.image_url, v_prod.image_url),
                coalesce(OLD.barcode, v_prod.barcode),
                coalesce(OLD.product_code, v_prod.product_code),
                v_price_gbp,
                coalesce(OLD.product_weight::numeric, v_prod.product_weight),
                coalesce(OLD.package_weight::numeric, v_prod.package_weight),
                v_file.id,
                NULL,
                now()
              )
              ON CONFLICT (tenant_id, billing_profile_id, product_id)
              DO UPDATE SET
                open_quantity = EXCLUDED.open_quantity,
                name = EXCLUDED.name,
                image_url = EXCLUDED.image_url,
                barcode = EXCLUDED.barcode,
                product_code = EXCLUDED.product_code,
                price_gbp = EXCLUDED.price_gbp,
                product_weight = EXCLUDED.product_weight,
                package_weight = EXCLUDED.package_weight,
                last_costing_file_id = EXCLUDED.last_costing_file_id,
                last_costing_item_id = EXCLUDED.last_costing_item_id,
                updated_at = now();
            END IF;
          ELSE
            DELETE FROM public.product_based_costing_backlog_items
            WHERE tenant_id = v_tenant_id
              AND billing_profile_id = v_file.billing_profile_id
              AND product_id = OLD.product_id;
          END IF;
        END IF;
      END IF;
    END IF;

    RETURN OLD;
  END IF;

  PERFORM public.upsert_pbc_backlog_from_item(NEW.id);
  RETURN NEW;
END;
$$;
