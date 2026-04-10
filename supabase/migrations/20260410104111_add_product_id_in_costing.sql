-- 1. Add the column (nullable)
ALTER TABLE product_based_costing_items
ADD COLUMN product_id BIGINT NULL;

-- 2. Add foreign key constraint
ALTER TABLE product_based_costing_items
ADD CONSTRAINT fk_product_based_costing_items_product
FOREIGN KEY (product_id)
REFERENCES products(id)
ON UPDATE CASCADE
ON DELETE SET NULL;