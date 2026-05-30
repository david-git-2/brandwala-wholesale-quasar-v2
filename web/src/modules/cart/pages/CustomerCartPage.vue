<template>
  <q-page class="cart-page q-pa-md">
    <div class="cart-header q-mb-md">
      <div>
        <div class="text-h5 text-weight-bold">Cart</div>
        <div class="text-caption text-grey-7">
          {{ cartSummary.totalItems }} items <span v-if="storeStore.selectedStore?.see_price"> | Subtotal {{ priceSymbol }}{{ formatPrice(cartSummary.subtotal) }}</span>
        </div>
      </div>
      <q-btn
        color="negative"
        icon="o_delete_sweep"
        label="Clear Cart"
        no-caps
        unelevated
        :disable="!cartStore.items.length"
        :loading="cartStore.saving"
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

    <div v-if="!cartStore.items.length" class="column items-center justify-center q-pa-xl text-grey-6 empty-cart-block">
      <q-icon name="o_remove_shopping_cart" size="64px" class="q-mb-sm text-grey-4" />
      <div class="text-subtitle1 text-weight-medium text-grey-7">Cart is Empty</div>
      <div class="text-caption text-grey-5">Add items from the store to place an order.</div>
    </div>

    <q-list v-else class="cart-list" separator>
      <q-item v-for="item in cartStore.items" :key="item.id" class="cart-row">
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

        <q-item-section class="cart-main">
          <q-item-label class="cart-name">{{ item.name }}</q-item-label>
          <q-item-label caption>
            Qty: {{ getDraftQty(item.id, item.quantity) }} | MOQ: {{ item.minimum_quantity }}
          </q-item-label>
          <q-item-label v-if="storeStore.selectedStore?.see_price" class="text-caption text-grey-7 q-mt-xs">
            Unit Price: {{ priceSymbol }}{{ formatPrice(getDisplayPrice(item)) }}
          </q-item-label>
        </q-item-section>

        <q-item-section side class="cart-actions">
          <div class="qty-box q-mb-xs">
            <q-btn
              dense
              round
              flat
              icon="remove"
              :disable="cartStore.saving"
              @click="decrementItem(item.id, item.minimum_quantity)"
            />
            <div class="quantity-value">{{ getDraftQty(item.id, item.quantity) }}</div>
            <q-btn
              dense
              round
              flat
              icon="add"
              :disable="cartStore.saving"
              @click="incrementItem(item.id, item.minimum_quantity)"
            />
          </div>

          <div v-if="storeStore.selectedStore?.see_price" class="text-right text-weight-medium q-mb-xs">
            {{ priceSymbol }}{{ formatPrice(getDisplayPrice(item) * getDraftQty(item.id, item.quantity)) }}
          </div>
          <div class="action-buttons">
            <q-btn
              v-if="isQuantityChanged(item.id, item.quantity)"
              dense
              unelevated
              color="primary"
              icon="save"
              label="Save"
              no-caps
              class="q-mb-xs"
              :loading="cartStore.saving"
              @click="saveQuantity(item.id, item.minimum_quantity)"
            />
            <q-btn
              dense
              flat
              color="negative"
              icon="delete"
              label="Remove"
              no-caps
              :loading="cartStore.saving"
              @click="removeItem(item.id)"
            />
          </div>
        </q-item-section>
      </q-item>
    </q-list>

    <div class="cart-footer q-mt-lg">
      <div class="text-caption text-grey-7">
        Total items: {{ cartSummary.totalItems }} <span v-if="storeStore.selectedStore?.see_price">  | Subtotal: {{ priceSymbol }}{{ formatPrice(cartSummary.subtotal) }}</span>
      </div>
      <q-btn
        color="primary"
        unelevated
        icon="o_shopping_bag"
        label="Place Order"
        no-caps
        :disable="!cartStore.items.length"
        :loading="orderStore.saving"
        @click="confirmPlaceOrderOpen = true"
      />
    </div>

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
            :loading="cartStore.saving"
            @click="onConfirmClear"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-model="confirmPlaceOrderOpen">
      <q-card style="min-width: 320px">
        <q-card-section class="text-h6">Place Order</q-card-section>
        <q-card-section>
          Are you sure you want to place this order?
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn
            color="primary"
            label="Confirm"
            :loading="orderStore.saving"
            @click="onConfirmPlaceOrder"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'

import SmartImage from 'src/components/SmartImage.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useOrderStore } from 'src/modules/order/stores/orderStore'
import { useStoreStore } from 'src/modules/store/stores/storeStore'
import { useCartStore } from '../stores/cartStore'

const authStore = useAuthStore()
const storeStore = useStoreStore()
const cartStore = useCartStore()
const orderStore = useOrderStore()
const router = useRouter()

const selectedStoreId = computed<number | null>({
  get: () => storeStore.selectedStore?.id ?? null,
  set: (value) => {
    storeStore.setSelectedStoreById(value)
  },
})
const confirmClearOpen = ref(false)
const confirmPlaceOrderOpen = ref(false)
const draftQuantities = ref<Record<number, number>>({})

const storeOptions = computed(() =>
  storeStore.items.map((store) => ({
    label: store.name,
    value: store.id,
  })),
)

const priceSymbol = computed(() =>
  cartStore.items.some((item) => item.price_bdt != null) ? '৳' : '£',
)

const getDisplayPrice = (item: { price_bdt?: number | null; price_gbp?: number | null }) =>
  Number(item.price_bdt ?? item.price_gbp ?? 0)

