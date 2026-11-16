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

  <article
    v-for="bill in visibleBills"
    :key="bill.id"
    class="shipment-ap-bill-card column q-mb-sm"
    data-test="shipment-ap-bill-card"
  >
    <header class="shipment-ap-bill-card__header row items-start no-wrap q-gutter-sm">
      <div class="col min-width-0 column q-gutter-y-xs">
        <div class="text-subtitle2 text-weight-bold text-grey-9 ellipsis">
          {{ bill.invoice_no || `Bill #${bill.id}` }}
        </div>
        <div class="row items-center q-gutter-xs wrap">
          <TfStatusBadge
            :status="bill.invoice_status"
            :label="invoiceStatusLabel(bill)"
          />
          <TfStatusBadge
            v-if="paymentBadgesById.get(bill.id)"
            :status="paymentBadgesById.get(bill.id)!.status"
            :label="paymentBadgesById.get(bill.id)!.label"
          />
        </div>
        <div
          v-if="displayBillSectionName(bill)"
          class="text-caption text-grey-7 ellipsis"
        >
          <span class="text-grey-6">Section :</span>
          <span class="text-weight-medium text-grey-9">{{ displayBillSectionName(bill) }}</span>
        </div>
        <div class="text-caption text-grey-7">
          <span class="text-weight-medium text-grey-9">{{ plugCurrency(bill) }}</span>
          · Total
          <span class="tf-num text-weight-medium text-grey-9">{{ formatMoney(displayBillTotal(bill)) }}</span>
          <template v-if="showBillDue(bill)">
            · Due
            <span class="tf-num text-weight-medium text-orange-9">{{ formatMoney(displayDueAmount(bill)) }}</span>
          </template>
        </div>
      </div>
      <div class="row q-gutter-x-xs shrink-0 items-center">
        <q-btn
          v-if="bill.invoice_status === 'draft' && canEdit"
          unelevated
          dense
          no-caps
          size="sm"
          color="primary"
          label="Issue"
          class="rounded-sq-btn"
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
          round
          size="sm"
          color="primary"
          icon="ph ph-eye"
          aria-label="View bill details"
          @click="emitOpen(bill.id)"
        />
      </div>
    </header>
  </article>

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
      <q-card-section class="column q-gutter-y-sm q-pt-none shipment-ap-bill-dialog__body">
        <q-select
          v-if="sectionOptions.length > 0"
          v-model="formSectionId"
          :options="sectionOptions"
          label="Section (optional)"
          outlined
          dense
          emit-value
          map-options
          clearable
          :loading="sectionsPreparing"
          :disable="sectionsPreparing"
          hide-bottom-space
        />
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
        <div class="column q-gutter-y-xs">
          <div class="text-caption text-weight-bold text-grey-7 text-uppercase" style="letter-spacing: 0.04em">
            Note
          </div>
          <RichTextEditor
            v-model="formNote"
            min-height="5.5rem"
            :with-table="false"
          />
        </div>
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
import { computed, onMounted, ref, watch } from 'vue';
import RichTextEditor from 'src/components/ui/RichTextEditor.vue';
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
import type { ShipmentSection } from '../types/shipmentSection';
import {
  shipmentApBillV2Repository,
  type CreateShipmentApBillPayload,
  type ShipmentApBillLineInput,
} from '../repositories/shipmentApBillV2Repository';
import { requestConfirmation, showErrorNotification } from 'src/utils/appFeedback';
import {
  displayBillTotal,
  displayDueAmount,
} from '../utils/shipmentApBillDisplay';
import {
  billNoteHasVisibleContent,
  billNoteHtml,
} from 'src/modules/bills_pays/utils/billNoteDisplay';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

const shipmentStore = useGlobalShipmentStore();

const props = defineProps<{
  shipmentId: number;
  tenantId?: number | null;
  bills: ShipmentApBillRow[];
  canEdit: boolean;
  loading?: boolean;
  defaultCurrency?: string;
  sections?: ShipmentSection[];
}>();

