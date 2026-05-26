-- Migration: add koba_wholesale module entry
-- Run after initial schema and any existing module seeds
INSERT INTO public.modules (key, name, description, is_active)
VALUES ('koba_wholesale', 'Koba Wholesale', 'Browse scraped Koba Wholesale products catalog.', true);
