-- BP20: one active plug index only (uq_active_standard_bill in money spine)

DROP INDEX IF EXISTS public.bills_ap_shipment_kind_uidx;
DROP INDEX IF EXISTS public.bills_source_plug_uidx;
