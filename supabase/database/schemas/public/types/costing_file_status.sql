CREATE TYPE public.costing_file_status AS ENUM (
  'draft',
  'customer_submitted',
  'in_review',
  'priced',
  'offered',
  'accepted',
  'po_placed',
  'cancelled',
  'completed'
);