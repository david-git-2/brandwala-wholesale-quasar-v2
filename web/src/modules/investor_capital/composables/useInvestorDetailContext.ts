import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { storeToRefs } from 'pinia';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useInvestorCapitalStore } from '../stores/investorCapitalStore';
import type { Investor, InvestorBalance } from '../types';

export const useInvestorDetailContext = () => {
  const route = useRoute();
  const router = useRouter();
  const authStore = useAuthStore();
  const capitalStore = useInvestorCapitalStore();
  const { investors, loadingInvestors, error } = storeToRefs(capitalStore);

  const investorId = computed(() => Number(route.params.id));
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const investor = computed<InvestorBalance | null>(() => {
    const id = investorId.value;
    if (!Number.isFinite(id) || id <= 0) {
      return null;
    }
    return investors.value.find((row) => row.investor_id === id) ?? null;
  });

  const investorAsProfile = computed<Investor | null>(() => {
    const row = investor.value;
    const tid = tenantId.value;
    if (!row || tid <= 0) {
      return null;
    }

    return {
      id: row.investor_id,
      tenant_id: tid,
      name: row.name,
      phone: row.phone,
      email: row.email,
      address: row.address,
      is_active: row.is_active,
      currency_code: row.currency_code || 'BDT',
      notes: row.notes,
      created_at: '',
      updated_at: '',
    };
  });

  const ensureInvestorLoaded = async () => {
    if (tenantId.value <= 0) {
      return;
    }
    if (investors.value.length === 0 && !loadingInvestors.value) {
      await capitalStore.fetchInvestorsByTenant(tenantId.value);
    }
  };

  watch(
    tenantId,
    (tid) => {
      if (tid > 0) {
        void ensureInvestorLoaded();
      }
    },
    { immediate: true },
  );

  const goBackToList = () => {
    void router.push({
      name: 'app-capital-investors-page',
      params: { tenantSlug: authStore.tenantSlug || undefined },
    });
  };

  return {
    investorId,
    tenantId,
    investor,
    investorAsProfile,
    loadingInvestors,
    error,
    ensureInvestorLoaded,
    goBackToList,
  };
};