const cartSummary = computed(() => {
  const totalItems = cartStore.items.reduce((sum, item) => {
    return sum + (draftQuantities.value[item.id] ?? item.quantity)
  }, 0)

  const subtotal = cartStore.items.reduce((sum, item) => {
    const qty = draftQuantities.value[item.id] ?? item.quantity
    const price = item.price_bdt ?? item.price_gbp ?? 0
    return sum + qty * price
  }, 0)

  return {
    totalItems,
    subtotal,
  }
})

const loadCart = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    return
  }

  await cartStore.fetchItemsForContext({
    tenant_id: tenantId,
    store_id: storeStore.selectedStore?.id ?? null,
    customer_group_id: authStore.customerGroupId ?? null,
  })
}

const onStoreChange = async () => {
  await loadCart()
}

const removeItem = async (itemId: number) => {
  await cartStore.deleteCartItem({ id: itemId })
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

  await cartStore.updateCartItem({
    id: itemId,
    quantity: nextQuantity,
    minimum_quantity: step,
  })

  const row = cartStore.items.find((item) => item.id === itemId)
  if (row) {
    draftQuantities.value[itemId] = row.quantity
  }
}

const clearCart = async () => {
  if (!cartStore.items.length) {
    return
  }

  await cartStore.clearCartItems(cartStore.items.map((item) => item.id))
}

const onConfirmClear = async () => {
  await clearCart()
  confirmClearOpen.value = false
}

const onPlaceOrder = async (): Promise<number | null> => {
  const tenantId = authStore.tenantId
  const customerGroupId = authStore.customerGroupId
  const customerGroup = authStore.customerGroup

  if (!tenantId || !customerGroupId || !customerGroup?.name) {
    return null
  }

  const cartId = cartStore.cartSnapshot?.cart?.id ?? null
  if (cartId) {
    await cartStore.fetchCartDetails(cartId)
  }

  const detailByProductId = new Map<
    number,
    {
      price_gbp: number | null
      price_bdt?: number | null
      barcode: string | null
      product_code: string | null
      product_weight: number | null
      package_weight: number | null
    }
  >()

  ;(cartStore.cartDetails?.items ?? []).forEach((item) => {
    const productId = item.product_id
    const product = item.product
    if (productId == null || !product) {
      return
    }

    detailByProductId.set(productId, {
      price_gbp: (product['price_gbp'] as number | null) ?? null,
      price_bdt: (product['price_bdt'] as number | null) ?? null,
      barcode: (product['barcode'] as string | null) ?? null,
      product_code: (product['product_code'] as string | null) ?? null,
      product_weight: (product['product_weight'] as number | null) ?? null,
      package_weight: (product['package_weight'] as number | null) ?? null,
    })
  })

  const result = await orderStore.placeOrderFromCart({
    tenant_id: tenantId,
    store_id: storeStore.selectedStore?.id ?? null,
    customer_group_id: customerGroupId,
    customer_group_name: customerGroup.name,
    accent_color: customerGroup.accentColor ?? null,
    can_see_price: Boolean(cartStore.cartSnapshot?.cart?.can_see_price),
    items: cartStore.items.map((item) => {
      const productDetail = detailByProductId.get(item.product_id ?? -1)
      return {
        product_id: item.product_id ?? null,
        name: item.name,
        image_url: item.image_url ?? null,
        price_gbp: item.price_gbp ?? productDetail?.price_gbp ?? null,
        price_bdt: item.price_bdt ?? productDetail?.price_bdt ?? productDetail?.price_gbp ?? null,
        barcode: productDetail?.barcode ?? null,
        product_code: productDetail?.product_code ?? null,
        product_weight: productDetail?.product_weight ?? null,
        package_weight: productDetail?.package_weight ?? null,
        quantity: item.quantity,
        minimum_quantity: item.minimum_quantity,
      }
    }),
  })

  if (!result?.success || !result.data?.id) {
    return null
  }

  return result.data.id
}

const onConfirmPlaceOrder = async () => {
  const orderId = await onPlaceOrder()

  if (!orderId) {
    return
  }

  await clearCart()
  confirmPlaceOrderOpen.value = false

  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/shop/orders/${orderId}`)
}

const formatPrice = (value: number | null) => {
  if (value == null) {
    return '0.00'
  }
  return Number(value).toFixed(2)
}

onMounted(async () => {
  await storeStore.fetchStoresForCustomer(authStore.tenantId ?? null)
  const selectedId = storeStore.selectedStore?.id ?? null
  const selectedExists = selectedId != null && storeStore.items.some((store) => store.id === selectedId)
  if (!selectedExists) {
    storeStore.setSelectedStore(storeStore.items[0] ?? null)
  }
  await loadCart()
})

watch(
  () => cartStore.items,
  (items) => {
    const nextDraft: Record<number, number> = {}

    items.forEach((item) => {
      nextDraft[item.id] = draftQuantities.value[item.id] ?? item.quantity
    })

    draftQuantities.value = nextDraft
  },
  { immediate: true },
)
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

.empty-banner {
  background: #fff9ef;
  color: #5b4c33;
  border: 1px solid #e8dbbf;
  border-radius: 12px;
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

@media (max-width: 680px) {
  .cart-header {
    flex-wrap: wrap;
    align-items: flex-start;
  }

  .store-switch {
    overflow-x: auto;
  }

  .cart-row {
    flex-wrap: wrap;
    align-items: flex-start;
    gap: 10px;
  }

  .cart-actions {
    width: 100%;
    min-width: 0;
    margin-top: 8px;
    align-items: stretch;
  }

  .action-buttons {
    align-items: stretch;
  }

  .cart-footer {
    position: sticky;
    bottom: 8px;
    z-index: 2;
    box-shadow: 0 10px 24px rgba(0, 0, 0, 0.08);
  }
}
</style>
