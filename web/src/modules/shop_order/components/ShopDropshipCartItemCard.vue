<template>
  <q-card flat bordered class="dropship-cart-item">
    <q-card-section class="q-pa-sm q-pa-md-sm">
      <!-- Manual order / resell edit -->
      <div v-if="showResellInput" class="dropship-cart-item__compact">
        <div class="dropship-cart-item__image dropship-cart-item__image--compact shop-product-thumb bg-grey-2">
          <q-img
            v-if="imageUrl"
            :src="imageUrl"
            :alt="name"
            fit="contain"
            class="dropship-cart-item__image-img"
          />
          <q-icon
            v-else
            name="ph ph-image"
            color="grey-4"
            class="dropship-cart-item__image-fallback"
          />
        </div>

        <div class="dropship-cart-item__compact-main min-width-0">
          <div class="dropship-cart-item__compact-head">
            <div class="text-body2 text-weight-bold text-grey-9 dropship-cart-item__name">
              {{ name }}
            </div>
            <q-btn
              flat
              round
              dense
              size="sm"
              icon="ph ph-trash"
              color="negative"
              :disable="disableRemove"
              :loading="isRemoving"
              aria-label="Remove item"
              @click="$emit('remove')"
            >
              <q-tooltip>{{ $t('shop.remove_item') }}</q-tooltip>
            </q-btn>
          </div>

          <div class="dropship-cart-item__compact-toolbar">
            <div class="dropship-cart-item__field dropship-cart-item__field--resell">
              <div class="dropship-cart-item__field-label">
                {{ $t('shop.dropship_col_resell', 'Resell') }}
              </div>
              <q-input
                :model-value="price"
                type="number"
                outlined
                dense
                hide-bottom-space
                class="dropship-cart-item__resell-input"
                input-class="text-weight-bold"
                :prefix="currencySymbol"
                :min="minResellPrice ?? 0"
                :disable="disableResell"
                :error="resellBelowMin"
                @update:model-value="onResellInput"
              />
              <div
                v-if="minResellPrice != null && minResellPrice > 0"
                class="dropship-cart-item__field-hint"
                :class="{ 'text-negative': resellBelowMin }"
              >
                {{
                  $t('shop.dropship_min_resell', {
                    price: `${currencySymbol}${minResellPrice.toFixed(2)}`,
                  })
                }}
              </div>
            </div>

            <div class="dropship-cart-item__field dropship-cart-item__field--qty">
              <div class="dropship-cart-item__field-label">{{ $t('shop.qty', 'Qty') }}</div>
              <div class="quantity-controls quantity-controls--spaced row items-center no-wrap">
                <q-btn
                  flat
                  round
                  dense
                  size="sm"
                  icon="ph ph-minus"
                  color="grey-7"
                  :disable="disableQty || quantity <= minQty"
                  aria-label="Decrease quantity"
                  @click="$emit('update:quantity', adjustQty(-minQty))"
                />
                <div class="quantity-value text-weight-bold text-center text-grey-9">
                  {{ quantity }}
                </div>
                <q-btn
                  flat
                  round
                  dense
                  size="sm"
                  icon="ph ph-plus"
                  color="grey-7"
                  :disable="disableQty"
                  aria-label="Increase quantity"
                  @click="$emit('update:quantity', adjustQty(minQty))"
                />
              </div>
            </div>

            <div class="dropship-cart-item__field dropship-cart-item__field--total">
              <div class="dropship-cart-item__field-label">
                {{ $t('shop.dropship_col_resell_total', 'Total') }}
              </div>
              <div class="dropship-cart-item__total text-body2 text-weight-bold text-grey-9">
                {{ currencySymbol }}{{ lineTotal.toFixed(2) }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Default dropship cart -->
      <div v-else class="row items-center no-wrap q-col-gutter-sm">
        <div class="col-auto">
          <div class="dropship-cart-item__image shop-product-thumb bg-grey-2">
            <q-img
              v-if="imageUrl"
              :src="imageUrl"
              :alt="name"
              fit="contain"
              class="dropship-cart-item__image-img"
            />
            <q-icon
              v-else
              name="ph ph-image"
              color="grey-4"
              class="dropship-cart-item__image-fallback"
            />
          </div>
        </div>

        <div class="col min-width-0">
          <div class="row items-start justify-between no-wrap q-col-gutter-xs">
            <div class="text-body2 text-weight-bold text-grey-9 dropship-cart-item__name col min-width-0">
              {{ name }}
            </div>
            <q-btn
              flat
              round
              dense
              size="sm"
              icon="ph ph-trash"
              color="negative"
              class="col-auto"
              :disable="disableRemove"
              :loading="isRemoving"
              @click="$emit('remove')"
            >
              <q-tooltip>{{ $t('shop.remove_item') }}</q-tooltip>
            </q-btn>
          </div>
          <div class="row items-center justify-between q-mt-xs">
            <div class="column q-gutter-y-xs">
              <div class="row items-center no-wrap quantity-controls">
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-minus"
                  color="grey-7"
                  :disable="disableQty || quantity <= minQty"
                  @click="$emit('update:quantity', adjustQty(-minQty))"
                />
                <div class="quantity-value text-weight-bold text-center text-grey-9">
                  {{ quantity }}
                </div>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-plus"
                  color="grey-7"
                  :disable="disableQty"
                  @click="$emit('update:quantity', adjustQty(minQty))"
                />
              </div>
              <q-btn
                v-if="showSaveQty"
                color="primary"
                size="xs"
                unelevated
                no-caps
                class="pill-btn q-px-sm self-start"
                :label="$t('shop.save_qty')"
                :loading="isSaving"
                @click="$emit('save-quantity')"
              />
            </div>
            <div class="text-body2 text-weight-bold text-grey-9">
              {{ currencySymbol }}{{ lineTotal.toFixed(2) }}
            </div>
          </div>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { adjustQtyByMoq } from '../utils/cartQuantityUtils';

const props = withDefaults(
  defineProps<{
    name: string;
    imageUrl?: string | null;
    quantity: number;
    price: number;
    currencySymbol?: string;
    minQty?: number;
    disableQty?: boolean;
    showSaveQty?: boolean;
    isSaving?: boolean;
    disableRemove?: boolean;
    isRemoving?: boolean;
    showResellInput?: boolean;
    minResellPrice?: number | null;
    disableResell?: boolean;
  }>(),
  {
    imageUrl: null,
    currencySymbol: '৳',
    minQty: 1,
    disableQty: false,
    showSaveQty: false,
    isSaving: false,
    disableRemove: false,
    isRemoving: false,
    showResellInput: false,
    minResellPrice: null,
    disableResell: false,
  },
);

const emit = defineEmits<{
  (e: 'update:quantity', value: number): void;
  (e: 'update:price', value: number): void;
  (e: 'save-quantity'): void;
  (e: 'remove'): void;
}>();

const lineTotal = computed(() => props.price * props.quantity);

const resellBelowMin = computed(
  () =>
    props.showResellInput &&
    props.minResellPrice != null &&
    props.minResellPrice > 0 &&
    props.price < props.minResellPrice,
);

const onResellInput = (val: string | number | null) => {
  const num = Number(val);
  if (!Number.isFinite(num)) return;
  emit('update:price', num);
};

const adjustQty = (delta: number) => adjustQtyByMoq(props.quantity, delta, props.minQty);
</script>

<style scoped>
.dropship-cart-item {
  border-radius: 12px;
  background: #ffffff;
  box-shadow: 0 2px 8px rgba(34, 56, 101, 0.04);
}

.dropship-cart-item__image {
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

.dropship-cart-item__image--compact {
  width: 56px;
  height: 56px;
  min-width: 56px;
}

.dropship-cart-item__image-img {
  width: 100%;
  height: 100%;
}

.dropship-cart-item__image-fallback {
  font-size: 0.35in;
}

.dropship-cart-item__image--compact .dropship-cart-item__image-fallback {
  font-size: 22px;
}

.dropship-cart-item__name {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.3;
}

.quantity-controls {
  background: rgba(34, 56, 101, 0.04);
  border-radius: 16px;
  padding: 1px 4px;
}

.quantity-value {
  min-width: 28px;
  font-size: 14px;
}

.dropship-cart-item__compact {
  display: grid;
  grid-template-columns: 64px minmax(0, 1fr);
  gap: 12px;
  align-items: start;
}

.dropship-cart-item__compact-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 10px;
}

.dropship-cart-item__compact-toolbar {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  gap: 12px 16px;
  align-items: start;
}

.dropship-cart-item__field-label {
  font-size: 11px;
  line-height: 1.2;
  font-weight: 600;
  color: rgba(34, 56, 101, 0.55);
  margin-bottom: 4px;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.dropship-cart-item__field-hint {
  font-size: 11px;
  line-height: 1.3;
  color: rgba(34, 56, 101, 0.5);
  margin-top: 4px;
}

.dropship-cart-item__field--qty {
  min-width: 112px;
}

.dropship-cart-item__field--total {
  min-width: 88px;
  text-align: right;
}

.dropship-cart-item__field--total .dropship-cart-item__field-label {
  text-align: right;
}

.dropship-cart-item__total {
  min-height: 40px;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  padding-top: 2px;
}

.dropship-cart-item__resell-input {
  width: 100%;
}

.quantity-controls--spaced {
  min-height: 40px;
  padding: 4px 10px;
  gap: 6px;
  justify-content: center;
}

.quantity-controls--spaced .quantity-value {
  min-width: 32px;
  font-size: 15px;
}

@media (max-width: 599px) {
  .dropship-cart-item__compact-toolbar {
    grid-template-columns: 1fr 1fr;
    grid-template-areas:
      'resell resell'
      'qty total';
  }

  .dropship-cart-item__field--resell {
    grid-area: resell;
  }

  .dropship-cart-item__field--qty {
    grid-area: qty;
  }

  .dropship-cart-item__field--total {
    grid-area: total;
  }
}
</style>
