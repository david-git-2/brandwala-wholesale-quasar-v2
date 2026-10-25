import { useMutation, useQueryClient } from '@tanstack/vue-query';
import {
  customerProfileRepository,
  type CreateCustomerProfileInput,
  type DeleteCustomerProfileInput,
  type UpdateCustomerProfileInput,
} from '../repositories/customerProfileRepository';
import { useCustomerProfileStore } from '../stores/customerProfileStore';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';
import { tenantQueryKeys } from 'src/modules/tenant/shared/queryKeys/tenantQueryKeys';

export function useCustomerProfileMutations() {
  const queryClient = useQueryClient();
  const customerProfileStore = useCustomerProfileStore();

  const createCustomerProfileMutation = useMutation({
    mutationFn: (input: CreateCustomerProfileInput) =>
      customerProfileRepository.createCustomerProfile(input),
    onSuccess: (data, variables) => {
      customerProfileStore.upsertInTenantCaches(data);
      void queryClient.invalidateQueries({
        queryKey: salesInvoiceQueryKeys.customerProfiles(variables.parent_tenant_id),
      });
      void queryClient.invalidateQueries({
        queryKey: tenantQueryKeys.customerGroups(variables.parent_tenant_id),
      });
    },
  });

  const updateCustomerProfileMutation = useMutation({
    mutationFn: (input: UpdateCustomerProfileInput & { tenant_id?: number }) =>
      customerProfileRepository.updateCustomerProfile({ id: input.id, patch: input.patch }),
    onSuccess: (data, variables) => {
      customerProfileStore.upsertInTenantCaches(data);
      const tenantId = variables.tenant_id;
      if (tenantId) {
        void queryClient.invalidateQueries({
          queryKey: salesInvoiceQueryKeys.customerProfiles(tenantId),
        });
      } else {
        void queryClient.invalidateQueries({
          queryKey: salesInvoiceQueryKeys.root,
        });
      }
    },
  });

  const deleteCustomerProfileMutation = useMutation({
    mutationFn: (input: DeleteCustomerProfileInput & { tenant_id?: number }) =>
      customerProfileRepository.deleteCustomerProfile({ id: input.id }),
    onSuccess: (_, variables) => {
      customerProfileStore.removeFromTenantCaches(variables.id);
      if (variables.tenant_id) {
        void queryClient.invalidateQueries({
          queryKey: salesInvoiceQueryKeys.customerProfiles(variables.tenant_id),
        });
      } else {
        void queryClient.invalidateQueries({
          queryKey: salesInvoiceQueryKeys.root,
        });
      }
    },
  });

  return {
    createCustomerProfileMutation,
    updateCustomerProfileMutation,
    deleteCustomerProfileMutation,
  };
}
