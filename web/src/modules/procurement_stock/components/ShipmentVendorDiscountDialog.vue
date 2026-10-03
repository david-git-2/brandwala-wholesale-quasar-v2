<template>
  <q-dialog v-model="isOpen" persistent @show="onShow">
    <q-card style="width: 520px; max-width: 95vw" class="q-pa-sm">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="text-h6 text-weight-bold text-grey-9 row items-center q-gutter-x-xs">
          <q-icon name="ph ph-receipt" color="primary" size="24px" />
          <span>Record vendor credit</span>
        </div>
        <q-btn v-close-popup flat round dense icon="ph ph-x" color="grey-7" />
      </q-card-section>

      <q-card-section class="q-pt-sm">
        <div v-if="lineLabel" class="text-caption text-grey-7 q-mb-md">
          {{ lineLabel }}
        </div>
        <p class="text-caption text-grey-8 q-mb-md" style="line-height: 1.35">
          Financial record only. Land splits and warehouse stock are not changed. Sort or re-grade
          product in the warehouse separately.
        </p>

        <q-banner
          v-if="outcomeOptions.length === 0"
          dense
          rounded
          class="bg-orange-1 text-orange-10 q-mb-md"
        >
          Add a sellable land split on this line first (after receive).
        </q-banner>

        <q-form v-else class="q-gutter-y-md" @submit.prevent="onSubmit">
          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">Land split</div>
            <q-select
              v-model="sourceOutcomeId"
              :options="outcomeOptions"
              emit-value
              map-options
              filled
              dense
              :disable="outcomeOptions.length <= 1"
            />
          </div>

          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">
              Units credited (max {{ maxSplitQty }})
            </div>
            <q-input
              v-model.number="quantity"
              type="number"
              min="1"
              :max="maxSplitQty"
              filled
              dense
              :rules="[
                (v) => (v != null && v >= 1) || 'Enter at least 1',
                (v) => v <= maxSplitQty || `Cannot exceed split qty ${maxSplitQty}`,
              ]"
            />
          </div>

          <div>
            <div class="text-caption text-weight-medium text-grey-8 q-mb-xs">
              Agreed purchase price ({{ currencySymbol }})
            </div>
            <q-input
              v-model.number="newPurchasePrice"
              type="number"
              step="0.01"
              min="0"
              filled
              dense
              :prefix="currencySymbol"
              :rules="[(v) => v != null && v >= 0 || 'Price must be 0 or more']"
            />
          </div>

          <div v-if="previewCredit > 0" class="text-caption text-grey-8">
            Credit this entry:
            <span class="text-weight-bold text-primary">{{ currencySymbol }}{{ previewCredit.toFixed(2) }}</span>
            ({{ quantity }} × price drop)
          </div>

          <div class="row justify-end q-gutter-sm q-pt-sm">
            <q-btn v-close-popup flat no-caps label="Cancel" color="grey-7" />
            <q-btn
              type="submit"
              color="primary"
              unelevated
              no-caps
              label="Save record"
              :loading="submitting"
            />
          </div>
        </q-form>

        <div v-if="recentCredits.length > 0" class="q-mt-lg q-pt-md" style="border-top: 1px solid #e2e8f0">
          <div class="text-caption text-weight-bold text-grey-8 q-mb-sm">Credits on this shipment</div>
          <q-list dense bordered separator class="rounded-borders">
            <q-item v-for="row in recentCredits" :key="row.id" dense>
              <q-item-section>
                <q-item-label class="text-caption text-weight-medium">
                  {{ row.item_name }} · {{ row.quantity }} pcs
                </q-item-label>
                <q-item-label caption>
                  {{ currencySymbol }}{{ Number(row.previous_purchase_price).toFixed(2) }}
                  → {{ currencySymbol }}{{ Number(row.new_purchase_price).toFixed(2) }}
                  · credit {{ currencySymbol }}{{ Number(row.credit_amount).toFixed(2) }}
                </q-item-label>
              </q-item-section>
              <q-item-section v-if="canDelete" side>
                <q-btn
                  flat
                  round
                  dense
                  size="sm"
                  icon="ph ph-trash"
                  color="negative"
                  aria-label="Remove vendor credit"
                  :disable="deletingCreditId === row.id"
                  :loading="deletingCreditId === row.id"
                  @click="onDeleteCredit(row.id)"
                />
              </q-item-section>
            </q-item>
          </q-list>
        </div>
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type { ShipmentItemOutcome } from '../repositories/globalShipmentRepository';
import {
  globalShipmentRepository,
  type ShipmentOutcomeVendorCredit,
} from '../repositories/globalShipmentRepository';
import { formatOutcomeReason } from '../constants/shipmentOutcomeLabels';

const props = defineProps<{
  modelValue: boolean;
  shipmentId: number;
  lineLabel: string;
  currencySymbol: string;
  extras: ShipmentItemOutcome[];
  submitting?: boolean;
  canDelete?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: { sourceOutcomeId: number; quantity: number; newPurchasePrice: number }];
  'delete-credit': [id: number];
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v),
});

const sourceOutcomeId = ref<number | null>(null);
const quantity = ref(1);
const newPurchasePrice = ref(0);
const recentCredits = ref<ShipmentOutcomeVendorCredit[]>([]);
const deletingCreditId = ref<number | null>(null);

const canDelete = computed(() => props.canDelete === true);

const discountableExtras = computed(() =>
  props.extras.filter(
    (row) => row.kind === 'sellable' && row.reason !== 'ordered' && Number(row.quantity) > 0,
  ),
);

const outcomeOptions = computed(() =>
  discountableExtras.value.map((row) => ({
    label: `${formatOutcomeReason(row.reason)} · split ${row.quantity} @ ${props.currencySymbol}${Number(row.purchase_price).toFixed(2)}`,
    value: row.id,
  })),
);

const selectedExtra = computed(() =>
  discountableExtras.value.find((r) => r.id === sourceOutcomeId.value),
);

const maxSplitQty = computed(() => selectedExtra.value?.quantity ?? 0);

const previewCredit = computed(() => {
  const row = selectedExtra.value;
  if (!row || quantity.value < 1) return 0;
  const drop = Number(row.purchase_price) - Number(newPurchasePrice.value);
  return Math.max(0, drop * quantity.value);
});

const loadCredits = async () => {
  if (!props.shipmentId) {
    recentCredits.value = [];
    return;
  }
  try {
    recentCredits.value = await globalShipmentRepository.listShipmentOutcomeVendorCredits(
      props.shipmentId,
    );
  } catch {
    recentCredits.value = [];
  }
};

const onShow = async () => {
  const first = discountableExtras.value[0];
  sourceOutcomeId.value = first?.id ?? null;
  quantity.value = first ? Number(first.quantity) || 1 : 1;
  newPurchasePrice.value = first ? Number(first.purchase_price) : 0;
  await loadCredits();
};

watch(sourceOutcomeId, (id) => {
  if (id == null) return;
  const row = discountableExtras.value.find((r) => r.id === id);
  if (!row) return;
  quantity.value = Number(row.quantity) || 1;
  newPurchasePrice.value = Number(row.purchase_price);
});

const onSubmit = () => {
  if (sourceOutcomeId.value == null) return;
  emit('submit', {
    sourceOutcomeId: sourceOutcomeId.value,
    quantity: quantity.value,
    newPurchasePrice: newPurchasePrice.value,
  });
};

const onDeleteCredit = (id: number) => {
  deletingCreditId.value = id;
  emit('delete-credit', id);
};

const clearDeleting = () => {
  deletingCreditId.value = null;
};

defineExpose({ loadCredits, clearDeleting });
</script>
