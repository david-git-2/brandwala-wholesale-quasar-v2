<template>
  <q-page class="dropship-return-page page-fixed-layout bg-grey-1 column no-wrap">
    <div class="return-page-header row items-center justify-between q-px-md q-py-sm bg-white border-bottom shadow-1">
      <div class="row items-center q-gutter-x-sm">
        <q-btn flat dense round icon="ph ph-arrow-left" color="grey-7" @click="goBack">
          <q-tooltip>Back to order</q-tooltip>
        </q-btn>
        <div>
          <div class="text-subtitle1 text-weight-bold text-grey-9 row items-center q-gutter-xs">
            <span>Finalize return: {{ orderData?.order.order_no || `#${orderId}` }}</span>
            <q-badge color="red-1" text-color="red-9" label="Dropship return" class="text-weight-bold q-ml-xs" />
          </div>
          <div class="text-caption text-grey-6">
            <span v-if="orderData">
              {{ orderData.order.customer_group_name || 'Merchant' }}
              <span class="q-mx-xs">•</span>
              {{ orderData.order.recipient_name || 'Recipient' }}
              <span v-if="orderData.courier.courier_awb_number" class="q-mx-xs">•</span>
              <span v-if="orderData.courier.courier_awb_number">
                {{ orderData.courier.courier_name || 'Courier' }} · {{ orderData.courier.courier_awb_number }}
              </span>
            </span>
          </div>
        </div>
      </div>

      <div class="row items-center q-gutter-sm">
        <q-btn flat dense no-caps label="Cancel" color="grey-7" class="q-px-sm text-weight-bold" @click="goBack" />
        <q-btn
          unelevated
          dense
          no-caps
          color="negative"
          icon="ph ph-arrow-u-up-left"
          label="Finalize return"
          class="q-px-md text-weight-bold"
          :loading="isSubmitting"
          :disable="!canSubmit || isSubmitting"
          @click="onFinalizeReturn"
        />
      </div>
    </div>

    <div v-if="isLoading" class="col column items-center justify-center q-pa-xl">
      <q-spinner-tail color="primary" size="48px" />
      <div class="text-subtitle2 text-grey-7 q-mt-md">Loading return details…</div>
    </div>

    <div v-else-if="errorMessage" class="col column items-center justify-center q-pa-xl">
      <q-icon name="ph ph-warning-circle" color="negative" size="48px" />
      <div class="text-subtitle1 text-weight-bold text-negative q-mt-sm">{{ errorMessage }}</div>
      <q-btn flat dense no-caps color="primary" label="Back to order" class="q-mt-md" @click="goBack" />
    </div>

    <div v-else-if="orderData" class="col row no-wrap return-body-container q-pa-md q-col-gutter-md overflow-hidden">
      <div class="col-12 col-md-8 column no-wrap full-height">
        <q-card flat class="floating-surface shadow-1 col column no-wrap overflow-hidden">
          <div class="row items-center justify-between q-px-md q-py-sm border-bottom bg-white">
            <q-checkbox
              v-model="selectAll"
              dense
              label="Select all lines"
              class="text-weight-bold text-caption text-grey-9"
              @update:model-value="onToggleSelectAll"
            />
            <div class="text-caption text-grey-6">
              Returning <strong class="text-primary">{{ selectedCount }}</strong> of {{ orderData.items.length }} lines
            </div>
          </div>

          <div class="col overflow-auto">
            <table class="dropship-return-table full-width">
              <thead>
                <tr>
                  <th style="width: 40px" class="text-center">#</th>
                  <th class="text-left" style="min-width: 200px">Product</th>
                  <th class="text-center" style="width: 120px">Picked / avail</th>
                  <th class="text-center" style="width: 130px">Return qty</th>
                  <th class="text-left" style="min-width: 150px">Grade</th>
                  <th class="text-left" style="min-width: 140px">Availability</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in returnTableRows"
                  :key="row.line.id"
                  :class="{ 'row-selected': row.input.selected }"
                >
                  <td class="text-center">
                    <q-checkbox
                      v-model="row.input.selected"
                      dense
                      :disable="row.maxReturnable <= 0"
                      @update:model-value="(val) => onToggleItemSelect(row.line.id, !!val)"
                    />
                  </td>
                  <td>
                    <div class="row items-center no-wrap q-gutter-x-sm">
                      <q-avatar square rounded class="bg-grey-2 product-thumb">
                        <img
                          v-if="row.line.image_url"
                          :src="row.line.image_url"
                          :alt="row.line.name"
                          style="object-fit: cover"
                        />
                        <q-icon v-else name="ph ph-package" color="grey-6" size="20px" />
                      </q-avatar>
                      <div class="min-width-0">
                        <div class="text-weight-bold text-grey-9 text-xs ellipsis-2-lines">{{ row.line.name }}</div>
                        <div v-if="row.line.product_code" class="text-caption text-grey-6">{{ row.line.product_code }}</div>
                      </div>
                    </div>
                  </td>
                  <td class="text-center">
                    <div class="text-caption text-weight-bold">{{ row.maxReturnable }} returnable</div>
                    <div class="text-xxs text-grey-6">
                      {{ row.line.confirmed_quantity ?? row.line.quantity }} picked
                    </div>
                  </td>
                  <td class="text-center">
                    <div class="row items-center justify-center no-wrap q-gutter-xs">
                      <q-btn
                        flat dense round size="xs" icon="ph ph-minus"
                        :disable="!row.input.selected || row.input.quantity <= 0"
                        @click="decrementQty(row.line.id)"
                      />
                      <q-input
                        v-model.number="row.input.quantity"
                        type="number"
                        dense outlined min="0" :max="row.maxReturnable"
                        class="qty-input text-center text-weight-bold"
                        :disable="!row.input.selected"
                        @update:model-value="() => onQtyChange(row.line.id)"
                      />
                      <q-btn
                        flat dense round size="xs" icon="ph ph-plus"
                        :disable="!row.input.selected || row.input.quantity >= row.maxReturnable"
                        @click="incrementQty(row.line.id)"
                      />
                    </div>
                  </td>
                  <td>
                    <q-select
                      v-model="row.input.grade_tag_id"
                      :options="gradeTagOptions"
                      option-value="id"
                      option-label="name"
                      emit-value
                      map-options
                      dense outlined
                      hide-bottom-space
                      :disable="!row.input.selected"
                      @update:model-value="(val) => onGradeTagChange(row.line.id, val as number | null)"
                    />
                  </td>
                  <td>
                    <q-select
                      v-model="row.input.to_availability"
                      :options="availabilityOptions"
                      emit-value
                      map-options
                      dense outlined
                      hide-bottom-space
                      :disable="!row.input.selected"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </q-card>
      </div>

      <div class="col-12 col-md-4 column no-wrap full-height">
        <q-card flat class="floating-surface shadow-1 col column no-wrap q-pa-md">
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm">Return charges</div>

          <div class="column q-gutter-md">
            <div>
              <div class="text-caption text-grey-7 q-mb-xs">Return cost</div>
              <div class="row q-gutter-sm items-center">
                <q-input
                  v-model.number="returnCostAmount"
                  type="number"
                  min="0"
                  step="0.01"
                  dense outlined
                  class="col"
                  input-class="text-right"
                />
                <q-btn-toggle
                  v-model="returnCostPayer"
                  dense no-caps unelevated toggle-color="primary" color="grey-3" text-color="grey-8"
                  :options="chargePayerOptions"
                />
              </div>
            </div>

            <q-toggle
              v-if="returnCostPayer === 'merchant'"
              v-model="deductFromMerchant"
              dense
              label="Deduct return fee from merchant wallet"
            />

            <q-input
              v-model="returnReasonNote"
              type="textarea"
              autogrow
              dense outlined
              label="Return reason note"
              :rules="returnReasonRules"
              hint="Required when return cost is greater than zero"
            />

            <q-separator />

            <div class="text-caption text-grey-7">
              Stock will be restocked via <strong>return_inbound</strong> at the grade and availability you choose per line.
              Wallet legs unwind only if delivery steps already ran on this order.
            </div>
          </div>

          <div class="q-mt-auto q-pt-md">
            <q-btn
              unelevated no-caps color="negative" icon="ph ph-check-circle"
              label="Confirm & finalize return"
              class="full-width text-weight-bold"
              :loading="isSubmitting"
              :disable="!canSubmit || isSubmitting"
              @click="onFinalizeReturn"
            />
          </div>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { tagRepository } from 'src/modules/tag/repositories/tagRepository';
