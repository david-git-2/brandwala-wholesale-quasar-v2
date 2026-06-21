begin;

alter table public.thrift_types
  add column if not exists icon text null;

-- Tenant default type
update public.thrift_types
set icon = 'category'
where name = 'General' and icon is null;

-- Global dress types (UK retail)
update public.thrift_types set icon = 'height' where is_global = true and name = 'Mini Dress' and icon is null;
update public.thrift_types set icon = 'woman' where is_global = true and name = 'Midi Dress' and icon is null;
update public.thrift_types set icon = 'nightlife' where is_global = true and name = 'Maxi Dress' and icon is null;
update public.thrift_types set icon = 'woman' where is_global = true and name = 'Midaxi Dress' and icon is null;
update public.thrift_types set icon = 'straighten' where is_global = true and name = 'Shift Dress' and icon is null;
update public.thrift_types set icon = 'checkroom' where is_global = true and name = 'Wrap Dress' and icon is null;
update public.thrift_types set icon = 'straighten' where is_global = true and name = 'Bodycon Dress' and icon is null;
update public.thrift_types set icon = 'straighten' where is_global = true and name = 'A-Line Dress' and icon is null;
update public.thrift_types set icon = 'straighten' where is_global = true and name = 'Fit and Flare Dress' and icon is null;
update public.thrift_types set icon = 'checkroom' where is_global = true and name = 'Shirt Dress' and icon is null;
update public.thrift_types set icon = 'straighten' where is_global = true and name = 'Skater Dress' and icon is null;
update public.thrift_types set icon = 'star' where is_global = true and name = 'Slip Dress' and icon is null;
update public.thrift_types set icon = 'woman' where is_global = true and name = 'Tea Dress' and icon is null;
update public.thrift_types set icon = 'checkroom' where is_global = true and name = 'Smock Dress' and icon is null;
update public.thrift_types set icon = 'checkroom' where is_global = true and name = 'Jumper Dress' and icon is null;
update public.thrift_types set icon = 'checkroom' where is_global = true and name = 'T-Shirt Dress' and icon is null;
update public.thrift_types set icon = 'star' where is_global = true and name = 'Cocktail Dress' and icon is null;
update public.thrift_types set icon = 'nightlife' where is_global = true and name = 'Evening Dress' and icon is null;
update public.thrift_types set icon = 'height' where is_global = true and name = 'Party Dress' and icon is null;
update public.thrift_types set icon = 'height' where is_global = true and name = 'Strappy Dress' and icon is null;
update public.thrift_types set icon = 'dry_cleaning' where is_global = true and name = 'Denim Dress' and icon is null;
update public.thrift_types set icon = 'checkroom' where is_global = true and name = 'Blazer Dress' and icon is null;
update public.thrift_types set icon = 'woman' where is_global = true and name = 'Swing Dress' and icon is null;
update public.thrift_types set icon = 'accessibility_new' where is_global = true and name = 'Off Shoulder Dress' and icon is null;

commit;
