import { computed } from 'vue';

export const useInvoiceWorkspace = () => {
  const kind = computed(() => 'parent' as const);
  const isParentTenant = computed(() => true);
  const isDeskView = computed(() => false);

  return { kind, isParentTenant, isDeskView };
};
