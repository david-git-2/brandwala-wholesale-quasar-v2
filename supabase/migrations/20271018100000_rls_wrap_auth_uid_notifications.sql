-- Perf: evaluate auth.uid() once per query instead of once per row in notification RLS policies.
do $$
declare
  r record;
  v_using text;
  v_check text;
  v_sql text;
begin
  for r in
    select schemaname, tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and tablename in (
        'user_push_subscriptions',
        'notification_recipients',
        'user_notification_preferences',
        'notification_delivery_log'
      )
      and (
        (qual ~ 'auth\.uid\(\)' and qual !~ 'SELECT auth\.uid\(\)')
        or (with_check ~ 'auth\.uid\(\)' and with_check !~ 'SELECT auth\.uid\(\)')
      )
  loop
    v_sql := format('alter policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
    if r.qual is not null then
      v_using := replace(r.qual, 'auth.uid()', '(select auth.uid())');
      v_sql := v_sql || format(' using (%s)', v_using);
    end if;
    if r.with_check is not null then
      v_check := replace(r.with_check, 'auth.uid()', '(select auth.uid())');
      v_sql := v_sql || format(' with check (%s)', v_check);
    end if;
    execute v_sql;
  end loop;
end $$;
