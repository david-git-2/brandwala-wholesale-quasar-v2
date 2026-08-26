import { computed, type MaybeRefOrGetter, toValue } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { dropshipCourierRepository } from '../repositories/dropshipCourierRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useDropshipCourierOptions(options: {
  tenantSlug: MaybeRefOrGetter<string | null>;
  orderTenantId?: MaybeRefOrGetter<number | null | undefined>;
}) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  const tenantSlug = computed(() => toValue(options.tenantSlug));
  const orderTenantId = computed(() => toValue(options.orderTenantId) ?? tenantId.value);

  const couriersQuery = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.couriers(tenantSlug.value)),
    enabled: computed(() => tenantId.value > 0),
    staleTime: 60_000,
    queryFn: () => dropshipCourierRepository.listCouriers(),
  });

  const couriers = computed(() =>
    (couriersQuery.data.value ?? []).filter(
      (courier) =>
        courier.is_active &&
        (courier.tenant_id == null || courier.tenant_id === orderTenantId.value),
    ),
  );

  const courierOptions = computed(() =>
    couriers.value.map((courier) => ({ label: courier.name, value: courier.id })),
  );

  return {
    couriers,
    courierOptions,
    couriersQuery,
  };
}
