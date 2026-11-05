CREATE TYPE public.global_shipment_cost_component AS ENUM (
  'subtotal',
  'carriage',
  'vat_tax',
  'misc'
);