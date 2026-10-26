-- batch_code_lists: one row per shipment; drop name and vendor_id.

DELETE FROM public.batch_code_lists WHERE shipment_id IS NULL;

ALTER TABLE public.batch_code_lists
  DROP CONSTRAINT IF EXISTS batch_code_lists_vendor_id_fkey;

DROP INDEX IF EXISTS public.batch_code_lists_vendor_idx;

ALTER TABLE public.batch_code_lists
  DROP COLUMN IF EXISTS vendor_id,
  DROP COLUMN IF EXISTS name;

ALTER TABLE public.batch_code_lists
  ALTER COLUMN shipment_id SET NOT NULL;

DROP INDEX IF EXISTS public.batch_code_lists_shipment_id_key;

CREATE UNIQUE INDEX batch_code_lists_shipment_id_key
  ON public.batch_code_lists USING btree (shipment_id);