import type { Tag } from 'src/modules/tag/types';
import type { StockAvailability } from 'src/modules/procurement_stock/constants/stockAvailability';
import { STOCK_AVAILABILITY_OPTIONS } from 'src/modules/procurement_stock/constants/stockAvailability';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { shopOrderService } from '../services/shopOrderService';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { DropshipManagementOrderView, DropshipSettlementChargePayer } from '../types/dropshipManagementOrder';
import {
  buildSettlementDraftPayload,
  settlementToFormState,
} from '../utils/dropshipManagementOrderMapper';
import {
  buildReturnItemsFromRows,
  returnableQty,
  type ReturnRowInput,
} from '../utils/dropshipReturnUtils';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const queryClient = useQueryClient();

const orderId = computed(() => Number(route.params.id));
const isSubmitting = ref(false);
const errorMessage = ref<string | null>(null);
const gradeTags = ref<Tag[]>([]);
const selectAll = ref(false);

const returnCostAmount = ref(0);
const returnCostPayer = ref<DropshipSettlementChargePayer>('company');
const deductFromMerchant = ref(true);
const returnReasonNote = ref('');

interface ReturnItemState {
  selected: boolean;
  quantity: number;
  grade_tag_id: number | null;
  to_availability: StockAvailability;
}

const returnInputs = ref<Record<number, ReturnItemState>>({});

