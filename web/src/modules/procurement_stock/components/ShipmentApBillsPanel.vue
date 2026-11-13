<template>
  <div class="column q-gutter-y-sm">
    <div
      class="text-caption text-weight-bold text-grey-7 text-uppercase"
      style="letter-spacing: 0.5px"
    >
      Cost lines
    </div>

    <TfDrawerSectionTabs
      v-model="activeBucket"
      :tabs="bucketTabs"
      aria-label="Filter bills by bucket"
      count-visibility="positive"
    />

    <div class="row items-center justify-between q-gutter-sm cost-lines-actions q-px-xs">
      <q-btn
        unelevated
        no-caps
        color="primary"
        icon="ph ph-plus"
        label="Create bill"
        size="sm"
        class="rounded-sq-btn text-weight-bold"
        padding="sm md"
        @click="openAddDialog"
      />
    </div>

    <div
      v-if="!loading && visibleBills.length === 0"
      class="text-caption text-grey-6 q-pa-sm rounded-borders bg-grey-1 border-grey"
    >
      No bills in this bucket yet. Use Create bill to record currency and component amounts.
    </div>

  <div
    v-for="bill in visibleBills"
    :key="bill.id"
    class="q-pa-sm bg-grey-1 rounded-borders border-grey column q-gutter-y-xs"
  >
    <div class="row items-center no-wrap q-gutter-sm">
      <div class="col min-width-0">
        <div class="text-caption text-weight-bold text-grey-9 ellipsis">
          {{ bill.invoice_no || `Bill #${bill.id}` }}
        </div>
        <div class="text-xxs text-grey-6">
          {{ plugCurrency(bill) }}
          · Bill total {{ formatMoney(bill.total_amount) }}
        </div>
        <div
          v-if="bill.cost_lines?.length"
          class="column q-gutter-y-xxs q-mt-xs"
        >
          <div
            v-for="(cl, clIdx) in bill.cost_lines"
            :key="`${bill.id}-${clIdx}`"
            class="text-xxs text-grey-7 row no-wrap justify-between q-gutter-sm"
          >
            <span class="ellipsis">{{ costComponentLabel(cl.cost_component) }}</span>
            <span class="text-weight-medium">{{ formatMoney(cl.amount) }}</span>
          </div>
        </div>
      </div>
      <TfStatusBadge :status="bill.invoice_status" :label="statusLabel(bill)" />
      <div class="row q-gutter-x-xs shrink-0">
        <q-btn
          v-if="bill.invoice_status === 'draft' && canEdit"
          flat
          dense
          no-caps
          size="sm"
          color="primary"
          label="Issue"
          :loading="actingBillId === bill.id && actionKind === 'issue'"
          @click="emitIssue(bill)"
        />
        <q-btn
          v-if="bill.invoice_status === 'draft' && canEdit"
          flat
          dense
          round
          size="sm"
          icon="ph ph-pencil-simple"
          aria-label="Edit bill"
          @click="openEditDialog(bill)"
        />
        <q-btn
          v-if="bill.invoice_status === 'draft' && canEdit"
          flat
          dense
          round
          size="sm"
          color="negative"
          icon="ph ph-trash"
          aria-label="Delete draft"
          :loading="actingBillId === bill.id && actionKind === 'void'"
          @click="emitVoid(bill)"
        />
        <q-btn
          flat
          dense
          no-caps
          size="sm"
          color="primary"
          label="View"
          icon="ph ph-eye"
          aria-label="View bill details"
          @click="emitOpen(bill.id)"
        />
      </div>
    </div>
  </div>

  <q-dialog v-model="dialogOpen" persistent>
    <q-card flat bordered class="column shipment-ap-bill-dialog">
      <q-card-section>
        <div class="text-subtitle2 text-weight-bold text-grey-9">
          {{ editBillId ? 'Edit bill' : 'Create bill' }}
        </div>
        <div class="text-caption text-grey-7 q-mt-xs">
          Scope:
          <span class="text-weight-medium text-grey-9">{{ activeBucketLabel }}</span>
        </div>
      </q-card-section>
      <q-card-section class="column q-gutter-y-sm q-pt-none">
        <q-select
          v-model="formCurrency"
          :options="currencyOptions"
          label="Currency"
          outlined
          dense
          emit-value
          map-options
          :disable="Boolean(editBillId)"
        />
        <div
          v-for="(line, idx) in formLines"
          :key="idx"
          class="row q-col-gutter-sm items-start q-pa-sm rounded-borders border-grey"
        >
          <div class="col-7">
            <q-select
              v-model="line.cost_component"
              :options="componentOptions"
              label="Component"
              outlined
              dense
              emit-value
              map-options
            />
          </div>
          <div class="col-5">
            <q-input
              v-model.number="line.amount"
              type="number"
              label="Amount"
              outlined
              dense
              min="0"
              step="0.01"
            />
          </div>
        </div>
        <TfBtn
          flat
          icon="ph ph-plus"
          label="Add line"
          size="sm"
          @click="addFormLine"
        />
      </q-card-section>
      <q-card-actions align="right" class="q-px-md q-pb-md q-pt-none">
        <q-btn flat no-caps label="Cancel" color="grey-8" @click="closeDialog" />
        <q-btn
          unelevated
          no-caps
          color="primary"
          :label="editBillId ? 'Save' : 'Create'"
          class="rounded-sq-btn text-weight-bold"
          padding="sm md"
          :loading="saving"
          :disable="!formValid"
          @click="submitDialog"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfDrawerSectionTabs from 'src/components/ui/TfDrawerSectionTabs.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import {
  SHIPMENT_AP_COST_BUCKETS,
  shipmentApKindLabel,
  type ShipmentApKind,
} from '../constants/shipmentApBuckets';
import {
  shipmentApBillBucket,
  shipmentApBillPlugCurrency,
  type ShipmentApBillRow,
} from '../repositories/shipmentApBillsRepository';
import {
  shipmentApBillV2Repository,
  type ShipmentApBillLineInput,
} from '../repositories/shipmentApBillV2Repository';

