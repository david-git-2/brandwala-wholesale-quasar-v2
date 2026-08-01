-- ============================================================================
-- GLOBAL REFERENCE SEEDER SQL SCRIPT
-- Seeds default system reference catalogs:
-- 1. markets
-- 2. global_currencies
-- 3. payment_methods
-- 4. units_of_measure
-- ============================================================================

-- 1. MARKETS
INSERT INTO public.markets (code, name, region, is_active, is_system)
VALUES
  ('BD_LOCAL', 'Bangladesh Local Market', 'ASIA', true, true),
  ('UK_MARKET', 'United Kingdom Market', 'EUROPE', true, true),
  ('US_MARKET', 'United States Market', 'NORTH_AMERICA', true, true),
  ('CN_MARKET', 'China Wholesale Market', 'ASIA', true, true),
  ('UAE_MARKET', 'UAE / Dubai Market', 'MIDDLE_EAST', true, true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  region = EXCLUDED.region,
  is_active = EXCLUDED.is_active,
  is_system = EXCLUDED.is_system;

-- 2. GLOBAL CURRENCIES
INSERT INTO public.global_currencies (code, name, symbol, country, is_active, is_system)
VALUES
  ('BDT', 'Bangladeshi Taka', '৳', 'Bangladesh', true, true),
  ('USD', 'US Dollar', '$', 'United States', true, true),
  ('GBP', 'British Pound', '£', 'United Kingdom', true, true),
  ('EUR', 'Euro', '€', 'Eurozone', true, true),
  ('RMB', 'Chinese Yuan', '¥', 'China', true, true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  symbol = EXCLUDED.symbol,
  country = EXCLUDED.country,
  is_active = EXCLUDED.is_active,
  is_system = EXCLUDED.is_system;

-- 3. PAYMENT METHODS
INSERT INTO public.payment_methods (code, name, category, scope, sort_order, is_active, is_system)
VALUES
  ('BKASH', 'bKash Mobile Wallet', 'bd_mobile_wallet', 'bd', 1, true, true),
  ('NAGAD', 'Nagad Mobile Wallet', 'bd_mobile_wallet', 'bd', 2, true, true),
  ('ROCKET', 'DBBL Rocket', 'bd_mobile_wallet', 'bd', 3, true, true),
  ('BANK_TRANSFER', 'Bank Transfer', 'bd_bank', 'both', 4, true, true),
  ('CASH', 'Cash Handover / COD', 'bd_cash', 'bd', 5, true, true),
  ('CARD', 'Credit / Debit Card', 'card', 'both', 6, true, true),
  ('WIRE_INTL', 'International Wire Transfer', 'international', 'international', 7, true, true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  scope = EXCLUDED.scope,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  is_system = EXCLUDED.is_system;

-- 4. UNITS OF MEASURE
INSERT INTO public.units_of_measure (code, name, unit_type, symbol, sort_order, is_active, is_system)
VALUES
  ('KG', 'Kilogram', 'weight', 'kg', 1, true, true),
  ('GRAM', 'Gram', 'weight', 'g', 2, true, true),
  ('PCS', 'Pieces', 'count', 'pcs', 3, true, true),
  ('PAIR', 'Pair', 'count', 'pr', 4, true, true),
  ('DOZEN', 'Dozen', 'count', 'dz', 5, true, true),
  ('MTR', 'Meter', 'length', 'm', 6, true, true),
  ('YRD', 'Yards', 'length', 'yd', 7, true, true),
  ('LTR', 'Litre', 'volume', 'l', 8, true, true),
  ('BOX', 'Box / Carton', 'packaging', 'box', 9, true, true),
  ('PACK', 'Pack', 'packaging', 'pk', 10, true, true)
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  unit_type = EXCLUDED.unit_type,
  symbol = EXCLUDED.symbol,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active,
  is_system = EXCLUDED.is_system;
