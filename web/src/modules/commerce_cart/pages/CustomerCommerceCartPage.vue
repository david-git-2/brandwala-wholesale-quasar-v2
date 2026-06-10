<template>
  <q-page class="cart-page q-pa-md">
    <div class="cart-header q-mb-md">
      <div>
        <div class="text-h5 text-weight-bold">Commerce Cart</div>
        <div class="text-caption text-grey-7">
          {{ cartSummary.totalItems }} items | Cost Subtotal {{ priceSymbol }}{{ formatPrice(cartSummary.costSubtotal) }}
        </div>
      </div>
      <q-btn
        color="negative"
        icon="o_delete_sweep"
        label="Clear Cart"
        no-caps
        unelevated
        :disable="!commerceCartStore.items.length"
        :loading="commerceCartStore.saving"
        @click="confirmClearOpen = true"
      />
    </div>

    <div v-if="storeOptions.length" class="store-switch q-mb-md">
      <q-btn-toggle
        v-model="selectedStoreId"
        no-caps
        unelevated
        toggle-color="primary"
        :options="storeOptions"
        @update:model-value="onStoreChange"
      />
    </div>

    <div v-if="!commerceCartStore.items.length" class="column items-center justify-center q-pa-xl text-grey-6 empty-cart-block">
      <q-icon name="o_remove_shopping_cart" size="64px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium text-grey-7">Cart is Empty</div>
      <div class="text-caption text-grey-5">Add items from the store to place a commerce order.</div>
    </div>

    <q-list v-else class="cart-list" separator>
      <q-item v-for="item in commerceCartStore.items" :key="item.id" class="cart-row">
        <q-item-section avatar>
          <div class="cart-image-wrap">
            <SmartImage
              :src="item.image_url ?? null"
              :alt="item.name"
              img-class="cart-item-image"
              fallback-class="cart-item-image-fallback"
            />
          </div>
        </q-item-section>
        <div class="cart-content-wrap">
          <q-item-section class="cart-main">
            <q-item-label class="cart-name text-subtitle1 text-weight-bold">{{ item.name }}</q-item-label>
            <q-item-label caption>
              Qty: {{ getDraftQty(item.id, item.quantity) }} | MOQ: {{ item.minimum_quantity }}
            </q-item-label>
            <q-item-label class="text-caption text-grey-7 q-mt-xs">
              Wholesale Price (Cost): {{ priceSymbol }}{{ formatPrice(item.price_bdt) }}
            </q-item-label>
            <q-item-label v-if="item.minimum_sell_price_bdt != null" class="text-caption text-green-7 q-mt-xs">
              Minimum Sell Price (Retail Floor): {{ priceSymbol }}{{ formatPrice(item.minimum_sell_price_bdt) }}
            </q-item-label>

            <div class="q-mt-sm" style="max-width: 250px;">
              <q-input
                v-model.number="recipientPrices[item.id]"
                type="number"
                label="Recipient Price (BDT) *"
                filled
                dense
                prefix="৳"
                :rules="[
                  (val) => val !== null && val !== undefined && val !== '' || 'Price is required',
                  (val) => Number(val) >= (item.minimum_sell_price_bdt ?? 0) || 'Price cannot be less than minimum sell price.',
                ]"
                lazy-rules
                class="soft-input"
              />
            </div>
          </q-item-section>

          <q-item-section side class="cart-actions">
            <div class="qty-box q-mb-xs">
              <q-btn
                dense
                round
                flat
                icon="remove"
                :disable="commerceCartStore.saving"
                @click="decrementItem(item.id, item.minimum_quantity)"
              />
              <div class="quantity-value">{{ getDraftQty(item.id, item.quantity) }}</div>
              <q-btn
                dense
                round
                flat
                icon="add"
                :disable="commerceCartStore.saving"
                @click="incrementItem(item.id, item.minimum_quantity)"
              />
            </div>

            <div class="text-right text-weight-medium q-mb-xs">
              Cost: {{ priceSymbol }}{{ formatPrice((item.price_bdt ?? 0) * getDraftQty(item.id, item.quantity)) }}
            </div>
            <div class="text-right text-weight-bold text-primary q-mb-xs">
              Recipient: {{ priceSymbol }}{{ formatPrice((recipientPrices[item.id] ?? 0) * getDraftQty(item.id, item.quantity)) }}
            </div>

            <div class="action-buttons">
              <q-btn
                v-if="isQuantityChanged(item.id, item.quantity)"
                color="primary"
                icon="save"
                label="Save"
                no-caps
                dense
                unelevated
                size="sm"
                class="q-px-sm"
                :loading="commerceCartStore.saving"
                @click="saveQuantity(item.id, item.minimum_quantity)"
              />
              <q-btn
                dense
                round
                flat
                color="negative"
                icon="o_delete"
                :loading="commerceCartStore.saving"
                @click="removeItem(item.id)"
              >
                <q-tooltip>Remove</q-tooltip>
              </q-btn>
            </div>
          </q-item-section>
        </div>
      </q-item>
    </q-list>

    <div class="cart-footer q-mt-lg">
      <div>
        <div class="text-caption text-grey-7">
          Total items: {{ cartSummary.totalItems }} | Cost: {{ priceSymbol }}{{ formatPrice(cartSummary.costSubtotal) }}
        </div>
        <div class="text-subtitle2 text-weight-bold text-primary">
          Total Recipient Value: {{ priceSymbol }}{{ formatPrice(cartSummary.recipientSubtotal) }}
        </div>
      </div>
      <q-btn
        color="primary"
        unelevated
        icon="o_shopping_bag"
        label="Place Order"
        no-caps
        :disable="!commerceCartStore.items.length || !isCartValid"
        :loading="commerceCartStore.saving"
        @click="openPlaceOrderDialog"
      />
    </div>

    <!-- Confirm Clear Dialog -->
    <q-dialog v-model="confirmClearOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Clear Cart</q-card-section>
        <q-card-section>
          Are you sure you want to remove all items from this cart?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="negative"
            label="Clear"
            :loading="commerceCartStore.saving"
            @click="onConfirmClear"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Place Order Dialog with Recipient Info -->
    <q-dialog v-model="confirmPlaceOrderOpen" persistent>
      <q-card style="min-width: 420px; max-width: 90vw;">
        <q-card-section class="row items-center q-pb-none">
          <q-icon name="shopping_bag" color="primary" size="24px" class="q-mr-sm" />
          <div class="text-h6 text-weight-bold">Recipient Information</div>
          <q-space />
          <q-btn flat round dense icon="close" v-close-popup />
        </q-card-section>

        <q-separator class="q-mt-sm" />

        <q-card-section>
          <q-form ref="orderForm" class="q-gutter-md q-mt-xs">
            <q-input
              v-model="recipientInfo.name"
              label="Recipient Name *"
              outlined
              dense
              :rules="[(val) => !!val || 'Recipient Name is required']"
            >
              <template #prepend>
                <q-icon name="person" color="grey-6" />
              </template>
            </q-input>

            <q-input
              v-model="recipientInfo.phone"
              label="Recipient Phone *"
              outlined
              dense
              :rules="[(val) => !!val || 'Recipient Phone is required']"
            >
              <template #prepend>
                <q-icon name="phone" color="grey-6" />
              </template>
            </q-input>

            <q-input
              v-model="recipientInfo.address"
              label="Shipping Address *"
              outlined
              dense
              type="textarea"
              rows="3"
              :rules="[(val) => !!val || 'Shipping Address is required']"
            >
              <template #prepend>
                <q-icon name="location_on" color="grey-6" />
              </template>
            </q-input>

             <q-input
              v-model.number="recipientInfo.deliveryCharge"
              label="Delivery Charge (BDT)"
              outlined
              dense
              type="number"
            >
              <template #prepend>
                <q-icon name="local_shipping" color="grey-6" />
              </template>
              <template #append>
                <span class="text-grey-7 text-caption">৳</span>
              </template>
            </q-input>

            <q-separator class="q-my-md" />

            <div class="row q-gutter-x-md q-mt-sm">
              <q-checkbox v-model="includeDeliveryCharge" label="Include Delivery Charge" dense class="text-grey-8" />
              <q-checkbox v-model="includeInvoicePrintCharge" label="Include Invoice Printing Expense" dense class="text-grey-8" />
            </div>

            <div class="q-gutter-y-xs q-mt-md">
              <div class="row justify-between text-subtitle2 text-grey-7">
                <div>Product Total:</div>
                <div class="text-weight-medium">৳{{ formatPrice(cartSummary.recipientSubtotal) }}</div>
              </div>
              <div class="row justify-between text-subtitle2 text-grey-7">
                <div>Delivery Charge:</div>
                <div class="text-weight-medium">৳{{ formatPrice(effectiveDeliveryChargeForTotal) }}</div>
              </div>
              <div v-if="recipientInfo.wrappingCharge > 0" class="row justify-between text-subtitle2 text-grey-7">
                <div>Wrapping Charge:</div>
                <div class="text-weight-medium">৳{{ formatPrice(recipientInfo.wrappingCharge) }}</div>
              </div>
              <div v-if="recipientInfo.cod > 0" class="row justify-between text-subtitle2 text-grey-7">
                <div>COD Charge:</div>
                <div class="text-weight-medium">৳{{ formatPrice(recipientInfo.cod) }}</div>
              </div>
              <div v-if="computedInvoicePrintCharge > 0" class="row justify-between text-subtitle2 text-grey-7">
                <div>Invoice Print Charge:</div>
                <div class="text-weight-medium">৳{{ formatPrice(computedInvoicePrintCharge) }}</div>
              </div>
              <q-separator class="q-my-sm" />
              <div class="row justify-between text-subtitle1 text-weight-bold text-primary">
                <div>Grand Total:</div>
                <div>৳{{ formatPrice(grandTotal) }}</div>
              </div>
              <div class="row justify-between text-subtitle2 text-weight-bold text-green-7 q-mt-xs">
                <div>Estimated Profit:</div>
                <div>৳{{ formatPrice(estimatedProfit) }}</div>
              </div>
            </div>
          </q-form>
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            label="Submit Order"
            unelevated
            :loading="submittingOrder"
            @click="onSubmitOrder"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import type { QForm } from 'quasar'

