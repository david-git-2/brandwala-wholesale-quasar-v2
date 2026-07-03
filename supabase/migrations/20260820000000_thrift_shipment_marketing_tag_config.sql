alter table public.thrift_shipments
  add column if not exists marketing_tag_config jsonb not null
  default '{
    "brand_name": "",
    "show_logo": true,
    "show_brand_name": true,
    "show_listed_sell": true,
    "show_core_sizes": true,
    "show_additional_sizes": true,
    "show_barcode_text": true
  }'::jsonb;

comment on column public.thrift_shipments.marketing_tag_config is
  'Per-shipment marketing sticker layout: shop brand and field visibility.';
