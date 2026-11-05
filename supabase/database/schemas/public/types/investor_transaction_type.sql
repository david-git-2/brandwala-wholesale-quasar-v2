CREATE TYPE public.investor_transaction_type AS ENUM (
  'deposit',
  'withdrawal',
  'profit_payout',
  'capital_in',
  'capital_adjustment',
  'withdrawal_paid',
  'profit_reinvest',
  'manual_adjustment'
);