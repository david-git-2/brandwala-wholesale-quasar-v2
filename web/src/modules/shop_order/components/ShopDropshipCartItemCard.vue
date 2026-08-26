<template>
  <q-card flat bordered class="dropship-cart-item">
    <q-card-section class="q-pa-sm q-pa-md-sm">
      <div class="row items-center no-wrap q-col-gutter-sm">
        <div class="col-auto">
          <div class="dropship-cart-item__image bg-grey-2">
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
          <div class="text-body2 text-weight-bold text-grey-9 dropship-cart-item__name">
            {{ name }}
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
  }>(),
  {
    imageUrl: null,
    currencySymbol: '৳',
    minQty: 1,
    disableQty: false,
    showSaveQty: false,
    isSaving: false,
  },
);

defineEmits<{
  (e: 'update:quantity', value: number): void;
  (e: 'save-quantity'): void;
}>();

const lineTotal = computed(() => props.price * props.quantity);

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

.dropship-cart-item__image-img {
  width: 100%;
  height: 100%;
}

.dropship-cart-item__image-fallback {
  font-size: 0.35in;
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
</style>
