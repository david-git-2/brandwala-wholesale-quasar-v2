<template>
  <div>
    <!-- DESKTOP DRAWER (Screen size > xs) -->
    <q-drawer
      v-if="!$q.screen.xs"
      :model-value="modelValue"
      side="right"
      overlay
      elevated
      :width="drawerWidth"
      class="quick-view-drawer theme-shop"
      @update:model-value="$emit('update:modelValue', $event)"
    >
      <div v-if="product" class="column full-height quick-view-content">
        <!-- Drawer Header -->
        <div class="row items-center justify-between q-pa-md border-bottom bg-surface">
          <div class="row items-center q-gutter-xs">
            <q-icon name="ph ph-eye" color="primary" size="20px" />
            <div class="text-subtitle1 text-weight-bold">{{ $t('shop.quick_view') }}</div>
          </div>
          <q-btn flat round dense icon="ph ph-x" color="grey-7" @click="close" />
        </div>

        <!-- Scrollable Content -->
        <div class="col scroll q-pa-md q-gutter-y-md">
          <!-- Image Section / Carousel -->
          <div class="product-media-container rounded-borders overflow-hidden bg-grey-1 relative-position">
            <q-carousel
              v-if="images.length > 0"
              v-model="activeSlide"
              animated
              arrows
              navigation
              infinite
              height="280px"
              class="product-carousel"
            >
              <q-carousel-slide
                v-for="(img, idx) in images"
                :key="idx"
                :name="idx"
                :img-src="img"
                class="column no-wrap flex-center"
              />
            </q-carousel>
            <div v-else class="column flex-center product-media-placeholder py-xl" style="height: 280px">
              <q-icon name="ph ph-image-square" size="48px" color="grey-4" />
              <div class="text-caption text-grey-5 q-mt-xs">{{ $t('shop.no_image_available') }}</div>
            </div>
          </div>

          <!-- Product Meta Info -->
          <div>
            <div class="row items-center justify-between q-mb-xs">
              <span class="text-caption text-uppercase text-weight-medium text-grey-7">
                {{ product.product_brand || 'Generic' }}
              </span>
              <q-badge
                v-if="permissions?.can_view_quantity && product.available_units !== null"
                :color="product.available_units > 0 ? 'positive' : 'negative'"
                outline
                class="text-weight-bold"
              >
                {{ product.available_units }} {{ $t('shop.avail') }}
              </q-badge>
            </div>
            <h2 class="text-h6 text-weight-bold q-my-none text-grey-9 leading-snug">
              {{ product.product_name }}
            </h2>
            <div v-if="product.sku" class="text-caption text-grey-6 q-mt-xs">
              SKU: <span class="text-mono">{{ product.sku }}</span>
            </div>
          </div>

          <!-- Pricing Block -->
          <q-card flat bordered class="q-pa-sm bg-grey-1">
            <div class="row items-baseline justify-between">
              <div>
                <span class="text-caption text-grey-7 block text-weight-medium">
                  {{ shopDetails?.shop_type === 'dropship' ? $t('shop.wholesale_price') : $t('shop.unit_price') }}
                </span>
                <span class="text-h6 text-weight-bold text-primary">
                  {{ formatMoney(product.unit_price_amount, product.unit_price_currency_symbol) }}
                </span>
              </div>
              <div v-if="product.minimum_sell_price_amount != null" class="text-right">
                <span class="text-caption text-grey-7 block text-weight-medium">
                  {{ $t('shop.min_sell_price') }}
                </span>
                <span class="text-subtitle2 text-weight-bold text-secondary">
                  {{ formatMoney(product.minimum_sell_price_amount, product.minimum_sell_price_currency_symbol) }}
                </span>
              </div>
            </div>
          </q-card>

          <!-- MOQ Warning -->
          <q-banner
            v-if="product.moq && product.moq > 1"
            dense
            rounded
            class="bg-warning-soft text-warning-dark border-warning"
          >
            <template #avatar>
              <q-icon name="ph ph-info" color="warning" size="20px" />
            </template>
            <div class="text-caption text-weight-medium">
              {{ $t('shop.moq_notice', { count: product.moq }) }}
            </div>
          </q-banner>

          <!-- Description / Specifications -->
          <div v-if="product.description || product.specifications">
            <div class="text-subtitle2 text-weight-bold text-grey-8 q-mb-xs">
              {{ $t('shop.description') }}
            </div>
            <p class="text-body2 text-grey-7 multiline-text q-mb-none">
              {{ product.description || product.specifications }}
            </p>
          </div>
        </div>

        <!-- Sticky Footer Action Bar -->
        <div class="q-pa-md border-top bg-surface">
          <div class="row items-center q-col-gutter-sm">
            <div class="col-auto">
              <div class="row items-center no-wrap quantity-stepper">
                <q-btn
                  flat
                  dense
                  round
                  icon="ph ph-minus"
                  size="sm"
                  :disabled="quantity <= 1"
                  @click="decrementQty"
                />
                <q-input
                  v-model.number="quantity"
                  dense
                  borderless
                  type="number"
                  input-class="text-center text-weight-bold text-body2"
                  style="width: 44px"
                  :min="1"
                  @blur="validateQuantity"
                />
                <q-btn flat dense round icon="ph ph-plus" size="sm" @click="incrementQty" />
              </div>
            </div>
            <div class="col">
              <q-btn
                color="primary"
                unelevated
                no-caps
                class="full-width pill-btn text-weight-bold"
                :loading="saving"
                :disabled="product.available_units === 0"
                @click="onAddToCart"
              >
                <q-icon name="ph ph-shopping-cart" size="18px" class="q-mr-xs" />
                {{ cartItem ? $t('shop.update_cart') : $t('shop.add_to_cart') }}
              </q-btn>
            </div>
          </div>
        </div>
      </div>
    </q-drawer>

    <!-- MOBILE BOTTOM SHEET DIALOG (Screen size xs) -->
    <q-dialog
      v-else
      :model-value="modelValue"
      position="bottom"
      class="quick-view-bottom-sheet theme-shop"
      @update:model-value="$emit('update:modelValue', $event)"
    >
      <q-card flat class="bottom-sheet-card column rounded-top-lg">
        <!-- Handlebar -->
        <div class="row justify-center q-py-xs">
          <div class="bottom-sheet-handle"></div>
        </div>

        <div v-if="product" class="q-pa-md column q-gutter-y-md max-height-mobile-sheet scroll">
          <!-- Header -->
          <div class="row items-center justify-between">
            <div class="text-caption text-uppercase text-weight-medium text-grey-7">
              {{ product.product_brand || 'Generic' }}
            </div>
            <q-btn flat round dense icon="ph ph-x" color="grey-7" @click="close" />
          </div>

          <h2 class="text-subtitle1 text-weight-bold q-my-none text-grey-9">
            {{ product.product_name }}
          </h2>

          <!-- Image Carousel -->
          <div class="product-media-container rounded-borders overflow-hidden bg-grey-1 relative-position">
            <q-carousel
              v-if="images.length > 0"
              v-model="activeSlide"
              animated
              arrows
              navigation
              infinite
              height="200px"
              class="product-carousel"
            >
              <q-carousel-slide
                v-for="(img, idx) in images"
                :key="idx"
                :name="idx"
                :img-src="img"
                class="column no-wrap flex-center"
              />
            </q-carousel>
            <div v-else class="column flex-center product-media-placeholder" style="height: 200px">
              <q-icon name="ph ph-image-square" size="36px" color="grey-4" />
            </div>
          </div>

          <!-- Pricing & Stock -->
          <div class="row items-center justify-between">
            <div>
              <div class="text-caption text-grey-6">{{ $t('shop.unit_price') }}</div>
              <div class="text-h6 text-weight-bold text-primary">
                {{ formatMoney(product.unit_price_amount, product.unit_price_currency_symbol) }}
              </div>
            </div>
            <q-badge
              v-if="permissions?.can_view_quantity && product.available_units !== null"
              :color="product.available_units > 0 ? 'positive' : 'negative'"
              outline
              class="text-weight-bold"
            >
              {{ product.available_units }} {{ $t('shop.avail') }}
            </q-badge>
          </div>

          <!-- Action Bar -->
          <div class="row items-center q-col-gutter-sm q-pt-sm border-top">
            <div class="col-auto">
              <div class="row items-center no-wrap quantity-stepper">
                <q-btn
                  flat
                  dense
                  round
                  icon="ph ph-minus"
                  size="sm"
                  :disabled="quantity <= 1"
                  @click="decrementQty"
                />
                <q-input
                  v-model.number="quantity"
                  dense
                  borderless
                  type="number"
                  input-class="text-center text-weight-bold text-body2"
                  style="width: 40px"
                  :min="1"
                  @blur="validateQuantity"
                />
                <q-btn flat dense round icon="ph ph-plus" size="sm" @click="incrementQty" />
              </div>
            </div>
            <div class="col">
              <q-btn
                color="primary"
                unelevated
                no-caps
                class="full-width pill-btn text-weight-bold"
                :loading="saving"
                :disabled="product.available_units === 0"
                @click="onAddToCart"
              >
                <q-icon name="ph ph-shopping-cart" size="18px" class="q-mr-xs" />
                {{ cartItem ? $t('shop.update_cart') : $t('shop.add_to_cart') }}
              </q-btn>
            </div>
          </div>
        </div>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useQuasar } from 'quasar';

