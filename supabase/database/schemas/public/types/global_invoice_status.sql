CREATE TYPE public.global_invoice_status AS ENUM (
  'draft',
  'proforma_generated',
  'issued',
  'voided'
);