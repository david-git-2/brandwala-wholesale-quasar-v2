-- Shipment AP drafts: list under parent scope; child brands can SELECT AP on parent books.

DROP POLICY IF EXISTS "global_invoices_select" ON "public"."bills";

CREATE POLICY "global_invoices_select" ON "public"."bills" FOR SELECT TO "authenticated" USING ((
  public.has_active_tenant_membership(issued_by_tenant_id)
  OR public.user_can_manage_parent_tenant(parent_tenant_id)
  OR (
    invoice_type = 'ap'::public.global_invoice_type
    AND (
      public.membership_has_module_action(parent_tenant_id, 'global_invoice', 'view')
      OR EXISTS (
        SELECT 1
        FROM public.tenants ct
        INNER JOIN public.memberships m ON m.tenant_id = ct.id
        WHERE ct.parent_id = bills.parent_tenant_id
          AND public.membership_email_matches_current_user(m.email)
          AND m.is_active = true
          AND public.membership_has_module_action(ct.id, 'global_invoice', 'view')
      )
    )
  )
));
