import { computed, onBeforeUnmount, ref, watch, type Ref } from 'vue';
import { useRouter } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { dropshipMerchantRepository } from '../repositories/dropshipMerchantRepository';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { ShopOrder, ShopOrderItem } from '../types';
import type { CourierServiceRow } from '../repositories/dropshipCourierRepository';
import type { DropshipInvoiceSummaryState } from '../utils/dropshipInvoiceSummary';
import type {
  DropshipInvoiceCourierState,
  DropshipInvoiceDeliveredQuantitiesState,
  DropshipInvoicePickupState,
} from '../utils/dropshipInvoiceFulfillment';
import { resolveDeliveryZone } from '../services/courierChargeEstimate';
import {
  showErrorNotification,
  showSuccessNotification,
  parseSupabaseError,
} from 'src/utils/appFeedback';
import { DROPSHIP_ORDER_DETAIL_READY_FOR_PICKUP_ROUTE } from './dropshipOrderDetailRoutes';

export function useDropshipOrderProcessingDesk(options: {
  tenantSlug: Ref<string | null>;
  orderId: Ref<number>;
  order: Ref<ShopOrder | null>;
  orderItems: Ref<ShopOrderItem[]>;
  summaryForm: Ref<DropshipInvoiceSummaryState>;
  pickupForm: DropshipInvoicePickupState;
  courierForm: DropshipInvoiceCourierState;
  deliveredQuantitiesForm: Ref<DropshipInvoiceDeliveredQuantitiesState>;
  couriers: Ref<CourierServiceRow[]>;
  refetchOrderDetail: () => Promise<unknown>;
  formReady?: Ref<boolean>;
}) {
  const router = useRouter();
  const authStore = useAuthStore();
  const queryClient = useQueryClient();

  const saving = ref(false);
  const advancingStatus = ref(false);
  const autoSaveState = ref<'idle' | 'pending' | 'saved' | 'error'>('idle');

  let autoSaveTimer: ReturnType<typeof setTimeout> | undefined;
  let lastPersistedSnapshot = '';

  const tenantId = computed(() => authStore.tenantId ?? 0);

  const merchantsQuery = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.merchants(options.tenantSlug.value)),
    enabled: computed(() => tenantId.value > 0),
    staleTime: 60_000,
    queryFn: () => dropshipMerchantRepository.listMerchants(),
  });

  const merchantOptions = computed(() =>
    (merchantsQuery.data.value ?? [])
      .filter((merchant) => merchant.is_active)
      .map((merchant) => ({
        label: `${merchant.merchant_name}${merchant.store_name ? ` (${merchant.store_name})` : ''} — ${merchant.phone_primary}`,
        value: merchant.id,
      })),
  );

  const invalidateDetail = async () => {
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.dropshipDetailV2(tenantId.value, options.orderId.value),
    });
    await options.refetchOrderDetail();
  };

  const validateQuantities = (): string | null => {
    for (const item of options.orderItems.value) {
      const delivered = options.deliveredQuantitiesForm.value[item.id] ?? 0;
      if (delivered < 0 || delivered > item.quantity) {
        return `Delivered quantity for "${item.name}" must be between 0 and ${item.quantity}.`;
      }
    }

    return null;
  };

  const serializeDeskForm = () =>
    JSON.stringify({
      summary: options.summaryForm.value,
      pickup: { ...options.pickupForm },
      courier: { ...options.courierForm },
      deliveredQuantities: options.deliveredQuantitiesForm.value,
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

    const quantityError = validateQuantities();
    if (quantityError) {
      if (!opts?.silent) showErrorNotification(quantityError);
      return false;
    }

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
        deliveredQuantities: options.deliveredQuantitiesForm.value,
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
      options.deliveredQuantitiesForm.value,
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
      void router.push({
        name: DROPSHIP_ORDER_DETAIL_READY_FOR_PICKUP_ROUTE,
        params: { id: order.id, tenantSlug: options.tenantSlug.value ?? undefined },
      });
    } catch (err) {
      showErrorNotification(parseSupabaseError(err, 'Failed to mark ready for pickup'));
    } finally {
      advancingStatus.value = false;
    }
  };

  const onMerchantSelect = (merchantId: string | null) => {
    if (!merchantId) return;
    const merchant = (merchantsQuery.data.value ?? []).find((row) => row.id === merchantId);
    if (!merchant) return;
    options.pickupForm.merchant_id = merchantId;
    options.pickupForm.sender_name = merchant.merchant_name;
    options.pickupForm.pickup_phone = merchant.phone_primary;
    options.pickupForm.pickup_address = merchant.pickup_address;
  };

  return {
    saving,
    advancingStatus,
    autoSaveState,
    merchantOptions,
    advanceToReadyForPickup,
    onMerchantSelect,
  };
}
