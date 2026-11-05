CREATE TYPE public.thrift_delivery_status AS ENUM (
  'PENDING',
  'SHIPPED',
  'DELIVERED',
  'RETURNED',
  'PARTIALLY_RETURNED'
);