<template>
  <div :class="fullPage ? 'shop-preview-full-page' : 'shop-preview-wrapper q-pa-md flex flex-center'">
    <!-- Outer Mock Web Browser Frame -->
    <div :class="fullPage ? 'browser-frame-full' : 'browser-frame shadow-24'">
      <!-- Browser Titlebar / Controls -->
      <div v-if="!fullPage" class="browser-header-bar flex items-center q-px-md gap-sm">
        <div class="flex items-center gap-xs">
          <div class="window-dot red"></div>
          <div class="window-dot yellow"></div>
          <div class="window-dot green"></div>
        </div>
        
        <!-- Address Bar -->
        <div class="address-bar col flex items-center justify-center text-caption text-grey-6 bg-grey-2 rounded q-mx-md q-py-xs">
          <q-icon name="lock" size="12px" class="q-mr-xs text-success" />
          <span>https://brandwala.com/shop/{{ shopName.toLowerCase().replace(/\s+/g, '-') || 'preview' }}</span>
        </div>
      </div>

      <!-- Browser Content Viewport -->
      <div class="viewport flex flex-column">
        <!-- Sandbox Mode Warning Banner -->
        <div class="sandbox-banner bg-amber text-black text-weight-bold text-center text-caption q-py-xs">
          <q-icon name="warning" size="16px" class="q-mr-xs" />
          Interactive Storefront Web Preview — Changes Not Saved
        </div>

        <!-- Store Web Header -->
        <div class="store-header bg-primary text-white q-py-md q-px-lg flex items-center justify-between shadow-2">
          <div class="store-info">
            <div class="store-name text-h6 text-weight-bold">
              {{ shopName || 'My Wholesale Shop' }}
            </div>
            <div class="text-caption text-blue-2 capitalize">
              {{ shopType?.replace('_', ' ') || 'Catalog' }} Storefront
            </div>
          </div>
          <!-- Cart Trigger -->
          <q-btn flat round dense icon="shopping_cart" size="lg" @click="showCart = true">
            <q-badge color="amber text-black" floating v-if="cartTotalQuantity > 0">
              {{ cartTotalQuantity }}
            </q-badge>
          </q-btn>
        </div>

        <!-- Filter & Search Controls in Desktop Row Layout -->
        <div class="filter-panel bg-white q-pa-md shadow-1">
          <div class="row q-col-gutter-md items-center">
            <div class="col-12 col-md-6">
              <q-input
                v-model="searchQuery"
                dense
                outlined
                placeholder="Search products by name or SKU..."
                class="search-bar"
              >
                <template v-slot:append>
                  <q-icon name="search" />
                </template>
              </q-input>
            </div>
            <div class="col-6 col-md-3">
              <q-select
                v-model="selectedBrand"
                :options="brandOptions"
                dense
                outlined
                label="Filter by Brand"
                emit-value
                map-options
                clearable
                class="full-width"
              />
            </div>
            <div class="col-6 col-md-3">
              <q-select
                v-model="selectedCategory"
                :options="categoryOptions"
                dense
                outlined
                label="Filter by Category"
                emit-value
                map-options
                clearable
                class="full-width"
              />
            </div>
          </div>
        </div>

        <!-- Catalog Scroll Area -->
        <div class="catalog-scroll-container col q-pa-lg scroll">
          <div v-if="isLoading" class="row q-col-gutter-md">
            <div v-for="n in 3" :key="n" class="col-12 col-sm-6 col-md-4">
              <q-card flat bordered style="border-radius: 12px; height: 260px;" class="q-mb-sm">
                <q-skeleton height="120px" square />
                <q-card-section class="q-pa-sm">
                  <q-skeleton type="text" width="80%" class="q-mb-xs" />
                  <q-skeleton type="text" width="45%" class="q-mb-md" />
                  <q-skeleton type="QBtn" width="60%" />
                </q-card-section>
              </q-card>
            </div>
          </div>
          <div v-else-if="filteredProducts.length === 0" class="flex flex-center flex-column q-py-xl">
            <q-icon name="search_off" size="48px" class="text-grey-4 q-mb-sm" />
            <div class="text-subtitle2 text-grey-6">No products match your filters</div>
          </div>
          <ShopPreviewProductList
            v-else
            :products="filteredProducts"
            :pricing-method="pricingMethod"
            :markup-percentage="markupPercentage"
            :is-negotiable="isNegotiable"
            :show-stock-quantity="showStockQuantity"
            :cart-items="cart"
            :negotiated-prices="negotiatedPrices"
            @update-quantity="updateCartQty"
            @negotiate-price="updateNegotiatedPrice"
          />
        </div>
      </div>
    </div>

    <!-- Dummy Cart Dialog -->
    <q-dialog v-model="showCart">
      <q-card class="cart-dialog-card">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-weight-bold">Simulated Shopping Cart</div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pt-md">
          <div v-if="cartItemsList.length === 0" class="flex flex-center flex-column q-py-lg">
            <q-icon name="shopping_cart" size="48px" class="text-grey-3 q-mb-sm" />
            <div class="text-grey-6 text-subtitle2">Your cart is empty</div>
          </div>
          <q-list v-else separator class="cart-items-list">
            <q-item v-for="item in cartItemsList" :key="item.product.id" class="q-px-none">
              <q-item-section avatar>
                <q-avatar rounded size="48px" class="bg-grey-2">
                  <img v-if="item.product.image_url" :src="item.product.image_url" />
                  <q-icon v-else name="shopping_bag" color="grey-6" />
                </q-avatar>
              </q-item-section>

              <q-item-section>
                <q-item-label class="text-weight-bold">{{ item.product.name }}</q-item-label>
                <q-item-label caption>
                  Brand: {{ item.product.brand || 'No Brand' }}
                </q-item-label>
                <q-item-label caption class="text-amber-9 text-weight-bold" v-if="item.negotiatedPrice !== null">
                  Negotiated Price: ${{ item.negotiatedPrice.toFixed(2) }}
                </q-item-label>
              </q-item-section>

              <q-item-section side class="text-right">
                <div class="text-weight-bold text-grey-9">
                  ${{ ((item.negotiatedPrice ?? item.unitPrice) * item.qty).toFixed(2) }}
                </div>
                <div class="text-caption text-grey-6">
                  {{ item.qty }} x ${{ (item.negotiatedPrice ?? item.unitPrice).toFixed(2) }}
                </div>
                <div class="flex items-center gap-xs q-mt-xs justify-end">
                  <q-btn flat round dense size="xs" icon="remove" color="primary" @click="updateCartQty(item.product.id, item.qty - 1)" />
                  <span class="text-caption text-weight-bold">{{ item.qty }}</span>
                  <q-btn flat round dense size="xs" icon="add" color="primary" @click="updateCartQty(item.product.id, item.qty + 1)" :disable="item.qty >= (item.product.available_units || 0)" />
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card-section>

        <q-separator v-if="cartItemsList.length > 0" />

        <q-card-section v-if="cartItemsList.length > 0" class="flex flex-column gap-sm">
          <div class="flex justify-between items-baseline">
            <span class="text-subtitle1 text-grey-7">Grand Total:</span>
            <span class="text-h5 text-weight-bold text-primary">${{ cartTotalAmount.toFixed(2) }}</span>
          </div>

          <div v-if="shopType === 'dropship'" class="text-caption text-grey-6">
            COD and delivery are set by the courier after processing and may vary.
            Estimated delivery: $60–$130; COD typically ~1%.
          </div>

          <!-- CTA based on Order Mode -->
          <q-btn
            color="primary"
            class="full-width q-py-sm text-weight-bold text-capitalize checkout-btn"
            :label="checkoutCTALabel"
            icon="shopping_bag"
            @click="simulateCheckout"
          />
        </q-card-section>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useQuasar } from 'quasar';
