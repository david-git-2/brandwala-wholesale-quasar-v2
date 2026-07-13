begin;

-- Correct the stock and allocation quantity mismatch for Vaseline Lip Therapy Rosy 20g Tin (Stock ID: 201)
-- that was caused by the incorrect self-healing stock adjustments in the previous migration.
update public.global_stocks
set quantity = greatest(quantity - 24, 0)
where id = 201;

update public.global_stock_allocations
set quantity = greatest(quantity - 24, 0)
where stock_id = 201;

commit;
