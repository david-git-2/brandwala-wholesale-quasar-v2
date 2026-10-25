import { computed, onBeforeUnmount, ref, watch, type Ref } from 'vue';
import { onBeforeRouteLeave } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { usePickupLocationsStore } from '../stores/pickupLocationsStore';
import { useDropshipOrderDetailV2Store } from '../stores/dropshipOrderDetailV2Store';
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
  requestUnsavedChangesConfirmation,
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
  hasFulfillmentDraftChanges?: Ref<boolean>;
  getFulfillmentCommitPayload?: () => {
    lines: Array<{
      order_item_id: number;
      unavailable: boolean;
      picks: Array<{ global_stock_id: number; quantity: number }>;
    }>;
  } | null;
  markFulfillmentCommitted?: () => void;
  onReadyForPickupCommitted?: (dropshipDetailRaw: unknown) => void;
  discardFulfillmentDraft?: () => void;
}) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();

  const saving = ref(false);
  const advancingStatus = ref(false);
  const lastPersistedSnapshot = ref('');

  const tenantId = computed(() => authStore.tenantId ?? 0);

  const pickupLocationsStore = usePickupLocationsStore();
  const { locations: pickupLocations } = storeToRefs(pickupLocationsStore);
  watch(
    tenantId,
    (id) => {
      if (id > 0) void pickupLocationsStore.ensureLocations();
    },
    { immediate: true },
  );

  const pickupLocationOptions = computed(() =>
    pickupLocations.value
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

  const serializeDeskForm = () =>
    JSON.stringify({
      summary: options.summaryForm.value,
      pickup: { ...options.pickupForm },
      courier: { ...options.courierForm },
    });

  const syncPersistedSnapshot = () => {
    lastPersistedSnapshot.value = serializeDeskForm();
  };

  const hasUnsavedDeskChanges = computed(() => {
    if (options.formReady && !options.formReady.value) return false;
    if (options.hasFulfillmentDraftChanges?.value) return true;
    if (!lastPersistedSnapshot.value) return false;
    return serializeDeskForm() !== lastPersistedSnapshot.value;
  });

  const invalidateDetail = async () => {
    await useDropshipOrderDetailV2Store().ensureDetail(
      tenantId.value,
      options.orderId.value,
      true,
    );
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.orderDetail(authStore.tenantId ?? null, options.orderId.value),
    });
  };

  const persistProcessingDesk = async (): Promise<boolean> => {
    const order = options.order.value;
    if (!order) return false;

    const snapshot = serializeDeskForm();
    if (snapshot === lastPersistedSnapshot.value) {
      return true;
    }

    saving.value = true;
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

      lastPersistedSnapshot.value = snapshot;
      return true;
    } catch (err) {
      showErrorNotification(parseSupabaseError(err, 'Failed to save processing desk'));
      return false;
    } finally {
      saving.value = false;
    }
  };

  watch(
    () => options.formReady?.value,
    (ready) => {
      if (ready) syncPersistedSnapshot();
    },
    { immediate: true },
  );

  const confirmDiscardUnsavedChanges = async (): Promise<boolean> => {
    if (!hasUnsavedDeskChanges.value) return true;
    const choice = await requestUnsavedChangesConfirmation();
    if (choice === 'discard') {
      options.discardFulfillmentDraft?.();
    }
    return choice === 'discard';
  };

  onBeforeRouteLeave(async () => {
    if (!hasUnsavedDeskChanges.value) return true;
    const choice = await requestUnsavedChangesConfirmation();
    if (choice === 'discard') {
      options.discardFulfillmentDraft?.();
    }
    return choice === 'discard';
  });

  const onBeforeUnload = (event: BeforeUnloadEvent) => {
    if (!hasUnsavedDeskChanges.value) return;
    event.preventDefault();
  };

  if (typeof window !== 'undefined') {
    window.addEventListener('beforeunload', onBeforeUnload);
  }

  onBeforeUnmount(() => {
    if (typeof window !== 'undefined') {
      window.removeEventListener('beforeunload', onBeforeUnload);
    }
  });

  const advanceToReadyForPickup = async () => {
    const order = options.order.value;
    if (!order) return;

    if (!canAdvanceToReadyForPickup.value) {
      showErrorNotification(readyForPickupBlockReason.value || 'Ready for pickup is not available yet.');
      return;
    }

    const confirmed = await requestConfirmation(
      'Save stock picks, unavailable lines, pickup, courier, and charges, then mark this order ready for pickup? Picking and summary edits will be locked after this step.',
      'Ready for pickup',
      'Save & mark ready',
    );
    if (!confirmed) return;

    advancingStatus.value = true;
    try {
      const deskSnapshot = serializeDeskForm();
      const deskChanged = deskSnapshot !== lastPersistedSnapshot.value;
      const fulfillment = options.getFulfillmentCommitPayload?.() ?? null;

      const desk = deskChanged
        ? shopOrderRepository.buildDropshipReadyForPickupDeskPayload({
            tenantId: tenantId.value,
            orderId: order.id,
            order,
            summary: options.summaryForm.value,
            pickup: { ...options.pickupForm },
            courier: { ...options.courierForm },
            deliveredQuantities: {},
            deliveryZone: resolveDeliveryZone(order.shipping_district ?? ''),
          })
        : null;

      const result = await shopOrderRepository.commitDropshipReadyForPickupBundle({
        tenantId: tenantId.value,
        orderId: order.id,
        fulfillment,
        desk,
      });

      if (result.success === false) {
        throw new Error(result.error || 'Failed to mark ready for pickup');
      }

      if (result.dropship_detail) {
        options.onReadyForPickupCommitted?.(result.dropship_detail);
      }

      options.markFulfillmentCommitted?.();
      if (deskChanged) {
        lastPersistedSnapshot.value = deskSnapshot;
      }

      showSuccessNotification('Saved and marked ready for pickup');
    } catch (err) {
      showErrorNotification(parseSupabaseError(err, 'Failed to mark ready for pickup'));
    } finally {
      advancingStatus.value = false;
    }
  };

  const onPickupLocationSelect = (pickupLocationId: string | null) => {
    if (!pickupLocationId) return;
    const location = pickupLocations.value.find((row) => row.id === pickupLocationId);
    if (!location) return;
    options.pickupForm.pickup_location_id = pickupLocationId;
    options.pickupForm.sender_name = location.location_name;
    options.pickupForm.pickup_phone = location.phone_primary;
    options.pickupForm.pickup_address = location.pickup_address;
  };

  return {
    saving,
    advancingStatus,
    hasUnsavedDeskChanges,
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
    confirmDiscardUnsavedChanges,
    syncPersistedSnapshot,
  };
}
