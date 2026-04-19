<template>
  <div class="row justify-center q-gutter-md customer-card-wrap">
    <q-card
      v-for="item in orderStore.selected?.order_items"
      :key="item.id"
      class="my-card"
    >
      <div class="product-image-wrap">
        <SmartImage :src="item.image_url"  :alt="item.name"
          img-class="product-image"
          fallback-class="product-image-fallback" />
      </div>

      <q-card-section>
        <div class="text-body1 text-weight-medium name-clamp">
          {{ item.name }}
        </div>

        <div class="field-chip field-qty q-mt-sm">
          <div class="field-row">
            <span>Quantity</span>
            <div v-if="orderStore.selected?.status==='final_offered'" class="qty-inline">
              <q-btn
                dense
                round
                color="primary"
                icon="remove"
                @click="decrementQuantity(item)"
              />
              <div class="qty-value">{{ quantityDraftById[item.id] ?? 0 }}</div>
              <q-btn
                dense
                round
                color="primary"
                icon="add"
                @click="incrementQuantity(item)"
              />
            </div>
            <span v-else>{{ item.ordered_quantity ?? '-' }}</span>
          </div>
        </div>
        <div
          v-if="orderStore.selected?.status==='final_offered' && isQuantityChanged(item)"
          class="q-mt-xs row justify-end"
        >
          <q-btn
            color="primary"
            dense
            no-caps
            label="Save"
            :loading="orderStore.saving"
            @click="saveQuantity(item.id)"
          />
        </div>

         <div v-if="orderStore.selected?.status==='customer_submit'" class="  q-mt-sm" >

        </div>
        <div v-else-if="orderStore.selected?.status==='priced' && isNegotiationEnabled" class="  q-mt-sm" >
          <div class="field-chip field-first-offer">
            <div class="field-row">
              <span>First Offer</span>
              <span>{{ item.first_offer_bdt ?? '-' }}</span>
            </div>
          </div>
          <div class="field-chip field-customer-offer q-mt-xs">
            <div class="field-row">
              <span>Customer Offer</span>
              <q-input
                :model-value="customerOfferDraftById[item.id]"
                type="number"
                dense
                outlined
                class="customer-offer-input"
                @update:model-value="(value) => onCustomerOfferInput(item.id, value)"
              />
            </div>
          </div>
          <div v-if="isCustomerOfferChanged(item)" class="q-mt-xs row justify-end">
            <q-btn
              color="primary"
              dense
              no-caps
              label="Save"
              :loading="orderStore.saving"
              @click="saveCustomerOffer(item.id)"
            />
          </div>

        </div>


          <div v-else-if="orderStore.selected?.status==='negotiate' && isNegotiationEnabled" class="  q-mt-sm" >
          <div class="field-chip field-first-offer q-mb-xs">
            <div class="field-row">
              <span>First Offer</span>
              <span>{{ item.first_offer_bdt ?? '-' }}</span>
            </div>
          </div>

          <div class="field-chip field-customer-offer">
            <div class="field-row">
              <span>Customer Offer</span>
              <span>{{ item.customer_offer_bdt ?? '-' }}</span>
            </div>
          </div>
        </div>
           <div v-else-if="orderStore.selected?.status==='final_offered'" class="  q-mt-sm" >
          <div
            v-if="isNegotiationEnabled"
            class="field-chip field-first-offer q-mb-xs"
          >
            <div class="field-row">
              <span>First Offer</span>
              <span>{{ item.first_offer_bdt ?? '-' }}</span>
            </div>
          </div>
          <div
            v-if="isNegotiationEnabled"
            class="field-chip field-customer-offer q-mb-xs"
          >
            <div class="field-row">
              <span>Customer Offer</span>
              <span>{{ item.customer_offer_bdt ?? '-' }}</span>
            </div>
          </div>
          <div class="field-chip field-final-offer">
            <div class="field-row">
              <span>Final Offer</span>
              <span>{{ getFinalOfferDisplay(item) }}</span>
            </div>
          </div>

        </div>
         <div v-else class="  q-mt-sm" >
          <div
            v-if="isNegotiationEnabled"
            class="field-chip field-first-offer q-mb-xs"
          >
            <div class="field-row">
              <span>First Offer</span>
              <span>{{ item.first_offer_bdt ?? '-' }}</span>
            </div>
          </div>
          <div
            v-if="isNegotiationEnabled"
            class="field-chip field-customer-offer q-mb-xs"
          >
            <div class="field-row">
              <span>Customer Offer</span>
              <span>{{ item.customer_offer_bdt ?? '-' }}</span>
            </div>
          </div>
          <div class="field-chip field-final-offer">
            <div class="field-row">
              <span>Final Offer</span>
              <span>{{ getFinalOfferDisplay(item) }}</span>
            </div>
          </div>

        </div>



      </q-card-section>
    </q-card>
  </div>
