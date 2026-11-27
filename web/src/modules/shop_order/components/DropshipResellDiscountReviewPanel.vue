<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useQuasar } from 'quasar';
import type { ShopOrder, ShopOrderItem } from '../types';
import type {
  DropshipResellDiscountLineResolution,
  FinalizeDropshipResellDiscountLineInput,
} from '../repositories/shopOrderRepository';
import { useFinalizeDropshipResellDiscountReviewMutation } from '../composables/useFinalizeDropshipResellDiscountReviewMutation';
import { shopOrderRepository } from '../repositories/shopOrderRepository';

const props = defineProps<{
  order: ShopOrder;
  items: ShopOrderItem[];
  currencySymbol: string;
}>();

const emit = defineEmits<{
  (e: 'confirmed'): void;
  (e: 'cancelled'): void;
}>();

const { t } = useI18n();
const $q = useQuasar();
const finalizeMutation = useFinalizeDropshipResellDiscountReviewMutation();

type LineState = {
  resolution: DropshipResellDiscountLineResolution | null;
  customAmount: number | null;
};

const lineState = reactive<Record<number, LineState>>({});
const cancelReason = ref('');

const allItems = computed(() => props.items ?? []);

const requestLines = computed(() =>
  allItems.value.filter((item) => item.requested_resell_discount_price_amount != null),
);

const hasResellRequest = (item: ShopOrderItem) =>
  item.requested_resell_discount_price_amount != null;

const initLineState = () => {
  requestLines.value.forEach((item) => {
    if (!lineState[item.id]) {
      lineState[item.id] = { resolution: null, customAmount: null };
    }
  });
};
watch(requestLines, initLineState, { immediate: true });

const listedResell = (item: ShopOrderItem) =>
  item.customer_sell_price_amount ?? item.unit_sell_price_amount ?? 0;

const formatMoney = (amount: number | null | undefined) =>
  `${props.currencySymbol}${Number(amount ?? 0).toFixed(2)}`;

const allResolved = computed(() =>
  requestLines.value.every((item) => {
    const st = lineState[item.id];
    if (!st?.resolution) return false;
    if (st.resolution === 'custom') {
      return st.customAmount != null && Number.isFinite(st.customAmount) && st.customAmount > 0;
    }
    return true;
  }),
);

const buildPayload = (): FinalizeDropshipResellDiscountLineInput[] =>
  requestLines.value.map((item) => {
    const st = lineState[item.id]!;
    const row: FinalizeDropshipResellDiscountLineInput = {
      order_item_id: item.id,
      resolution: st.resolution!,
    };
    if (st.resolution === 'custom') {
      row.approved_resell_amount = st.customAmount;
    }
    return row;
  });

const confirmOrder = async () => {
  if (!allResolved.value) return;
  try {
    await finalizeMutation.mutateAsync({
      orderId: props.order.id,
      lines: buildPayload(),
    });
    emit('confirmed');
  } catch {
    // toast via mutation
  }
};

const cancelOrder = () => {
  $q.dialog({
    title: t('shop_admin.resell_discount_cancel_title'),
    message: t('shop_admin.resell_discount_cancel_message'),
    prompt: {
      model: cancelReason.value,
      type: 'text',
      isValid: (val: string) => String(val ?? '').trim().length > 0,
    },
    cancel: true,
    persistent: true,
  }).onOk(async (reason: string) => {
    try {
      await shopOrderRepository.cancelShopOrderDropship(props.order.id, reason.trim());
      emit('cancelled');
    } catch (err) {
      $q.notify({
        type: 'negative',
        message: err instanceof Error ? err.message : t('shop_admin.resell_discount_cancel_failed'),
      });
    }
  });
};
</script>

<template>
  <q-card flat bordered class="q-mb-md resell-discount-review-panel">
    <q-card-section class="bg-amber-1">
      <div class="text-subtitle1 text-weight-bold text-grey-9">
        {{ $t('shop_admin.resell_discount_review_title') }}
      </div>
      <div class="text-body2 text-grey-8">
        {{ $t('shop_admin.resell_discount_review_hint') }}
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section class="q-pa-none">
      <q-markup-table flat dense class="resell-discount-review-table">
        <thead>
          <tr>
            <th class="text-left">{{ $t('shop_admin.product') }}</th>
            <th class="text-right">{{ $t('shop_admin.quantity') }}</th>
            <th class="text-right">{{ $t('shop_admin.middle_man_cost') }}</th>
            <th class="text-right">{{ $t('shop_admin.listed_resell') }}</th>
            <th class="text-right">{{ $t('shop.dropship_col_requested_resell') }}</th>
            <th class="text-left">{{ $t('shop_admin.resell_discount_reason') }}</th>
            <th class="text-left">{{ $t('shop_admin.resell_discount_decision') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in allItems" :key="item.id">
            <td class="text-left">
              <div class="text-weight-medium">{{ item.name }}</div>
              <div
                v-if="item.unit_minimum_sell_price_amount"
                class="text-caption text-grey-7"
              >
                {{ $t('shop_admin.min_resell') }}:
                {{ formatMoney(item.unit_minimum_sell_price_amount) }}
              </div>
            </td>
            <td class="text-right">{{ item.quantity }}</td>
            <td class="text-right">
              {{ formatMoney(item.unit_sell_price_amount ?? item.unit_list_price_amount) }}
            </td>
            <td class="text-right text-primary text-weight-bold">
              {{ formatMoney(listedResell(item)) }}
            </td>
            <td class="text-right" :class="hasResellRequest(item) ? 'text-amber-9 text-weight-bold' : 'text-grey-6'">
              {{
                hasResellRequest(item)
                  ? formatMoney(item.requested_resell_discount_price_amount)
                  : '—'
              }}
            </td>
            <td class="text-left text-caption" style="max-width: 180px">
              {{
                hasResellRequest(item)
                  ? item.resell_discount_request_reason?.trim() || '—'
                  : '—'
              }}
            </td>
            <td>
              <div v-if="hasResellRequest(item)" class="column q-gutter-y-xs">
                <q-option-group
                  v-model="lineState[item.id].resolution"
                  :options="[
                    { label: $t('shop_admin.resell_discount_accept'), value: 'use_requested' },
                    { label: $t('shop_admin.resell_discount_keep_listed'), value: 'use_listed' },
                    { label: $t('shop_admin.resell_discount_adjust'), value: 'custom' },
                  ]"
                  type="radio"
                  dense
                  color="primary"
                />
                <q-input
                  v-if="lineState[item.id]?.resolution === 'custom'"
                  v-model.number="lineState[item.id].customAmount"
                  type="number"
                  dense
                  outlined
                  :label="$t('shop_admin.resell_discount_adjusted_amount')"
                  style="max-width: 140px"
                />
              </div>
              <span v-else class="text-caption text-grey-6">
                {{ $t('shop_admin.resell_discount_no_change') }}
              </span>
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </q-card-section>

    <q-separator />

    <q-card-actions align="right" class="q-pa-md q-gutter-sm">
      <q-btn
        flat
        no-caps
        color="negative"
        :label="$t('shop_admin.resell_discount_cancel_order')"
        @click="cancelOrder"
      />
      <q-btn
        unelevated
        no-caps
        color="primary"
        :loading="finalizeMutation.isPending.value"
        :disable="!allResolved"
        :label="$t('shop_admin.resell_discount_confirm_order')"
        @click="confirmOrder"
      />
    </q-card-actions>
  </q-card>
</template>

<style scoped>
.resell-discount-review-table th {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
</style>