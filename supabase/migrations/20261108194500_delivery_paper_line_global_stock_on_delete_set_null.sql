-- Dispatch (issue_outbound) deletes global_stocks rows at qty 0; lines keep history via snapshot.
ALTER TABLE public.delivery_paper_line
  DROP CONSTRAINT IF EXISTS delivery_paper_line_global_stock_id_fkey;

ALTER TABLE public.delivery_paper_line
  ADD CONSTRAINT delivery_paper_line_global_stock_id_fkey
  FOREIGN KEY (global_stock_id) REFERENCES public.global_stocks(id) ON DELETE SET NULL;
