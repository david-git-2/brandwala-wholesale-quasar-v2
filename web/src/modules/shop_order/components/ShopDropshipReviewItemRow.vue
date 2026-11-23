<template>
  <div class="dropship-review-item-wrap">
    <!-- xs: per-item card -->
    <div class="dropship-review-item dropship-review-item--card lt-sm">
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
              <div class="text-body2 text-weight-bold text-primary">
                {{ formatMoney(item.resellPrice * item.quantity) }}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- sm+: grid row -->
    <div class="dropship-review-item dropship-review-item--grid gt-xs dropship-review-list__row-grid">
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
      </div>

      <div class="dropship-review-item__cell dropship-review-item__cell--input-line text-right">
        <span class="text-body2 text-weight-medium text-grey-9">
          {{ formatMoney(item.purchasePrice * item.quantity) }}
        </span>
      </div>

      <div class="dropship-review-item__cell dropship-review-item__cell--input-line text-right">
        <span class="text-body2 text-weight-bold text-primary">
          {{ formatMoney(item.resellPrice * item.quantity) }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatCartMoney } from '../utils/cartPriceUtils';
import type { DropshipReviewListItem } from './ShopDropshipReviewItemsList.vue';

const props = withDefaults(
  defineProps<{
    item: DropshipReviewListItem;
    currencySymbol?: string;
    disableResell?: boolean;
  }>(),
  {
    currencySymbol: '৳',
    disableResell: false,
  },
);

const emit = defineEmits<{
  (e: 'update:resellPrice', itemId: number, value: number): void;
  (e: 'resell-price-blur', itemId: number): void;
}>();

const resellBelowMin = computed(
  () => props.item.resellPrice < props.item.minResellPrice,
);

const formatMoney = (amount: number) =>
  formatCartMoney(amount, props.currencySymbol ?? '৳');

const onResellInput = (val: string | number | null) => {
  if (val === '' || val === null) return;
  const numVal = Number(val);
  if (!Number.isNaN(numVal) && numVal >= 0) {
    emit('update:resellPrice', props.item.id, numVal);
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

</style>