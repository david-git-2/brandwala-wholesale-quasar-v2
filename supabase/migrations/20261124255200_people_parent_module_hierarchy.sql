-- Group people/party submodules under the parent module `people`.
UPDATE public.modules
SET parent_module_key = 'people'
WHERE key IN (
  'customer',
  'billing_profile',
  'recipient_profile',
  'vendor',
  'investor_capital',
  'investor_profiles',
  'investor_capital_ledger',
  'investor_shipment_share',
  'investor_portal'
)
AND EXISTS (SELECT 1 FROM public.modules WHERE key = 'people');
