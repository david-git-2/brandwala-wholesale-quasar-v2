-- Enable RLS on dropship gift tables (Supabase linter 0013).

CREATE POLICY "shop_customer_stocks_superadmin_all" ON public.shop_customer_stocks
  USING (
    EXISTS (
      SELECT 1
      FROM public.memberships m
      WHERE lower(trim(both FROM m.email)) = public.current_user_email()
        AND m.role = 'superadmin'::public.app_role
        AND m.is_active = true
    )
  );

CREATE POLICY "shop_customer_stocks_staff_all" ON public.shop_customer_stocks
  USING (public.is_tenant_staff(tenant_id))
  WITH CHECK (public.is_tenant_staff(tenant_id));

ALTER TABLE public.shop_customer_stocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shop_auto_gift_items_superadmin_all" ON public.shop_auto_gift_items
  USING (
    EXISTS (
      SELECT 1
      FROM public.memberships m
      WHERE lower(trim(both FROM m.email)) = public.current_user_email()
        AND m.role = 'superadmin'::public.app_role
        AND m.is_active = true
    )
  );

CREATE POLICY "shop_auto_gift_items_staff_all" ON public.shop_auto_gift_items
  USING (public.is_tenant_staff(tenant_id))
  WITH CHECK (public.is_tenant_staff(tenant_id));

ALTER TABLE public.shop_auto_gift_items ENABLE ROW LEVEL SECURITY;
