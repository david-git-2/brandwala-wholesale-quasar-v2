-- Allow tenant available_balance to go negative (Pay / settle_shipment_payee overdraft).
-- Vendor, cargo_company, and other entity wallets stay >= 0.

ALTER TABLE public.wallet_accounts
  DROP CONSTRAINT IF EXISTS wallet_accounts_available_non_negative;

ALTER TABLE public.wallet_accounts
  ADD CONSTRAINT wallet_accounts_available_non_negative
  CHECK (available_balance >= 0 OR entity_type = 'tenant');
