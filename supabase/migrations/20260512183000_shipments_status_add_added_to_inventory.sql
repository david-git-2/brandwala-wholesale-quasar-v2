begin;

alter table public.shipments
  drop constraint if exists shipments_status_check;

alter table public.shipments
  add constraint shipments_status_check
  check (
    status in (
      'Draft',
      'Order Placed',
      'Proforma Generated',
      'Payment Done',
      'Delivery Date Received',
      'Uk Warehouse Delivery Received',
      'Air Shipment Date Set',
      'Airport Arrival',
      'Airport Released',
      'Warehouse Received',
      'Added to Inventory'
    )
  );

commit;