import SmartImage from 'src/components/SmartImage.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useStoreStore } from 'src/modules/store/stores/storeStore'
import { useCommerceCartStore } from '../stores/commerceCartStore'
import { commerceOrderService } from 'src/modules/commerce_order/services/commerceOrderService'
import type { CommerceOrderSettings } from 'src/modules/commerce_order/types'

const authStore = useAuthStore()
const storeStore = useStoreStore()
const commerceCartStore = useCommerceCartStore()
const router = useRouter()

const selectedStoreId = computed<number | null>({
  get: () => storeStore.selectedStore?.id ?? null,
  set: (value) => {
    storeStore.setSelectedStoreById(value)
  },
})

const confirmClearOpen = ref(false)
const confirmPlaceOrderOpen = ref(false)
const submittingOrder = ref(false)
const orderForm = ref<InstanceType<typeof QForm> | null>(null)

const draftQuantities = ref<Record<number, number>>({})
const recipientPrices = ref<Record<number, number | undefined>>({})

const recipientInfo = ref({
  name: '',
  phone: '',
  address: '',
  deliveryCharge: 0,
  wrappingCharge: 0,
  cod: 0,
})

const orderSettings = ref<CommerceOrderSettings | null>(null)
const loadOrderSettings = async () => {
  if (!authStore.tenantId) return
  const res = await commerceOrderService.getCommerceOrderSettings(authStore.tenantId)
  if (res.success && res.data) {
    orderSettings.value = res.data
  }
}

