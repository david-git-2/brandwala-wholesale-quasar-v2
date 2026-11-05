CREATE VIEW public.v_kernel_bill_summaries WITH (security_invoker=true) AS SELECT b.id AS bill_id,
    b.parent_tenant_id,
    b.issued_by_tenant_id,
    b.source_type,
    b.source_id,
    b.source_key,
    b.document_kind,
    b.invoice_type,
    b.invoice_no,
    b.invoice_date,
        CASE
            WHEN (b.invoice_status = 'voided'::public.global_invoice_status) THEN 'voided'::text
            WHEN (b.invoice_status = ANY (ARRAY['draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status])) THEN 'draft'::text
            WHEN (b.invoice_status = 'issued'::public.global_invoice_status) THEN 'issued'::text
            ELSE 'draft'::text
        END AS lifecycle_status,
    b.payment_status AS settlement_status,
    COALESCE(b.txn_currency_code, b.currency_code, 'BDT'::text) AS txn_currency_code,
    COALESCE(b.txn_total_amount, b.total_amount) AS txn_total_amount,
    COALESCE(b.currency_code, 'BDT'::text) AS currency_code,
    b.total_amount,
        CASE
            WHEN ((b.document_kind = 'standard'::public.bill_document_kind) AND (b.invoice_status = 'issued'::public.global_invoice_status)) THEN COALESCE(oc.open_books, b.due_amount, (0)::numeric)
            ELSE COALESCE(b.due_amount, (0)::numeric)
        END AS open_books,
        CASE
            WHEN ((b.document_kind = 'standard'::public.bill_document_kind) AND (b.invoice_status = 'issued'::public.global_invoice_status)) THEN COALESCE(oc.open_txn, oc.open_books, b.due_amount, (0)::numeric)
            ELSE COALESCE(b.due_amount, (0)::numeric)
        END AS open_txn,
    b.due_date,
    b.from_profile_id,
    b.to_profile_id,
    b.profile_id,
    b.parent_bill_id
   FROM (public.bills b
     LEFT JOIN LATERAL public._kernel_bill_open_components(COALESCE(b.parent_bill_id, b.id)) oc(credits_issued, debits_issued, settled_books, open_books, open_txn, credit_open) ON (true));

GRANT ALL ON public.v_kernel_bill_summaries TO anon;

GRANT ALL ON public.v_kernel_bill_summaries TO authenticated;

GRANT ALL ON public.v_kernel_bill_summaries TO service_role;