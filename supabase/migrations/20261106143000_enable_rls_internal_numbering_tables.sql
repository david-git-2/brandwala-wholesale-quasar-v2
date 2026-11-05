-- Numbering/counter tables: SECURITY DEFINER RPCs only; block PostgREST direct access.

ALTER TABLE public.document_number_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_number_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_scoped_counters ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.document_number_configs FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.document_number_counters FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.tenant_scoped_counters FROM PUBLIC, anon, authenticated;

GRANT ALL ON TABLE public.document_number_configs TO service_role;
GRANT ALL ON TABLE public.document_number_counters TO service_role;
GRANT ALL ON TABLE public.tenant_scoped_counters TO service_role;