const emit = defineEmits<{
  create: [bucket: ShipmentApKind, payload: CreateShipmentApBillPayload];
  update: [billId: number, payload: Pick<CreateShipmentApBillPayload, 'lines' | 'note' | 'meta'>];
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
const formNote = ref('');
const formSectionId = ref<number | null>(null);
const sectionsPreparing = ref(false);

const billShipmentSections = computed((): ShipmentSection[] => {
  const storeSections = shipmentStore.currentShipmentSections ?? [];
  const storeForShipment =
    storeSections.length > 0
    && storeSections.every((s) => s.shipment_id === props.shipmentId)
      ? storeSections
      : [];
  if (storeForShipment.length > 0) return storeForShipment;
  const fromProps = props.sections ?? [];
  if (
    fromProps.length > 0
    && fromProps.every((s) => s.shipment_id === props.shipmentId)
  ) {
    return fromProps;
  }
  return [];
});

const sectionOptions = computed(() =>
  billShipmentSections.value.map((s) => ({
    label: s.title?.trim() || `Section #${s.id}`,
    value: s.id,
  })),
);

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

const sectionLabelByBillId = ref(new Map<number, string>());

const billSectionLabel = (bill: ShipmentApBillRow): string | null => {
  const titled = bill.section_title?.trim();
  if (titled) return titled;
  const sid = bill.section_id;
  if (sid == null || !Number.isFinite(sid)) return null;
  const match = billShipmentSections.value.find((s) => s.id === sid);
  return match?.title?.trim() || `Section #${sid}`;
};

const displayBillSectionName = (bill: ShipmentApBillRow): string | null =>
  sectionLabelByBillId.value.get(bill.id) ?? billSectionLabel(bill);

const enrichBillSectionNames = async (bills: ShipmentApBillRow[]) => {
  if (!props.tenantId || bills.length === 0) return;
  await shipmentStore.fetchShipmentSections(props.shipmentId);
  const next = new Map(sectionLabelByBillId.value);
  const pending: Promise<void>[] = [];
  for (const bill of bills) {
    const fromRow = billSectionLabel(bill);
    if (fromRow) {
      next.set(bill.id, fromRow);
      continue;
    }
    if (next.has(bill.id)) continue;
    pending.push(
      shipmentApBillV2Repository
        .loadDraftBillForEdit(props.tenantId, bill.id)
        .then((draft) => {
          if (draft.sectionTitle?.trim()) {
            next.set(bill.id, draft.sectionTitle.trim());
            return;
          }
          if (draft.sectionId == null) return;
          const match = billShipmentSections.value.find((s) => s.id === draft.sectionId);
          next.set(
            bill.id,
            match?.title?.trim() || `Section #${draft.sectionId}`,
          );
        })
        .catch(() => undefined),
    );
  }
  await Promise.all(pending);
  sectionLabelByBillId.value = next;
};

onMounted(() => {
  void shipmentStore.fetchShipmentSections(props.shipmentId);
});

watch(
  () => [props.tenantId, visibleBills.value] as const,
  ([tenantId, bills]) => {
    if (!tenantId || bills.length === 0) return;
    void enrichBillSectionNames(bills);
  },
  { immediate: true },
);

const formValid = computed(
  () =>
    formLines.value.some((l) => Number(l.amount) > 0)
    && Boolean(formCurrency.value),
);

const plugCurrency = (bill: ShipmentApBillRow) =>
  shipmentApBillPlugCurrency(bill) ?? formCurrency.value;

const formatMoney = (n: number) =>
  Number.isFinite(n) ? n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '—';

const invoiceStatusLabel = (bill: ShipmentApBillRow) => {
  const s = bill.invoice_status?.trim().toLowerCase();
  if (s === 'draft') return 'Draft';
  if (s === 'issued') return 'Issued';
  if (s === 'voided') return 'Voided';
  return bill.invoice_status ?? '—';
};

const resolvePaymentStatusBadge = (bill: ShipmentApBillRow): { status: string; label: string } | null => {
  if (bill.invoice_status !== 'issued') return null;
  const due = displayDueAmount(bill);
  const total = displayBillTotal(bill);
  if (bill.payment_status === 'paid' || due <= 0.009) {
    return { status: 'paid', label: 'Paid' };
  }
  const paid = Math.max(0, total - due);
  if (due > 0.009 && paid > 0.009) {
    return { status: 'partial', label: 'Partially paid' };
  }
  const raw = bill.payment_status?.trim().toLowerCase();
  if (raw === 'due' || raw === 'unpaid') {
    return { status: 'unpaid', label: 'Due' };
  }
  return { status: bill.payment_status ?? 'unpaid', label: raw ? titleCase(raw) : 'Due' };
};

const paymentBadgesById = computed(() => {
  const map = new Map<number, { status: string; label: string }>();
  for (const bill of visibleBills.value) {
    const badge = resolvePaymentStatusBadge(bill);
    if (badge) map.set(bill.id, badge);
  }
  return map;
});

const showBillDue = (bill: ShipmentApBillRow) => {
  if (bill.invoice_status !== 'issued') return false;
  if (resolvePaymentStatusBadge(bill)?.status === 'paid') return false;
  return displayDueAmount(bill) > 0.009;
};

const titleCase = (s: string) =>
  s.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());

