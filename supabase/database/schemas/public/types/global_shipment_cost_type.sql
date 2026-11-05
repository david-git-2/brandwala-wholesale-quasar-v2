CREATE TYPE public.global_shipment_cost_type AS ENUM (
  'product',
  'cargo',
  'duty',
  'insurance',
  'labor',
  'washing',
  'transport',
  'handling',
  'local'
);