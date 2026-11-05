CREATE TYPE public.stock_physical_count_status AS ENUM (
  'draft',
  'counting',
  'pending_approval',
  'posted',
  'cancelled'
);