const storeOptions = computed(() =>
  storeStore.items.map((store) => ({
    label: store.name,
    value: store.id,
  })),
)

const priceSymbol = '৳'

const includeDeliveryCharge = ref(true)
const includeInvoicePrintCharge = ref(false)

const computedInvoicePrintCharge = computed(() => {
  return includeInvoicePrintCharge.value ? (Number(orderSettings.value?.default_invoice_print_charge) || 0) : 0
})

const effectiveDeliveryChargeForTotal = computed(() => {
  return includeDeliveryCharge.value ? 0 : Number(recipientInfo.value.deliveryCharge || 0)
})

const grandTotal = computed(() => {
  return (
    Number(cartSummary.value.recipientSubtotal || 0)
    + effectiveDeliveryChargeForTotal.value
  )
})

const estimatedProfit = computed(() => {
  const deliveryCostImpact = includeDeliveryCharge.value ? Number(recipientInfo.value.deliveryCharge || 0) : 0
  return (
    Number(cartSummary.value.recipientSubtotal || 0)
    - Number(cartSummary.value.costSubtotal || 0)
    - deliveryCostImpact
    - Number(recipientInfo.value.wrappingCharge || 0)
    - Number(recipientInfo.value.cod || 0)
    - Number(computedInvoicePrintCharge.value || 0)
  )
})

const cartSummary = computed(() => {
  let totalItems = 0
  let costSubtotal = 0
  let recipientSubtotal = 0

  commerceCartStore.items.forEach((item) => {
    const qty = draftQuantities.value[item.id] ?? item.quantity
    totalItems += qty
    costSubtotal += qty * (item.price_bdt ?? 0)
    recipientSubtotal += qty * (recipientPrices.value[item.id] ?? 0)
  })

  return {
    totalItems,
    costSubtotal,
    recipientSubtotal,
  }
})

