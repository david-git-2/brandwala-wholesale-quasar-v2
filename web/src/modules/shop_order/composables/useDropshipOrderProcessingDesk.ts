import { computed, onBeforeUnmount, ref, watch, type Ref } from 'vue';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { pickupLocationRepository } from '../repositories/pickupLocationRepository';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { ShopOrder, ShopOrderItem } from '../types';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import type { DropshipInvoiceSummaryState } from '../utils/dropshipInvoiceSummary';
import type {
  DropshipInvoiceCourierState,
  DropshipInvoicePickupState,
} from '../utils/dropshipInvoiceFulfillment';
import { isDropshipLineResolved } from '../utils/dropshipInvoiceFulfillment';
import { resolveDeliveryZone } from '../services/courierChargeEstimate';
import {
  showErrorNotification,
  showSuccessNotification,
  parseSupabaseError,
  requestConfirmation,
} from 'src/utils/appFeedback';

export function useDropshipOrderProcessingDesk(options: {
  tenantSlug: Ref<string | null>;
  orderId: Ref<number>;
  order: Ref<ShopOrder | null>;
  orderItems: Ref<ShopOrderItem[]>;
  summaryForm: Ref<DropshipInvoiceSummaryState>;
  pickupForm: DropshipInvoicePickupState;
  courierForm: DropshipInvoiceCourierState;
  couriers: Ref<CourierServiceRow[]>;
  canMarkReadyForPickup: Ref<boolean>;
  allLinesResolved: Ref<boolean>;
  totalDeliveredQty: Ref<number>;
  refetchOrderDetail: () => Promise<unknown>;
  formReady?: Ref<boolean>;
}) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();

  const saving = ref(false);
  const advancingStatus = ref(false);
  const autoSaveState = ref<'idle' | 'pending' | 'saved' | 'error'>('idle');

  let autoSaveTimer: ReturnType<typeof setTimeout> | undefined;
  let lastPersistedSnapshot = '';

  const tenantId = computed(() => authStore.tenantId ?? 0);

  const locationsQuery = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.pickupLocations(options.tenantSlug.value)),
    enabled: computed(() => tenantId.value > 0),
    staleTime: 60_000,
    queryFn: () => pickupLocationRepository.listLocations(),
  });

  const pickupLocationOptions = computed(() =>
    (locationsQuery.data.value ?? [])
      .filter((location) => location.is_active)
      .map((location) => ({
        label: `${location.location_name}${location.store_name ? ` (${location.store_name})` : ''} — ${location.phone_primary}`,
        value: location.id,
      })),
  );

  const pendingLineNames = computed(() =>
    options.orderItems.value
      .filter((item) => item.quantity > 0 && !isDropshipLineResolved(item))
      .map((item) => item.name),
  );

  const hasCourier = computed(() => Boolean(options.courierForm.courier_service_id));

  const hasPickupLocation = computed(() => {
    const pickup = options.pickupForm;
    return (
      Boolean(pickup.sender_name?.trim()) &&
      Boolean(pickup.pickup_phone?.trim()) &&
      Boolean(pickup.pickup_address?.trim())
    );
  });

  const allLinesResolvedLocal = computed(() => {
    const lines = options.orderItems.value.filter((item) => item.quantity > 0);
    if (lines.length === 0) return false;
    return lines.every((item) => isDropshipLineResolved(item));
  });

  const canAdvanceToReadyForPickup = computed(
    () =>
      options.canMarkReadyForPickup.value &&
      hasCourier.value &&
      hasPickupLocation.value &&
      allLinesResolvedLocal.value,
  );

  const readyForPickupBlockReason = computed(() => {
    if (!options.canMarkReadyForPickup.value) return null;
    if (!allLinesResolvedLocal.value) {
      return pendingLineNames.value.length
        ? `Pick stock or cancel: ${pendingLineNames.value.join(', ')}`
        : 'Pick stock or cancel every product.';
    }
    if (!hasPickupLocation.value) return 'Choose a pickup location (name, phone, and address).';
    if (!hasCourier.value) return 'Choose a courier.';
    return null;
  });

  const showNothingToShipBanner = computed(
    () => allLinesResolvedLocal.value && options.totalDeliveredQty.value <= 0,
  );

  const invalidateDetail = async () => {
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.dropshipDetailV2(tenantId.value, options.orderId.value),
    });
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.orderDetail(authStore.tenantId ?? null, options.orderId.value),
    });
    await options.refetchOrderDetail();
  };

  const serializeDeskForm = () =>
    JSON.stringify({
      summary: options.summaryForm.value,
      pickup: { ...options.pickupForm },
      courier: { ...options.courierForm },
    });

  const syncPersistedSnapshot = () => {
    lastPersistedSnapshot = serializeDeskForm();
    autoSaveState.value = 'saved';
  };

  const persistProcessingDesk = async (opts?: {
    silent?: boolean;
    skipRefetch?: boolean;
  }): Promise<boolean> => {
    const order = options.order.value;
    if (!order) return false;

    const snapshot = serializeDeskForm();
    if (snapshot === lastPersistedSnapshot) {
      autoSaveState.value = 'saved';
      return true;
    }

    saving.value = true;
    autoSaveState.value = 'pending';
    try {
      await shopOrderRepository.saveDropshipProcessingDesk({
        tenantId: tenantId.value,
        orderId: order.id,
        order,
        summary: options.summaryForm.value,
        pickup: { ...options.pickupForm },
        courier: { ...options.courierForm },
        deliveredQuantities: {},
        deliveryZone: resolveDeliveryZone(order.shipping_district ?? ''),
      });

      lastPersistedSnapshot = snapshot;
      autoSaveState.value = 'saved';

      if (!opts?.silent) {
        showSuccessNotification('Processing desk saved');
      }

      if (!opts?.skipRefetch) {
        await invalidateDetail();
      }

      return true;
    } catch (err) {
      autoSaveState.value = 'error';
      showErrorNotification(parseSupabaseError(err, 'Failed to save processing desk'));
      return false;
    } finally {
      saving.value = false;
    }
  };

  const scheduleAutoSave = () => {
    if (options.formReady && !options.formReady.value) return;

    const snapshot = serializeDeskForm();
    if (snapshot === lastPersistedSnapshot) return;

    autoSaveState.value = 'pending';
    if (autoSaveTimer) clearTimeout(autoSaveTimer);
    autoSaveTimer = setTimeout(() => {
      autoSaveTimer = undefined;
      void persistProcessingDesk({ silent: true, skipRefetch: true });
    }, 750);
  };

  watch(
    () => [
      options.summaryForm.value,
      { ...options.pickupForm },
      { ...options.courierForm },
      options.formReady?.value ?? true,
    ],
    () => {
      if (options.formReady && !options.formReady.value) return;
      scheduleAutoSave();
    },
    { deep: true },
  );

  watch(
    () => options.formReady?.value,
    (ready) => {
      if (ready) syncPersistedSnapshot();
    },
    { immediate: true },
  );

  onBeforeUnmount(() => {
    if (autoSaveTimer) clearTimeout(autoSaveTimer);
  });

  const advanceToReadyForPickup = async () => {
    const order = options.order.value;
    if (!order) return;

    if (!canAdvanceToReadyForPickup.value) {
      showErrorNotification(readyForPickupBlockReason.value || 'Ready for pickup is not available yet.');
      return;
    }

    const confirmed = await requestConfirmation(
      'Mark this order as ready for pickup? Picking and summary edits will be locked after this step.',
      'Ready for pickup',
      'Mark ready for pickup',
    );
    if (!confirmed) return;

    advancingStatus.value = true;
    try {
      const { data, error } = await supabase.rpc('advance_dropship_order_status', {
        p_order_id: order.id,
        p_target_status: 'ready_for_pickup',
      });
      if (error) throw error;
      if (data && typeof data === 'object' && (data as { success?: boolean }).success === false) {
        throw new Error((data as { error?: string }).error || 'Failed to update status');
      }

      showSuccessNotification('Status updated to ready for pickup');
      await invalidateDetail();
    } catch (err) {
      showErrorNotification(parseSupabaseError(err, 'Failed to mark ready for pickup'));
    } finally {
      advancingStatus.value = false;
    }
  };

  const onPickupLocationSelect = (pickupLocationId: string | null) => {
    if (!pickupLocationId) return;
    const location = (locationsQuery.data.value ?? []).find((row) => row.id === pickupLocationId);
    if (!location) return;
    options.pickupForm.pickup_location_id = pickupLocationId;
    options.pickupForm.sender_name = location.location_name;
    options.pickupForm.pickup_phone = location.phone_primary;
    options.pickupForm.pickup_address = location.pickup_address;
  };

  return {
    saving,
    advancingStatus,
    autoSaveState,
    pickupLocationOptions,
    pendingLineNames,
    hasCourier,
    hasPickupLocation,
    allLinesResolvedLocal,
    canAdvanceToReadyForPickup,
    readyForPickupBlockReason,
    showNothingToShipBanner,
    advanceToReadyForPickup,
    onPickupLocationSelect,
    invalidateDetail,
  };
}
