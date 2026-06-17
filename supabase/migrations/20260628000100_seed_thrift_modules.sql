-- =========================================================
-- Seed the master module catalog for Thrift Modules
-- =========================================================

begin;

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values
  (
    'thrift_category',
    'Thrift Category',
    'Manage classification categories for thrift stock items.',
    true
  ),
  (
    'thrift_type',
    'Thrift Type',
    'Manage product styles and classification types within the thrift catalog.',
    true
  ),
  (
    'thrift_shelf',
    'Thrift Shelf',
    'Track physical shelf storage and aisle locations in the warehouse.',
    true
  ),
  (
    'thrift_stock',
    'Thrift Stock',
    'Manage inventory stock items, brands, and quantities.',
    true
  ),
  (
    'thrift_pricing',
    'Thrift Pricing',
    'Track COGS, listed prices, and target pricing margins.',
    true
  ),
  (
    'thrift_invoice',
    'Thrift Invoice',
    'Handle invoicing, billing, split shipping, and customer charges.',
    true
  ),
  (
    'thrift_invoice_item',
    'Thrift Invoice Item',
    'Detail individual billing records and net profit tracking per invoice.',
    true
  ),
  (
    'thrift_accounting_ledger',
    'Thrift Accounting Ledger',
    'Record and audit revenue, expenses, and asset losses.',
    true
  )
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

commit;