import ShopPreviewProductList from './ShopPreviewProductList.vue';
import { shopPricingService } from '../services/shopPricingService';

const props = withDefaults(
  defineProps<{
    shopName: string;
    shopType: 'vendor_catalog' | 'fixed_price' | 'dropship' | null;
    orderMode: 'procurement_intent' | 'checkout_fixed' | 'checkout_wholesale';
    pricingMethod: 'direct_cost' | 'markup';
    markupPercentage: number;
    isNegotiable: boolean;
    showStockQuantity: boolean;
    vendorFilters?: Array<{ vendor_code: string; brands: string[] }> | null;
    fullPage?: boolean;
  }>(),
  {
    shopName: 'Demo Store',
    shopType: 'vendor_catalog',
    orderMode: 'procurement_intent',
    pricingMethod: 'direct_cost',
    markupPercentage: 0,
    isNegotiable: false,
    showStockQuantity: true,
    vendorFilters: () => [],
    fullPage: false,
  }
);

const $q = useQuasar();

// --- Static Mock Products Fallback ---
const mockProducts = [
  { id: 101, name: 'CeraVe Moisturizing Cream 454g', brand: 'CeraVe', category: 'Skincare', reference_cost_amount: 14.50, available_units: 45, product_code: 'CV-MC-454', vendor_code: 'COCOON' },
  { id: 102, name: 'Sensodyne Rapid Relief Toothpaste 75ml', brand: 'Sensodyne', category: 'Dental Care', reference_cost_amount: 4.80, available_units: 120, product_code: 'SEN-RR-75', vendor_code: 'WTS' },
  { id: 103, name: 'Brylcreem Original Hair Dressing 150ml', brand: 'Brylcreem', category: 'Haircare', reference_cost_amount: 5.20, available_units: 30, product_code: 'BRY-HD-150', vendor_code: 'WTS' },
  { id: 104, name: 'La Roche-Posay Anthelios SPF50+ 50ml', brand: 'La Roche-Posay', category: 'Skincare', reference_cost_amount: 18.00, available_units: 25, product_code: 'LRP-ANT-50', vendor_code: 'COCOON' },
  { id: 105, name: 'CeraVe Foaming Cleanser 236ml', brand: 'CeraVe', category: 'Skincare', reference_cost_amount: 9.80, available_units: 60, product_code: 'CV-FC-236', vendor_code: 'COCOON' },
  { id: 106, name: 'Colgate Total Original Toothpaste 75ml', brand: 'Colgate', category: 'Dental Care', reference_cost_amount: 2.10, available_units: 150, product_code: 'COL-TOT-75', vendor_code: 'WTS' },
];

