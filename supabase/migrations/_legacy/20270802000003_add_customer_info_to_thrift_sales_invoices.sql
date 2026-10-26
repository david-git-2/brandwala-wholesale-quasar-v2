-- Add customer_name and customer_phone to thrift_sales_invoices
ALTER TABLE public.thrift_sales_invoices
  ADD COLUMN IF NOT EXISTS customer_name TEXT NULL,
  ADD COLUMN IF NOT EXISTS customer_phone TEXT NULL;

COMMENT ON COLUMN public.thrift_sales_invoices.customer_name IS 'Customer full name for thrift invoice';
COMMENT ON COLUMN public.thrift_sales_invoices.customer_phone IS 'Customer phone number for thrift invoice';
