CREATE TYPE public.stock_location_kind AS ENUM (
  'warehouse',
  'zone',
  'shelf',
  'level',
  'bin',
  'returns'
);