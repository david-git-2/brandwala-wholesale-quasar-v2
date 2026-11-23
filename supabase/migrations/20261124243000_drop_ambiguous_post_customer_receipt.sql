-- record_dropship_courier_remittance: disambiguate post_customer_receipt_with_allocations overload.

DROP FUNCTION IF EXISTS public.post_customer_receipt_with_allocations(
  bigint,
  bigint,
  date,
  text,
  text,
  text,
  jsonb,
  jsonb,
  bigint,
  text,
  numeric,
  numeric
);

DROP FUNCTION IF EXISTS public.post_customer_receipt_with_allocations(
  bigint,
  bigint,
  date,
  text,
  text,
  text,
  jsonb,
  jsonb,
  bigint,
  text,
  numeric,
  numeric,
  boolean,
  text
);