const props = defineProps<{
  modelValue: boolean;
  product: any | null;
  shopDetails?: any | null;
  permissions?: any | null;
  cartItem?: any | null;
  saving?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'add-to-cart', payload: { product: any; quantity: number }): void;
}>();

const $q = useQuasar();
const activeSlide = ref(0);
const quantity = ref(1);

const drawerWidth = computed(() => {
  if ($q.screen.gt.md) return 460;
  return 380;
});

const images = computed(() => {
  if (!props.product) return [];
  const list: string[] = [];
  if (props.product.product_image_url) {
    list.push(props.product.product_image_url);
  }
  if (Array.isArray(props.product.gallery_images)) {
    props.product.gallery_images.forEach((img: string) => {
      if (img && !list.includes(img)) list.push(img);
    });
  }
  return list;
});

watch(
  () => props.product,
  (newProd) => {
    if (newProd) {
      activeSlide.value = 0;
      quantity.value = props.cartItem?.quantity || newProd.moq || 1;
    }
  },
  { immediate: true },
);

watch(
  () => props.cartItem,
  (newItem) => {
    if (newItem) {
      quantity.value = newItem.quantity;
    }
  },
);

function close() {
  emit('update:modelValue', false);
}

function incrementQty() {
  quantity.value++;
}

function decrementQty() {
  if (quantity.value > 1) {
    quantity.value--;
  }
}

