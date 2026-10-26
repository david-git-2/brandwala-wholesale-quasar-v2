-- Add 'accepted' state to public.costing_file_status
alter type public.costing_file_status add value if not exists 'accepted' after 'offered';
