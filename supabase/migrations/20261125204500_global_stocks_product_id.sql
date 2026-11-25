-- Denormalize product_id on global_stocks (sourced from global_shipment_items).

ALTER TABLE public.global_stocks
  ADD COLUMN IF NOT EXISTS product_id bigint;

UPDATE public.global_stocks gs
SET product_id = gsi.product_id
FROM public.global_shipment_items gsi
WHERE gsi.id = gs.shipment_item_id
  AND gs.product_id IS DISTINCT FROM gsi.product_id;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'global_stocks_product_id_fkey'
      AND conrelid = 'public.global_stocks'::regclass
  ) THEN
    ALTER TABLE public.global_stocks
      ADD CONSTRAINT global_stocks_product_id_fkey
      FOREIGN KEY (product_id) REFERENCES public.products (id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS global_stocks_product_id_idx
  ON public.global_stocks (product_id)
  WHERE product_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.trg_global_stocks_set_product_id()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_pid bigint;
BEGIN
  SELECT gsi.product_id
  INTO v_pid
  FROM public.global_shipment_items gsi
  WHERE gsi.id = NEW.shipment_item_id;

  NEW.product_id := v_pid;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_global_stocks_set_product_id ON public.global_stocks;
CREATE TRIGGER trg_global_stocks_set_product_id
  BEFORE INSERT OR UPDATE OF shipment_item_id
  ON public.global_stocks
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_global_stocks_set_product_id();

CREATE OR REPLACE FUNCTION public.trg_global_shipment_items_propagate_product_id()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.product_id IS DISTINCT FROM OLD.product_id THEN
    UPDATE public.global_stocks gs
    SET
      product_id = NEW.product_id,
      updated_at = now()
    WHERE gs.shipment_item_id = NEW.id
      AND gs.product_id IS DISTINCT FROM NEW.product_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_global_shipment_items_propagate_product_id ON public.global_shipment_items;
CREATE TRIGGER trg_global_shipment_items_propagate_product_id
  AFTER UPDATE OF product_id
  ON public.global_shipment_items
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_global_shipment_items_propagate_product_id();