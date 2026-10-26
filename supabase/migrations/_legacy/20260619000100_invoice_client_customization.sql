-- Migration to add customizable client_name and client_tr to invoices table

alter table public.invoices
  add column if not exists client_name text null,
  add column if not exists client_tr text null;
