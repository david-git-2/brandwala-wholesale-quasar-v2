-- Trigger to auto-upsert PBC backlog whenever a costing item is inserted, updated, or deleted
CREATE OR REPLACE FUNCTION public.trg_fn_auto_upsert_pbc_backlog()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.upsert_pbc_backlog_from_item(OLD.id);
    RETURN OLD;
  ELSE
    PERFORM public.upsert_pbc_backlog_from_item(NEW.id);
    RETURN NEW;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_pbc_items_auto_backlog ON public.product_based_costing_items;

CREATE TRIGGER trg_pbc_items_auto_backlog
AFTER INSERT OR UPDATE OF quantity, confirmed_quantity, ordered_quantity, product_id OR DELETE
ON public.product_based_costing_items
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_auto_upsert_pbc_backlog();
