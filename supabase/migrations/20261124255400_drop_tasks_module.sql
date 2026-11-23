-- Drop deprecated tasks module, its RPCs, and tasks-only tables.
DELETE FROM public.role_grants WHERE module_key = 'tasks';
DELETE FROM public.tenant_modules WHERE module_key = 'tasks';
DELETE FROM public.module_actions WHERE module_key = 'tasks';
DELETE FROM public.modules WHERE key = 'tasks';

DROP FUNCTION IF EXISTS public.get_tasks_dashboard_metrics(bigint) CASCADE;
DROP FUNCTION IF EXISTS public.global_search_tasks(text) CASCADE;
DROP FUNCTION IF EXISTS public.list_items_paginated(bigint, integer, integer, text, text, text, text, text, text, boolean, bigint, text, timestamp with time zone, timestamp with time zone) CASCADE;

DROP TABLE IF EXISTS public.item_assignees CASCADE;
DROP TABLE IF EXISTS public.item_tags CASCADE;
DROP TABLE IF EXISTS public.item_permissions CASCADE;
DROP TABLE IF EXISTS public.comments CASCADE;
DROP TABLE IF EXISTS public.activity_logs CASCADE;
DROP TABLE IF EXISTS public.items CASCADE;