const chargePayerOptions = [
  { label: 'Recipient', value: 'recipient' as const },
  { label: 'Merchant', value: 'merchant' as const },
  { label: 'Company', value: 'company' as const },
];

const availabilityOptions = STOCK_AVAILABILITY_OPTIONS.map((opt) => ({
  label: opt.label,
  value: opt.value,
}));

const detailQueryKey = computed(() =>
  shopOrderQueryKeys.dropshipManagementDetail(authStore.tenantId ?? 0, orderId.value),
);

const {
  data: orderData,
  isLoading,
  error: queryError,
} = useQuery({
  queryKey: detailQueryKey,
  enabled: computed(() => !!authStore.tenantId && Number.isFinite(orderId.value) && orderId.value > 0),
  queryFn: async (): Promise<DropshipManagementOrderView | null> => {
    if (!authStore.tenantId) return null;
    const res = await shopOrderService.fetchDropshipManagementOrder(authStore.tenantId, orderId.value);
    if (!res.success || !res.data) {
      throw new Error(res.error ?? 'Failed to load order');
    }
    return res.data;
  },
});

watch(
  () => queryError.value,
  (err) => {
    if (err instanceof Error) errorMessage.value = err.message;
  },
);

watch(
  orderData,
  async (data) => {
    if (!data) return;
    if (data.order.status === 'returned') {
      errorMessage.value = 'This order is already returned.';
      return;
    }
    if (data.order.status !== 'shipped') {
      errorMessage.value = 'Only shipped orders can be marked as returned from this desk.';
      return;
    }
    errorMessage.value = null;

    const formState = settlementToFormState(data.settlement);
    returnCostAmount.value = formState.returnCost.amount;
    returnCostPayer.value = formState.returnCost.payer;
    returnReasonNote.value = formState.returnReasonNote;
    deductFromMerchant.value = true;

    if (gradeTags.value.length === 0) {
      gradeTags.value = await tagRepository
        .listTagsForCategory({ moduleKey: 'stock_grade', code: 'warehouse' })
        .catch(() => [] as Tag[]);
    }

    const standardGradeId =
      gradeTags.value.find((t) => t.slug === 'standard')?.id
      ?? gradeTags.value[0]?.id
      ?? null;

    const nextInputs: Record<number, ReturnItemState> = {};
    for (const line of data.items) {
      nextInputs[line.id] = {
        selected: false,
        quantity: 0,
        grade_tag_id: line.grade_tag_id ?? standardGradeId,
        to_availability: 'held',
      };
    }
    returnInputs.value = nextInputs;
  },
  { immediate: true },
);

const gradeTagOptions = computed(() =>
  gradeTags.value.map((t) => ({ id: t.id, name: t.name })),
);

const returnTableRows = computed(() => {
  const items = orderData.value?.items ?? [];
  return items.map((line) => {
    const maxReturnable = returnableQty(line);
    const input = returnInputs.value[line.id] ?? {
      selected: false,
      quantity: 0,
      grade_tag_id: null,
      to_availability: 'held' as StockAvailability,
    };
    return { line, maxReturnable, input };
  });
});

const selectedCount = computed(() =>
  Object.values(returnInputs.value).filter((s) => s.selected && s.quantity > 0).length,
);

const canSubmit = computed(() => selectedCount.value > 0);

const returnReasonRules = [
  () => returnCostAmount.value <= 0 || returnReasonNote.value.trim().length > 0 || 'Return reason is required when cost > 0',
];

function goBack() {
  router.push({
    name: 'app-shop-dropship-management-detail-page',
    params: { tenantSlug: route.params.tenantSlug, id: orderId.value },
  });
}

function onToggleItemSelect(itemId: number, val: boolean) {
  const state = returnInputs.value[itemId];
  const line = orderData.value?.items.find((i) => i.id === itemId);
  if (!state || !line) return;
  state.selected = val;
  if (val && state.quantity === 0) {
    state.quantity = returnableQty(line);
  }
}

function onToggleSelectAll(val: boolean) {
  for (const line of orderData.value?.items ?? []) {
    const max = returnableQty(line);
    const state = returnInputs.value[line.id];
    if (state && max > 0) {
      state.selected = val;
      state.quantity = val ? max : 0;
    }
  }
}