const isCartValid = computed(() => {
  if (commerceCartStore.items.length === 0) {
    return false
  }

  return commerceCartStore.items.every((item) => {
    const price = recipientPrices.value[item.id]
    if (price === undefined || price === null || isNaN(price)) {
      return false
    }
    const minSell = item.minimum_sell_price_bdt ?? 0
    return price >= minSell
  })
})

const loadCart = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    return
  }

  await commerceCartStore.fetchItemsForContext({
    tenant_id: tenantId,
    store_id: storeStore.selectedStore?.id ?? null,
    customer_group_id: authStore.customerGroupId ?? null,
  })
}

const onStoreChange = async () => {
  await loadCart()
}

const removeItem = async (itemId: number) => {
  await commerceCartStore.deleteCartItem({ id: itemId })
}

const getDraftQty = (itemId: number, fallbackQuantity: number) => {
  if (draftQuantities.value[itemId] == null) {
    draftQuantities.value[itemId] = fallbackQuantity
  }
  return draftQuantities.value[itemId]
}

const isQuantityChanged = (itemId: number, originalQuantity: number) =>
  getDraftQty(itemId, originalQuantity) !== originalQuantity

const incrementItem = (itemId: number, minimumQuantity: number) => {
  const step = Math.max(1, minimumQuantity || 1)
  const current = getDraftQty(itemId, step)
  draftQuantities.value[itemId] = current + step
}

const decrementItem = (itemId: number, minimumQuantity: number) => {
  const step = Math.max(1, minimumQuantity || 1)
  const current = getDraftQty(itemId, step)
  const next = current - step
  draftQuantities.value[itemId] = next < step ? step : next
}

const saveQuantity = async (itemId: number, minimumQuantity: number) => {
  const step = Math.max(1, minimumQuantity || 1)
  const nextQuantity = Math.max(step, draftQuantities.value[itemId] ?? step)

  await commerceCartStore.updateCartItem({
    id: itemId,
    quantity: nextQuantity,
  })

  const row = commerceCartStore.items.find((item) => item.id === itemId)
  if (row) {
    draftQuantities.value[itemId] = row.quantity
  }
}

const clearCart = async () => {
  const tenantId = authStore.tenantId
  const customerGroupId = authStore.customerGroupId
  if (!tenantId || !customerGroupId) {
    return
  }

  await commerceCartStore.clearCartItems(tenantId, customerGroupId)
}

const onConfirmClear = async () => {
  await clearCart()
  confirmClearOpen.value = false
}

const openPlaceOrderDialog = () => {
  const totalRecipient = cartSummary.value.recipientSubtotal
  const defaultCodPercent = orderSettings.value?.default_cod_percent || 0
  const defaultWrapping = orderSettings.value?.default_wrapping_charge || 0

  includeDeliveryCharge.value = true
  includeInvoicePrintCharge.value = false

  recipientInfo.value = {
    name: '',
    phone: '',
    address: '',
    deliveryCharge: 0,
    wrappingCharge: Number(defaultWrapping),
    cod: Number(((defaultCodPercent / 100) * totalRecipient).toFixed(2)),
  }
  confirmPlaceOrderOpen.value = true
}

const onSubmitOrder = async () => {
  const formOk = await orderForm.value?.validate()
  if (!formOk) {
    return
  }

  const tenantId = authStore.tenantId
  const customerGroupId = authStore.customerGroupId
  if (!tenantId || !customerGroupId) {
    return
  }

  submittingOrder.value = true
  try {
    const itemsPayload = commerceCartStore.items.map((item) => ({
      product_id: item.product_id,
      image_url: item.image_url,
      cost_bdt: item.price_bdt ?? 0,
      sell_price_bdt: item.price_bdt ?? 0,
      recipient_price_bdt: recipientPrices.value[item.id] ?? 0,
      quantity: item.quantity,
      phone_invite_id: null,
    }))

    const shipmentPayment = Number(grandTotal.value || 0)

    const result = await commerceOrderService.placeCommerceOrder({
      tenant_id: tenantId,
      customer_group_id: customerGroupId,
      recipient_name: recipientInfo.value.name,
      recipient_phone: recipientInfo.value.phone,
      shipping_address: recipientInfo.value.address,
      shipment_payment: shipmentPayment,
      invoice_print_charge: computedInvoicePrintCharge.value,
      wrapping_charge: recipientInfo.value.wrappingCharge,
      cod: recipientInfo.value.cod,
      delivery_charge: recipientInfo.value.deliveryCharge,
      is_delivery_charge_inclusive: includeDeliveryCharge.value,
      items: itemsPayload,
    })

    if (result.success && result.data) {
      await commerceCartStore.clearCartItems(tenantId, customerGroupId)
      confirmPlaceOrderOpen.value = false

      const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
      await router.push(`${tenantPrefix}/shop/commerce-shop/orders/${result.data}`)
    }
  } finally {
    submittingOrder.value = false
  }
}

