<template>
  <div class="product-grid q-col-gutter-md row">
    <div
      v-for="product in products"
      :key="product.id"
      class="col-12 col-sm-6 col-md-4 product-card-wrapper"
    >
      <q-card flat bordered class="product-card full-height flex flex-column justify-between">
        <!-- Badge for Brand -->
        <div class="brand-badge-container">
          <q-badge outline color="secondary" class="brand-badge text-weight-medium">
            {{ product.brand || 'No Brand' }}
          </q-badge>
        </div>

        <!-- Product Image / Placeholder -->
        <div class="product-image-container flex flex-center">
          <img
            v-if="product.image_url"
            :src="product.image_url"
            :alt="product.name"
            class="product-image"
          />
          <div v-else class="product-image-placeholder flex flex-center">
            <q-icon name="shopping_bag" size="40px" class="text-grey-4" />
          </div>
        </div>

        <q-card-section class="q-pa-sm q-pt-md">
          <div class="product-name text-weight-bold text-grey-9 line-clamp-2">
            {{ product.name || 'Unnamed Product' }}
          </div>
          <div class="text-caption text-grey-6 q-mt-xs">
            SKU: {{ product.product_code || 'N/A' }}
          </div>

          <!-- Pricing Section -->
          <div class="price-section q-mt-sm">
            <div class="text-caption text-grey-5" v-if="pricingMethod === 'markup'">
              Base cost: ${{ getBaseCost(product).toFixed(2) }}
            </div>
            <div class="price-row flex items-baseline gap-xs">
              <span class="final-price text-h6 text-weight-bold text-primary">
                ${{ calculatePrice(product).toFixed(2) }}
              </span>
              <span v-if="pricingMethod === 'markup'" class="text-caption text-grey-6 text-weight-medium">
                (+{{ markupPercentage }}%)
              </span>
            </div>
          </div>
        </q-card-section>

        <q-card-actions class="q-pa-sm flex flex-column gap-sm items-stretch">
          <!-- Quantity Selector -->
          <ShopPreviewQuantitySelector
            :model-value="getCartQty(product.id)"
            :stock="product.available_units || 0"
            :show-stock-quantity="showStockQuantity"
            @update:model-value="val => $emit('update-quantity', product.id, val)"
          />

          <!-- Negotiation Actions -->
          <div v-if="isNegotiable" class="negotiation-box q-mt-xs">
            <div v-if="getNegotiatedPrice(product.id) !== null" class="negotiated-tag text-caption bg-amber-1 text-amber-9 q-pa-xs rounded-borders flex items-center justify-between">
              <span>Offer: <strong>${{ getNegotiatedPrice(product.id)?.toFixed(2) }}</strong></span>
              <q-btn
                flat
                round
                dense
                size="xs"
                icon="close"
                color="amber-9"
                @click="$emit('negotiate-price', product.id, null)"
              />
            </div>
            <q-btn
              v-else
              outline
              color="amber-9"
              size="sm"
              icon="handshake"
              label="Negotiate Price"
              class="full-width negotiate-btn"
              @click="promptNegotiation(product)"
            />
          </div>
        </q-card-actions>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import ShopPreviewQuantitySelector from './ShopPreviewQuantitySelector.vue';
import { useQuasar } from 'quasar';

const props = withDefaults(
  defineProps<{
    products: any[];
    pricingMethod: 'direct_cost' | 'markup';
    markupPercentage: number;
    isNegotiable: boolean;
    showStockQuantity: boolean;
    cartItems: Record<number, number>;
    negotiatedPrices: Record<number, number | null>;
  }>(),
  {
    products: () => [],
    pricingMethod: 'direct_cost',
    markupPercentage: 0,
    isNegotiable: false,
    showStockQuantity: true,
    cartItems: () => ({}),
    negotiatedPrices: () => ({}),
  }
);

const emit = defineEmits<{
  (e: 'update-quantity', productId: number, quantity: number): void;
  (e: 'negotiate-price', productId: number, price: number | null): void;
}>();

const $q = useQuasar();

const getBaseCost = (product: any): number => {
  return product.reference_cost_amount || product.list_price_amount || 0;
};

const calculatePrice = (product: any): number => {
  const base = getBaseCost(product);
  if (props.pricingMethod === 'markup') {
    return base * (1 + (props.markupPercentage || 0) / 100);
  }
  return base;
};

const getCartQty = (productId: number): number => {
  return props.cartItems[productId] || 0;
};

const getNegotiatedPrice = (productId: number): number | null => {
  return props.negotiatedPrices[productId] ?? null;
};

const promptNegotiation = (product: any) => {
  const currentPrice = calculatePrice(product);
  $q.dialog({
    title: 'Negotiate Price',
    message: `Propose your buying price per unit (Current: $${currentPrice.toFixed(2)}):`,
    prompt: {
      model: String((currentPrice * 0.9).toFixed(2)),
      type: 'number',
    },
    cancel: true,
    persistent: true,
  }).onOk((data: string) => {
    const offeredPrice = parseFloat(data);
    if (!isNaN(offeredPrice) && offeredPrice > 0) {
      emit('negotiate-price', product.id, offeredPrice);
    }
  });
};
</script>

<style scoped>
.product-grid {
  margin: 0;
}

.product-card {
  border-radius: 12px;
  position: relative;
  overflow: hidden;
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  background: white;
}

.product-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
  border-color: rgba(var(--q-primary), 0.4);
}

.brand-badge-container {
  position: absolute;
  top: 8px;
  left: 8px;
  z-index: 2;
}

.brand-badge {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(4px);
}

.product-image-container {
  height: 160px;
  background: #f8fafc;
  width: 100%;
  border-bottom: 1px solid rgba(0, 0, 0, 0.03);
}

.product-image {
  max-height: 100%;
  max-width: 100%;
  object-fit: contain;
  padding: 8px;
}

.product-image-placeholder {
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%);
}

.product-name {
  font-size: 13px;
  line-height: 1.4;
  height: 36px;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.price-row {
  display: flex;
  align-items: center;
}

.final-price {
  letter-spacing: -0.5px;
}

.negotiate-btn {
  border-radius: 8px;
  text-transform: none;
}

.negotiated-tag {
  border: 1px dashed #d97706;
}

.gap-sm {
  gap: 8px;
}
.gap-xs {
  gap: 4px;
}
</style>
