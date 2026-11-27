<template>
  <FilterSidebar
    :model-value="modelValue"
    title="Edit order line"
    width="min(480px, 92vw)"
    :resizable="false"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="text-caption text-grey-7 q-mb-sm">Customer link &amp; ops fields</div>
    <div class="q-gutter-y-sm">
      <q-input
        v-model="url"
        class="pp-app-edit-line__url"
        outlined
        dense
        hide-bottom-space
        readonly
        label="Product URL"
        type="url"
        @click="openUrl"
      >
        <template #append>
          <q-icon
            name="ph ph-arrow-square-out"
            class="cursor-pointer"
            @click.stop="openUrl"
          />
        </template>
      </q-input>
      <q-input
        :model-value="storeLabel"
        outlined
        dense
        hide-bottom-space
        readonly
        label="Store"
      />
      <q-input
        v-model="trackingUrl"
        outlined
        dense
        hide-bottom-space
        clearable
        label="Tracking URL"
        type="url"
      >
        <template #append>
          <q-icon
            v-if="trackingUrl.trim()"
            name="ph ph-arrow-square-out"
            class="cursor-pointer"
            @click.stop="openTrackingUrl"
          />
        </template>
      </q-input>
      <q-input
        v-model.number="neededQty"
        outlined
        dense
        hide-bottom-space
        readonly
        type="number"
        label="Quantity needed"
      />
      <q-input
        v-model="description"
        outlined
        dense
        hide-bottom-space
        readonly
        type="textarea"
        label="Customer description"
        :rows="3"
      />
      <q-input v-model="productName" outlined dense hide-bottom-space label="Product name" />
      <q-input v-model="imageUrl" outlined dense hide-bottom-space label="Image URL" type="url" />
      <q-input
        v-model.number="unitPrice"
        outlined
        dense
        hide-bottom-space
        type="number"
        min="0"
        step="0.01"
        label="Unit price"
      />
      <q-select
        v-model="supplierGroupId"
        outlined
        dense
        emit-value
        map-options
        clearable
        label="Supplier group"
        :options="supplierOptions"
        :loading="supplierGroupsQuery.isPending.value"
      />
      <q-select
        v-model="shipmentId"
        outlined
        dense
        emit-value
        map-options
        options-dense
        label="Shipment"
        :options="shipmentOptions"
        :loading="shipmentsQuery.isPending.value"
      >
        <template #option="scope">
          <q-item v-bind="scope.itemProps">
            <q-item-section>
              <div class="pp-shipment-opt">
                <div class="pp-shipment-opt__name">{{ scope.opt.name }}</div>
                <div v-if="scope.opt.value != null" class="pp-shipment-opt__id">
                  #{{ scope.opt.value }}
                </div>
              </div>
            </q-item-section>
          </q-item>
        </template>
        <template #selected-item="scope">
          <div v-if="scope.opt" class="pp-shipment-opt">
            <div class="pp-shipment-opt__name">{{ scope.opt.name }}</div>
            <div v-if="scope.opt.value != null" class="pp-shipment-opt__id">
              #{{ scope.opt.value }}
            </div>
          </div>
        </template>
      </q-select>
      <q-select
        v-model="placementStatus"
        outlined
        dense
        emit-value
        map-options
        label="Fulfillment"
        :options="placementOptions"
      />
      <q-input
        v-model.number="placedQty"
        outlined
        dense
        hide-bottom-space
        type="number"
        min="0"
        step="1"
        clearable
        label="Ordered quantity"
      />
      <q-input
        v-model.number="receivedQty"
        outlined
        dense
        hide-bottom-space
        type="number"
        min="0"
        step="1"
        clearable
        label="Received quantity"
      />
    </div>
    <template #footer>
      <div class="row justify-end q-gutter-sm">
        <TfBtn variant="tertiary" size="md" label="Cancel" @click="$emit('update:modelValue', false)" />
        <TfBtn
          variant="primary"
          size="md"
          label="Save"
          :loading="loading"
          :disable="!canSubmit"
          @click="submit"
        />
      </div>
    </template>
  </FilterSidebar>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import FilterSidebar from 'src/components/FilterSidebar.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import { usePpPeopleGroupsQuery } from '../composables/usePpPeopleGroupsQuery';
