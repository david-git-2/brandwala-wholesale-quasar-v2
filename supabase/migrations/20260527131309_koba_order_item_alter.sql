ALTER TABLE koba_order_items 
  DROP COLUMN custom_price_gbp,
  ADD COLUMN confirmed_quantity INT DEFAULT NULL;