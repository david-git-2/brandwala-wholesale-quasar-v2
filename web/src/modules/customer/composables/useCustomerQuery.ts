import { useQuery, useMutation, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { customerRepository } from '../repositories/customerRepository';
import { customerQueryKeys } from '../services/customerQueryKeys';
import type {
  CreateCustomerInput,
  UpdateCustomerInput,
  CustomerGroupMemberCreateInput,
  CustomerGroupMemberUpdateInput,
} from '../types/customer';

export function useCustomerListQuery(
  tenantId: Ref<number | null | undefined>,
  search?: Ref<string | undefined>
) {
  return useQuery({
    queryKey: computed(() => customerQueryKeys.list(tenantId.value ?? null, search?.value)),
    queryFn: () => {
      if (!tenantId.value) return [];
      return customerRepository.listCustomers(tenantId.value, search?.value);
    },
    enabled: computed(() => !!tenantId.value),
    staleTime: 60 * 1000,
  });
}

export function useCustomerMembersQuery(customerGroupId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => customerQueryKeys.members(customerGroupId.value ?? null)),
    queryFn: () => {
      if (!customerGroupId.value) return [];
      return customerRepository.listCustomerMembers(customerGroupId.value);
    },
    enabled: computed(() => !!customerGroupId.value),
    staleTime: 30 * 1000,
  });
}

export function useCustomerMutations() {
  const queryClient = useQueryClient();

  const createCustomerMutation = useMutation({
    mutationFn: (input: CreateCustomerInput) => customerRepository.createCustomer(input),
    onSuccess: (newCustomer, variables) => {
      queryClient.setQueryData(
        customerQueryKeys.list(variables.tenant_id),
        (old: any[] = []) => [newCustomer, ...old]
      );
      void queryClient.invalidateQueries({
        queryKey: customerQueryKeys.root,
      });
    },
  });

  const updateCustomerMutation = useMutation({
    mutationFn: (input: UpdateCustomerInput) => customerRepository.updateCustomer(input),
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: customerQueryKeys.root,
      });
    },
  });

  const createMemberMutation = useMutation({
    mutationFn: (input: CustomerGroupMemberCreateInput) =>
      customerRepository.createCustomerMember(input),
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: customerQueryKeys.members(variables.customer_group_id),
      });
      void queryClient.invalidateQueries({
        queryKey: customerQueryKeys.root,
      });
    },
  });

  const updateMemberMutation = useMutation({
    mutationFn: (input: CustomerGroupMemberUpdateInput) =>
      customerRepository.updateCustomerMember(input),
    onSuccess: (_, variables) => {
      if (variables.customer_group_id) {
        void queryClient.invalidateQueries({
          queryKey: customerQueryKeys.members(variables.customer_group_id),
        });
      } else {
        void queryClient.invalidateQueries({
          queryKey: customerQueryKeys.root,
        });
      }
    },
  });

  const deleteMemberMutation = useMutation({
    mutationFn: (payload: { id: number; customer_group_id: number }) =>
      customerRepository.deleteCustomerMember(payload.id),
    onSuccess: (_, variables) => {
      void queryClient.invalidateQueries({
        queryKey: customerQueryKeys.members(variables.customer_group_id),
      });
      void queryClient.invalidateQueries({
        queryKey: customerQueryKeys.root,
      });
    },
  });

  return {
    createCustomerMutation,
    updateCustomerMutation,
    createMemberMutation,
    updateMemberMutation,
    deleteMemberMutation,
  };
}
