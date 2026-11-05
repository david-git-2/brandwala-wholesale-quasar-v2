CREATE TABLE public.customer_group_members (
  id                bigint                     DEFAULT nextval('public.customer_group_members_id_seq'::regclass) NOT NULL,
  customer_group_id bigint                     NOT NULL,
  name              text                       NOT NULL,
  email             text                       NOT NULL,
  role              public.customer_group_role NOT NULL,
  is_active         boolean                    DEFAULT true NOT NULL,
  added_by          bigint,
  created_at        timestamp with time zone   DEFAULT now() NOT NULL,
  updated_at        timestamp with time zone   DEFAULT now() NOT NULL,
  tenant_role_id    bigint
);

CREATE INDEX customer_group_members_email_idx ON public.customer_group_members (lower(TRIM(BOTH FROM email)));

CREATE INDEX customer_group_members_email_active_idx ON public.customer_group_members (lower(TRIM(BOTH FROM email)), is_active);

CREATE INDEX customer_group_members_tenant_role_id_idx ON public.customer_group_members (tenant_role_id);

CREATE UNIQUE INDEX customer_group_members_group_email_unique ON public.customer_group_members (customer_group_id, lower(TRIM(BOTH FROM email)));

CREATE INDEX customer_group_members_group_id_idx ON public.customer_group_members (customer_group_id);

CREATE TRIGGER trg_before_customer_member_insert
  BEFORE INSERT ON public.customer_group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_assign_default_customer_role();

CREATE TRIGGER trg_cgm_bump_version
  AFTER INSERT OR DELETE OR UPDATE ON public.customer_group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_bump_cgm_version();

CREATE TRIGGER trg_cgm_permission_guardrails
  BEFORE INSERT OR UPDATE ON public.customer_group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_cgm_permission_guardrails();

CREATE TRIGGER trg_cgm_sync_tenant_role
  BEFORE INSERT OR UPDATE ON public.customer_group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_sync_cgm_tenant_role();

CREATE TRIGGER trg_customer_group_members_email_rules
  BEFORE INSERT OR UPDATE ON public.customer_group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_customer_group_member_email_rules();

CREATE TRIGGER trg_customer_group_members_updated_at
  BEFORE UPDATE ON public.customer_group_members
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY customer_group_members_delete ON public.customer_group_members
  FOR DELETE
  TO authenticated
  USING (public.can_manage_customer_group_member(customer_group_id));

CREATE POLICY customer_group_members_insert ON public.customer_group_members
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_manage_customer_group_member(customer_group_id));

CREATE POLICY customer_group_members_select ON public.customer_group_members
  FOR SELECT
  TO authenticated
  USING (public.can_manage_customer_group_member(customer_group_id));

CREATE POLICY customer_group_members_update ON public.customer_group_members
  FOR UPDATE
  TO authenticated
  USING (public.can_manage_customer_group_member(customer_group_id))
  WITH CHECK (public.can_manage_customer_group_member(customer_group_id));

ALTER SEQUENCE public.customer_group_members_id_seq OWNED BY public.customer_group_members.id;

ALTER TABLE public.customer_group_members
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.customer_group_members
  ADD CONSTRAINT customer_group_members_pkey PRIMARY KEY (id);

ALTER TABLE public.customer_group_members
  ADD CONSTRAINT customer_group_members_customer_group_id_fkey FOREIGN KEY (customer_group_id) REFERENCES public.customer_groups(id) ON DELETE CASCADE;

ALTER TABLE public.customer_group_members
  ADD CONSTRAINT customer_group_members_tenant_role_id_fkey FOREIGN KEY (tenant_role_id) REFERENCES public.tenant_roles(id) ON DELETE RESTRICT;

GRANT ALL ON public.customer_group_members TO anon;

GRANT ALL ON public.customer_group_members TO authenticated;

GRANT ALL ON public.customer_group_members TO service_role;