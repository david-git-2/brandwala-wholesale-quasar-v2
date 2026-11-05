CREATE TABLE public.costing_file_viewers (
  id               bigint                   DEFAULT nextval('public.costing_file_viewers_id_seq'::regclass) NOT NULL,
  costing_file_id  bigint                   NOT NULL,
  membership_id    bigint                   NOT NULL,
  created_by_email text                     DEFAULT public.current_user_email() NOT NULL,
  created_at       timestamp with time zone DEFAULT now() NOT NULL,
  updated_at       timestamp with time zone DEFAULT now() NOT NULL
);

CREATE INDEX costing_file_viewers_membership_id_idx ON public.costing_file_viewers (membership_id);

CREATE INDEX costing_file_viewers_costing_file_id_idx ON public.costing_file_viewers (costing_file_id);

CREATE TRIGGER trg_costing_file_viewers_updated_at
  BEFORE UPDATE ON public.costing_file_viewers
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY costing_file_viewers_delete ON public.costing_file_viewers
  FOR DELETE
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.costing_files cf
  WHERE ((cf.id = costing_file_viewers.costing_file_id) AND public.can_manage_costing_file_viewers(cf.tenant_id)))));

CREATE POLICY costing_file_viewers_insert ON public.costing_file_viewers
  FOR INSERT
  TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.costing_files cf
  WHERE ((cf.id = costing_file_viewers.costing_file_id) AND public.can_manage_costing_file_viewers(cf.tenant_id)))));

CREATE POLICY costing_file_viewers_select ON public.costing_file_viewers
  FOR SELECT
  TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM public.costing_files cf
  WHERE ((cf.id = costing_file_viewers.costing_file_id) AND public.can_manage_costing_file_viewers(cf.tenant_id)))));

ALTER SEQUENCE public.costing_file_viewers_id_seq OWNED BY public.costing_file_viewers.id;

ALTER TABLE public.costing_file_viewers
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.costing_file_viewers
  ADD CONSTRAINT costing_file_viewers_pkey PRIMARY KEY (id);

ALTER TABLE public.costing_file_viewers
  ADD CONSTRAINT costing_file_viewers_unique UNIQUE (costing_file_id, membership_id);

ALTER TABLE public.costing_file_viewers
  ADD CONSTRAINT costing_file_viewers_costing_file_id_fkey FOREIGN KEY (costing_file_id) REFERENCES public.costing_files(id) ON DELETE CASCADE;

ALTER TABLE public.costing_file_viewers
  ADD CONSTRAINT costing_file_viewers_membership_id_fkey FOREIGN KEY (membership_id) REFERENCES public.memberships(id) ON DELETE CASCADE;

GRANT ALL ON public.costing_file_viewers TO anon;

GRANT ALL ON public.costing_file_viewers TO authenticated;

GRANT ALL ON public.costing_file_viewers TO service_role;