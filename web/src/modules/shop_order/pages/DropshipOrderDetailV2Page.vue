<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { DROPSHIP_ORDER_DETAIL_PROCESSING_ROUTE } from '../composables/dropshipOrderDetailRoutes';
import { useDropshipOrderDetailV2Query } from '../composables/useDropshipOrderDetailV2Query';
import { useDropshipOrderStatusRedirect } from '../composables/useDropshipOrderStatusRedirect';
import DropshipOrderConfirmedInvoicePaper from '../components/DropshipOrderConfirmedInvoicePaper.vue';
import {
  showErrorNotification,
  showSuccessNotification,
  parseSupabaseError,
} from 'src/utils/appFeedback';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const queryClient = useQueryClient();
const advancingStatus = ref(false);

const tenantSlug = computed(() =>
  typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null,
);
const orderId = computed(() => Number(route.params.id || 0));

const orderDetailQuery = useDropshipOrderDetailV2Query({ tenantSlug, orderId });

const order = computed(() => orderDetailQuery.data.value?.order ?? null);
const orderItems = computed(() => orderDetailQuery.data.value?.items ?? []);
const isConfirmed = computed(() => order.value?.status === 'confirmed');
const isLoading = computed(() => orderDetailQuery.isLoading.value);
const loadError = computed(() => orderDetailQuery.error.value);

useDropshipOrderStatusRedirect({
  expectedView: 'confirmed',
  status: computed(() => order.value?.status ?? null),
  orderId,
  tenantSlug,
  enabled: computed(() => !isLoading.value && !!order.value),
});

const goToProcessingPage = () => {
  void router.push({
    name: DROPSHIP_ORDER_DETAIL_PROCESSING_ROUTE,
    params: {
      id: orderId.value,
      tenantSlug: route.params.tenantSlug,
    },
  });
};

const advanceToProcessing = async () => {
  if (!order.value || order.value.status !== 'confirmed') return;

  advancingStatus.value = true;
  try {
    const { data, error } = await supabase.rpc('advance_dropship_order_status', {
      p_order_id: order.value.id,
      p_target_status: 'processing',
    });
    if (error) throw error;
    if (data && typeof data === 'object' && (data as { success?: boolean }).success === false) {
      throw new Error((data as { error?: string }).error || 'Failed to update status');
    }

    showSuccessNotification('Status updated to processing');
    await queryClient.invalidateQueries({
      queryKey: shopOrderQueryKeys.dropshipDetailV2(authStore.tenantId ?? 0, orderId.value),
    });
    goToProcessingPage();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to update status'));
  } finally {
    advancingStatus.value = false;
  }
};
</script>

<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
      <section v-if="isLoading" class="dropship-order-detail-v2__loading">
        <q-skeleton type="rect" height="520px" class="dropship-order-detail-v2__paper-skeleton" />
      </section>

      <section v-else-if="loadError" class="text-caption text-negative">
        {{ loadError instanceof Error ? loadError.message : 'Failed to load order.' }}
      </section>

      <template v-else-if="order">
        <DropshipOrderConfirmedInvoicePaper
          v-if="isConfirmed"
          :order="order"
          :order-items="orderItems"
        />

        <div
          v-if="isConfirmed"
          class="dropship-order-detail-v2__footer-actions"
        >
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-package"
            label="Start processing"
            class="text-weight-bold"
            style="border-radius: 8px; min-width: 220px"
            :loading="advancingStatus"
            @click="advanceToProcessing"
          />
        </div>

        <q-card v-else flat bordered class="form-card">
          <q-card-section class="q-pa-lg text-center">
            <q-icon name="ph ph-file-text" size="40px" color="grey-5" class="q-mb-sm" />
            <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-xs">
              Paper invoice view
            </div>
            <p class="text-body2 text-grey-6 q-mb-sm">
              Full recipient and item details appear here once the order is confirmed.
            </p>
            <q-chip dense outline color="grey-7" class="text-capitalize">
              Current status: {{ order.status.replace(/_/g, ' ') }}
            </q-chip>
          </q-card-section>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<style scoped>
.dropship-order-detail-v2 {
  background: #eef1f4;
}

.dropship-order-detail-v2__paper-skeleton {
  max-width: 920px;
  margin: 0 auto;
  border-radius: 2px;
}

.dropship-order-detail-v2__footer-actions {
  max-width: 920px;
  margin: 0 auto;
  display: flex;
  justify-content: center;
  padding-top: 0.25rem;
}
</style>
