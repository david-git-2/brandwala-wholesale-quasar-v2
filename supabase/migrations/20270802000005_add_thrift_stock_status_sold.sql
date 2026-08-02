-- Migration: Add SOLD to thrift_stock_status
-- Must run in its own transaction so the new enum value is usable by later migrations.

ALTER TYPE public.thrift_stock_status ADD VALUE IF NOT EXISTS 'SOLD';
