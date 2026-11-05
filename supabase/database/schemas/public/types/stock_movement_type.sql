CREATE TYPE public.stock_movement_type AS ENUM (
  'receive_putaway',
  'location_transfer',
  'availability_transfer',
  'adjustment',
  'return_inbound',
  'receive_rollback',
  'grade_change',
  'issue_outbound',
  'vendor_return'
);