function incrementQty(itemId: number) {
  const state = returnInputs.value[itemId];
  const line = orderData.value?.items.find((i) => i.id === itemId);
  if (!state || !line) return;
  const max = returnableQty(line);
  if (state.quantity < max) {
    state.quantity += 1;
    state.selected = true;
  }
}

function decrementQty(itemId: number) {
  const state = returnInputs.value[itemId];
  if (!state || state.quantity <= 0) return;
  state.quantity -= 1;
  if (state.quantity === 0) state.selected = false;
}

function onQtyChange(itemId: number) {
  const state = returnInputs.value[itemId];
  const line = orderData.value?.items.find((i) => i.id === itemId);
  if (!state || !line) return;
  const max = returnableQty(line);
  if (state.quantity > max) state.quantity = max;
  if (state.quantity < 0) state.quantity = 0;
  state.selected = state.quantity > 0;
}

function onGradeTagChange(itemId: number, gradeId: number | null) {
  const tag = gradeTags.value.find((t) => t.id === gradeId);
  const state = returnInputs.value[itemId];
  if (!state) return;
  if (tag?.metadata?.maps_to_availability === 'unsellable') {
    state.to_availability = 'unsellable';
  } else if (state.to_availability === 'unsellable') {
    state.to_availability = 'held';
  }
}

function buildRows(): ReturnRowInput[] {
  return (orderData.value?.items ?? []).map((line) => {
    const input = returnInputs.value[line.id];
    return {
      order_item_id: line.id,
      selected: input?.selected ?? false,
      quantity: input?.quantity ?? 0,
      grade_tag_id: input?.grade_tag_id ?? null,
      to_availability: input?.to_availability ?? 'held',
      note: '',
    };
  });
}

async function onFinalizeReturn() {
  if (!authStore.tenantId || !orderData.value) return;

  if (returnCostAmount.value > 0 && !returnReasonNote.value.trim()) {
    showErrorNotification('Return reason is required when return cost is greater than zero.');
    return;
  }

  let returnItems;
  try {
    const rows = buildRows();
    for (const row of rows) {
      if (!row.selected || row.quantity <= 0) continue;
      const line = orderData.value.items.find((i) => i.id === row.order_item_id);
      if (!line) continue;
      const max = returnableQty(line);
      if (row.quantity > max) {
        showErrorNotification(`Return quantity exceeds returnable amount for ${line.name}.`);
        return;
      }
    }
    returnItems = buildReturnItemsFromRows(rows);
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Invalid return lines.');
    return;
  }

  const baseForm = settlementToFormState(orderData.value.settlement);
  const payload = {
    ...buildSettlementDraftPayload({
      ...baseForm,
      returnCost: { amount: returnCostAmount.value, payer: returnCostPayer.value },
      returnReasonNote: returnReasonNote.value.trim(),
    }),
    return_items: returnItems,
    deduct_from_middle_man: returnCostPayer.value === 'merchant' && deductFromMerchant.value,
  };

  isSubmitting.value = true;
  try {
    const res = await shopOrderService.markDropshipOrderReturnedFromSettlement(
      authStore.tenantId,
      orderId.value,
      payload,
    );
    if (!res.success) {
      showErrorNotification(res.error ?? 'Failed to finalize return.');
      return;
    }
    showSuccessNotification('Return finalized. Stock restocked and order marked as returned.');
    await queryClient.invalidateQueries({ queryKey: detailQueryKey.value });
    goBack();
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<style scoped>
.dropship-return-page .return-page-header {
  flex-shrink: 0;
  z-index: 2;
}

.return-body-container {
  min-height: 0;
}

.dropship-return-table {
  border-collapse: collapse;
  font-size: 12px;
}

.dropship-return-table th,
.dropship-return-table td {
  padding: 8px 10px;
  border-bottom: 1px solid #e8eaed;
  vertical-align: middle;
}

.dropship-return-table th {
  background: #fafbfc;
  font-weight: 600;
  color: #5f6368;
  position: sticky;
  top: 0;
  z-index: 1;
}

.dropship-return-table tr.row-selected {
  background: #fef7f7;
}

.qty-input {
  width: 56px;
}

.product-thumb {
  height: 1in;
  width: 1in;
  border: 1px solid #e3e6ea;
  flex-shrink: 0;
}

.ellipsis-2-lines {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.min-width-0 {
  min-width: 0;
}

.floating-surface {
  border-radius: 10px;
  border: 1px solid #e3e6ea;
}
</style>

<script lang="ts">
export default {
  name: 'DropshipReturnFinalizePage',
};
</script>
