<template>
  <section v-if="shipment" class="row items-start justify-between q-col-gutter-sm shipment-header-bar">
    <div class="col">
      <div class="row items-center no-wrap q-gutter-x-xs">
        <q-btn
          flat
          dense
          round
          icon="ph ph-arrow-left"
          color="grey-7"
          aria-label="Back"
          @click="$emit('go-back')"
        />
        <div class="min-width-0">
          <!-- #id + name; tap-to-edit name in place -->
          <div class="text-subtitle1 text-weight-bold row items-center q-gutter-x-xs no-wrap">
            <span class="text-grey-7 text-weight-medium shipment-id-prefix">
              #{{ (shipment as any).tenant_shipment_id || shipment.id }}
            </span>
            <template v-if="editingName">
              <q-input
                ref="nameEditInputRef"
                v-model="inlineNameInput"
                dense
                outlined
                hide-bottom-space
                class="col soft-input shipment-name-edit-input"
                aria-label="Shipment name"
                @keyup.enter="commitInlineName"
                @keyup.escape="cancelInlineName"
                @blur="commitInlineName"
              />
            </template>
            <template v-else>
              <span
                class="ellipsis"
                :class="{ 'cursor-pointer text-primary': isEditable }"
                @click="startInlineNameEdit"
              >
                {{ shipment.name }}
              </span>
              <q-icon
                v-if="isEditable"
                name="ph ph-pencil-simple"
                size="xs"
                color="grey-6"
                class="cursor-pointer shipment-id-prefix"
                @click="startInlineNameEdit"
              />
            </template>
          </div>

          <!-- Chips Row for Type, Vendor & Cargo -->
          <div class="row items-center q-gutter-xs q-mt-xs wrap">
            <!-- Interactive Type Chip -->
            <q-chip
              clickable
              outline
              dense
              square
              size="sm"
              color="primary"
              class="cursor-pointer"
              :disable="!isEditable"
            >
              <span class="text-capitalize">{{ shipment.type }}</span>
              <q-icon v-if="isEditable" name="ph ph-caret-down" size="xs" class="q-ml-xs" />
              <q-menu v-if="isEditable" auto-close>
                <q-list dense style="min-width: 140px">
                  <q-item
                    v-for="opt in typeOptions"
                    :key="opt.value"
                    clickable
                    :active="shipment.type === opt.value"
                    @click="$emit('update-type', opt.value)"
                  >
                    <q-item-section>{{ opt.label }}</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-chip>

            <!-- Interactive Vendor Chip -->
            <q-chip
              clickable
              outline
              dense
              square
              size="sm"
              color="teal-8"
              class="cursor-pointer"
              :disable="!isEditable"
            >
              <span>{{ currentVendorLabel }}</span>
              <q-icon v-if="isEditable" name="ph ph-caret-down" size="xs" class="q-ml-xs" />
              <q-menu v-if="isEditable" auto-close @before-show="$emit('ensure-vendors')">
                <q-list dense style="min-width: 180px; max-height: 280px" class="scroll">
                  <q-item v-if="loadingVendors" dense>
                    <q-item-section class="text-grey-6">Loading…</q-item-section>
                  </q-item>
                  <q-item
                    v-for="opt in vendorOptions"
                    :key="opt.value"
                    clickable
                    :active="shipment.vendor_id === opt.value"
                    @click="$emit('update-vendor', opt.value)"
                  >
                    <q-item-section>{{ opt.label }}</q-item-section>
                  </q-item>
                  <q-item v-if="!loadingVendors && !vendorOptions.length" dense>
                    <q-item-section class="text-grey-6">No vendors</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-chip>

            <!-- Interactive Cargo Vendor Chip -->
            <q-chip
              clickable
              outline
              dense
              square
              size="sm"
              color="indigo-8"
              class="cursor-pointer"
              :disable="!isEditable"
            >
              <span>{{ currentCargoLabel }}</span>
              <q-icon v-if="isEditable" name="ph ph-caret-down" size="xs" class="q-ml-xs" />
              <q-menu v-if="isEditable" auto-close @before-show="$emit('ensure-cargo')">
                <q-list dense style="min-width: 180px; max-height: 280px" class="scroll">
                  <q-item v-if="loadingCargo" dense>
                    <q-item-section class="text-grey-6">Loading…</q-item-section>
                  </q-item>
                  <q-item
                    v-if="shipment.cargo_company_id"
                    clickable
                    @click="$emit('update-cargo', null)"
                  >
                    <q-item-section class="text-grey-7">Clear</q-item-section>
                  </q-item>
                  <q-item
                    v-for="opt in cargoOptions"
                    :key="opt.value"
                    clickable
                    :active="shipment.cargo_company_id === opt.value"
                    @click="$emit('update-cargo', opt.value)"
                  >
                    <q-item-section>{{ opt.label }}</q-item-section>
                  </q-item>
                  <q-item v-if="!loadingCargo && !cargoOptions.length" dense>
                    <q-item-section class="text-grey-6">No cargo companies</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-chip>

            <span class="text-grey-5">·</span>
            <span class="text-caption text-grey-7">
              {{ shipment.received_date || '—' }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <div class="col-auto row q-gutter-xs items-center">
      <q-btn
        v-if="shipment.status === 'received' || shipment.stock_ready"
        outline
        dense
        no-caps
        size="sm"
        color="primary"
        icon="ph ph-package"
        label="Organize Stock"
        style="border-radius: 8px"
        class="q-px-xs"
        @click="$emit('organize-stock')"
      >
        <q-tooltip>View & split batch stock in warehouse</q-tooltip>
      </q-btn>
      <q-btn
        flat
        dense
        no-caps
        size="sm"
        color="primary"
        icon="ph ph-download-simple"
        label="Excel"
        @click="$emit('download-excel')"
      />
      <q-btn
        v-if="isEditable"
        flat
        dense
        no-caps
        size="sm"
        color="negative"
        icon="ph ph-trash"
        label="Delete"
        @click="$emit('delete-shipment')"
      />
    </div>
  </section>
</template>

<script setup lang="ts">
import { ref, watch, nextTick } from 'vue';
import type { QInput } from 'quasar';
import type { GlobalShipment } from '../repositories/globalShipmentRepository';

const props = defineProps<{
  shipment: GlobalShipment | null;
  isEditable: boolean;
  typeOptions: Array<{ label: string; value: 'international' | 'local' | 'transfer' }>;
  vendorOptions: Array<{ label: string; value: number }>;
  currentVendorLabel: string;
  loadingVendors: boolean;
  cargoOptions: Array<{ label: string; value: number }>;
  currentCargoLabel: string;
  loadingCargo: boolean;
}>();

const emit = defineEmits<{
  'go-back': [];
  'update-name': [name: string];
  'update-type': [type: 'international' | 'local' | 'transfer'];
  'update-vendor': [vendorId: number];
  'update-cargo': [cargoId: number | null];
  'ensure-vendors': [];
  'ensure-cargo': [];
  'download-excel': [];
  'delete-shipment': [];
  'organize-stock': [];
}>();

const inlineNameInput = ref('');
const editingName = ref(false);
const nameEditInputRef = ref<QInput | null>(null);

watch(
  () => props.shipment?.name,
  (val) => {
    if (val && !editingName.value) inlineNameInput.value = val;
  },
  { immediate: true },
);

const startInlineNameEdit = async () => {
  if (!props.isEditable || editingName.value) return;
  inlineNameInput.value = props.shipment?.name ?? '';
  editingName.value = true;
  await nextTick();
  const native = nameEditInputRef.value?.$el?.querySelector?.('input') as
    | HTMLInputElement
    | undefined;
  native?.focus();
  native?.select();
};

const cancelInlineName = () => {
  editingName.value = false;
  inlineNameInput.value = props.shipment?.name ?? '';
};

const commitInlineName = () => {
  if (!editingName.value) return;
  const next = inlineNameInput.value.trim();
  const current = props.shipment?.name ?? '';
  editingName.value = false;
  if (!next || next === current) {
    cancelInlineName();
    return;
  }
  emit('update-name', next);
};
</script>

<style scoped>
.shipment-header-bar .min-width-0 {
  min-width: 0;
}
.shipment-id-prefix {
  flex-shrink: 0;
}
.shipment-name-edit-input {
  max-width: 420px;
}
</style>
