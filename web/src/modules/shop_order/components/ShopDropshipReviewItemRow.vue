<template>
  <div class="dropship-review-item-wrap">
    <!-- xs–sm: per-item card -->
    <div class="dropship-review-item dropship-review-item--card lt-md">
      <div class="dropship-review-item__card-grid">
        <div class="dropship-review-item__image shop-product-thumb bg-grey-2">
          <q-img
            v-if="item.imageUrl"
            :src="item.imageUrl"
            :alt="item.name"
            fit="contain"
            class="dropship-review-item__image-img"
          />
          <q-icon
            v-else
            name="ph ph-image"
            color="grey-4"
            class="dropship-review-item__image-fallback"
          />
        </div>

        <div class="dropship-review-item__card-main min-width-0">
          <div class="text-body2 text-weight-bold text-grey-9 dropship-review-item__name">
            {{ item.name }}
          </div>
          <div class="dropship-review-item__meta text-caption text-grey-6 q-mt-xs">
            {{ $t('shop.qty') }}: {{ item.quantity }}
            · {{ $t('shop.dropship_col_purchase') }}: {{ formatMoney(item.purchasePrice) }}
          </div>

          <div class="dropship-review-item__field q-mt-sm">
            <div class="dropship-review-item__field-label">
              {{ $t('shop.dropship_col_resell') }}
            </div>
            <q-input
              :model-value="item.resellPrice"
              type="number"
              outlined
              dense
              hide-bottom-space
              class="dropship-review-item__resell-input"
              input-class="text-weight-bold"
              :prefix="currencySymbol"
              :min="item.minResellPrice"
              :disable="disableResell || item.isSaving"
              :loading="item.isSaving"
              :error="resellBelowMin"
              :error-message="
                resellBelowMin
                  ? $t('shop.dropship_resell_below_min', { price: formatMoney(item.minResellPrice) })
                  : undefined
              "
              @update:model-value="onResellInput"
              @blur="$emit('resell-price-blur', item.id)"
            />
            <div
              class="dropship-review-item__field-hint"
              :class="{ 'text-negative': resellBelowMin }"
            >
              {{ $t('shop.dropship_min_resell', { price: formatMoney(item.minResellPrice) }) }}
            </div>
            <button
              v-if="!hasDiscountRequest"
              type="button"
              class="dropship-review-item__discount-btn q-mt-xs"
              @click="discountDialogOpen = true"
            >
              <q-icon name="ph ph-seal-percent" size="15px" />
              <span>{{ $t('shop.dropship_request_discount') }}</span>
            </button>
            <div
              v-else
              class="dropship-review-item__discount-pending q-mt-xs"
              role="status"
            >
              <div class="dropship-review-item__discount-status">
                <q-icon name="ph ph-hourglass-medium" size="14px" />
                <span>{{
                  $t('shop.dropship_discount_requested', {
                    price: formatMoney(requestedDiscountAmount!),
                  })
                }}</span>
              </div>
              <div class="dropship-review-item__discount-pending-actions">
                <TfBtn
                  variant="link"
                  size="sm"
                  :label="$t('shop.dropship_edit_discount_request')"
                  :disable="discountActionsBusy"
                  @click="discountDialogOpen = true"
                />
                <TfBtn
                  variant="link"
                  size="sm"
                  :label="$t('shop.dropship_remove_discount_request')"
                  :disable="discountActionsBusy"
                  :loading="isClearingDiscount"
                  @click="onDiscountRemove"
                />
              </div>
            </div>
          </div>

          <div class="dropship-review-item__totals row q-mt-sm q-col-gutter-md">
            <div class="col">
              <div class="dropship-review-item__field-label">
                {{ $t('shop.dropship_col_purchase_total') }}
              </div>
              <div class="text-body2 text-weight-medium text-grey-9">
                {{ formatMoney(item.purchasePrice * item.quantity) }}
              </div>
            </div>
            <div class="col text-right">
              <div class="dropship-review-item__field-label">
                {{ $t('shop.dropship_col_resell_total') }}
              </div>
              <div
                class="text-body2 text-weight-bold"
                :class="hasDiscountRequest ? 'dropship-review-item__resell-total--pending' : 'text-primary'"
              >
                {{ formatMoney(effectiveResellLineTotal) }}
              </div>
              <div v-if="hasDiscountRequest" class="dropship-review-item__resell-total-hint">
                {{ $t('shop.dropship_resell_total_if_discount_accepted') }}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- md+: grid row -->
    <div class="dropship-review-item dropship-review-item--grid gt-sm dropship-review-list__row-grid">
      <div class="dropship-review-item__cell dropship-review-item__cell--product min-width-0">
        <div class="dropship-review-item__product row items-start no-wrap q-col-gutter-sm">
          <div class="dropship-review-item__image dropship-review-item__image--sm shop-product-thumb bg-grey-2">
            <q-img
              v-if="item.imageUrl"
              :src="item.imageUrl"
              :alt="item.name"
              fit="contain"
              class="dropship-review-item__image-img"
            />
            <q-icon
              v-else
              name="ph ph-image"
              color="grey-4"
              class="dropship-review-item__image-fallback"
            />
          </div>
          <div class="col min-width-0">
            <div class="text-body2 text-weight-bold text-grey-9 dropship-review-item__name">
              {{ item.name }}
            </div>
          </div>
        </div>
      </div>

      <div class="dropship-review-item__cell dropship-review-item__cell--input-line text-center">
        <span class="text-body2 text-weight-medium text-grey-9">{{ item.quantity }}</span>
      </div>

      <div class="dropship-review-item__cell dropship-review-item__cell--input-line text-right">
        <span class="text-body2 text-grey-8">{{ formatMoney(item.purchasePrice) }}</span>
      </div>

      <div class="dropship-review-item__cell dropship-review-item__cell--resell min-width-0">
        <div class="dropship-review-item__resell-input-wrap">
          <q-input
            :model-value="item.resellPrice"
            type="number"
            outlined
            dense
            hide-bottom-space
            class="dropship-review-item__resell-input"
            input-class="text-weight-bold"
            :prefix="currencySymbol"
            :min="item.minResellPrice"
            :disable="disableResell || item.isSaving"
            :loading="item.isSaving"
            :error="resellBelowMin"
            :error-message="
              resellBelowMin
                ? $t('shop.dropship_resell_below_min', { price: formatMoney(item.minResellPrice) })
                : undefined
            "
            @update:model-value="onResellInput"
            @blur="$emit('resell-price-blur', item.id)"
          />
        </div>
        <div
          class="dropship-review-item__field-hint dropship-review-item__field-hint--grid"
          :class="{ 'text-negative': resellBelowMin }"
        >
          {{ $t('shop.dropship_min_resell', { price: formatMoney(item.minResellPrice) }) }}
        </div>
        <button
          v-if="!hasDiscountRequest"
          type="button"
          class="dropship-review-item__discount-btn dropship-review-item__discount-btn--grid"
          @click="discountDialogOpen = true"
        >
          <q-icon name="ph ph-seal-percent" size="14px" />
          <span>{{ $t('shop.dropship_request_discount') }}</span>
        </button>
        <div
          v-else
          class="dropship-review-item__discount-pending dropship-review-item__discount-pending--grid"
          role="status"
        >
          <div class="dropship-review-item__discount-status">
            <q-icon name="ph ph-hourglass-medium" size="14px" />
            <span>{{
              $t('shop.dropship_discount_requested', {
                price: formatMoney(requestedDiscountAmount!),
              })
            }}</span>
          </div>
          <div class="dropship-review-item__discount-pending-actions">
            <TfBtn
              variant="link"
              size="sm"
              :label="$t('shop.dropship_edit_discount_request')"
              :disable="discountActionsBusy"
              @click="discountDialogOpen = true"
            />
            <TfBtn
              variant="link"
              size="sm"
              :label="$t('shop.dropship_remove_discount_request')"
              :disable="discountActionsBusy"
              :loading="isClearingDiscount"
              @click="onDiscountRemove"
            />
          </div>
        </div>
      </div>

      <div class="dropship-review-item__cell dropship-review-item__cell--input-line text-right">
        <span class="text-body2 text-weight-medium text-grey-9">
          {{ formatMoney(item.purchasePrice * item.quantity) }}
        </span>
      </div>

      <div class="dropship-review-item__cell dropship-review-item__cell--resell-total text-right">
        <div
          class="text-body2 text-weight-bold"
          :class="hasDiscountRequest ? 'dropship-review-item__resell-total--pending' : 'text-primary'"
        >
          {{ formatMoney(effectiveResellLineTotal) }}
        </div>
        <div v-if="hasDiscountRequest" class="dropship-review-item__resell-total-hint text-right">
          {{ $t('shop.dropship_resell_total_if_discount_accepted') }}
        </div>
      </div>

    </div>

    <ShopDropshipRequestDiscountDialog
      v-model="discountDialogOpen"
      :product-name="item.name"
      :currency-symbol="currencySymbol"
      :initial-requested-price="item.requestedResellDiscountPrice"
      :initial-reason="item.resellDiscountRequestReason"
      :loading="isSubmittingDiscount"
      @submit="onDiscountSubmit"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import ShopDropshipRequestDiscountDialog from './ShopDropshipRequestDiscountDialog.vue';
