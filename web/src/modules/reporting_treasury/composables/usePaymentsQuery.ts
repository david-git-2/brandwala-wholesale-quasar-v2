import { ref, computed, watch, unref, type MaybeRef } from 'vue';
import { useQuery, useMutation, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { paymentsRepository } from '../repositories/paymentsRepository';
import { financeReportQueryKeys } from '../shared/queryKeys';
import type {
  BatchPaymentPayload,
  UpdateInstrumentDetailsPayload,
  VoidCustomerReceiptPayload,
} from '../types/paymentsTypes';

export function usePayments() {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const searchQuery = ref('');
  const debouncedSearch = ref('');

  let searchTimer: ReturnType<typeof setTimeout> | undefined;
  watch(searchQuery, (val) => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      debouncedSearch.value = val.trim();
    }, 300);
  });

  // 1. Customer Groups Summary Query
  const customerGroupsQuery = useQuery({
    queryKey: computed(() =>
      tenantId.value
        ? financeReportQueryKeys.customerGroupsSummary(tenantId.value, debouncedSearch.value)
        : financeReportQueryKeys.root,
    ),
    queryFn: () =>
      paymentsRepository.listCustomerGroupsPaymentSummary({
        tenantId: tenantId.value || 0,
        search: debouncedSearch.value || null,
      }),
    enabled: computed(() => Boolean(tenantId.value && tenantId.value > 0)),
    staleTime: 15_000,
  });

  // 2. Open Invoices Query
  const openInvoicesQuery = useQuery({
    queryKey: computed(() =>
      tenantId.value
        ? financeReportQueryKeys.openInvoicesPayment(tenantId.value, null, debouncedSearch.value)
        : financeReportQueryKeys.root,
    ),
    queryFn: () =>
      paymentsRepository.listOpenInvoicesForPayment({
        tenantId: tenantId.value || 0,
        search: debouncedSearch.value || null,
      }),
    enabled: computed(() => Boolean(tenantId.value && tenantId.value > 0)),
    staleTime: 15_000,
  });

  // Helper to fetch open invoices for a specific customer group on demand (e.g. for batch settlement modal)
  async function fetchGroupInvoices(customerGroupId: number) {
    if (!tenantId.value) return [];
    return paymentsRepository.listOpenInvoicesForPayment({
      tenantId: tenantId.value,
      customerGroupId,
    });
  }

  // 3. Record Batch / Single Payment Mutation
  const recordPaymentMutation = useMutation({
    mutationFn: (payload: BatchPaymentPayload) =>
      paymentsRepository.recordBatchCustomerPayment(payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: financeReportQueryKeys.root });
    },
  });

  function useCustomerGroupReceipts(customerGroupId: MaybeRef<number | null>) {
    const groupId = computed(() => unref(customerGroupId));
    return useQuery({
      queryKey: computed(() =>
        tenantId.value && groupId.value
          ? financeReportQueryKeys.customerGroupReceipts(tenantId.value, groupId.value)
          : financeReportQueryKeys.root,
      ),
      queryFn: () =>
        paymentsRepository.listCustomerGroupReceipts({
          tenantId: tenantId.value || 0,
          customerGroupId: groupId.value || 0,
        }),
      enabled: computed(() => Boolean(tenantId.value && groupId.value && groupId.value > 0)),
      staleTime: 10_000,
    });
  }

  const updateInstrumentMutation = useMutation({
    mutationFn: (payload: UpdateInstrumentDetailsPayload) =>
      paymentsRepository.updatePaymentInstrumentDetails(payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: financeReportQueryKeys.root });
    },
  });

  const voidReceiptMutation = useMutation({
    mutationFn: (payload: VoidCustomerReceiptPayload) =>
      paymentsRepository.voidCustomerReceipt(payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: financeReportQueryKeys.root });
    },
  });

  return {
    tenantId,
    searchQuery,
    debouncedSearch,
    customerGroups: computed(() => customerGroupsQuery.data.value ?? []),
    isCustomerGroupsLoading: customerGroupsQuery.isLoading,
    customerGroupsError: computed(() => (customerGroupsQuery.error.value as Error | null)?.message ?? null),

    openInvoices: computed(() => openInvoicesQuery.data.value ?? []),
    isOpenInvoicesLoading: openInvoicesQuery.isLoading,
    openInvoicesError: computed(() => (openInvoicesQuery.error.value as Error | null)?.message ?? null),

    fetchGroupInvoices,
    recordPayment: recordPaymentMutation.mutateAsync,
    isSubmittingPayment: recordPaymentMutation.isPending,
    useCustomerGroupReceipts,
    updateInstrumentDetails: updateInstrumentMutation.mutateAsync,
    isUpdatingInstrument: updateInstrumentMutation.isPending,
    voidCustomerReceipt: voidReceiptMutation.mutateAsync,
    isVoidingReceipt: voidReceiptMutation.isPending,

    refetchAll: () => {
      void customerGroupsQuery.refetch();
      void openInvoicesQuery.refetch();
    },
  };
}
