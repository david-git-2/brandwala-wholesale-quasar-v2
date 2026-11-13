import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { supabase } from 'src/boot/supabase';

export type DeskBillPartyOption = {
  id: number;
  name: string;
  profile_type: string;
};

export function useDeskBillPartyOptions(parentTenantId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => ['bills_pays', 'deskPartyOptions', parentTenantId.value ?? 0]),
    queryFn: async (): Promise<DeskBillPartyOption[]> => {
      const tid = parentTenantId.value;
      if (!tid) return [];
      const { data, error } = await supabase
        .from('profiles')
        .select('id, name, profile_type')
        .eq('tenant_id', tid)
        .eq('is_active', true)
        .is('deleted_at', null)
        .order('name', { ascending: true });
      if (error) throw error;
      return (data ?? []).map((row) => ({
        id: Number(row.id),
        name: String(row.name ?? ''),
        profile_type: String(row.profile_type ?? ''),
      }));
    },
    enabled: computed(() => (parentTenantId.value ?? 0) > 0),
    staleTime: 5 * 60_000,
  });
}
