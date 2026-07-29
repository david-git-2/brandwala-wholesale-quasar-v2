import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { customerGroupRepository } from '../repositories/customerGroupRepository';
import { tenantQueryKeys } from '../shared/queryKeys/tenantQueryKeys';
import type {
  CustomerGroupCreateInput,
  CustomerGroupDeleteInput,
  CustomerGroupUpdateInput,
} from '../types';

export function useCustomerGroupMutations() {
  const queryClient = useQueryClient();

  const createGroupMutation = useMutation({
    mutationFn: (input: CustomerGroupCreateInput) =>
      customerGroupRepository.createCustomerGroup(input),
    onSuccess: (data) => {
      void queryClient.invalidateQueries({
        queryKey: tenantQueryKeys.customerGroups(data.tenant_id),
      });
      void queryClient.invalidateQueries({
        queryKey: ['billing_profiles', data.tenant_id],
      });
    },
  });

  const updateGroupMutation = useMutation({
    mutationFn: (input: CustomerGroupUpdateInput & { email?: string | null; phone?: string | null; address?: string | null }) =>
      customerGroupRepository.updateCustomerGroup(input),
    onSuccess: (data) => {
      void queryClient.invalidateQueries({
        queryKey: tenantQueryKeys.customerGroups(data.tenant_id),
      });
      void queryClient.invalidateQueries({
        queryKey: ['billing_profiles', data.tenant_id],
      });
    },
  });

  const deleteGroupMutation = useMutation({
    mutationFn: (input: CustomerGroupDeleteInput & { tenant_id?: number }) =>
      customerGroupRepository.deleteCustomerGroup({ id: input.id }),
    onSuccess: (_, variables) => {
      if (variables.tenant_id) {
        void queryClient.invalidateQueries({
          queryKey: tenantQueryKeys.customerGroups(variables.tenant_id),
        });
        void queryClient.invalidateQueries({
          queryKey: ['billing_profiles', variables.tenant_id],
        });
      } else {
        void queryClient.invalidateQueries({
          queryKey: tenantQueryKeys.root,
        });
        void queryClient.invalidateQueries({
          queryKey: ['billing_profiles'],
        });
      }
    },
  });

  return {
    createGroupMutation,
    updateGroupMutation,
    deleteGroupMutation,
  };
}
