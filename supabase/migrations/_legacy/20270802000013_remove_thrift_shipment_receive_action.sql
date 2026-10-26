-- Remove unused thrift_shipment.receive action (never wired in UI/RLS).

begin;

delete from public.system_role_templates
where module_key = 'thrift_shipment'
  and action = 'receive';

delete from public.tenant_role_grants
where module_key = 'thrift_shipment'
  and action = 'receive';

delete from public.membership_grants
where module_key = 'thrift_shipment'
  and action = 'receive';

update public.module_actions
set is_active = false
where module_key = 'thrift_shipment'
  and action = 'receive';

commit;
