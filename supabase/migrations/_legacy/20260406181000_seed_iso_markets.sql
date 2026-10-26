-- =========================================================
-- Seed ISO markets (system managed)
-- =========================================================

insert into public.markets (id, name, code, is_active, is_system, region)
values
  (1, 'United States', 'US', true, true, 'North America'),
  (2, 'United Kingdom', 'GB', true, true, 'Europe'),
  (3, 'Canada', 'CA', true, true, 'North America'),
  (4, 'Australia', 'AU', true, true, 'Oceania'),
  (5, 'Germany', 'DE', true, true, 'Europe'),
  (6, 'France', 'FR', true, true, 'Europe'),
  (7, 'Italy', 'IT', true, true, 'Europe'),
  (8, 'Spain', 'ES', true, true, 'Europe'),
  (9, 'Netherlands', 'NL', true, true, 'Europe'),
  (10, 'Sweden', 'SE', true, true, 'Europe'),

  (11, 'Bangladesh', 'BD', true, true, 'South Asia'),
  (12, 'India', 'IN', true, true, 'South Asia'),
  (13, 'Pakistan', 'PK', true, true, 'South Asia'),
  (14, 'China', 'CN', true, true, 'East Asia'),
  (15, 'Japan', 'JP', true, true, 'East Asia'),
  (16, 'South Korea', 'KR', true, true, 'East Asia'),
  (17, 'Singapore', 'SG', true, true, 'Southeast Asia'),
  (18, 'Malaysia', 'MY', true, true, 'Southeast Asia'),
  (19, 'Indonesia', 'ID', true, true, 'Southeast Asia'),
  (20, 'Thailand', 'TH', true, true, 'Southeast Asia'),
  (21, 'Vietnam', 'VN', true, true, 'Southeast Asia'),
  (22, 'Philippines', 'PH', true, true, 'Southeast Asia'),

  (23, 'United Arab Emirates', 'AE', true, true, 'Middle East'),
  (24, 'Saudi Arabia', 'SA', true, true, 'Middle East'),
  (25, 'Qatar', 'QA', true, true, 'Middle East'),
  (26, 'Kuwait', 'KW', true, true, 'Middle East'),
  (27, 'Oman', 'OM', true, true, 'Middle East'),
  (28, 'Bahrain', 'BH', true, true, 'Middle East'),

  (29, 'South Africa', 'ZA', true, true, 'Africa'),
  (30, 'Nigeria', 'NG', true, true, 'Africa'),
  (31, 'Kenya', 'KE', true, true, 'Africa'),
  (32, 'Egypt', 'EG', true, true, 'Africa'),
  (33, 'Morocco', 'MA', true, true, 'Africa'),

  (34, 'Poland', 'PL', true, true, 'Europe'),
  (35, 'Belgium', 'BE', true, true, 'Europe'),
  (36, 'Switzerland', 'CH', true, true, 'Europe'),
  (37, 'Austria', 'AT', true, true, 'Europe'),
  (38, 'Denmark', 'DK', true, true, 'Europe'),
  (39, 'Norway', 'NO', true, true, 'Europe'),
  (40, 'Finland', 'FI', true, true, 'Europe'),
  (41, 'Ireland', 'IE', true, true, 'Europe'),
  (42, 'Portugal', 'PT', true, true, 'Europe'),
  (43, 'Czech Republic', 'CZ', true, true, 'Europe'),

  (44, 'Mexico', 'MX', true, true, 'North America'),
  (45, 'Brazil', 'BR', true, true, 'South America'),
  (46, 'Argentina', 'AR', true, true, 'South America'),
  (47, 'Chile', 'CL', true, true, 'South America'),
  (48, 'Colombia', 'CO', true, true, 'South America'),
  (49, 'Peru', 'PE', true, true, 'South America')
on conflict (id) do update
set
  name = excluded.name,
  code = excluded.code,
  is_active = excluded.is_active,
  is_system = excluded.is_system,
  region = excluded.region;

select setval(
  'public.markets_id_seq',
  (select coalesce(max(id), 1) from public.markets),
  true
);