const billNotePayload = (html: string): string | undefined => {
  const trimmed = billNoteHtml(html);
  if (!billNoteHasVisibleContent(trimmed)) return undefined;
  return trimmed;
};

const resetForm = () => {
  formCurrency.value = props.defaultCurrency ?? 'GBP';
  formLines.value = [{ cost_component: 'subtotal', amount: 0 }];
  formNote.value = '';
  formSectionId.value = null;
  editBillId.value = null;
};

const buildSectionMeta = (): CreateShipmentApBillPayload['meta'] => {
  const sectionId = formSectionId.value;
  if (sectionId == null) {
    return { section_id: null, section_title: null };
  }
  const match = billShipmentSections.value.find((s) => s.id === sectionId);
  return {
    section_id: sectionId,
    section_title: match?.title?.trim() || null,
  };
};

const ensureSectionsForBillDialog = async () => {
  sectionsPreparing.value = true;
  try {
    let sections = await shipmentStore.fetchShipmentSections(props.shipmentId);
    if (sections.length > 0) return;
    if (shipmentStore.currentShipment?.id !== props.shipmentId) {
      await shipmentStore.fetchShipmentDetails(props.shipmentId);
    }
    sections = shipmentStore.currentShipmentSections ?? [];
    if (sections.length > 0) return;
    const vendorId = shipmentStore.currentShipment?.vendor_id;
    if (!vendorId) return;
    await shipmentStore.createSection({
      shipment_id: props.shipmentId,
      title: 'Main order',
      vendor_id: vendorId,
    });
  } finally {
    sectionsPreparing.value = false;
  }
};

const openAddDialog = async () => {
  resetForm();
  dialogOpen.value = true;
  await ensureSectionsForBillDialog();
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
  formNote.value = '';
  formSectionId.value = null;
  dialogOpen.value = true;
  await ensureSectionsForBillDialog();
  let lines: ShipmentApBillLineInput[] =
    bill.cost_lines?.map((cl) => ({
      cost_component: cl.cost_component,
      amount: cl.amount,
      description: cl.description ?? null,
    })) ?? [];

  if (props.tenantId) {
    try {
      const draft = await shipmentApBillV2Repository.loadDraftBillForEdit(
        props.tenantId,
        bill.id,
      );
      formNote.value = draft.note ?? '';
      formSectionId.value = draft.sectionId ?? null;
      if (lines.length === 0 && draft.lines.length > 0) {
        lines = draft.lines;
      }
    } catch (err: unknown) {
      showErrorNotification((err as Error).message || 'Could not load draft bill details');
    }
  }

  if (lines.length === 0) {
    formLines.value = [{ cost_component: 'misc', amount: bill.total_amount }];
  } else {
    lines.forEach((l) => ensureComponentOption(l.cost_component));
    formLines.value = mapCostLinesToForm(lines);
  }
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
  const note = billNotePayload(formNote.value);
  const sectionMeta = buildSectionMeta();
  saving.value = true;
  try {
    if (editBillId.value) {
      emit('update', editBillId.value, {
        lines,
        note: note ?? '',
        meta: sectionMeta,
      });
    } else {
      emit('create', activeBucket.value, {
        currency_code: formCurrency.value,
        lines,
        meta: sectionMeta,
        ...(note != null ? { note } : {}),
      });
    }
    closeDialog();
  } finally {
    saving.value = false;
  }
};

const emitIssue = async (bill: ShipmentApBillRow) => {
  const label = bill.invoice_no?.trim() || `Bill #${bill.id}`;
  const ok = await requestConfirmation(
    `Issue ${label}? After issue, draft line edits are locked.`,
    'Issue bill',
    'Issue',
  );
  if (!ok) return;
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

<style scoped lang="scss">
.shipment-ap-bill-card {
  padding: var(--tf-space-md, 12px);
  border-radius: var(--tf-radius-md, 12px);
  border: 1px solid var(--tf-neutral-border, rgba(0, 0, 0, 0.12));
  background: var(--tf-neutral-surface, #fff);
  gap: 4px;
}

.shipment-ap-bill-card__header {
  width: 100%;
}

.shipment-ap-bill-dialog {
  width: min(560px, 92vw);
  max-width: 560px;
}

.shipment-ap-bill-dialog__body {
  max-height: min(72vh, 560px);
  overflow-y: auto;
}
</style>
