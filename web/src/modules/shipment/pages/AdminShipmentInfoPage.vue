<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <q-btn
        flat
        no-caps
        color="primary"
        icon="arrow_back"
        label="Back to Shipment Details"
        @click="onBack"
      />
    </div>

    <div class="text-h5 q-mb-md">
      Shipment Info #{{ shipmentStore.selectedShipment?.id ?? shipmentId }}
    </div>

    <PageInitialLoader v-if="initialLoading" />

    <q-banner v-else-if="shipmentStore.loading" class="bg-grey-2 text-grey-8 q-mb-md">
      Loading shipment info...
    </q-banner>

    <q-banner v-if="!initialLoading && shipmentStore.error" class="bg-red-1 text-negative q-mb-md">
      {{ shipmentStore.error }}
    </q-banner>

    <q-card v-if="!initialLoading" flat bordered>
      <q-card-section class="q-gutter-md">
        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-md-4 text-weight-medium">Name</div>
          <div class="col-12 col-md-8 row items-center q-gutter-sm">
            <template v-if="editingField === 'name'">
              <q-input v-model="draft.name" outlined dense class="col" />
              <q-btn color="primary" label="Save" :loading="shipmentStore.saving" @click="saveField('name')" />
              <q-btn flat label="Cancel" :disable="shipmentStore.saving" @click="cancelEdit" />
            </template>
            <template v-else>
              <div class="col">{{ shipmentStore.selectedShipment?.name || '-' }}</div>
              <q-btn flat round dense icon="edit" @click="startEdit('name')" />
            </template>
          </div>
        </div>

        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-md-4 text-weight-medium">Product Conversion Rate</div>
          <div class="col-12 col-md-8 row items-center q-gutter-sm">
            <template v-if="editingField === 'product_conversion_rate'">
              <q-input v-model.number="draft.product_conversion_rate" type="number" step="0.0001" outlined dense class="col" />
              <q-btn color="primary" label="Save" :loading="shipmentStore.saving" @click="saveField('product_conversion_rate')" />
              <q-btn flat label="Cancel" :disable="shipmentStore.saving" @click="cancelEdit" />
            </template>
            <template v-else>
              <div class="col">{{ displayNumber(shipmentStore.selectedShipment?.product_conversion_rate) }}</div>
              <q-btn flat round dense icon="edit" @click="startEdit('product_conversion_rate')" />
            </template>
          </div>
        </div>

        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-md-4 text-weight-medium">Cargo Conversion Rate</div>
          <div class="col-12 col-md-8 row items-center q-gutter-sm">
            <template v-if="editingField === 'cargo_conversion_rate'">
              <q-input v-model.number="draft.cargo_conversion_rate" type="number" step="0.0001" outlined dense class="col" />
              <q-btn color="primary" label="Save" :loading="shipmentStore.saving" @click="saveField('cargo_conversion_rate')" />
              <q-btn flat label="Cancel" :disable="shipmentStore.saving" @click="cancelEdit" />
            </template>
            <template v-else>
              <div class="col">{{ displayNumber(shipmentStore.selectedShipment?.cargo_conversion_rate) }}</div>
              <q-btn flat round dense icon="edit" @click="startEdit('cargo_conversion_rate')" />
            </template>
          </div>
        </div>

        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-md-4 text-weight-medium">Cargo Rate</div>
          <div class="col-12 col-md-8 row items-center q-gutter-sm">
            <template v-if="editingField === 'cargo_rate'">
              <q-input v-model.number="draft.cargo_rate" type="number" step="0.0001" outlined dense class="col" />
              <q-btn color="primary" label="Save" :loading="shipmentStore.saving" @click="saveField('cargo_rate')" />
              <q-btn flat label="Cancel" :disable="shipmentStore.saving" @click="cancelEdit" />
            </template>
            <template v-else>
              <div class="col">{{ displayNumber(shipmentStore.selectedShipment?.cargo_rate) }}</div>
              <q-btn flat round dense icon="edit" @click="startEdit('cargo_rate')" />
            </template>
          </div>
        </div>

        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-md-4 text-weight-medium">Weight</div>
          <div class="col-12 col-md-8 row items-center q-gutter-sm">
            <template v-if="editingField === 'weight'">
              <q-input v-model.number="draft.weight" type="number" step="0.001" outlined dense class="col" />
              <q-btn color="primary" label="Save" :loading="shipmentStore.saving" @click="saveField('weight')" />
              <q-btn flat label="Cancel" :disable="shipmentStore.saving" @click="cancelEdit" />
            </template>
            <template v-else>
              <div class="col">{{ displayNumber(shipmentStore.selectedShipment?.weight) }}</div>
              <q-btn flat round dense icon="edit" @click="startEdit('weight')" />
            </template>
          </div>
        </div>

        <div class="row items-center q-col-gutter-sm">
          <div class="col-12 col-md-4 text-weight-medium">Received Weight</div>
          <div class="col-12 col-md-8 row items-center q-gutter-sm">
            <template v-if="editingField === 'received_weight'">
              <q-input v-model.number="draft.received_weight" type="number" step="0.001" outlined dense class="col" />
              <q-btn color="primary" label="Save" :loading="shipmentStore.saving" @click="saveField('received_weight')" />
              <q-btn flat label="Cancel" :disable="shipmentStore.saving" @click="cancelEdit" />
            </template>
            <template v-else>
              <div class="col">{{ displayNumber(shipmentStore.selectedShipment?.received_weight) }}</div>
              <q-btn flat round dense icon="edit" @click="startEdit('received_weight')" />
            </template>
          </div>
        </div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import PageInitialLoader from 'src/components/PageInitialLoader.vue'
