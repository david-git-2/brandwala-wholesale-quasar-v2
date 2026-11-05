CREATE TABLE public.memberships (
  id             bigint                   DEFAULT nextval('public.memberships_id_seq'::regclass) NOT NULL,
  tenant_id      bigint,
  role           public.app_role          NOT NULL,
  is_active      boolean                  DEFAULT true NOT NULL,
  created_at     timestamp with time zone DEFAULT now() NOT NULL,
  updated_at     timestamp with time zone DEFAULT now() NOT NULL,
  email          text                     NOT NULL,
  accent_color   text,
  preference     jsonb                    DEFAULT '{}'::jsonb NOT NULL,
  investor_id    bigint,
  tenant_role_id bigint
);

CREATE UNIQUE INDEX memberships_email_tenant_unique ON public.memberships (lower(TRIM(BOTH FROM email)), COALESCE(tenant_id, '-1'::integer::bigint));

CREATE INDEX memberships_tenant_role_id_idx ON public.memberships (tenant_role_id);

CREATE UNIQUE INDEX memberships_one_active_owner_per_tenant_idx ON public.memberships (tenant_id)
  WHERE ROLE = 'owner'::public.app_role AND is_active = true;

CREATE INDEX memberships_role_idx ON public.memberships (ROLE);

CREATE UNIQUE INDEX memberships_superadmin_email_unique ON public.memberships (lower(TRIM(BOTH FROM email)))
  WHERE ROLE = 'superadmin'::public.app_role AND tenant_id IS NULL;

CREATE INDEX memberships_email_idx ON public.memberships (lower(TRIM(BOTH FROM email)));

CREATE INDEX memberships_tenant_id_idx ON public.memberships (tenant_id);

CREATE TRIGGER trg_before_membership_insert
  BEFORE INSERT ON public.memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_assign_default_membership_role();

CREATE TRIGGER trg_memberships_bump_version
  AFTER INSERT OR DELETE OR UPDATE ON public.memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_bump_membership_version();

CREATE TRIGGER trg_memberships_guard_update
  BEFORE UPDATE ON public.memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_membership_update();

CREATE TRIGGER trg_memberships_normalize_email
  BEFORE INSERT OR UPDATE OF email ON public.memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.normalize_membership_email();

CREATE TRIGGER trg_memberships_owner_placement
  BEFORE INSERT OR UPDATE OF ROLE, tenant_id ON public.memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_memberships_owner_placement();

CREATE TRIGGER trg_memberships_permission_guardrails
  BEFORE INSERT OR UPDATE ON public.memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_memberships_permission_guardrails();

CREATE TRIGGER trg_memberships_updated_at
  BEFORE UPDATE ON public.memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY memberships_delete ON public.memberships
  FOR DELETE
  TO authenticated
  USING (public.can_update_membership_row(tenant_id, ROLE));

CREATE POLICY memberships_insert ON public.memberships
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_assign_membership_role(tenant_id, role));

CREATE POLICY memberships_select ON public.memberships
  FOR SELECT
  TO authenticated
  USING ((public.is_superadmin() OR public.has_active_tenant_membership(tenant_id)));

CREATE POLICY memberships_select_own ON public.memberships
  FOR SELECT
  TO authenticated
  USING ((lower(TRIM(BOTH FROM email)) = public.current_user_email()));

CREATE POLICY memberships_update ON public.memberships
  FOR UPDATE
  TO authenticated
  USING (public.can_update_membership_row(tenant_id, ROLE))
  WITH CHECK (public.can_assign_membership_role(tenant_id, role));

ALTER SEQUENCE public.memberships_id_seq OWNED BY public.memberships.id;

ALTER TABLE public.memberships
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.memberships
  ADD CONSTRAINT memberships_investor_id_fkey FOREIGN KEY (investor_id) REFERENCES public.investors(id) ON DELETE SET NULL;

ALTER TABLE public.memberships
  ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);

ALTER TABLE public.memberships
  ADD CONSTRAINT memberships_role_tenant_check CHECK (role = 'superadmin'::public.app_role AND tenant_id IS NULL OR role <> 'superadmin'::public.app_role AND tenant_id IS NOT NULL);

ALTER TABLE public.memberships
  ADD CONSTRAINT memberships_tenant_role_id_fkey FOREIGN KEY (tenant_role_id) REFERENCES public.tenant_roles(id) ON DELETE RESTRICT;

ALTER TABLE public.memberships
  ADD CONSTRAINT memberships_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;

GRANT ALL ON public.memberships TO anon;

GRANT ALL ON public.memberships TO authenticated;

GRANT ALL ON public.memberships TO service_role;