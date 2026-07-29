import { useMutation, useQueryClient } from '@tanstack/vue-query';
import { customerGroupRepository } from '../repositories/customerGroupRepository';
import { tenantQueryKeys } from '../shared/queryKeys/tenantQueryKeys';
import { salesInvoiceQueryKeys } from 'src/modules/sales_invoice/services/salesInvoiceQueryKeys';
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
        queryKey: salesInvoiceQueryKeys.root,
      });
    },
  });

  const createAndLinkGroupMutation = useMutation({
    mutationFn: (input: {
      billing_profile_id: number;
      tenant_id: number;
      name: string;
      email?: string | null;
      phone?: string | null;
      address?: string | null;
      color?: string | null;
    }) => customerGroupRepository.createAndLinkToBillingProfile(input),
    onSuccess: (data) => {
      void queryClient.invalidateQueries({
        queryKey: tenantQueryKeys.customerGroups(data.tenant_id),
      });
      void queryClient.invalidateQueries({
        queryKey: salesInvoiceQueryKeys.root,
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
        queryKey: salesInvoiceQueryKeys.root,
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
          queryKey: salesInvoiceQueryKeys.root,
        });
      } else {
        void queryClient.invalidateQueries({
          queryKey: tenantQueryKeys.root,
        });
        void queryClient.invalidateQueries({
          queryKey: salesInvoiceQueryKeys.root,
        });
      }
    },
  });

  return {
    createGroupMutation,
    createAndLinkGroupMutation,
    updateGroupMutation,
    deleteGroupMutation,
  };
}

