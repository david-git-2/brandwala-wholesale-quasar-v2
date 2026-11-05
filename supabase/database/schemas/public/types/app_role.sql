CREATE TYPE public.app_role AS ENUM (
  'superadmin',
  'admin',
  'owner',
  'staff',
  'viewer',
  'investor',
  'manager',
  'cashier'
);