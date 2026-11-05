CREATE SEQUENCE public.activity_logs_id_seq;

GRANT ALL ON SEQUENCE public.activity_logs_id_seq TO anon;

GRANT ALL ON SEQUENCE public.activity_logs_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.activity_logs_id_seq TO service_role;