-- Tenant wallet credits for Cash in report (credits only, by method).

create or replace function public.get_tenant_cash_in_report(
  p_tenant_id bigint,
  p_start_date timestamp with time zone default null,
  p_end_date timestamp with time zone default null
) returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
as $$
declare
  v_books_id bigint;
  v_cash_in numeric(18,4) := 0.0000;
  v_count integer := 0;
  v_by_method jsonb;
  v_entries jsonb;
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;

  select coalesce(t.parent_id, t.id)
  into v_books_id
  from public.tenants t
  where t.id = p_tenant_id;

  if v_books_id is null then
    raise exception 'Tenant not found';
  end if;

  if not (
    public.membership_has_module_action(p_tenant_id, 'universal_wallet', 'view')
    or public.membership_has_module_action(v_books_id, 'universal_wallet', 'view')
  ) then
    raise exception 'Not authorized';
  end if;

  with lined as (
    select
      l.id,
      l.amount,
      l.source_type,
      l.source_id,
      l.metadata,
      l.created_at,
      coalesce(
        nullif(trim(l.metadata->>'method'), ''),
        nullif(trim(gp.method), ''),
        'other'
      ) as method,
      nullif(l.metadata->>'label', '') as label,
      case
        when (l.metadata->>'invoice_id') ~ '^[0-9]+$' then (l.metadata->>'invoice_id')::bigint
        else null
      end as invoice_id
    from public.universal_wallet_ledger l
    left join public.global_payments gp
      on l.source_id ~ '^[0-9]+$'
     and gp.id = l.source_id::bigint
     and gp.tenant_id = v_books_id
    where l.tenant_id = v_books_id
      and l.entity_type = 'tenant'
      and l.entity_id = v_books_id
      and l.type = 'credit'
      and coalesce(l.metadata->>'purpose', '') <> 'apply_store_credit'
      and (p_start_date is null or l.created_at >= p_start_date)
      and (p_end_date is null or l.created_at <= p_end_date)
  )
  select
    coalesce(sum(amount), 0.0000),
    count(*)::integer,
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'method', m.method,
          'amount', m.amt,
          'count', m.cnt
        ) order by m.amt desc)
        from (
          select method, sum(amount) as amt, count(*)::integer as cnt
          from lined
          group by method
        ) m
      ),
      '[]'::jsonb
    ),
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'id', e.id,
          'amount', e.amount,
          'method', e.method,
          'source_type', e.source_type,
          'source_id', e.source_id,
          'label', e.label,
          'invoice_id', e.invoice_id,
          'created_at', e.created_at
        ) order by e.created_at desc, e.id desc)
        from lined e
      ),
      '[]'::jsonb
    )
  into v_cash_in, v_count, v_by_method, v_entries
  from lined;

  return jsonb_build_object(
    'tenant_id', v_books_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'cash_in_total', v_cash_in,
    'entry_count', v_count,
    'by_method', v_by_method,
    'entries', v_entries
  );
end;
$$;

alter function public.get_tenant_cash_in_report(bigint, timestamp with time zone, timestamp with time zone) owner to postgres;

grant execute on function public.get_tenant_cash_in_report(bigint, timestamp with time zone, timestamp with time zone) to authenticated, service_role;
