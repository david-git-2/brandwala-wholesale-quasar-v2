import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  billingProfileRepository,
  type CreateBillingProfileInput,
  type DeleteBillingProfileInput,
  type UpdateBillingProfileInput,
} from '../repositories/billingProfileRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import { tenantQueryKeys } from 'src/modules/tenant/shared/queryKeys/tenantQueryKeys';

export function useBillingProfileMutations() {
  const queryClient = useQueryClient();

  const createBillingProfileMutation = useMutation({
    mutationFn: (input: CreateBillingProfileInput) =>
      billingProfileRepository.createBillingProfile(input),
    onSuccess: (data) => {
      void queryClient.invalidateQueries({
        queryKey: salesInvoiceQueryKeys.billingProfiles(data.tenant_id),
      });
      if (data.tenant_id) {
        void queryClient.invalidateQueries({
          queryKey: tenantQueryKeys.customerGroups(data.tenant_id),
        });
      }
    },
  });

  const updateBillingProfileMutation = useMutation({
    mutationFn: (input: UpdateBillingProfileInput & { tenant_id?: number }) =>
      billingProfileRepository.updateBillingProfile({ id: input.id, patch: input.patch }),
    onSuccess: (data, variables) => {
      const tenantId = data.tenant_id || variables.tenant_id;
      if (tenantId) {
        void queryClient.invalidateQueries({
          queryKey: salesInvoiceQueryKeys.billingProfiles(tenantId),
        });
      } else {
        void queryClient.invalidateQueries({
          queryKey: salesInvoiceQueryKeys.root,
        });
      }
    },
  });

  const deleteBillingProfileMutation = useMutation({
    mutationFn: (input: DeleteBillingProfileInput & { tenant_id?: number }) =>
      billingProfileRepository.deleteBillingProfile({ id: input.id }),
    onSuccess: (_, variables) => {
      if (variables.tenant_id) {
        void queryClient.invalidateQueries({
          queryKey: salesInvoiceQueryKeys.billingProfiles(variables.tenant_id),
        });
      } else {
        void queryClient.invalidateQueries({
          queryKey: salesInvoiceQueryKeys.root,
        });
      }
    },
  });

  return {
    createBillingProfileMutation,
    updateBillingProfileMutation,
    deleteBillingProfileMutation,
  };
}
