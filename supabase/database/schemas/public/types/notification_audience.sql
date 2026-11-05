CREATE TYPE public.notification_audience AS ENUM (
  'child_only',
  'parent_only',
  'child_and_parent',
  'assignee_only'
);