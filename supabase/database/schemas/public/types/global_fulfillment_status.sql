CREATE TYPE public.global_fulfillment_status AS ENUM (
  'pending',
  'packed',
  'shipped',
  'delivered'
);