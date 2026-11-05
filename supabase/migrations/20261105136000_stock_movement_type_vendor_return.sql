-- post_stock_movement (20261105120100) and RTV RPCs reference vendor_return; enum label was never added.

ALTER TYPE public.stock_movement_type ADD VALUE IF NOT EXISTS 'vendor_return';
