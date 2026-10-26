-- Add owner to app_role (separate migration so later SQL can cast to it).
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'owner' AFTER 'admin';
