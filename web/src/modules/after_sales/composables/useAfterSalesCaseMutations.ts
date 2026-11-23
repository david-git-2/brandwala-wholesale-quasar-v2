import { useMutation, useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { afterSalesRepositoryStub } from '../repositories/afterSalesRepository.stub';
import { afterSalesQueryKeys } from '../services/afterSalesQueryKeys';
import type { AfterSalesCaseStatus, AfterSalesPolicyProgram } from '../types/afterSales.types';

export function useAfterSalesPoliciesQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => afterSalesQueryKeys.policies(tenantId.value ?? 0)),
    queryFn: () => afterSalesRepositoryStub.listPolicies(tenantId.value!),
    enabled: computed(() => Boolean(tenantId.value)),
    staleTime: 60_000,
  });
}

export function useAfterSalesPolicyQuery(policyId: Ref<string | null | undefined>) {
  return useQuery({
    queryKey: computed(() => afterSalesQueryKeys.policy(policyId.value ?? '')),
    queryFn: () => afterSalesRepositoryStub.getPolicy(policyId.value!),
    enabled: computed(() => Boolean(policyId.value)),
    staleTime: 30_000,
  });
}

export function useSaveAfterSalesPolicyMutation(tenantId: Ref<number | null | undefined>) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (policy: AfterSalesPolicyProgram) =>
      afterSalesRepositoryStub.savePolicy(tenantId.value!, policy),
    onSuccess: (data) => {
      if (tenantId.value) {
        void queryClient.invalidateQueries({
          queryKey: afterSalesQueryKeys.policies(tenantId.value),
        });
      }
      void queryClient.invalidateQueries({ queryKey: afterSalesQueryKeys.policy(data.id) });
    },
  });
}

export function useUpsertAfterSalesPoliciesMutation(tenantId: Ref<number | null | undefined>) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (programs: AfterSalesPolicyProgram[]) =>
      afterSalesRepositoryStub.upsertPolicies(tenantId.value!, programs),
    onSuccess: (data) => {
      if (tenantId.value) {
        queryClient.setQueryData(afterSalesQueryKeys.policies(tenantId.value), data);
      }
    },
  });
}

export function useAfterSalesCaseQuery(caseId: Ref<string | null | undefined>) {
  return useQuery({
    queryKey: computed(() => afterSalesQueryKeys.case(caseId.value ?? '')),
    queryFn: () => afterSalesRepositoryStub.getCase(caseId.value!),
    enabled: computed(() => Boolean(caseId.value)),
    staleTime: 10_000,
  });
}

export function useAfterSalesCaseByInvoiceQuery(invoiceId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => afterSalesQueryKeys.caseByInvoice(invoiceId.value ?? 0)),
    queryFn: () => afterSalesRepositoryStub.getCaseByInvoiceId(invoiceId.value!),
    enabled: computed(() => Boolean(invoiceId.value)),
    staleTime: 10_000,
  });
}

export function useAfterSalesCaseMutations(tenantId: Ref<number | null | undefined>) {
  const queryClient = useQueryClient();

  const invalidateAll = async (caseId?: string) => {
    if (tenantId.value) {
      await queryClient.invalidateQueries({ queryKey: ['after_sales', 'hub', tenantId.value] });
      await queryClient.invalidateQueries({ queryKey: ['after_sales', 'cases'] });
    }
    if (caseId) {
      await queryClient.invalidateQueries({ queryKey: afterSalesQueryKeys.case(caseId) });
    }
  };

  const approve = useMutation({
    mutationFn: (caseId: string) => afterSalesRepositoryStub.approveCase(caseId),
    onSuccess: (data) => void invalidateAll(data.id),
  });

  const reject = useMutation({
    mutationFn: (caseId: string) => afterSalesRepositoryStub.rejectCase(caseId),
    onSuccess: (data) => void invalidateAll(data.id),
  });

  const markReceived = useMutation({
    mutationFn: (caseId: string) => afterSalesRepositoryStub.markCaseReceived(caseId),
    onSuccess: (data) => void invalidateAll(data.id),
  });

  const advanceToExecuting = useMutation({
    mutationFn: (caseId: string) => afterSalesRepositoryStub.advanceCaseToExecuting(caseId),
    onSuccess: (data) => void invalidateAll(data.id),
  });

  const closeCase = useMutation({
    mutationFn: (caseId: string) => afterSalesRepositoryStub.closeCase(caseId),
    onSuccess: (data) => void invalidateAll(data.id),
  });

  const updateLines = useMutation({
    mutationFn: ({
      caseId,
      lines,
    }: {
      caseId: string;
      lines: Parameters<typeof afterSalesRepositoryStub.updateCaseLines>[1];
    }) => afterSalesRepositoryStub.updateCaseLines(caseId, lines),
    onSuccess: (data) => void invalidateAll(data.id),
  });

  const updateStatus = useMutation({
    mutationFn: ({ caseId, status }: { caseId: string; status: AfterSalesCaseStatus }) =>
      afterSalesRepositoryStub.updateCaseStatus(caseId, status),
    onSuccess: (data) => void invalidateAll(data.id),
  });

  return {
    approve,
    reject,
    markReceived,
    advanceToExecuting,
    closeCase,
    updateLines,
    updateStatus,
  };
}
