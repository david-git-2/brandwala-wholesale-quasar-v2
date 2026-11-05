BEGIN;

SELECT plan(7);

SELECT has_function('public', 'next_document_number', ARRAY['bigint', 'text', 'text', 'timestamp with time zone']);
SELECT has_function('public', 'peek_document_number', ARRAY['bigint', 'text', 'text', 'timestamp with time zone']);

WITH new_tenant AS (
  INSERT INTO public.tenants (name, slug, is_active)
  VALUES ('DocNum Test', 'docnum-' || substr(md5(random()::text), 1, 8), true)
  RETURNING id
)
SELECT ok(
  public.next_document_number(new_tenant.id, 'shop_order', NULL, now()) ~ '^SO-[0-9]{6}-[0-9]{4}$',
  'shop_order format'
)
FROM new_tenant;

WITH new_tenant AS (
  INSERT INTO public.tenants (name, slug, is_active)
  VALUES ('DocNum Peek', 'docpeek-' || substr(md5(random()::text), 1, 8), true)
  RETURNING id
),
first_no AS (
  SELECT public.next_document_number(new_tenant.id, 'shop_order', NULL, now()) AS n1
  FROM new_tenant
),
peek_no AS (
  SELECT public.peek_document_number(new_tenant.id, 'shop_order', NULL, now()) AS p
  FROM new_tenant
),
second_no AS (
  SELECT public.next_document_number(new_tenant.id, 'shop_order', NULL, now()) AS n2
  FROM new_tenant
)
SELECT is(
  (SELECT p FROM peek_no),
  (SELECT n2 FROM second_no),
  'peek matches the next consumed number'
);

WITH new_tenant AS (
  INSERT INTO public.tenants (name, slug, is_active)
  VALUES ('DocNum Inv', 'docinv-' || substr(md5(random()::text), 1, 8), true)
  RETURNING id
)
SELECT ok(
  public.generate_sales_invoice_number(new_tenant.id, 'wholesale'::public.global_invoice_type, current_date)
    ~ '^INV-WS-[0-9]{4}-[0-9]{4}$',
  'sales invoice format'
)
FROM new_tenant;

WITH new_tenant AS (
  INSERT INTO public.tenants (name, slug, is_active)
  VALUES ('DocNum AP', 'docap-' || substr(md5(random()::text), 1, 8), true)
  RETURNING id
)
SELECT ok(
  public.generate_sales_invoice_number(new_tenant.id, 'ap'::public.global_invoice_type, current_date)
    ~ '^AP-[0-9]{4}-[0-9]{4}$',
  'ap bill format'
)
FROM new_tenant;

SELECT ok(
  (
    SELECT prosrc LIKE '%next_document_number%'
      AND prosrc NOT LIKE '%sales_invoice_counters%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'generate_sales_invoice_number'
  ),
  'generate_sales_invoice_number delegates to document numbering'
);

SELECT ok(
  (
    SELECT prosrc LIKE '%next_document_number%'
      AND prosrc NOT LIKE '%random()%'
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'generate_shop_order_number'
  ),
  'generate_shop_order_number uses document numbering'
);

SELECT finish();
ROLLBACK;
