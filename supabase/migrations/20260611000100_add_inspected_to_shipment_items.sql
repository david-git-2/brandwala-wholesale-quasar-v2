-- Migration: Add inspected column to shipment_items
alter table public.shipment_items add column if not exists inspected boolean not null default false;
