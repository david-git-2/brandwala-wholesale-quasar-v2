-- Add grade_change to stock_movement_type enum
alter type public.stock_movement_type add value if not exists 'grade_change';
