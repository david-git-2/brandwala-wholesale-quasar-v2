CREATE TYPE public.thrift_stock_status AS ENUM (
  'AVAILABLE',
  'OUT_OF_STOCK',
  'DAMAGED',
  'STOLEN',
  'SOLD',
  'RESERVED'
);