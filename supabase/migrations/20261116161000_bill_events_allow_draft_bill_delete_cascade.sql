-- Draft bill hard-delete: ON DELETE CASCADE from bills must purge bill_events
-- when money.allow_kernel_delete is set (shipment AP void / desk draft delete).

CREATE OR REPLACE FUNCTION money_kernel.fn_bill_events_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF TG_OP = 'DELETE'
     AND current_setting('money.allow_kernel_delete', true) = '1' THEN
    RETURN OLD;
  END IF;

  RAISE EXCEPTION
    'bill_events is append-only; cannot UPDATE or DELETE row id=%', OLD.id;
END;
$$;