<div class="row justify-end">
  <q-btn
        v-if="canEditCustomerOffer"
          color="primary"
          class="q-mt-md"
          no-caps
          label="Save Customer Offers"
          :loading="orderStore.saving"
          @click="onAskSaveCustomerOffers"
        />
</div>
  <div v-if="orderStore.selected?.status==='final_offered'" class="row justify-end q-mt-md">
    <q-btn
      color="primary"
      no-caps
      label="Place Order"
      :loading="orderStore.saving"
      @click="onAskPlaceOrder"
    />
  </div>

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
          label="Place Order"
          :loading="orderStore.saving"
          @click="onConfirmPlaceOrder"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>

  <q-dialog v-model="confirmSaveCustomerOffersOpen">
    <q-card style="min-width: 320px">
      <q-card-section class="text-h6">Save Customer Offers</q-card-section>
      <q-card-section>
        Are you sure you want to save customer offers?
      </q-card-section>
      <q-card-actions align="right">
        <q-btn flat label="Cancel" v-close-popup />
        <q-btn
          color="primary"
          label="Save"
          :loading="orderStore.saving"
          @click="onConfirmSaveCustomerOffers"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import SmartImage from 'src/components/SmartImage.vue'
import { useOrderStore } from '../stores/orderStore'

const orderStore = useOrderStore()
const customerOfferDraftById = ref<Record<number, number | null>>({})
const quantityDraftById = ref<Record<number, number | null>>({})
const confirmPlaceOrderOpen = ref(false)
const confirmSaveCustomerOffersOpen = ref(false)

type OrderCardItem = {
  id: number
  first_offer_bdt: number | null
  customer_offer_bdt: number | null
  final_offer_bdt: number | null
  ordered_quantity: number | null
  minimum_quantity: number | null
}
const canEditCustomerOffer = computed(() => orderStore.selected?.negotiate && orderStore.selected?.status === 'priced')

const orderItems = computed(
  () => (orderStore.selected?.order_items ?? []) as Array<OrderCardItem & Record<string, unknown>>,
)

watch(
  orderItems,
  (items) => {
    const nextOfferDraft: Record<number, number | null> = {}
    const nextQuantityDraft: Record<number, number | null> = {}
    items.forEach((item) => {
      nextOfferDraft[item.id] = item.customer_offer_bdt ?? item.first_offer_bdt ?? null
      nextQuantityDraft[item.id] = item.ordered_quantity ?? 0
    })
    customerOfferDraftById.value = nextOfferDraft
    quantityDraftById.value = nextQuantityDraft
  },
  { immediate: true },
)

