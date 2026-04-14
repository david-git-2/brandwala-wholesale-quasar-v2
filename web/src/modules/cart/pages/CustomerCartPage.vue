<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div class="text-h5">Cart</div>
      {{authStore.customerGroup }}
      <q-btn
        color="negative"
        icon="delete_sweep"
        label="Clear Cart"
        :disable="!cartStore.items.length"
        :loading="cartStore.saving"
        @click="confirmClearOpen = true"
      />
    </div>

    <div v-if="storeOptions.length" class="q-mb-md">
      <q-btn-toggle
        v-model="selectedStoreId"
        no-caps
        unelevated
        toggle-color="primary"
        :options="storeOptions"
        @update:model-value="onStoreChange"
      />
    </div>

    <q-banner v-if="!cartStore.items.length" class="bg-grey-2 text-grey-8">
      Cart is empty.
    </q-banner>

    <q-list v-else bordered separator>
      <q-item v-for="item in cartStore.items" :key="item.id" class="cart-row">
        <q-item-section avatar>
          <SmartImage
            :src="item.image_url ?? null"
            :alt="item.name"
            img-class="cart-item-image"
            fallback-class="cart-item-image-fallback"
          />
        </q-item-section>

        <q-item-section>
          <q-item-label>{{ item.name }}</q-item-label>
          <q-item-label caption>
            Qty: {{ getDraftQty(item.id, item.quantity) }} | MOQ: {{ item.minimum_quantity }}
          </q-item-label>
        </q-item-section>

        <q-item-section side class="cart-actions">
          <div class="row items-center q-gutter-xs q-mb-xs">
            <q-btn
              dense
              round
              flat
              icon="remove"
              :disable="cartStore.saving"
              @click="decrementItem(item.id, item.minimum_quantity)"
            />
            <div class="text-body2">{{ getDraftQty(item.id, item.quantity) }}</div>
            <q-btn
              dense
              round
              flat
              icon="add"
              :disable="cartStore.saving"
              @click="incrementItem(item.id, item.minimum_quantity)"
            />
          </div>

          <div class="text-right q-mb-xs">
            £{{ formatPrice(item.price_gbp) }}
          </div>
          <q-btn
            v-if="isQuantityChanged(item.id, item.quantity)"
            dense
            unelevated
            color="primary"
            icon="save"
            label="Save"
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
            :loading="cartStore.saving"
            @click="removeItem(item.id)"
          />
        </q-item-section>
      </q-item>
    </q-list>

    <div class="row q-col-gutter-sm q-mt-lg">
      <div class="col-12 col-sm-auto">
        <q-btn
          outline
          color="primary"
          icon="shopping_bag"
          label="Place Order"
          :disable="!cartStore.items.length"
          :loading="orderStore.saving"
          @click="confirmPlaceOrderOpen = true"
        />
      </div>
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

import SmartImage from 'src/components/SmartImage.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useOrderStore } from 'src/modules/order/stores/orderStore'
import { useStoreStore } from 'src/modules/store/stores/storeStore'
import { useCartStore } from '../stores/cartStore'

const authStore = useAuthStore()
const storeStore = useStoreStore()
const cartStore = useCartStore()
const orderStore = useOrderStore()

const selectedStoreId = ref<number | null>(null)
const confirmClearOpen = ref(false)
const confirmPlaceOrderOpen = ref(false)
const draftQuantities = ref<Record<number, number>>({})

const storeOptions = computed(() =>
  storeStore.items.map((store) => ({
    label: store.name,
    value: store.id,
  })),
)

const loadCart = async () => {
  const tenantId = authStore.tenantId
  if (!tenantId) {
    return
  }

  await cartStore.fetchItemsForContext({
    tenant_id: tenantId,
    store_id: selectedStoreId.value,
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

const onPlaceOrder = async () => {
  const tenantId = authStore.tenantId
  const customerGroupId = authStore.customerGroupId
  const customerGroup = authStore.customerGroup

  if (!tenantId || !customerGroupId || !customerGroup?.name) {
    return false
  }

  const result = await orderStore.placeOrderFromCart({
    tenant_id: tenantId,
    store_id: selectedStoreId.value,
    customer_group_id: customerGroupId,
    customer_group_name: customerGroup.name,
    accent_color: customerGroup.accentColor ?? null,
  })

  return Boolean(result?.success)
}

const onConfirmPlaceOrder = async () => {
  const placed = await onPlaceOrder()

  if (!placed) {
    return
  }

  await clearCart()
  confirmPlaceOrderOpen.value = false
}

const formatPrice = (value: number | null) => {
  if (value == null) {
    return '0.00'
  }
  return Number(value).toFixed(2)
}

onMounted(async () => {
  await storeStore.fetchStoresForCustomer()
  selectedStoreId.value = storeStore.items[0]?.id ?? null
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
  width: 56px;
  height: 56px;
  border-radius: 8px;
  object-fit: cover;
}

.cart-actions {
  min-width: 150px;
}

@media (max-width: 680px) {
  .cart-row {
    flex-wrap: wrap;
    align-items: flex-start;
  }

  .cart-actions {
    width: 100%;
    min-width: 0;
    margin-top: 8px;
    align-items: flex-start;
  }
}
</style>