import { useShopCartMutations } from '../composables/useShopCartMutations';
import { formatCartMoney } from '../utils/cartPriceUtils';
import {
  effectiveResellUnitPrice,
  hasPendingResellDiscount,
} from '../utils/dropshipReviewPricingUtils';
import type { DropshipReviewListItem } from './ShopDropshipReviewItemsList.vue';

const props = withDefaults(
  defineProps<{
    item: DropshipReviewListItem;
    shopId?: number | null;
    currencySymbol?: string;
    disableResell?: boolean;
  }>(),
  {
    shopId: null,
    currencySymbol: '৳',
    disableResell: false,
  },
);

const emit = defineEmits<{
  (e: 'update:resellPrice', itemId: number, value: number): void;
  (e: 'resell-price-blur', itemId: number): void;
}>();

const discountDialogOpen = ref(false);
const { submitResellDiscountRequestMutation, clearResellDiscountRequestMutation } =
  useShopCartMutations();

const isSubmittingDiscount = computed(
  () =>
    submitResellDiscountRequestMutation.isPending.value &&
    submitResellDiscountRequestMutation.variables.value?.cartItemId === props.item.id,
);

const isClearingDiscount = computed(
  () =>
    clearResellDiscountRequestMutation.isPending.value &&
    clearResellDiscountRequestMutation.variables.value?.cartItemId === props.item.id,
);