import { usePpShipmentsQuery } from '../composables/usePpShipmentsQuery';
import type {
  PpOrderLine,
  PpOrderLinePlacementStatus,
  PpStaffOrderLineUpdatePayload,
} from '../types/ppPurchaseRequest';
import { buildPpShipmentSelectOptions } from '../types/ppShipment';
import { PP_ORDER_LINE_STAFF_PLACEMENT_OPTIONS } from '../utils/ppOrderLinePlacement';
import { buildPpStaffOrderLineUpdate } from '../utils/ppStaffOrderLineUpdate';
import { openPpOrderLineUrl, ppOrderLineHostLabel } from '../utils/ppOrderLineUrl';

const props = defineProps<{
  modelValue: boolean;
  loading?: boolean;
  editLine?: PpOrderLine | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: PpStaffOrderLineUpdatePayload];
}>();

const supplierType = ref<'supplier'>('supplier');
const supplierGroupsQuery = usePpPeopleGroupsQuery(supplierType);
const shipmentsQuery = usePpShipmentsQuery();

const url = ref('');
const trackingUrl = ref('');
const neededQty = ref<number | null>(null);
const description = ref('');
const productName = ref('');
const imageUrl = ref('');
const unitPrice = ref<number | null>(null);
const supplierGroupId = ref<number | null>(null);
const shipmentId = ref<number | null>(null);
const placementStatus = ref<PpOrderLinePlacementStatus>('requested');
const placedQty = ref<number | null>(null);
const receivedQty = ref<number | null>(null);

const placementOptions = PP_ORDER_LINE_STAFF_PLACEMENT_OPTIONS;

const supplierOptions = computed(() =>
  (supplierGroupsQuery.data.value ?? []).map((g) => ({
    label: g.name,
    value: g.id,
  })),
);

const shipmentOptions = computed(() =>
  buildPpShipmentSelectOptions(shipmentsQuery.data.value ?? []),
);

const storeLabel = computed(() => ppOrderLineHostLabel(url.value));

const populateFromEdit = () => {
  const line = props.editLine;
  if (!line) return;
  url.value = line.url;
  trackingUrl.value = line.tracking_url?.trim() ?? '';
  neededQty.value = Number(line.needed_qty);
  description.value = line.description?.trim() ?? '';
  productName.value = line.product_name?.trim() ?? '';
  imageUrl.value = line.image_url?.trim() ?? '';
  unitPrice.value = line.unit_price == null ? null : Number(line.unit_price);
  supplierGroupId.value = line.pp_supplier_group_id;
  shipmentId.value = line.shipment_id;
  placementStatus.value = line.placement_status === 'none' ? 'requested' : line.placement_status;
  placedQty.value = line.placed_qty == null ? null : Number(line.placed_qty);
  receivedQty.value = line.received_qty == null ? null : Number(line.received_qty);
};

watch(
  () => [props.modelValue, props.editLine] as const,
  ([open]) => {
    if (open) populateFromEdit();
  },
);

const canSubmit = computed(() => {
  const qty = neededQty.value;
  return url.value.trim().length > 0 && qty != null && Number.isFinite(qty) && qty > 0;
});

const openUrl = () => {
  openPpOrderLineUrl(url.value);
};

const openTrackingUrl = () => {
  openPpOrderLineUrl(trackingUrl.value);
};

const submit = () => {
  const line = props.editLine;
  if (!canSubmit.value || neededQty.value == null || !line) return;
  emit(
    'submit',
    buildPpStaffOrderLineUpdate(line, {
      url: url.value.trim(),
      tracking_url: trackingUrl.value.trim() || null,
      needed_qty: neededQty.value,
      description: description.value.trim() || null,
      product_name: productName.value.trim() || null,
      image_url: imageUrl.value.trim() || null,
      unit_price: unitPrice.value,
      pp_supplier_group_id: supplierGroupId.value,
      shipment_id: shipmentId.value,
      placement_status: placementStatus.value,
      placed_qty: placedQty.value,
      received_qty: receivedQty.value,
    }),
  );
};
</script>

<style scoped>
.pp-shipment-opt__name {
  font-size: 13px;
  font-weight: 600;
  line-height: 1.35;
}

.pp-shipment-opt__id {
  font-size: 11px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  font-family: var(--tf-font-mono);
  color: var(--tf-neutral-muted);
}

.pp-app-edit-line__url :deep(.q-field__control) {
  cursor: pointer;
}

.pp-app-edit-line__url :deep(input) {
  cursor: pointer;
  color: var(--q-primary);
  text-decoration: underline;
  text-underline-offset: 2px;
}
</style>