const props = defineProps<{
  shipmentId: number;
  booksTenantId?: number | null;
  bills: ShipmentApBillRow[];
  canEdit: boolean;
  loading?: boolean;
  defaultCurrency?: string;
}>();

const emit = defineEmits<{
  create: [bucket: ShipmentApKind, payload: { currency_code: string; lines: ShipmentApBillLineInput[] }];
  update: [billId: number, payload: { lines: ShipmentApBillLineInput[] }];
  issue: [billId: number];
  void: [billId: number];
  open: [billId: number];
}>();

const activeBucket = ref<ShipmentApKind>(SHIPMENT_AP_COST_BUCKETS[0]);
const dialogOpen = ref(false);
const editBillId = ref<number | null>(null);
const saving = ref(false);
const actingBillId = ref<number | null>(null);
const actionKind = ref<'issue' | 'void' | null>(null);

const componentOptions: { label: string; value: string }[] = [
  { label: 'Subtotal', value: 'subtotal' },
  { label: 'Carriage', value: 'carriage' },
  { label: 'VAT / tax', value: 'vat_tax' },
  { label: 'Misc', value: 'misc' },
];

const currencyOptions = ['BDT', 'GBP', 'USD'].map((c) => ({ label: c, value: c }));

const formCurrency = ref(props.defaultCurrency ?? 'GBP');
const formLines = ref<ShipmentApBillLineInput[]>([
  { cost_component: 'subtotal', amount: 0 },
]);

const activeBucketLabel = computed(() =>
  shipmentApKindLabel(activeBucket.value).replace(' AP', ''),
);

const bucketTabs = computed(() =>
  SHIPMENT_AP_COST_BUCKETS.map((bucket) => {
    const count = props.bills.filter(
      (b) => shipmentApBillBucket(b) === bucket && b.invoice_status !== 'voided',
    ).length;
    return {
      name: bucket,
      label: shipmentApKindLabel(bucket).replace(' AP', ''),
      count,
    };
  }),
);

