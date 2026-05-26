<template>
  <q-page class="bw-page q-pa-md">
    <!-- Header -->
    <div class="cart-header q-mb-md">
      <div class="row items-center q-gutter-sm">
        <q-btn flat round icon="arrow_back" color="grey-8" :to="{ name: productsRouteName }" />
        <div>
          <div class="text-h5 text-weight-bold">Cart</div>
          <div class="text-caption text-grey-7">
            {{ cartStore.items.length }} item{{ cartStore.items.length === 1 ? '' : 's' }} in your cart
          </div>
        </div>
      </div>
      <div class="row items-center q-gutter-sm">
        <q-btn
          flat
          no-caps
          color="primary"
          icon="receipt_long"
          label="View Orders"
          :to="{ name: ordersRouteName }"
        />
        <q-btn
          v-if="cartStore.items.length > 0"
          outline
          color="negative"
          icon="delete_sweep"
          label="Clear Cart"
          no-caps
          :loading="cartStore.saving"
          @click="onClearCart"
        />
      </div>
    </div>

    <!-- Empty State -->
    <div v-if="cartStore.items.length === 0" class="empty-state-card q-pa-xl text-center">
      <q-icon name="shopping_cart" size="64px" color="grey-4" class="q-mb-md" />
      <div class="text-h6 text-grey-8 text-weight-medium">Your cart is empty</div>
      <div class="text-caption text-grey-6 q-mb-lg">Add some products from the catalog to get started.</div>
      <q-btn
        color="primary"
        label="Browse Products"
        no-caps
        unelevated
        :to="{ name: productsRouteName }"
      />
    </div>

    <!-- Cart Layout Grid -->
    <div v-else class="row q-col-gutter-md">
      <!-- Left: Cart Items List -->
      <div class="col-12 col-md-8">
        <q-card flat class="cart-card">
          <q-list separator>
            <q-item v-for="item in cartStore.items" :key="item.id" class="q-py-md item-row">
              <q-item-section avatar>
                <q-avatar square size="70px" class="bg-grey-2 item-avatar">
                  <img v-if="item.image_url" :src="toDirectGoogleImageUrl(item.image_url)" referrerpolicy="no-referrer" />
                  <q-icon v-else name="image_not_supported" color="grey-5" />
                </q-avatar>
              </q-item-section>

              <q-item-section>
                <div class="text-caption text-primary text-uppercase text-weight-bold" v-if="item.brand">{{ item.brand }}</div>
                <div class="text-subtitle1 text-weight-bold text-grey-9 item-name">{{ item.name }}</div>
                
                <!-- Qty Stepper and Save / Delete actions -->
                <div class="row items-center q-gutter-sm q-mt-sm">
                  <div class="qty-stepper">
                    <q-btn
                      flat dense round
                      icon="remove"
                      size="xs"
                      :disable="getDraftQty(item) <= item.case_size"
                      @click="bumpQty(item, -1)"
                    />
                    <span class="qty-value">{{ getDraftQty(item) }}</span>
                    <q-btn
                      flat dense round
                      icon="add"
                      size="xs"
                      @click="bumpQty(item, 1)"
                    />
                  </div>

                  <q-btn
                    v-if="isDirty(item)"
                    color="primary"
                    icon="save"
                    label="Save"
                    no-caps
                    dense
                    unelevated
                    size="sm"
                    class="q-px-sm"
                    :loading="cartStore.saving"
                    @click="onSaveItem(item)"
                  />

                  <q-btn
                    flat
                    round
                    color="negative"
                    icon="delete"
                    size="sm"
                    :loading="cartStore.saving"
                    @click="onRemoveItem(item)"
                  />
                </div>
              </q-item-section>

              <q-item-section side class="text-right">
                <div class="text-h6 text-primary text-weight-bold">
                  ৳{{ Number((item.unit_price_gbp || 0) * getDraftQty(item)).toFixed(2) }}
                </div>
                <div class="text-caption text-grey-6">
                  ৳{{ Number(item.unit_price_gbp || 0).toFixed(2) }} each
                </div>
                <div class="text-caption text-positive q-mt-xs" v-if="item.commission">
                  Commission: ৳{{ Number(item.commission * getDraftQty(item)).toFixed(2) }}
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>

      <!-- Right: Order Summary & Checkout Form -->
      <div class="col-12 col-md-4">
        <q-card flat class="cart-card q-pa-md">
          <div class="text-subtitle1 text-weight-bold text-grey-9 q-mb-md">Order Summary</div>
          
          <div class="row justify-between q-py-xs text-grey-8">
            <div>Total units</div>
            <div class="text-weight-bold">{{ totalQty }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8">
            <div>Subtotal</div>
            <div class="text-weight-bold">৳{{ totalPrice.toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8">
            <div>Delivery</div>
            <div class="text-weight-bold">৳{{ deliveryCharge.toFixed(2) }}</div>
          </div>
          
          <q-separator class="q-my-sm" />
          
          <div class="row justify-between q-py-xs text-h6 text-weight-bold text-grey-9">
            <div>Total</div>
            <div class="text-primary">৳{{ finalTotal.toFixed(2) }}</div>
          </div>

          <q-separator class="q-my-md" />

          <div class="row justify-between q-py-xs text-grey-8">
            <div>Products Commission</div>
            <div class="text-weight-bold text-positive">৳{{ totalCommission.toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="extraProfitTotal > 0">
            <div>Extra Profit Share (You 90% | Company 10%)</div>
            <div class="text-weight-bold text-positive">+৳{{ extraProfitUser.toFixed(2) }} | +৳{{ extraProfitCompany.toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="deliveryAdjustment > 0">
            <div>Delivery Adjustment</div>
            <div class="text-weight-bold text-positive">+৳{{ deliveryAdjustment.toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="codCharge > 0">
            <div>COD Charge (1.00%)</div>
            <div class="text-weight-bold text-negative">-৳{{ codCharge.toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="packingCharge > 0">
            <div>Packing Charge</div>
            <div class="text-weight-bold text-negative">-৳{{ packingCharge.toFixed(2) }}</div>
          </div>
          <div class="row justify-between q-py-xs text-grey-8" v-if="invoiceCharge > 0">
            <div>Invoice Charge</div>
            <div class="text-weight-bold text-negative">-৳{{ invoiceCharge.toFixed(2) }}</div>
          </div>
          
          <div class="row justify-between q-py-xs text-subtitle1 text-weight-bold text-positive q-mt-sm">
            <div>Order Commission</div>
            <div>৳{{ netOrderCommission.toFixed(2) }}</div>
          </div>

          <q-separator class="q-my-md" />

          <!-- Checkout Form -->
          <div class="text-subtitle2 text-weight-bold text-grey-9 q-mb-sm">Shipping Information</div>
          <q-form @submit="onCheckout" class="q-gutter-sm">
            <q-input
              v-model="shipping.name"
              label="Recipient Name *"
              outlined dense
              :rules="[val => !!val || 'Name is required']"
            />
            <q-input
              v-model="shipping.phone"
              label="Phone Number *"
              outlined dense
              mask="###########"
              unmasked-value
              :rules="[
                val => !!val || 'Phone is required',
                val => val.length === 11 || 'Must be an 11-digit number'
              ]"
            />
            <q-select
              v-model="shipping.district"
              label="District *"
              outlined dense
              :options="districtOptions"
              use-input
              input-debounce="0"
              @filter="filterDistricts"
              :rules="[val => !!val || 'District is required']"
            />
            <q-input
              v-model="shipping.thana"
              label="Thana *"
              outlined dense
              :rules="[val => !!val || 'Thana is required']"
            />
            <q-input
              v-model="shipping.address"
              label="Full Address *"
              outlined dense
              type="textarea"
              rows="3"
              :rules="[val => !!val || 'Address is required']"
            />
            
            <q-checkbox v-model="shipping.free_delivery" label="Request Free Delivery" class="q-my-sm" />

            <q-btn
              type="submit"
              color="primary"
              label="Place Order"
              icon="shopping_bag"
              no-caps
              unelevated
              class="w-full q-py-sm text-weight-bold q-mt-md checkout-btn"
              :loading="cartStore.saving"
              :disable="hasUnsavedChanges"
            />

            <div v-if="hasUnsavedChanges" class="text-caption text-negative text-center q-mt-xs">
              Please save quantity changes before placing order.
            </div>
          </q-form>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useKobaCartStore } from 'src/modules/koba/retail/stores/kobaCartStore'
import type { KobaCartItem } from '../repositories/kobaCartRepository'

const cartStore = useKobaCartStore()
const router = useRouter()
const authStore = useAuthStore()

const productsRouteName = computed(() => {
  return authStore.scope === 'shop' ? 'shop-koba-retail-page' : 'app-koba-retail-page'
})
const ordersRouteName = computed(() => {
  return authStore.scope === 'shop' ? 'shop-koba-retail-orders-page' : 'app-koba-retail-orders-page'
})

// District list matching brandwala retail
const DISTRICT_OPTIONS = [
  'Bagerhat', 'Bandarban', 'Barguna', 'Barishal', 'Bogra', 'Bhola', 'Brahmanbaria',
  'Chandpur', 'Chapainawabganj', 'Chittagong', 'Chuadanga', "Cox's Bazar", 'Comilla',
  'Dhaka', 'Dhaka Sub-Urban', 'Dinajpur', 'Faridpur', 'Feni', 'Gaibandha', 'Gazipur',
  'Gopalganj', 'Habiganj', 'Jamalpur', 'Jashore', 'Jhalokati', 'Jhenaidah', 'Joypurhat',
  'Khagrachori', 'Khulna', 'kishoreganj', 'Kurigram', 'Kustia', 'Lalmonirhat', 'Laxmipur',
  'Madaripur', 'Magura', 'Manikganj', 'Meherpur', 'Moulvibazar', 'Munshiganj', 'Mymensingh',
  'Naogaon', 'Narail', 'Narayanganj', 'Narshindi', 'Natore', 'Netrokona', 'Nilphamari',
  'Noakhali', 'Pabna', 'Panchgarh', 'Patuakhali', 'Pirojpur', 'Rajbari', 'Rajshahi',
  'Rangamati', 'Rangpur', 'Shariatpur', 'Shatkhira', 'Sherpur', 'Sirajganj', 'Sunamganj',
  'Sylhet', 'Tangail', 'Thakurgaon'
]

const districtOptions = ref(DISTRICT_OPTIONS)
const draftQty = ref<Record<number, number>>({})

const shipping = ref({
  name: '',
  phone: '',
  district: '',
  thana: '',
  address: '',
  free_delivery: false
})

onMounted(async () => {
  await cartStore.fetchCart()
  // Populate draft quantities
  cartStore.items.forEach((item) => {
    draftQty.value[item.id] = item.quantity
  })
})

function toDirectGoogleImageUrl(url: string | null) {
  if (!url) return ''
  const m1 = url.match(/[?&]id=([^&]+)/)
  const m2 = url.match(/\/file\/d\/([^/]+)/)
  const fileId = m1?.[1] || m2?.[1]
  if (!fileId) return url
  return `https://lh3.googleusercontent.com/d/${fileId}`
}

function getDraftQty(item: KobaCartItem): number {
  const val = draftQty.value[item.id]
  return val !== undefined ? val : item.quantity
}

function bumpQty(item: KobaCartItem, amount: number) {
  const current = getDraftQty(item)
  const next = Math.max(item.case_size, current + amount * item.case_size)
  draftQty.value[item.id] = next
}

function isDirty(item: KobaCartItem): boolean {
  return getDraftQty(item) !== item.quantity
}

const hasUnsavedChanges = computed(() => {
  return cartStore.items.some((item) => isDirty(item))
})

const totalQty = computed(() => {
  return cartStore.items.reduce((sum, item) => sum + getDraftQty(item), 0)
})

const totalPrice = computed(() => {
  return cartStore.items.reduce((sum, item) => sum + (item.unit_price_gbp || 0) * getDraftQty(item), 0)
})

const totalCommission = computed(() => {
  return cartStore.items.reduce((sum, item) => sum + (item.commission || 0) * getDraftQty(item), 0)
})

const deliveryCharge = ref(0)
const finalTotal = computed(() => totalPrice.value + deliveryCharge.value)

const extraProfitTotal = ref(0)
const extraProfitUser = computed(() => extraProfitTotal.value * 0.9)
const extraProfitCompany = computed(() => extraProfitTotal.value * 0.1)

const deliveryAdjustment = ref(0)
const codCharge = computed(() => finalTotal.value * 0.01)
const packingCharge = computed(() => totalQty.value > 0 ? 37 : 0) // Placeholder logic based on text
const invoiceCharge = computed(() => totalQty.value > 0 ? 1 : 0) // Placeholder logic based on text

const netOrderCommission = computed(() => {
  return totalCommission.value + extraProfitUser.value + deliveryAdjustment.value - codCharge.value - packingCharge.value - invoiceCharge.value
})

async function onSaveItem(item: KobaCartItem) {
  const targetQty = getDraftQty(item)
  await cartStore.updateItemQty(item.id, targetQty)
}

async function onRemoveItem(item: KobaCartItem) {
  await cartStore.removeItem(item.id)
  delete draftQty.value[item.id]
}

async function onClearCart() {
  await cartStore.clearCart()
  draftQty.value = {}
}

function filterDistricts(val: string, update: (cb: () => void) => void) {
  if (val === '') {
    update(() => {
      districtOptions.value = DISTRICT_OPTIONS
    })
    return
  }
  update(() => {
    const needle = val.toLowerCase()
    districtOptions.value = DISTRICT_OPTIONS.filter(v => v.toLowerCase().indexOf(needle) > -1)
  })
}

async function onCheckout() {
  const result = await cartStore.checkout({
    name: shipping.value.name,
    phone: shipping.value.phone,
    district: shipping.value.district,
    thana: shipping.value.thana,
    address: shipping.value.address,
    free_delivery: shipping.value.free_delivery,
    extra_profit_user: extraProfitUser.value,
    extra_profit_company: extraProfitCompany.value,
    delivery_adjustment: deliveryAdjustment.value,
    cod_charge: codCharge.value,
    packing_charge: packingCharge.value,
    invoice_charge: invoiceCharge.value,
    net_order_commission: netOrderCommission.value,
  })

  if (result.success) {
    void router.push({ name: ordersRouteName.value })
  }
}
</script>

<style scoped>
.cart-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(6px);
}

.empty-state-card {
  border-radius: 16px;
  border: 1px dashed rgba(0, 0, 0, 0.12);
  background: #fdfdfd;
}

.cart-card {
  border-radius: 16px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  background: rgba(255, 255, 255, 0.95);
}

.item-row {
  transition: background-color 0.15s ease;
}

.item-row:hover {
  background: rgba(0, 0, 0, 0.01);
}

.item-avatar {
  border-radius: 8px;
  border: 1px solid rgba(0, 0, 0, 0.04);
}

.item-name {
  line-height: 1.3;
}

.qty-stepper {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 6px;
  border: 1px solid #e5e7eb;
  border-radius: 999px;
  background: #f9fafb;
}

.qty-value {
  min-width: 32px;
  text-align: center;
  font-size: 13px;
  font-weight: 700;
  color: #0f172a;
}

.checkout-btn {
  border-radius: 12px;
}

.w-full {
  width: 100%;
}

@media (max-width: 599px) {
  .cart-header {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