const normalizeNumber = (value: string | number | null) => {
  if (value == null || value === '') {
    return null
  }

  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

const getInitialCustomerOffer = (item: OrderCardItem) => item.customer_offer_bdt ?? item.first_offer_bdt ?? null
const isNegotiationEnabled = computed(() => orderStore.selected?.negotiate !== false)
const getFinalOfferDisplay = (item: OrderCardItem) =>
  item.final_offer_bdt ?? item.customer_offer_bdt ?? item.first_offer_bdt ?? '-'

const isCustomerOfferChanged = (item: OrderCardItem) =>
  customerOfferDraftById.value[item.id] !== getInitialCustomerOffer(item)

const onCustomerOfferInput = (itemId: number, value: string | number | null) => {
  customerOfferDraftById.value[itemId] = normalizeNumber(value)
}

const getInitialQuantity = (item: OrderCardItem) => item.ordered_quantity ?? 0

const isQuantityChanged = (item: OrderCardItem) =>
  (quantityDraftById.value[item.id] ?? 0) !== getInitialQuantity(item)

const getQuantityStep = (item: OrderCardItem) => {
  const raw = Number(item.minimum_quantity ?? 1)
  return Number.isFinite(raw) && raw > 0 ? Math.floor(raw) : 1
}

const incrementQuantity = (item: OrderCardItem) => {
  const step = getQuantityStep(item)
  const current = quantityDraftById.value[item.id] ?? 0
  quantityDraftById.value[item.id] = current + step
}

const decrementQuantity = (item: OrderCardItem) => {
  const step = getQuantityStep(item)
  const current = quantityDraftById.value[item.id] ?? 0
  quantityDraftById.value[item.id] = Math.max(0, current - step)
}

const saveCustomerOffer = async (itemId: number) => {
  const nextOffer = customerOfferDraftById.value[itemId] ?? null
  const result = await orderStore.updateOrderItemRaw({
    id: itemId,
    patch: {
      customer_offer_bdt: nextOffer,
    },
  })

  if (!result.success || !orderStore.selected) {
    return
  }

  const row = orderStore.selected.order_items.find((entry) => entry.id === itemId)
  if (row) {
    customerOfferDraftById.value[itemId] = row.customer_offer_bdt ?? row.first_offer_bdt ?? null
  }
}

const saveQuantity = async (itemId: number) => {
  const nextQuantity = quantityDraftById.value[itemId] ?? 0
  const result = await orderStore.updateOrderItemRaw({
    id: itemId,
    patch: {
      ordered_quantity: nextQuantity,
    },
  })

  if (!result.success || !orderStore.selected) {
    return
  }

  const row = orderStore.selected.order_items.find((entry) => entry.id === itemId)
  if (row) {
    quantityDraftById.value[itemId] = row.ordered_quantity ?? 0
  }
}

const onAskPlaceOrder = () => {
  confirmPlaceOrderOpen.value = true
}

const onConfirmPlaceOrder = async () => {
  if (!orderStore.selected?.id) {
    return
  }

  await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      status: 'ordered',
    },
  })
  confirmPlaceOrderOpen.value = false
}

const onAskSaveCustomerOffers = () => {
  confirmSaveCustomerOffersOpen.value = true
}

const onConfirmSaveCustomerOffers = async () => {
  await onSaveCustomerOffers()
  confirmSaveCustomerOffersOpen.value = false
}

const onSaveCustomerOffers = async () => {
  const payload = orderItems.value.map((item) => ({
    id: item.id,
    customer_offer_bdt: customerOfferDraftById.value[item.id] ?? null,
  }))

  if (!payload.length) {
    return
  }

  const result = await orderStore.bulkUpdateOrderItemsRaw(payload)
  if (!result.success) {
    return
  }

  const shouldNegotiate = orderStore.selected?.negotiate !== false
  if (!orderStore.selected?.id) {
    return
  }

  await orderStore.updateOrder({
    id: orderStore.selected.id,
    patch: {
      status: shouldNegotiate ? 'negotiate' : 'final_offered',
    },
  })
}
</script>

<style scoped>
.customer-card-wrap {
  width: 100%;
}

.my-card {
  width: 280px;
  border-radius: 12px;
}

.product-image-wrap {
  width: 100%;
  height: 180px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #fff;
  border-top-left-radius: 12px;
  border-top-right-radius: 12px;
  overflow: hidden;
}

.name-clamp {
  display: -webkit-box;
  line-clamp: 3;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4em;
  min-height: 4.2em;
}
:deep(.product-image) {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
  padding: 8px;
}

:deep(.product-image-fallback) {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #746655;
  background: #f3efe9;
  font-size: 0.95rem;
}

.field-chip {
  display: block;
  padding: 6px 8px;
  border-radius: 8px;
  font-weight: 600;
}

.field-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.customer-offer-input {
  min-width: 120px;
}

:deep(.customer-offer-input .q-field__control) {
  background: #ffffff;
}

.qty-inline {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.qty-value {
  min-width: 40px;
  text-align: center;
  font-weight: 700;
}

.field-qty {
  background: #f2f4f7;
}

.field-first-offer {
  background: #e0f2f6;
}

.field-customer-offer {
  background: #f8e8d5;
}

.field-final-offer {
  background: #e8e2f8;
}
</style>