function validateQuantity() {
  if (!quantity.value || quantity.value < 1) {
    quantity.value = 1;
  }
}

function formatMoney(amount?: number | null, symbol?: string | null): string {
  if (amount == null || Number.isNaN(amount)) return '-';
  const sym = symbol || '$';
  return `${sym}${Number(amount).toFixed(2)}`;
}

function onAddToCart() {
  if (!props.product) return;
  emit('add-to-cart', {
    product: props.product,
    quantity: quantity.value,
  });
}
</script>

<style scoped lang="scss">
.border-bottom {
  border-bottom: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.12));
}

.border-top {
  border-top: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.12));
}

.bg-surface {
  background-color: var(--bw-theme-surface, #ffffff);
}

.quantity-stepper {
  border: 1.5px solid var(--bw-theme-border, rgba(34, 56, 101, 0.18));
  border-radius: 8px;
  padding: 2px 4px;
}

.bottom-sheet-card {
  max-height: 85vh;
  border-top-left-radius: 16px;
  border-top-right-radius: 16px;
  background-color: var(--bw-theme-base, #ffffff);
}

.bottom-sheet-handle {
  width: 40px;
  height: 4px;
  border-radius: 2px;
  background-color: rgba(0, 0, 0, 0.2);
}

.bg-warning-soft {
  background-color: rgba(245, 158, 11, 0.1);
}

.text-warning-dark {
  color: #b45309;
}

.border-warning {
  border: 1px solid rgba(245, 158, 11, 0.3);
}

.max-height-mobile-sheet {
  max-height: calc(85vh - 20px);
}
</style>