const visibleBills = computed(() =>
  props.bills.filter(
    (b) =>
      shipmentApBillBucket(b) === activeBucket.value && b.invoice_status !== 'voided',
  ),
);

const formValid = computed(() =>
  formLines.value.some((l) => Number(l.amount) > 0) && Boolean(formCurrency.value),
);

const plugCurrency = (bill: ShipmentApBillRow) =>
  shipmentApBillPlugCurrency(bill) ?? formCurrency.value;

const formatMoney = (n: number) =>
  Number.isFinite(n) ? n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '—';

const statusLabel = (bill: ShipmentApBillRow) =>
  bill.invoice_status === 'draft' ? 'Draft' : bill.invoice_status;

const resetForm = () => {
  formCurrency.value = props.defaultCurrency ?? 'GBP';
  formLines.value = [{ cost_component: 'subtotal', amount: 0 }];
  editBillId.value = null;
};

const openAddDialog = () => {
  resetForm();
  dialogOpen.value = true;
};

const costComponentLabel = (component: string) =>
  component
    .split('_')
    .map((w) => (w ? w.charAt(0).toUpperCase() + w.slice(1) : w))
    .join(' ');

const mapCostLinesToForm = (lines: ShipmentApBillLineInput[]) =>
  lines.map((cl) => ({
    cost_component: cl.cost_component,
    amount: Number(cl.amount),
    description: cl.description ?? undefined,
  }));

const ensureComponentOption = (component: string) => {
  if (!componentOptions.some((o) => o.value === component)) {
    componentOptions.push({
      label: costComponentLabel(component),
      value: component,
    });
  }
};

const openEditDialog = async (bill: ShipmentApBillRow) => {
  editBillId.value = bill.id;
  formCurrency.value = shipmentApBillPlugCurrency(bill) ?? props.defaultCurrency ?? 'GBP';
  let lines: ShipmentApBillLineInput[] =
    bill.cost_lines?.map((cl) => ({
      cost_component: cl.cost_component,
      amount: cl.amount,
      description: cl.description ?? null,
    })) ?? [];

  if (lines.length === 0 && props.booksTenantId) {
    try {
      lines = await shipmentApBillV2Repository.loadDraftCostLines(props.booksTenantId, bill.id);
    } catch {
      lines = [];
    }
  }

  if (lines.length === 0) {
    formLines.value = [{ cost_component: 'misc', amount: bill.total_amount }];
  } else {
    lines.forEach((l) => ensureComponentOption(l.cost_component));
    formLines.value = mapCostLinesToForm(lines);
  }
  dialogOpen.value = true;
};

const closeDialog = () => {
  dialogOpen.value = false;
  resetForm();
};

const addFormLine = () => {
  formLines.value.push({ cost_component: 'misc', amount: 0 });
};

const submitDialog = async () => {
  const lines = formLines.value
    .filter((l) => Number(l.amount) > 0)
    .map((l) => ({ ...l, amount: Number(l.amount) }));
  if (lines.length === 0) return;
  saving.value = true;
  try {
    if (editBillId.value) {
      emit('update', editBillId.value, { lines });
    } else {
      emit('create', activeBucket.value, {
        currency_code: formCurrency.value,
        lines,
      });
    }
    closeDialog();
  } finally {
    saving.value = false;
  }
};

const emitIssue = (bill: ShipmentApBillRow) => {
  actingBillId.value = bill.id;
  actionKind.value = 'issue';
  emit('issue', bill.id);
};

const emitVoid = (bill: ShipmentApBillRow) => {
  actingBillId.value = bill.id;
  actionKind.value = 'void';
  emit('void', bill.id);
};

const emitOpen = (billId: number) => emit('open', billId);

watch(
  () => props.loading,
  (v) => {
    if (!v) {
      actingBillId.value = null;
      actionKind.value = null;
    }
  },
);
</script>

<style scoped>
.shipment-ap-bill-dialog {
  width: min(560px, 92vw);
  max-width: 560px;
}
</style>
