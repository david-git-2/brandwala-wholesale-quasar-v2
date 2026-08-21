-- Migration: 20270831000120_rename_invoice_status_posted_to_issued.sql
-- Description: Standardize global_invoice_status enum from 'posted' to 'issued'

-- 1. Rename enum value in PostgreSQL
ALTER TYPE "public"."global_invoice_status" RENAME VALUE 'posted' TO 'issued';
