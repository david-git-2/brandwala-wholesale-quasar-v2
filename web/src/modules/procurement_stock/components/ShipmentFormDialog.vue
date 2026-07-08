<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin" style="width: 600px; max-width: 90vw;">
      <q-form @submit="onSubmit">
        <q-card-section class="row items-center q-pb-none">
          <div class="text-h6 text-primary text-weight-bold">
            {{ isEdit ? 'Edit Shipment Details' : 'Create New Inbound Shipment' }}
          </div>
          <q-space />
          <q-btn icon="close" flat round dense v-close-popup />
        </q-card-section>

        <q-card-section class="q-pa-md q-gutter-y-md">
          <!-- Error banner -->
          <q-banner v-if="error" class="bg-negative text-white rounded-borders q-py-sm">
            {{ error }}
          </q-banner>

          <!-- Core Details -->
          <div class="text-subtitle2 text-grey-8 q-mb-xs">Core Information</div>
          <q-input
            v-model="form.name"
            label="Shipment Name *"
            filled
            dense
            :rules="[val => !!val || 'Name is required', val => val.trim().length > 0 || 'Name cannot be blank']"
          />

          <div class="row q-col-gutter-sm">
            <div class="col-12">
              <q-select
                v-model="form.type"
                :options="typeOptions"
                label="Shipment Type *"
                filled
                dense
                emit-value
                map-options
              />
            </div>
          </div>

          <!-- Currency Settings -->
          <div class="text-subtitle2 text-grey-8 q-mt-md q-mb-xs">Currencies</div>
          <div class="row q-col-gutter-sm">
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.shipment_purchase_currency_id"
                :options="currencyOptions"
                label="Purchase Currency"
                filled
                dense
                emit-value
                map-options
                clearable
                :loading="loadingCurrencies"
              />
            </div>
            <div class="col-12 col-sm-6">
              <q-select
                v-model="form.shipment_cost_currency_id"
                :options="currencyOptions"
                label="Cost Currency"
                filled
                dense
                emit-value
                map-options
                clearable
                :loading="loadingCurrencies"
              />
            </div>
          </div>

          <!-- Rates (only shown or prioritized during Edit or advanced toggle) -->
          <div v-if="isEdit" class="q-gutter-y-md">
            <div class="text-subtitle2 text-grey-8 q-mt-md q-mb-xs">Costing & Conversion Rates</div>
            
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="form.status"
                  :options="statusOptions"
                  label="Shipment Status *"
                  filled
                  dense
                  emit-value
                  map-options
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model="form.received_date"
                  label="Received Date"
                  filled
                  dense
                  readonly
                  clearable
                >
                  <template #append>
                    <q-icon name="event" class="cursor-pointer">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-date v-model="form.received_date" mask="YYYY-MM-DD">
                          <div class="row items-center justify-end">
                            <q-btn v-close-popup label="Close" color="primary" flat />
                          </div>
                        </q-date>
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="form.transaction_rate"
                  type="number"
                  step="0.0001"
                  label="Transaction Rate"
                  filled
                  dense
                />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="form.product_conversion_rate"
                  type="number"
                  step="0.0001"
                  label="Product Conv. Rate"
                  filled
                  dense
                  :rules="[val => val >= 0 || 'Must be >= 0']"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="form.cargo_conversion_rate"
                  type="number"
                  step="0.0001"
                  label="Cargo Conv. Rate"
                  filled
                  dense
                  :rules="[val => val >= 0 || 'Must be >= 0']"
                />
              </div>
              <div class="col-12 col-sm-4">
                <q-input
                  v-model.number="form.cargo_rate"
                  type="number"
                  step="0.01"
                  label="Cargo Rate"
                  filled
                  dense
                  :rules="[val => val >= 0 || 'Must be >= 0']"
                />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <div class="bg-grey-2 q-pa-sm rounded-borders text-caption text-grey-8" style="min-height: 40px; display: flex; align-items: center;">
                  <span>
                    Received Weight: <strong class="text-black">{{ form.received_weight !== null ? `${form.received_weight} kg` : '—' }}</strong>
                    <br />
                    <span class="text-grey-6 text-weight-light" style="font-size: 10px;">(Set automatically via Weight Balance)</span>
                  </span>
                </div>
              </div>
              <div class="col-12 col-sm-6 items-center flex">
                <q-checkbox v-model="form.stock_ready" label="Stock Ready" />
              </div>
            </div>

          </div>
        </q-card-section>

        <q-card-actions align="right" class="q-pa-md bg-grey-1">
          <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
          <q-btn
            type="submit"
            color="primary"
            unelevated
            :label="isEdit ? 'Save Changes' : 'Create Shipment'"
            :loading="submitting"
            no-caps
          />
        </q-card-actions>
      </q-form>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useDialogPluginComponent } from 'quasar'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useGlobalShipmentStore } from '../stores/globalShipmentStore'
