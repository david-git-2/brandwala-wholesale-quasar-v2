import { useQuery } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import type { MaybeRefOrGetter } from 'vue';
import { toValue } from 'vue';

export const useAppBootstrapQuery = (
  email: MaybeRefOrGetter<string | null | undefined>,
  tenantId: MaybeRefOrGetter<number | null | undefined>,
  membershipId?: MaybeRefOrGetter<number | null | undefined>,
) => {
  return useQuery({
    queryKey: ['app-bootstrap', () => toValue(tenantId), () => toValue(membershipId)],
    queryFn: async () => {
      const emailVal = toValue(email);
      const tenantIdVal = toValue(tenantId);
      const membershipIdVal = toValue(membershipId);

      if (!emailVal || !tenantIdVal) {
        return null;
      }

      const { data, error } = await supabase.rpc('get_app_bootstrap_context', {
        p_email: emailVal,
        p_tenant_id: tenantIdVal,
        p_membership_id: membershipIdVal ?? undefined,
      });

      if (error) {
        throw error;
      }

      return Array.isArray(data) ? data[0] : data;
    },
    enabled: () => Boolean(toValue(email) && toValue(tenantId)),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000,   // 30 minutes
    refetchOnWindowFocus: true,
  });
};