const discountActionsBusy = computed(
  () => isSubmittingDiscount.value || isClearingDiscount.value,
);

const resellBelowMin = computed(
  () => props.item.resellPrice < props.item.minResellPrice,
);

const requestedDiscountAmount = computed(
  () => props.item.requestedResellDiscountPrice ?? null,
);

const hasDiscountRequest = computed(() =>
  hasPendingResellDiscount(requestedDiscountAmount.value),
);

const effectiveResellLineTotal = computed(() => {
  const unit = effectiveResellUnitPrice(
    props.item.resellPrice,
    requestedDiscountAmount.value,
  );
  return unit * props.item.quantity;
});

const formatMoney = (amount: number) =>
  formatCartMoney(amount, props.currencySymbol ?? '৳');

const onResellInput = (val: string | number | null) => {
  if (val === '' || val === null) return;
  const numVal = Number(val);
  if (!Number.isNaN(numVal) && numVal >= 0) {
    emit('update:resellPrice', props.item.id, numVal);
  }
};

const onDiscountSubmit = async (payload: { requestedPrice: number; reason: string }) => {
  if (!props.shopId) return;
  try {
    await submitResellDiscountRequestMutation.mutateAsync({
      cartItemId: props.item.id,
      requestedPrice: payload.requestedPrice,
      reason: payload.reason,
      shopId: props.shopId,
    });
    discountDialogOpen.value = false;
  } catch {
    // Toast handled in mutation.
  }
};

const onDiscountRemove = async () => {
  if (!props.shopId) return;
  try {
    await clearResellDiscountRequestMutation.mutateAsync({
      cartItemId: props.item.id,
      shopId: props.shopId,
    });
  } catch {
    // Toast handled in mutation.
  }
};
</script>

<script lang="ts">
export default {
  name: 'ShopDropshipReviewItemRow',
};
</script>