import { useShipmentStore } from '../stores/shipmentStore'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const shipmentStore = useShipmentStore()

const shipmentId = computed(() => Number(route.params.id))
const initialLoading = ref(true)
type EditableField =
  | 'name'
  | 'product_conversion_rate'
  | 'cargo_conversion_rate'
  | 'cargo_rate'
  | 'weight'
  | 'received_weight'
const editingField = ref<EditableField | null>(null)

const draft = reactive({
  name: '',
  product_conversion_rate: null as number | null,
  cargo_conversion_rate: null as number | null,
  cargo_rate: null as number | null,
  weight: null as number | null,
  received_weight: null as number | null,
})

const toNullableNumber = (value: unknown) => {
  if (value === '' || value == null) return null
  const n = Number(value)
  return Number.isFinite(n) ? n : null
}

const displayNumber = (value: unknown) => {
  const n = toNullableNumber(value)
  return n == null ? '-' : String(n)
}

const syncDraftFromStore = () => {
  const current = shipmentStore.selectedShipment
  draft.name = current?.name ?? ''
  draft.product_conversion_rate = toNullableNumber(current?.product_conversion_rate)
  draft.cargo_conversion_rate = toNullableNumber(current?.cargo_conversion_rate)
  draft.cargo_rate = toNullableNumber(current?.cargo_rate)
  draft.weight = toNullableNumber(current?.weight)
  draft.received_weight = toNullableNumber(current?.received_weight)
}

const onBack = async () => {
  const tenantPrefix = authStore.tenantSlug ? `/${authStore.tenantSlug}` : ''
  await router.push(`${tenantPrefix}/app/shipment/${shipmentId.value}`)
}

const startEdit = (field: EditableField) => {
  syncDraftFromStore()
  editingField.value = field
}

const cancelEdit = () => {
  editingField.value = null
  syncDraftFromStore()
}

const saveField = async (field: EditableField) => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }

  const patch: {
    name?: string
    product_conversion_rate?: number | null
    cargo_conversion_rate?: number | null
    cargo_rate?: number | null
    weight?: number | null
    received_weight?: number | null
  } = {}

  if (field === 'name') patch.name = draft.name.trim()
  if (field === 'product_conversion_rate') patch.product_conversion_rate = toNullableNumber(draft.product_conversion_rate)
  if (field === 'cargo_conversion_rate') patch.cargo_conversion_rate = toNullableNumber(draft.cargo_conversion_rate)
  if (field === 'cargo_rate') patch.cargo_rate = toNullableNumber(draft.cargo_rate)
  if (field === 'weight') patch.weight = toNullableNumber(draft.weight)
  if (field === 'received_weight') patch.received_weight = toNullableNumber(draft.received_weight)

  const result = await shipmentStore.updateShipment({
    id: shipmentId.value,
    patch,
  })

  if (!result.success) {
    return
  }

  editingField.value = null
  syncDraftFromStore()
}

onMounted(async () => {
  if (!Number.isFinite(shipmentId.value) || shipmentId.value <= 0) {
    return
  }
  try {
    await shipmentStore.fetchShipmentById(shipmentId.value)
    syncDraftFromStore()
  } finally {
    initialLoading.value = false
  }
})
</script>
