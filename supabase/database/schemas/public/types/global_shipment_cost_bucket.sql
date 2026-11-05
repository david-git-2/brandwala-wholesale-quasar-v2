CREATE TYPE public.global_shipment_cost_bucket AS ENUM (
  'material',
  'freight',
  'customs',
  'handling',
  'finance',
  'other'
);