<style scoped>
.dropship-review-item--card {
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: var(--tf-radius-sm, 8px);
  padding: 12px;
  background: var(--tf-theme-surface, #fff);
}

.dropship-review-item__card-grid {
  display: grid;
  grid-template-columns: 56px minmax(0, 1fr);
  gap: 12px;
  align-items: start;
}

.dropship-review-item__image {
  width: 56px;
  height: 56px;
  min-width: 56px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: var(--tf-radius-sm, 8px);
  overflow: hidden;
}

.dropship-review-item__image--sm {
  width: 64px;
  height: 64px;
  min-width: 64px;
}

.dropship-review-item__image-img {
  width: 100%;
  height: 100%;
}

.dropship-review-item__image-fallback {
  font-size: 22px;
}

.dropship-review-item__image--sm .dropship-review-item__image-fallback {
  font-size: 26px;
}

.dropship-review-item__name {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.35;
}

.dropship-review-item__field-label {
  font-size: 11px;
  line-height: 1.2;
  font-weight: 600;
  color: rgba(34, 56, 101, 0.55);
  margin-bottom: 4px;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.dropship-review-item__field-hint {
  font-size: 11px;
  line-height: 1.3;
  color: rgba(34, 56, 101, 0.5);
  margin-top: 4px;
}

.dropship-review-item__resell-input {
  width: 100%;
}

.dropship-review-item--grid .dropship-review-item__cell--input-line {
  display: flex;
  align-items: center;
  min-height: 40px;
}

.dropship-review-item__resell-input-wrap {
  display: flex;
  align-items: center;
  min-height: 40px;
}

.dropship-review-item__field-hint--grid {
  margin-top: 2px;
  line-height: 1.25;
}

.dropship-review-item__discount-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: 0;
  padding: 5px 10px;
  max-width: 100%;
  font: inherit;
  font-size: 11px;
  font-weight: 600;
  line-height: 1.25;
  letter-spacing: 0.01em;
  color: color-mix(in srgb, var(--tf-warning) 78%, var(--tf-neutral-ink));
  background: var(--tf-warning-soft);
  border: 1px solid color-mix(in srgb, var(--tf-warning) 30%, var(--tf-neutral-border));
  border-radius: var(--tf-radius-sm, 6px);
  cursor: pointer;
  white-space: nowrap;
  transition:
    background-color var(--tf-dur-fast, 120ms) var(--tf-ease, ease),
    border-color var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.dropship-review-item__discount-btn:hover {
  background: color-mix(in srgb, var(--tf-warning-soft) 70%, var(--tf-warning) 30%);
  border-color: color-mix(in srgb, var(--tf-warning) 45%, var(--tf-neutral-border));
}

.dropship-review-item__discount-btn:focus-visible {
  outline: 2px solid color-mix(in srgb, var(--tf-warning) 55%, transparent);
  outline-offset: 2px;
}

.dropship-review-item__discount-btn--grid {
  margin-top: 6px;
}

.dropship-review-item__discount-pending {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
  max-width: 100%;
}

.dropship-review-item__discount-pending--grid {
  margin-top: 6px;
}

.dropship-review-item__discount-status {
  display: inline-flex;
  align-items: flex-start;
  gap: 6px;
  max-width: 100%;
  padding: 6px 10px;
  font-size: 11px;
  font-weight: 600;
  line-height: 1.35;
  color: color-mix(in srgb, var(--tf-warning) 72%, var(--tf-neutral-ink));
  background: var(--tf-warning-soft);
  border: 1px solid color-mix(in srgb, var(--tf-warning) 28%, var(--tf-neutral-border));
  border-radius: var(--tf-radius-sm, 6px);
}

.dropship-review-item__discount-pending-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px 10px;
  padding-left: 2px;
}

.dropship-review-item__cell--resell-total {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  justify-content: flex-start;
  min-height: 40px;
  gap: 2px;
}

.dropship-review-item__resell-total--pending {
  color: color-mix(in srgb, var(--tf-warning) 75%, var(--tf-neutral-ink));
}

.dropship-review-item__resell-total-hint {
  font-size: 10px;
  line-height: 1.25;
  font-weight: 600;
  color: rgba(34, 56, 101, 0.55);
  max-width: 120px;
}
</style>