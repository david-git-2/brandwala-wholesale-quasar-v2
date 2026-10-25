import { computed, type MaybeRefOrGetter, toValue } from 'vue';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useCourierServicesStore } from '../stores/courierServicesStore';

export function useDropshipCourierOptions(options: {
  tenantSlug: MaybeRefOrGetter<string | null>;
  orderTenantId?: MaybeRefOrGetter<number | null | undefined>;
}) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  const orderTenantId = computed(() => toValue(options.orderTenantId) ?? tenantId.value);

  const courierStore = useCourierServicesStore();
  const { couriers: allCouriers, loading } = storeToRefs(courierStore);

  const couriers = computed(() =>
    allCouriers.value.filter(
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
    couriersLoading: loading,
  };
}
