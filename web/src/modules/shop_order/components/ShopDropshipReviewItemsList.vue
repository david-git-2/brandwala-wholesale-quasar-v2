<template>
  <q-card flat bordered class="dropship-review-list">
    <q-card-section class="q-px-md q-py-sm border-bottom">
      <div class="text-subtitle2 text-weight-bold text-grey-9">
        {{ $t('shop.items') }} ({{ itemCount }})
      </div>
    </q-card-section>

    <div class="dropship-review-list__table">
      <div class="dropship-review-list__head row text-caption text-grey-6 text-weight-medium gt-sm">
        <div class="col">{{ $t('shop.dropship_col_product') }}</div>
        <div class="col-auto col-qty text-center">{{ $t('shop.qty') }}</div>
        <div class="col-auto col-unit text-right">{{ $t('shop.dropship_col_purchase') }}</div>
        <div class="col-auto col-resell text-right">{{ $t('shop.dropship_col_resell') }}</div>
        <div class="col-auto col-total text-right">{{ $t('shop.dropship_col_purchase_total') }}</div>
        <div class="col-auto col-total text-right">{{ $t('shop.dropship_col_resell_total') }}</div>
      </div>

      <div
        v-for="item in items"
        :key="item.id"
        class="dropship-review-row row items-start q-px-md q-py-md"
      >
        <div class="col col-product">
          <div class="row items-start no-wrap q-col-gutter-sm">
            <div class="dropship-review-row__image bg-grey-2">
              <q-img
                v-if="item.imageUrl"
                :src="item.imageUrl"
                :alt="item.name"
                fit="contain"
                class="dropship-review-row__image-img"
              />
              <q-icon v-else name="ph ph-image" color="grey-4" class="dropship-review-row__image-fallback" />
            </div>
            <div class="col min-width-0">
              <div class="text-body2 text-weight-bold text-grey-9 dropship-review-row__name">
                {{ item.name }}
              </div>
              <div class="text-caption text-grey-6 q-mt-xs lt-md">
                {{ $t('shop.qty') }}: {{ item.quantity }}
                · {{ $t('shop.dropship_col_purchase') }}: {{ formatMoney(item.purchasePrice) }}
              </div>
            </div>
          </div>
        </div>

        <div class="col-auto col-qty text-center gt-sm">
          <span class="text-body2 text-weight-medium text-grey-9">{{ item.quantity }}</span>
        </div>

        <div class="col-auto col-unit text-right gt-sm">
          <span class="text-body2 text-grey-8">{{ formatMoney(item.purchasePrice) }}</span>
        </div>

        <div class="col-auto col-resell">
          <q-input
            :model-value="item.resellPrice"
            type="number"
            outlined
            dense
            class="dropship-review-row__resell-input"
            :prefix="item.currencySymbol"
            :min="item.minResellPrice"
            :error="item.resellPrice < item.minResellPrice"
            :error-message="
              item.resellPrice < item.minResellPrice
                ? $t('shop.dropship_resell_below_min', { price: formatMoney(item.minResellPrice) })
                : undefined
            "
            @update:model-value="(val) => onResellInput(item.id, val)"
          />
          <div class="text-caption text-grey-6 q-mt-xs">
            {{ $t('shop.dropship_min_resell', { price: formatMoney(item.minResellPrice) }) }}
          </div>
        </div>

        <div class="col-auto col-total text-right gt-sm">
          <span class="text-body2 text-weight-medium text-grey-9">
            {{ formatMoney(item.purchasePrice * item.quantity) }}
          </span>
        </div>

        <div class="col-auto col-total text-right gt-sm">
          <span class="text-body2 text-weight-bold text-primary">
            {{ formatMoney(item.resellPrice * item.quantity) }}
          </span>
        </div>
      </div>
    </div>

    <div class="dropship-review-list__footer row items-center q-px-md q-py-sm">
      <div class="col gt-sm text-body2 text-weight-bold text-grey-9">
        {{ $t('shop.dropship_column_totals') }}
      </div>
      <div class="col-auto col-qty gt-sm" />
      <div class="col-auto col-unit gt-sm" />
      <div class="col-auto col-resell gt-sm" />
      <div class="col-auto col-total text-right">
        <div class="text-caption text-grey-6">{{ $t('shop.dropship_col_purchase_total') }}</div>
        <div class="text-body2 text-weight-bold text-grey-9">{{ formatMoney(totals.purchaseTotal) }}</div>
      </div>
      <div class="col-auto col-total text-right q-ml-md">
        <div class="text-caption text-grey-6">{{ $t('shop.dropship_col_resell_total') }}</div>
        <div class="text-body2 text-weight-bold text-primary">{{ formatMoney(totals.resellTotal) }}</div>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import type { DropshipReviewUiItem } from '../mocks/dropshipCartUiMocks';
import { formatDropshipUiMoney } from '../mocks/dropshipCartUiMocks';

const props = defineProps<{
  items: DropshipReviewUiItem[];
  itemCount: number;
  totals: {
    purchaseTotal: number;
    resellTotal: number;
  };
  currencySymbol?: string;
}>();

const emit = defineEmits<{
  (e: 'update:resellPrice', itemId: number, value: number): void;
}>();

const formatMoney = (amount: number) =>
  formatDropshipUiMoney(amount, props.currencySymbol ?? '৳');

const onResellInput = (itemId: number, val: string | number | null) => {
  if (val === '' || val === null) {
    emit('update:resellPrice', itemId, 0);
    return;
  }
  const numVal = Number(val);
  if (!Number.isNaN(numVal) && numVal >= 0) {
    emit('update:resellPrice', itemId, numVal);
  }
};
</script>

<style scoped>
.dropship-review-list {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
  overflow: hidden;
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.dropship-review-list__head,
.dropship-review-row,
.dropship-review-list__footer {
  gap: 8px;
}

.dropship-review-list__head {
  padding: 10px 16px;
  border-bottom: 1px solid rgba(34, 56, 101, 0.06);
}

.dropship-review-row + .dropship-review-row {
  border-top: 1px solid rgba(34, 56, 101, 0.06);
}

.dropship-review-list__footer {
  border-top: 1px solid rgba(34, 56, 101, 0.08);
  background: rgba(34, 56, 101, 0.03);
}

.col-qty {
  width: 48px;
}

.col-unit {
  width: 96px;
}

.col-resell {
  width: 140px;
}

.col-total {
  width: 108px;
}

.dropship-review-row__image {
  width: 1in;
  height: 1in;
  min-width: 1in;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 8px;
  overflow: hidden;
}

.dropship-review-row__image-img {
  width: 100%;
  height: 100%;
}

.dropship-review-row__image-fallback {
  font-size: 0.35in;
}

.dropship-review-row__name {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.35;
}

.dropship-review-row__resell-input {
  width: 120px;
}

@media (max-width: 599px) {
  .dropship-review-row {
    flex-direction: column;
  }

  .dropship-review-row__resell-input {
    width: 100%;
    max-width: 220px;
  }

  .dropship-review-list__footer {
    flex-wrap: wrap;
    justify-content: space-between;
  }

  .dropship-review-list__footer .col-total {
    width: auto;
    min-width: 120px;
  }
}
</style>
