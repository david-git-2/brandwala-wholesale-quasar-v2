<template>
  <q-dialog v-model="localOpen" persistent>
    <q-card style="min-width: 420px; max-width: 90vw">
      <q-card-section class="row items-center justify-between">
        <div class="text-h6">{{ isBatch ? 'Batch Add to Shipment' : 'Add Shipment' }}</div>
        <q-btn flat round dense icon="ph ph-x" :disable="loading || creatingShipment" @click="onCancel" />
      </q-card-section>

      <q-separator />

      <q-card-section class="q-gutter-md">
        <q-select
          v-model="form.shipment_id"
          :options="shipmentOptions"
          label="Shipment"
          outlined
          emit-value
          map-options
          :rules="[requiredRule]"
          :disable="loading || creatingShipment"
        >
          <template #after>
            <q-btn
              round
              dense
              flat
              icon="ph ph-plus"
              color="primary"
              :loading="creatingShipment"
              @click="onCreateInlineShipment"
            >
              <q-tooltip>Create new draft shipment</q-tooltip>
            </q-btn>
          </template>
        </q-select>

        <q-checkbox
          v-if="form.shipment_id !== props.defaultShipmentId"
          v-model="form.save_as_default"
          label="Set as file default shipment"
          dense
        />

        <template v-if="!isBatch">
          <q-input
            v-model.number="form.quantity"
            label="Quantity"
            type="number"
            outlined
            :rules="[requiredRule]"
            :disable="loading"
          />

          <q-input
            v-model.number="form.price_gbp"
            label="Price (GBP)"
            type="number"
            step="0.01"
            outlined
            :disable="loading"
          />
        </template>
      </q-card-section>

      <q-separator />

      <q-card-actions align="right">
        <q-btn flat label="Cancel" color="grey-7" :disable="loading || creatingShipment" @click="onCancel" />
        <q-btn color="primary" label="Save" :loading="loading" :disable="loading || creatingShipment" @click="onSave" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';

type Shipment = {
  id: number;
  name: string;
  status?: string | null;
  tenant_shipment_id?: number | null;
};

const props = defineProps<{
  modelValue: boolean;
  quantity?: number | null;
  priceGbp?: number | null;
  defaultShipmentId?: number | null;
  isBatch?: boolean;
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (
    e: 'save',
    payload: {
      shipment_id: number;
      quantity?: number | null;
      price_gbp?: number | null;
      save_as_default?: boolean;
    },
  ): void;
  (e: 'shipment-change', shipmentId: number | null): void;
}>();

const shipmentStore = useGlobalShipmentStore();
const tenantStore = useTenantStore();
const creatingShipment = ref(false);

const localOpen = computed({
  get: () => props.modelValue,
  set: (value: boolean) => emit('update:modelValue', value),
});

const form = reactive<{
  shipment_id: number | null;
  quantity: number | null;
  price_gbp: number | null;
  save_as_default: boolean;
}>({
  shipment_id: props.defaultShipmentId ?? null,
  quantity: props.quantity ?? null,
  price_gbp: props.priceGbp ?? null,
  save_as_default: true,
});

watch(
  () => props.modelValue as boolean,
  (opened) => {
    if (opened) {
      form.shipment_id = props.defaultShipmentId ?? null;
      form.quantity = props.quantity ?? null;
      form.price_gbp = props.priceGbp ?? null;
      form.save_as_default = true;
    }
  },
);

watch(
  () => props.defaultShipmentId,
  (value) => {
    if (localOpen.value) {
      form.shipment_id = value ?? null;
    }
  },
);

watch(
  () => props.quantity,
  (value) => {
    if (localOpen.value) {
      form.quantity = value ?? null;
    }
  },
);

watch(
  () => props.priceGbp,
  (value) => {
    if (localOpen.value) {
      form.price_gbp = value ?? null;
    }
  },
);

const shipmentOptions = computed(() =>
  (shipmentStore.rows ?? [])
    .filter((shipment: Shipment) => shipment.status === 'draft')
    .map((shipment: Shipment) => ({
      label: `#${shipment.tenant_shipment_id ?? shipment.id} ${shipment.name}`,
      value: shipment.id,
    })),
);

const requiredRule = (value: unknown) =>
  (value !== null && value !== undefined && value !== '') || 'This field is required';

const onCancel = () => {
  localOpen.value = false;
};

const onCreateInlineShipment = async () => {
  const tenantId = tenantStore.selectedTenant?.id;
  if (!tenantId) return;

  creatingShipment.value = true;
  try {
    const created = await shipmentStore.createShipment(tenantId, {
      name: `Shipment ${new Date().toLocaleDateString()}`,
      type: 'international',
      shipment_purchase_currency_id: null,
      shipment_cost_currency_id: null,
    });
    if (created?.id) {
      await shipmentStore.fetchShipments(tenantId);
      form.shipment_id = created.id;
    }
  } finally {
    creatingShipment.value = false;
  }
};

const onSave = () => {
  if (props.loading || creatingShipment.value) {
    return;
  }
  if (form.shipment_id == null) {
    return;
  }
  if (!props.isBatch && form.quantity == null) {
    return;
  }

  emit('save', {
    shipment_id: form.shipment_id,
    quantity: form.quantity == null ? null : Number(form.quantity),
    price_gbp:
      form.price_gbp === null || form.price_gbp === undefined ? null : Number(form.price_gbp),
    save_as_default: form.save_as_default,
  });
};

watch(
  () => form.shipment_id,
  (value) => {
    if (localOpen.value) {
      emit('shipment-change', value ?? null);
    }
  },
);
</script>