import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository'
import type { GlobalShipment } from '../repositories/globalShipmentRepository'

const props = defineProps<{
  shipment?: GlobalShipment
}>()

defineEmits([
  ...useDialogPluginComponent.emits
])

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent()

const authStore = useAuthStore()
const shipmentStore = useGlobalShipmentStore()

const isEdit = computed(() => !!props.shipment)
const submitting = ref(false)
const error = ref<string | null>(null)

const typeOptions = [
  { label: 'International', value: 'international' },
  { label: 'Domestic', value: 'domestic' },
]

const statusOptions = [
  { label: 'Draft', value: 'Draft' },
  { label: 'Order Placed', value: 'Order Placed' },
  { label: 'Proforma Generated', value: 'Proforma Generated' },
  { label: 'Payment Done', value: 'Payment Done' },
  { label: 'Delivery Date Received', value: 'Delivery Date Received' },
  { label: 'UK Warehouse Delivery Received', value: 'Uk Warehouse Delivery Received' },
  { label: 'Air Shipment Date Set', value: 'Air Shipment Date Set' },
  { label: 'Airport Arrival', value: 'Airport Arrival' },
  { label: 'Airport Released', value: 'Airport Released' },
  { label: 'Warehouse Received', value: 'Warehouse Received' },
  { label: 'Ready Stock', value: 'Ready Stock' },
]

const form = ref({
  name: '',
  type: 'international' as 'domestic' | 'international',
  shipment_purchase_currency_id: null as number | null,
  shipment_cost_currency_id: null as number | null,
  status: 'Draft',
  product_conversion_rate: 1.0,
  cargo_conversion_rate: 1.0,
  cargo_rate: 0.0,
  received_weight: null as number | null,
  received_date: null as string | null,
  transaction_rate: null as number | null,
  stock_ready: false,
})

const currencyOptions = ref<Array<{ label: string; value: number }>>([])
const loadingCurrencies = ref(false)

onMounted(async () => {
  // Load currencies
  loadingCurrencies.value = true
  try {
    const list = await globalReferenceRepository.listCurrencies()
    currencyOptions.value = list.map((c) => ({
      label: `${c.code} (${c.symbol}) - ${c.name}`,
      value: c.id,
    }))
  } catch (err: unknown) {
    console.error('Failed to load currencies', err)
  } finally {
    loadingCurrencies.value = false
  }

  // Initialize form if edit mode
  if (props.shipment) {
    form.value = {
      name: props.shipment.name,
      type: props.shipment.type,
      shipment_purchase_currency_id: props.shipment.shipment_purchase_currency_id,
      shipment_cost_currency_id: props.shipment.shipment_cost_currency_id,
      status: props.shipment.status,
      product_conversion_rate: props.shipment.product_conversion_rate,
      cargo_conversion_rate: props.shipment.cargo_conversion_rate,
      cargo_rate: props.shipment.cargo_rate,
      received_weight: props.shipment.received_weight,
      received_date: props.shipment.received_date,
      transaction_rate: props.shipment.transaction_rate,
      stock_ready: props.shipment.stock_ready,
    }
  }
})

const onSubmit = async () => {
  if (!authStore.tenantId) return
  submitting.value = ref(true).value
  error.value = null

  try {
    if (isEdit.value && props.shipment) {
      const updated = await shipmentStore.updateShipment(props.shipment.id, form.value)
      onDialogOK(updated)
    } else {
      const created = await shipmentStore.createShipment(authStore.tenantId, {
        name: form.value.name,
        type: form.value.type,
        shipment_purchase_currency_id: form.value.shipment_purchase_currency_id,
        shipment_cost_currency_id: form.value.shipment_cost_currency_id,
      })
      onDialogOK(created)
    }
  } catch (err: unknown) {
    error.value = (err as Error).message || 'Failed to save shipment.'
  } finally {
    submitting.value = false
  }
}
</script>