onMounted(async () => {
  await storeStore.fetchStoresForCustomer(authStore.tenantId ?? null)
  const selectedId = storeStore.selectedStore?.id ?? null
  const selectedExists = selectedId != null && storeStore.items.some((store) => store.id === selectedId)
  if (!selectedExists) {
    storeStore.setSelectedStore(storeStore.items[0] ?? null)
  }
  await loadCart()
  await loadOrderSettings()
})

watch(
  () => commerceCartStore.items,
  (items) => {
    const nextDraft: Record<number, number> = {}
    const nextPrices: Record<number, number> = {}

    items.forEach((item) => {
      nextDraft[item.id] = draftQuantities.value[item.id] ?? item.quantity
      // preserve any already-entered price; do not prefill new items
      if (recipientPrices.value[item.id] !== undefined) {
        nextPrices[item.id] = recipientPrices.value[item.id]!
      }
    })

    draftQuantities.value = nextDraft
    recipientPrices.value = nextPrices
  },
  { immediate: true },
)

const formatPrice = (value: number | null | undefined) => {
  if (value == null) {
    return '0.00'
  }
  return Number(value).toFixed(2)
}
</script>

<style scoped>
:deep(.cart-item-image),
:deep(.cart-item-image-fallback) {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.cart-header {
  display: flex;
  gap: 12px;
  align-items: center;
  justify-content: space-between;
  padding: 12px 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(6px);
}

.store-switch {
  padding: 10px;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 14px;
  backdrop-filter: blur(6px);
}

.empty-cart-block {
  background: rgba(255, 255, 255, 0.86);
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 16px;
  backdrop-filter: blur(6px);
  text-align: center;
}

.cart-list {
  background: rgba(255, 255, 255, 0.92);
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 16px;
  overflow: hidden;
}

.cart-row {
  padding: 14px 12px;
  transition: background-color 0.18s ease;
}

.cart-row:hover {
  background: rgba(59, 130, 246, 0.04);
}

.cart-image-wrap {
  width: 74px;
  height: 74px;
  border-radius: 12px;
  border: 1px solid #e6eaf2;
  background: #ffffff;
  padding: 6px;
}

.cart-main {
  min-width: 0;
}

.cart-name {
  white-space: normal;
  line-height: 1.35;
}

.qty-box {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 2px 8px;
  border: 1px solid #e5e7eb;
  border-radius: 999px;
  background: #ffffff;
}

.quantity-value {
  min-width: 24px;
  text-align: center;
  font-size: 0.9rem;
  font-weight: 600;
}

.cart-actions {
  min-width: 170px;
}

.cart-content-wrap {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: row;
  align-items: center;
}

.action-buttons {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
}

.cart-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(6px);
  box-shadow: 0 8px 22px rgba(15, 23, 42, 0.05);
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

@media (max-width: 680px) {
  .cart-header {
    flex-wrap: wrap;
    align-items: flex-start;
  }

  .store-switch {
    overflow-x: auto;
  }

  .cart-row {
    display: flex;
    flex-direction: row;
    align-items: flex-start;
    gap: 12px;
    padding: 12px 8px;
  }

  .cart-image-wrap {
    width: 1.2in;
    height: 1.2in;
    flex: 0 0 1.2in;
    padding: 4px;
  }

  .cart-content-wrap {
    flex-direction: column;
    align-items: stretch;
    flex: 1;
    padding-left: 12px;
  }

  .cart-main {
    padding: 0 !important;
  }

  .cart-actions {
    width: 100%;
    min-width: unset;
    margin-top: 8px;
    padding: 0 !important;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
  }

  .action-buttons {
    flex-direction: row;
    gap: 8px;
    align-items: center;
  }

  .cart-footer {
    position: sticky;
    bottom: 8px;
    z-index: 2;
    box-shadow: 0 10px 24px rgba(0, 0, 0, 0.08);
  }
}

@media (max-width: 599px) {
  .cart-page {
    padding: 4px !important;
  }
}
</style>
