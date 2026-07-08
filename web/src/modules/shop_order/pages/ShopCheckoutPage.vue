<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <!-- Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="row items-center q-gutter-x-sm">
            <q-btn flat round icon="arrow_back" color="grey-7" @click="goBack" />
            <div>
              <div class="text-overline">Shop &amp; Order</div>
              <h1 class="text-h5 q-my-none">Checkout</h1>
              <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                Provide shipping details and finalize your order.
              </p>
            </div>
          </div>
        </div>
      </section>

      <div class="row q-col-gutter-lg">
        <!-- Delivery and Billing details (8 cols) -->
        <div class="col-xs-12 col-md-8">
          <div class="column q-gutter-md">
            <!-- Shipping Information -->
            <q-card flat bordered class="form-card">
              <q-card-section class="q-px-md q-py-sm border-bottom">
                <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                  <q-icon name="local_shipping" size="18px" class="q-mr-xs text-primary" />
                  Shipping Information
                </div>
              </q-card-section>

              <q-card-section class="q-gutter-md">
                <div class="row q-col-gutter-md">
                  <div class="col-12 col-sm-6">
                    <q-input v-model="recipientName" outlined dense label="Recipient Name" />
                  </div>
                  <div class="col-12 col-sm-6">
                    <q-input v-model="recipientPhone" outlined dense label="Recipient Phone" />
                  </div>
                </div>
                <q-input
                  v-model="shippingAddress"
                  outlined
                  dense
                  type="textarea"
                  label="Shipping Address"
                  rows="3"
                />
              </q-card-section>
            </q-card>

            <!-- Billing Info -->
            <q-card flat bordered class="form-card">
              <q-card-section class="q-px-md q-py-sm border-bottom">
                <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
                  <q-icon name="payment" size="18px" class="q-mr-xs text-primary" />
                  Billing Profile
                </div>
              </q-card-section>

              <q-card-section>
                <q-select
                  v-model="billingProfile"
                  outlined
                  dense
                  label="Select Billing Profile"
                  :options="billingOptions"
                  class="full-width"
                />
                <p class="text-caption text-grey-6 q-mt-sm q-mb-none">
                  Choose the commercial billing account for payment terms.
                </p>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <!-- Checkout Summary (4 cols) -->
        <div class="col-xs-12 col-md-4">
          <q-card flat bordered class="summary-card sticky-card">
            <q-card-section class="q-px-md q-py-sm border-bottom">
              <div class="text-subtitle2 text-weight-bold text-grey-9">Items Summary</div>
            </q-card-section>

            <q-list class="item-list-compact" separator>
              <q-item v-for="item in cartStore.items" :key="item.id" class="q-py-sm">
                <q-item-section avatar>
                  <q-avatar size="36px" rounded class="bg-grey-2">
                    <q-img v-if="item.image_url" :src="item.image_url" />
                    <q-icon v-else name="image" size="18px" color="grey-4" />
                  </q-avatar>
                </q-item-section>
                <q-item-section>
                  <div class="text-caption text-weight-bold text-grey-9 item-name">
                    {{ item.name }}
                  </div>
                  <div class="text-caption text-grey-6">Qty: {{ item.quantity }}</div>
                </q-item-section>
                <q-item-section side v-if="cartStore.cart?.see_price_snapshot">
                  <div class="text-caption text-weight-bold text-grey-9">
                    {{ formatItemTotal(item) }}
                  </div>
                </q-item-section>
              </q-item>
            </q-list>

            <q-separator />

            <q-card-section class="q-py-md">
              <div class="row justify-between items-baseline q-mb-lg">
                <span class="text-subtitle1 text-weight-bold text-grey-9">Estimated Total</span>
                <span
                  v-if="cartStore.cart?.see_price_snapshot"
                  class="text-h6 text-weight-bold text-primary"
                >
                  {{ formatCartTotal() }}
                </span>
                <span v-else class="text-subtitle1 text-grey-5 italic"> Prices Hidden </span>
              </div>

              <!-- PLACE ORDER -->
              <q-btn
                color="primary"
                unelevated
                no-caps
                label="Place Order"
                class="full-width pill-btn text-weight-bold q-py-sm"
                :loading="orderStore.saving"
                :disabled="!recipientName || !recipientPhone || !shippingAddress"
                @click="submitOrder"
              />
            </q-card-section>
          </q-card>
        </div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useShopCartStore } from '../stores/shopCartStore';
import { useShopOrderStore } from '../stores/shopOrderStore';

const route = useRoute();
const router = useRouter();
const cartStore = useShopCartStore();
const orderStore = useShopOrderStore();

const recipientName = ref('');
const recipientPhone = ref('');
const shippingAddress = ref('');
const billingProfile = ref(null);

const billingOptions = ref([
  { label: 'Default Term Account (Net 30)', value: 'default' },
  { label: 'Proforma Invoice (Pre-pay)', value: 'proforma' },
]);

const goBack = () => {
  const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
  void router.push(`${tenantSlug}/shop/cart`);
};

const submitOrder = async () => {
  if (!cartStore.cart?.id) return;
  const res = await orderStore.submitOrder(
    cartStore.cart.id,
    recipientName.value,
    recipientPhone.value,
    shippingAddress.value,
    null,
  );
  if (res.success) {
    cartStore.clearCart();
    const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
    void router.push(`${tenantSlug}/shop/orders`);
  }
};

// Formatting helpers
const formatItemTotal = (item: any) => {
  const price =
    item.customer_sell_price_amount ??
    item.unit_sell_price_amount ??
    item.unit_list_price_amount ??
    0;
  const total = price * item.quantity;
  return `£${total.toFixed(2)}`;
};

const formatCartTotal = () => {
  return `£${cartStore.cartTotal.toFixed(2)}`;
};
</script>

<script lang="ts">
export default {
  name: 'ShopCheckoutPage',
};
</script>

<style scoped>
.form-card,
.summary-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.item-list-compact {
  max-height: 250px;
  overflow-y: auto;
}

.item-name {
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.sticky-card {
  position: sticky;
  top: 24px;
}

.font-semibold {
  font-weight: 500;
}

.italic {
  font-style: italic;
}
</style>
