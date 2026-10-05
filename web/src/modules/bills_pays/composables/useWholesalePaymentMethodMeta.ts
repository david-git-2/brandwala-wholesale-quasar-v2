import { ref } from 'vue';
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';

export type WholesaleMethodOption = {
  label: string;
  value: string;
  code: string;
  category: string;
};

export function useWholesalePaymentMethodMeta(defaultMethodCode = 'cash') {
  const loadingPaymentMeta = ref(false);
  const methodOptions = ref<WholesaleMethodOption[]>([]);
  const bdBankOptions = ref<Array<{ label: string; value: number }>>([]);

  const loadPaymentMeta = async (ensureMethod: (code: string) => void) => {
    loadingPaymentMeta.value = true;
    try {
      const [methods, banks] = await Promise.all([
        globalReferenceRepository.listPaymentMethods(),
        globalReferenceRepository.listBdBanks(),
      ]);
      methodOptions.value = methods
        .filter((m) => m.scope === 'bd' || m.scope === 'both')
        .sort((a, b) => a.sort_order - b.sort_order)
        .map((m) => ({
          label: m.name,
          value: m.code.toLowerCase(),
          code: m.code.toUpperCase(),
          category: m.category,
        }));
      if (!methodOptions.value.some((m) => m.value === defaultMethodCode)) {
        const fallback =
          methodOptions.value.find((m) => m.value === 'cash')?.value ??
          methodOptions.value[0]?.value ??
          defaultMethodCode;
        ensureMethod(fallback);
      }
      bdBankOptions.value = banks
        .sort((a, b) => a.sort_order - b.sort_order)
        .map((b) => ({ label: b.name, value: b.id }));
    } finally {
      loadingPaymentMeta.value = false;
    }
  };

  return {
    loadingPaymentMeta,
    methodOptions,
    bdBankOptions,
    loadPaymentMeta,
  };
}
