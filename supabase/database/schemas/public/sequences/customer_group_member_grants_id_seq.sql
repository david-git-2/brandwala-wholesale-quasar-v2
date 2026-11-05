CREATE SEQUENCE public.customer_group_member_grants_id_seq;

GRANT ALL ON SEQUENCE public.customer_group_member_grants_id_seq TO anon;

GRANT ALL ON SEQUENCE public.customer_group_member_grants_id_seq TO authenticated;

GRANT ALL ON SEQUENCE public.customer_group_member_grants_id_seq TO service_role;