const productsList = ref<any[]>(mockProducts);
const isLoading = ref(false);
let fetchTimeout: ReturnType<typeof setTimeout> | null = null;

const loadRealProducts = async () => {
  isLoading.value = true;
  try {
    const res = await shopPricingService.fetchPreviewProducts(props.vendorFilters || []);
    if (res.success && res.data && res.data.length > 0) {
      productsList.value = res.data;
    } else {
      productsList.value = mockProducts;
    }
  } catch {
    productsList.value = mockProducts;
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => props.vendorFilters,
  () => {
    if (fetchTimeout) clearTimeout(fetchTimeout);
    fetchTimeout = setTimeout(() => {
      void loadRealProducts();
    }, 400);
  },
  { deep: true, immediate: true }
);

// --- Filters & State ---
const searchQuery = ref('');
const selectedBrand = ref<string | null>(null);
const selectedCategory = ref<string | null>(null);
const showCart = ref(false);

// --- Dummy Cart State ---
const cart = ref<Record<number, number>>({});
const negotiatedPrices = ref<Record<number, number | null>>({});

// --- Unique brands and categories for options ---
const brandOptions = computed(() => {
  const brands = new Set(productsList.value.map(p => p.brand).filter(Boolean));
  return Array.from(brands).map(b => ({ label: b, value: b }));
});

const categoryOptions = computed(() => {
  const cats = new Set(productsList.value.map(p => p.category).filter(Boolean));
  return Array.from(cats).map(c => ({ label: c, value: c }));
});

// --- Filtered catalog list ---
const filteredProducts = computed(() => {
  return productsList.value.filter(product => {
    const matchesSearch = !searchQuery.value || product.name.toLowerCase().includes(searchQuery.value.toLowerCase()) || product.product_code.toLowerCase().includes(searchQuery.value.toLowerCase());
    const matchesBrand = !selectedBrand.value || product.brand === selectedBrand.value;
    const matchesCategory = !selectedCategory.value || product.category === selectedCategory.value;
    return matchesSearch && matchesBrand && matchesCategory;
  });
});

// --- Cart computation ---
const cartTotalQuantity = computed(() => {
  return Object.values(cart.value).reduce((a, b) => a + b, 0);
});

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

const cartItemsList = computed(() => {
  return Object.entries(cart.value)
    .map(([idStr, qty]) => {
      const id = parseInt(idStr);
      const product = productsList.value.find(p => p.id === id);
      if (!product) return null;
      return {
        product,
        qty,
        unitPrice: calculatePrice(product),
        negotiatedPrice: negotiatedPrices.value[product.id] ?? null,
      };
    })
    .filter((item): item is NonNullable<typeof item> => item !== null);
});

const cartTotalAmount = computed(() => {
  return cartItemsList.value.reduce((total, item) => {
    const price = item.negotiatedPrice ?? item.unitPrice;
    return total + price * item.qty;
  }, 0);
});

// --- CTA checkout labels based on shop configurations ---
const checkoutCTALabel = computed(() => {
  if (props.orderMode === 'procurement_intent') {
    return 'Submit Procurement Intent';
  }
  if (props.orderMode === 'checkout_wholesale') {
    return 'Checkout (Wholesale)';
  }
  return 'Checkout (Fixed Price)';
});

// --- Actions ---
const updateCartQty = (productId: number, quantity: number) => {
  if (quantity <= 0) {
    delete cart.value[productId];
  } else {
    cart.value[productId] = quantity;
  }
  saveCart();
};

const updateNegotiatedPrice = (productId: number, price: number | null) => {
  negotiatedPrices.value[productId] = price;
  saveCart();
};

const simulateCheckout = () => {
  showCart.value = false;
  $q.notify({
    type: 'positive',
    message: `Sandbox checkout simulated: "${checkoutCTALabel.value}" submitted successfully!`,
    caption: `Simulated order total: $${cartTotalAmount.value.toFixed(2)}`,
    icon: 'check',
    position: 'bottom',
    timeout: 3000,
  });
  // Clear cart after checkout
  cart.value = {};
  negotiatedPrices.value = {};
  saveCart();
};

// --- Storage management ---
const saveCart = () => {
  try {
    sessionStorage.setItem('shop_preview_cart_demo', JSON.stringify({
      cart: cart.value,
      negotiatedPrices: negotiatedPrices.value,
    }));
  } catch {
    // Ignore storage issues
  }
};

const loadCart = () => {
  try {
    const data = sessionStorage.getItem('shop_preview_cart_demo');
    if (data) {
      const parsed = JSON.parse(data);
      if (parsed.cart) cart.value = parsed.cart;
      if (parsed.negotiatedPrices) negotiatedPrices.value = parsed.negotiatedPrices;
    }
  } catch {
    // Ignore storage issues
  }
};

onMounted(() => {
  loadCart();
});
</script>

<style scoped>
.shop-preview-wrapper {
  background: radial-gradient(circle at center, #f8fafc, #f1f5f9);
  border-radius: 16px;
  overflow: hidden;
  height: 100%;
  width: 100%;
  min-height: 550px;
}

.shop-preview-full-page {
  width: 100%;
  height: 100%;
  overflow: hidden;
}

.browser-frame-full {
  width: 100%;
  height: 100%;
  background: transparent;
  display: flex;
  flex-direction: column;
}

.browser-frame {
  width: 100%;
  max-width: 1100px;
  height: 680px;
  background: #f1f5f9;
  border-radius: 12px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  position: relative;
  border: 1px solid #cbd5e1;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.15);
  overflow: hidden;
}

.browser-header-bar {
  height: 40px;
  background: #e2e8f0;
  border-bottom: 1px solid #cbd5e1;
}

.window-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.window-dot.red { background: #ef4444; }
.window-dot.yellow { background: #f59e0b; }
.window-dot.green { background: #10b981; }

.address-bar {
  background: white;
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  max-width: 600px;
}

.viewport {
  background: #f8fafc;
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.sandbox-banner {
  font-size: 11px;
  letter-spacing: 0.5px;
}

.store-header {
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
}

.catalog-scroll-container {
  background: #f8fafc;
}

.cart-dialog-card {
  width: 100%;
  max-width: 480px;
  border-radius: 16px;
}

.cart-items-list {
  max-height: 400px;
  overflow-y: auto;
}

.checkout-btn {
  border-radius: 10px;
}

.gap-sm {
  gap: 8px;
}
.gap-xs {
  gap: 4px;
}
</style>

