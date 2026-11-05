CREATE TYPE public.global_shipment_outcome_reason AS ENUM (
  'general',
  'vendor_discount',
  'missing',
  'damaged',
  'other',
  'ordered'
);