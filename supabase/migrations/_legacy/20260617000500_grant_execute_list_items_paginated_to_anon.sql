-- Migration to grant execute on list_items_paginated to anon and service_role
grant execute on function public.list_items_paginated(
  bigint,
  integer,
  integer,
  text,
  text,
  text,
  text,
  text,
  text,
  boolean,
  bigint,
  text,
  timestamptz,
  timestamptz
) to anon, service_role;
