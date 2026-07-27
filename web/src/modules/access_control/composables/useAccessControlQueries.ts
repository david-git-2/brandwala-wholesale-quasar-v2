import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { accessControlQueryKeys } from '../shared/queryKeys/accessControlQueryKeys';
import { accessControlRepository } from '../repositories/accessControlRepository';

const STALE_5_MIN = 5 * 60 * 1000;

export function useTenantModulesQuery(tenantId: Ref<number | null>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => accessControlQueryKeys.tenantModules(tenantId.value || 0)),
    queryFn: () => accessControlRepository.fetchTenantModules(tenantId.value!),
    enabled: computed(() => enabled.value && !!tenantId.value),
    staleTime: STALE_5_MIN,
  });
}

export function useCatalogModulesQuery(enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => accessControlQueryKeys.catalogModules()),
    queryFn: () => accessControlRepository.fetchCatalogModules(),
    enabled,
    staleTime: STALE_5_MIN,
  });
}

export function useTenantRolesQuery(
  tenantId: Ref<number | null>,
  scope: Ref<'app' | 'shop'>,
  enabled: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() =>
      accessControlQueryKeys.tenantRoles(tenantId.value || 0, scope.value),
    ),
    queryFn: () => accessControlRepository.fetchTenantRoles(tenantId.value!, scope.value),
    enabled: computed(() => enabled.value && !!tenantId.value),
    staleTime: STALE_5_MIN,
  });
}

export function useMemberOverrideIdsQuery(tenantId: Ref<number | null>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => accessControlQueryKeys.memberOverrideIds(tenantId.value || 0)),
    queryFn: () => accessControlRepository.fetchMembershipOverrideIds(tenantId.value!),
    enabled: computed(() => enabled.value && !!tenantId.value),
    staleTime: STALE_5_MIN,
  });
}

export function useTenantMembersQuery(tenantId: Ref<number | null>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => accessControlQueryKeys.tenantMembers(tenantId.value || 0)),
    queryFn: () => accessControlRepository.fetchTenantMembers(tenantId.value!),
    enabled: computed(() => enabled.value && !!tenantId.value),
    staleTime: STALE_5_MIN,
  });
}

export function useCustomerGroupsQuery(tenantId: Ref<number | null>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => accessControlQueryKeys.customerGroups(tenantId.value || 0)),
    queryFn: () => accessControlRepository.fetchCustomerGroups(tenantId.value!),
    enabled: computed(() => enabled.value && !!tenantId.value),
    staleTime: STALE_5_MIN,
  });
}

export function useCustomerGroupMembersQuery(groupId: Ref<number | null>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => accessControlQueryKeys.customerGroupMembers(groupId.value || 0)),
    queryFn: () => accessControlRepository.fetchCustomerGroupMembers(groupId.value!),
    enabled: computed(() => enabled.value && !!groupId.value),
    staleTime: STALE_5_MIN,
  });
}

export function useBillingProfilesQuery(tenantId: Ref<number | null>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => accessControlQueryKeys.billingProfiles(tenantId.value || 0)),
    queryFn: () => accessControlRepository.fetchBillingProfiles(tenantId.value!),
    enabled: computed(() => enabled.value && !!tenantId.value),
    staleTime: STALE_5_MIN,
  });
}

export function useInvestorsQuery(enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => accessControlQueryKeys.investors()),
    queryFn: () => accessControlRepository.fetchInvestors(),
    enabled,
    staleTime: STALE_5_MIN,
  });
}

export function useCgmOverrideIdsQuery(groupId: Ref<number | null>, enabled: Ref<boolean>) {
  return useQuery({
    queryKey: computed(() => accessControlQueryKeys.cgmOverrideIds(groupId.value || 0)),
    queryFn: () => accessControlRepository.fetchCgmOverrideIds(groupId.value!),
    enabled: computed(() => enabled.value && !!groupId.value),
    staleTime: STALE_5_MIN,
  });
}
