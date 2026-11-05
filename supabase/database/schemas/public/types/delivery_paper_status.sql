CREATE TYPE public.delivery_paper_status AS ENUM (
  'draft',
  'packed',
  'dispatched',
  'delivered',
  'cancelled'
);