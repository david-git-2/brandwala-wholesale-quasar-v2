<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div v-if="loadingExisting" class="col flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else class="col overflow-auto compose-scroll">
      <div class="compose-card column no-wrap">
        <div class="compose-sticky-toolbar compose-kind-toolbar row items-center justify-between q-col-gutter-sm">
          <div class="col row items-end q-gutter-md wrap">
            <div v-if="showSettlementGroup" class="compose-kind-group">
              <div class="compose-kind-heading">Settlement</div>
              <div class="compose-toolbar-segment">
                <q-btn
                  v-for="opt in settlementOptions"
                  :key="opt.value"
                  dense
                  unelevated
                  no-caps
                  :icon="opt.icon"
                  :label="opt.label"
                  :color="composePaperKind === opt.value ? 'primary' : 'transparent'"
                  :text-color="composePaperKind === opt.value ? 'white' : 'grey-8'"
                  class="compose-toolbar-btn"
                  :disable="directionLocked || (opt.value === 'condition' && !hasStockLines)"
                  @click="composePaperKind = opt.value"
                />
              </div>
            </div>
            <div class="compose-kind-group">
              <div class="compose-kind-heading">Document</div>
              <div class="compose-toolbar-segment compose-document-segment">
                <q-btn
                  v-for="opt in documentKindOptions"
                  :key="opt.value"
                  dense
                  unelevated
                  no-caps
                  :label="opt.label"
                  :color="documentKind === opt.value ? 'primary' : 'transparent'"
                  :text-color="documentKind === opt.value ? 'white' : 'grey-9'"
                  class="compose-toolbar-btn"
                  @click="onDocumentKindClick(opt.value)"
                />
              </div>
              <q-select
                v-if="documentKind !== 'standard'"
                v-model="parentBillId"
                :options="parentBillOptions"
                option-value="id"
                option-label="label"
                emit-value
                map-options
                use-input
                input-debounce="300"
                outlined
                dense
                class="compose-parent-bill-select q-mt-xs"
                label="Parent bill *"
                @filter="filterParentBills"
              />
            </div>
            <div class="compose-kind-group">
              <div class="compose-kind-heading">Source</div>
              <div class="row items-center q-gutter-xs wrap compose-document-chips">
                <q-chip
                  dense
                  outline
                  class="compose-document-chip"
                  color="grey-3"
                  text-color="grey-8"
                >
                  <span class="text-weight-medium">{{ sourceTypeLabel }}</span>
                </q-chip>
                <q-chip
                  v-if="sourceId"
                  dense
                  outline
                  class="compose-document-chip"
                  color="grey-3"
                  text-color="grey-8"
                >
                  ID {{ sourceId }}
                </q-chip>
                <q-chip
                  v-if="sourceKey"
                  dense
                  outline
                  class="compose-document-chip"
                  color="grey-3"
                  text-color="grey-8"
                >
                  {{ sourceKey }}
                </q-chip>
              </div>
            </div>
          </div>
          <div class="compose-toolbar-segment col-shrink compose-lifecycle-group">
            <q-btn
              dense
              unelevated
              no-caps
              label="Save as draft"
              icon="ph ph-floppy-disk"
              color="transparent"
              text-color="grey-8"
              class="compose-toolbar-btn"
              :loading="composeMutation.isPending.value"
              :disable="!canSave || voidingDraft"
              @click="saveDraft"
            />
            <q-btn
              dense
              unelevated
              no-caps
              label="Issue"
              icon="ph ph-check-circle"
              :color="canIssue && !voidingDraft ? 'primary' : 'transparent'"
              :text-color="canIssue && !voidingDraft ? 'white' : 'grey-6'"
              class="compose-toolbar-btn"
              :loading="composeMutation.isPending.value"
              :disable="!canIssue || voidingDraft"
              @click="issueBill"
            />
            <q-btn
              dense
              unelevated
              no-caps
              label="Void"
              icon="ph ph-prohibit"
              :color="canVoidDraft && !composeMutation.isPending.value ? 'negative' : 'transparent'"
              :text-color="
                canVoidDraft && !composeMutation.isPending.value ? 'white' : 'grey-6'
              "
              class="compose-toolbar-btn"
              :loading="voidingDraft"
              :disable="!canVoidDraft || composeMutation.isPending.value"
              @click="voidDraft"
            />
          </div>
        </div>

        <div class="compose-body q-pa-md q-gutter-y-md">
        <div class="row q-col-gutter-sm">
          <div class="col-12 col-sm-6">
            <div class="compose-party-card q-pa-sm">
              <q-select
                v-model="fromProfileId"
                :options="fromProfileOptions"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                use-input
                fill-input
                hide-selected
                input-debounce="300"
                outlined
                dense
                class="compose-party-select"
                :readonly="directionLocked"
                :disable="directionLocked"
                :error="profilesAreSame"
                error-message="Must differ from To"
                @filter="filterFromProfiles"
              >
                <template #prepend>
                  <span class="compose-party-label">From</span>
                </template>
                <template #option="scope">
                  <q-item v-bind="scope.itemProps" dense>
                    <q-item-section>
                      <q-item-label class="row items-center no-wrap q-gutter-x-xs">
                        <span class="ellipsis">{{ scope.opt.name }}</span>
                        <q-chip
                          dense
                          :color="profileTypeChip(scope.opt).color"
                          :text-color="profileTypeChip(scope.opt).textColor"
                          class="q-ma-none"
                        >
                          {{ profileTypeChip(scope.opt).label }}
                        </q-chip>
                      </q-item-label>
                      <q-item-label v-if="profilePartyCaption(scope.opt)" caption>
                        {{ profilePartyCaption(scope.opt) }}
                      </q-item-label>
                    </q-item-section>
                  </q-item>
                </template>
                <template #no-option>
                  <q-item dense>
                    <q-item-section class="text-grey-7">No profiles found</q-item-section>
                  </q-item>
                </template>
              </q-select>
            </div>
          </div>
          <div class="col-12 col-sm-6">
            <div class="compose-party-card q-pa-sm">
              <q-select
                v-model="toProfileId"
                :options="toProfileOptions"
                option-value="id"
                option-label="name"
                emit-value
                map-options
                use-input
                fill-input
                hide-selected
                input-debounce="300"
                outlined
                dense
                class="compose-party-select"
                :readonly="directionLocked || isWalkIn"
                :disable="directionLocked || isWalkIn"
                :error="profilesAreSame && !isWalkIn"
                error-message="Must differ from From"
                @filter="filterToProfiles"
              >
                <template #prepend>
                  <span class="compose-party-label">To</span>
                </template>
                <template #option="scope">
                  <q-item v-bind="scope.itemProps" dense>
                    <q-item-section>
                      <q-item-label class="row items-center no-wrap q-gutter-x-xs">
                        <span class="ellipsis">{{ scope.opt.name }}</span>
                        <q-chip
                          dense
                          :color="profileTypeChip(scope.opt).color"
                          :text-color="profileTypeChip(scope.opt).textColor"
                          class="q-ma-none"
                        >
                          {{ profileTypeChip(scope.opt).label }}
                        </q-chip>
                      </q-item-label>
                      <q-item-label v-if="profilePartyCaption(scope.opt)" caption>
                        {{ profilePartyCaption(scope.opt) }}
                      </q-item-label>
                    </q-item-section>
                  </q-item>
                </template>
                <template #no-option>
                  <q-item dense>
                    <q-item-section class="text-grey-7">No profiles found</q-item-section>
                  </q-item>
                </template>
              </q-select>
              <div v-if="isWalkIn" class="text-caption text-grey-7 q-px-xs q-pt-xs">
                Walk-in — no bill-to on paper.
              </div>
            </div>
          </div>
        </div>

        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-4">
            <q-input v-model="invoiceDate" outlined dense label="Invoice date" readonly>
              <template #append>
                <q-icon name="ph ph-calendar" class="cursor-pointer">
                  <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                    <q-date v-model="invoiceDate" mask="YYYY-MM-DD">
                      <div class="row items-center justify-end">
                        <q-btn v-close-popup label="Close" color="primary" flat />
                      </div>
                    </q-date>
                  </q-popup-proxy>
                </q-icon>
              </template>
            </q-input>
          </div>
          <div class="col-12 col-sm-4">
            <q-input
              :model-value="dueDate ?? ''"
              outlined
              dense
              label="Due date"
              readonly
              clearable
              @clear="dueDate = null"
            >
              <template #append>
                <q-icon name="ph ph-calendar" class="cursor-pointer">
                  <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                    <q-date
                      :model-value="dueDate ?? ''"
                      mask="YYYY-MM-DD"
                      @update:model-value="onDueDatePicked"
                    >
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

        <q-separator />

        <div class="row items-center justify-between q-mb-xs">
          <div class="text-subtitle2 text-weight-bold">Lines</div>
          <q-btn-dropdown
            outline
            dense
            no-caps
            color="primary"
            icon="ph ph-plus"
            label="Add line"
          >
            <q-list dense class="compose-add-line-menu">
              <q-item
                v-for="opt in addLineMenuOptions"
                :key="opt.key"
                v-close-popup
                clickable
                :disable="opt.line_kind === 'stock' && !showStockSearch"
                @click="addBlankLine(opt)"
              >
                <q-item-section avatar>
                  <q-icon :name="opt.icon" size="18px" />
                </q-item-section>
                <q-item-section>
                  <q-item-label>{{ opt.label }}</q-item-label>
                  <q-item-label v-if="opt.caption" caption>{{ opt.caption }}</q-item-label>
                </q-item-section>
              </q-item>
            </q-list>
          </q-btn-dropdown>
        </div>
        <div v-if="!lines.length" class="compose-lines-empty text-center text-grey-7 q-py-lg">
          Use Add line for stock, description, or charge lines.
        </div>

        <q-dialog v-model="stockLinePickerOpen">
          <q-card class="compose-stock-picker-card">
            <q-card-section class="row items-center justify-between q-pb-none">
              <div class="text-weight-bold">Add stock line</div>
              <q-btn flat round dense icon="ph ph-x" @click="stockLinePickerOpen = false" />
            </q-card-section>
            <q-card-section>
              <BillStockSearch :tenant-id="tenantId" @select="onStockPickedFromPicker" />
            </q-card-section>
          </q-card>
        </q-dialog>
        <q-markup-table v-if="lines.length" flat dense class="compose-lines-table">
          <thead>
            <tr>
              <th class="text-left">Kind</th>
              <th class="text-left">Item</th>
              <th class="text-right">Qty</th>
              <th class="text-right">Unit</th>
              <th class="text-right">Line disc.</th>
              <th class="text-right">Line total</th>
              <th />
            </tr>
          </thead>
          <tbody>
            <tr v-for="(line, idx) in lines" :key="line.key">
              <td class="text-caption text-grey-8 text-capitalize">{{ lineKindLabel(line) }}</td>
              <td class="compose-line-item-cell">
                <BillLineItemDisplay
                  v-if="line.line_kind === 'stock'"
                  :name="line.name"
                  :image-url="line.image_url"
                  show-thumbnail
                />
                <div v-else-if="line.line_kind === 'charge'" class="column q-gutter-y-xs">
                  <q-select
                    :model-value="line.charge_type ?? 'shipping'"
                    :options="chargeTypeOptions"
                    dense
                    outlined
                    emit-value
                    map-options
                    hide-bottom-space
                    @update:model-value="(v) => onChargeTypeChange(line, v)"
                  />
                  <q-input
                    v-model="line.name"
                    dense
                    outlined
                    hide-bottom-space
                    placeholder="Label"
                  />
                </div>
                <q-input
                  v-else
                  v-model="line.name"
                  dense
                  outlined
                  hide-bottom-space
                  placeholder="Description"
                />
              </td>
              <td class="text-right">
                <q-input
                  v-model.number="line.quantity"
                  type="number"
                  dense
                  outlined
                  :max="line.line_kind === 'stock' ? line.available_atp : undefined"
                  min="0.001"
                  :readonly="line.line_kind === 'charge'"
                  style="max-width: 72px"
                />
              </td>
              <td class="text-right">
                <q-input
                  v-model.number="line.sell_price_amount"
                  type="number"
                  dense
                  outlined
                  min="0"
                  style="max-width: 96px"
                />
              </td>
              <td class="text-right">
                <q-input
                  v-if="line.line_kind !== 'charge'"
                  v-model.number="line.line_discount_amount"
                  type="number"
                  dense
                  outlined
                  min="0"
                  style="max-width: 96px"
                />
                <span v-else class="text-grey-6">—</span>
              </td>
              <td class="text-right text-weight-medium">{{ formatAmountBdt(lineTotal(line)) }}</td>
              <td class="text-right">
                <q-btn flat round dense icon="ph ph-trash" color="negative" @click="removeLine(idx)" />
              </td>
            </tr>
          </tbody>
        </q-markup-table>

        <q-separator />

        </div>

        <div class="compose-footer q-pa-md">
          <div class="row q-col-gutter-md items-end">
            <div class="col-12 col-sm-6">
              <q-input
                v-model.number="discountAmount"
                outlined
                dense
                label="Header discount"
                type="number"
                min="0"
              />
            </div>
            <div class="col-12 col-sm-6">
              <div class="totals-panel">
                <div class="total-row"><span>Subtotal</span><span>{{ formatAmountBdt(subtotal) }}</span></div>
                <div v-if="discountAmount" class="total-row">
                  <span>Discount</span><span>−{{ formatAmountBdt(discountAmount) }}</span>
                </div>
                <div class="total-row text-weight-bold">
                  <span>Total (est.)</span><span>{{ formatAmountBdt(estimatedTotal) }}</span>
                </div>
              </div>
            </div>
          </div>
          <q-separator class="q-my-md" />
          <div class="compose-note-section">
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Note</div>
            <q-input
              v-model="note"
              outlined
              dense
              type="textarea"
              autogrow
              placeholder="Comment on this bill (not a credit note)"
              :rows="2"
            />
          </div>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { supabase } from 'src/boot/supabase';
import { formatAmountBdt } from 'src/utils/currency';
import {
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import type { CustomerProfile } from 'src/modules/sales_invoice/repositories/customerProfileRepository';
import { useCustomerProfiles } from 'src/modules/sales_invoice/composables/useCustomerProfiles';
import {
  billsRepository,
  type SalesInvoiceStockItem,
} from '../repositories/billsRepository';
import BillStockSearch from '../components/BillStockSearch.vue';
import BillLineItemDisplay from '../components/BillLineItemDisplay.vue';
type ComposeLineKind = 'stock' | 'description' | 'charge';
import { useBillComposeMutation } from '../composables/useBillComposeMutation';
import type { Database } from 'src/types/supabase';

type BillDocumentKind = Database['public']['Enums']['bill_document_kind'];
type BillSettlementKind = Database['public']['Enums']['bill_settlement_kind'];
type BillDirection = 'they_owe' | 'we_owe';

type ComposeLine = {
  key: string;
  line_kind: ComposeLineKind;
  id?: number;
  global_stock_id?: number;
  name: string;
  image_url?: string | null;
  available_atp?: number;
  quantity: number;
  sell_price_amount: number;
  line_discount_amount: number;
  charge_type?: string;
};

const chargeTypeOptions = [
  { label: 'Shipping', value: 'shipping' },
  { label: 'Wrapping', value: 'wrapping' },
  { label: 'Print', value: 'print' },
  { label: 'Delivery', value: 'delivery' },
  { label: 'Other', value: 'other' },
];

const chargeTypeLabel = (type: string) =>
  chargeTypeOptions.find((o) => o.value === type)?.label ?? 'Charge';

type AddLineMenuOption = {
  key: string;
  label: string;
  caption: string;
  icon: string;
  line_kind: ComposeLineKind;
};

const addLineMenuOptions: AddLineMenuOption[] = [
  {
    key: 'stock',
    label: 'Stock',
    caption: 'Search sellable inventory',
    icon: 'ph ph-package',
    line_kind: 'stock',
  },
  {
    key: 'description',
    label: 'Description',
    caption: 'Text or service line',
    icon: 'ph ph-text-align-left',
    line_kind: 'description',
  },
  {
    key: 'charge',
    label: 'Charge',
    caption: 'Shipping, fees, print, …',
    icon: 'ph ph-receipt',
    line_kind: 'charge',
  },
];

const stockLinePickerOpen = ref(false);

const lineKindLabel = (line: ComposeLine) => {
  if (line.line_kind === 'charge' && line.charge_type) {
    return line.charge_type.replace(/_/g, ' ');
  }
  return line.line_kind;
};

type ComposePaperKind = 'take' | 'condition' | 'walkin';

const settlementOptions: Array<{ label: string; value: ComposePaperKind; icon: string }> = [
  { label: 'Take', value: 'take', icon: 'ph ph-arrow-circle-down' },
  { label: 'Condition', value: 'condition', icon: 'ph ph-seal-check' },
  { label: 'Walk-in', value: 'walkin', icon: 'ph ph-storefront' },
];

const documentKindOptions: Array<{ label: string; value: BillDocumentKind }> = [
  { label: 'Standard', value: 'standard' },
  { label: 'Credit note', value: 'credit_note' },
  { label: 'Debit note', value: 'debit_note' },
];

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();
const composeMutation = useBillComposeMutation();
const { setCustomBreadcrumbs, clearCustomBreadcrumbs } = useBreadcrumbs();
const composeBreadcrumbTitle = ref('New bill');

const TENANT_PROFILE_STORAGE_KEY = 'bills_pays_last_tenant_side_profile_id';

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const parentTenantId = computed(() => {
  const t = authStore.selectedTenant;
  if (!t) return null;
  return t.parent_id ?? t.id;
});

const { profiles: deskProfiles, profileById, ensureLoaded: ensureProfilesLoaded } =
  useCustomerProfiles(parentTenantId, { scope: 'desk' });

const documentKind = ref<BillDocumentKind>('standard');
const parentBillId = ref<number | null>(null);
const parentBillOptions = ref<Array<{ id: number; label: string }>>([]);

const sourceType = ref<string | null>(null);
const sourceId = ref<string | null>(null);
const sourceKey = ref<string | null>(null);

const formatSourceToken = (value: string | null | undefined) =>
  value?.trim() ? value.replace(/_/g, ' ') : '';

const sourceTypeLabel = computed(() => {
  if (sourceType.value) return formatSourceToken(sourceType.value);
  return editInvoiceId.value ? '—' : 'compose';
});

const applySourcePlugFromBill = (bill: {
  source_type?: string | null;
  source_id?: string | null;
  source_key?: string | null;
}) => {
  sourceType.value = bill.source_type ?? null;
  sourceId.value = bill.source_id ?? null;
  sourceKey.value = bill.source_key ?? null;
};

const refreshBillSourcePlug = async (billId: number) => {
  const { data, error } = await supabase
    .from('bills')
    .select('source_type, source_id, source_key')
    .eq('id', billId)
    .maybeSingle();
  if (error) throw error;
  if (data) applySourcePlugFromBill(data);
};

const onDocumentKindClick = (kind: BillDocumentKind) => {
  documentKind.value = kind;
  if (kind === 'standard') {
    parentBillId.value = null;
    parentBillOptions.value = [];
  }
};

watch(parentBillId, async (id) => {
  if (!id || documentKind.value === 'standard') return;
  const { data, error } = await supabase
    .from('bills')
    .select('from_profile_id, to_profile_id, invoice_type')
    .eq('id', id)
    .maybeSingle();
  if (error || !data) return;
  if (data.from_profile_id) fromProfileId.value = data.from_profile_id;
  if (data.to_profile_id) toProfileId.value = data.to_profile_id;
});

const tenantSideProfileId = ref<number | null>(null);
const composePaperKind = ref<ComposePaperKind>('take');
const lines = ref<ComposeLine[]>([]);

const stockLines = computed(() =>
  lines.value.filter((l) => l.line_kind === 'stock' && l.global_stock_id != null),
);

const fromProfileId = ref<number | null>(null);
const toProfileId = ref<number | null>(null);
const fromProfileOptions = ref<CustomerProfile[]>([]);
const toProfileOptions = ref<CustomerProfile[]>([]);

const directionLocked = computed(
  () => documentKind.value !== 'standard' && parentBillId.value != null,
);

/** To = tenant profile → we owe (pay out); otherwise they owe (collect). */
const billDirection = computed<BillDirection>(() => {
  const tenantSide = tenantSideProfileId.value;
  if (tenantSide != null && toProfileId.value === tenantSide) {
    return 'we_owe';
  }
  return 'they_owe';
});

const isWalkIn = computed(
  () => billDirection.value === 'they_owe' && composePaperKind.value === 'walkin',
);

const showSettlementGroup = computed(() => billDirection.value === 'they_owe');

const showStockSearch = computed(
  () =>
    billDirection.value === 'they_owe' &&
    documentKind.value === 'standard' &&
    composePaperKind.value !== 'walkin',
);

const hasStockLines = computed(() => stockLines.value.length > 0);

const rememberTenantSideProfile = (id: number | null) => {
  if (id == null || !tenantId.value) return;
  localStorage.setItem(`${TENANT_PROFILE_STORAGE_KEY}_${tenantId.value}`, String(id));
};

const applyDefaultTenantSideProfile = (profiles: CustomerProfile[]) => {
  const issuedId = tenantId.value;
  const tenantRow =
    profiles.find((p) => p.profile_type === 'tenant' && p.subject_id === issuedId) ??
    profiles.find((p) => p.id === tenantSideProfileId.value);
  if (!tenantRow) return;

  tenantSideProfileId.value = tenantRow.id;
  if (!editInvoiceId.value && fromProfileId.value == null) {
    fromProfileId.value = tenantRow.id;
  }
};

watch(
  () => [fromProfileId.value, toProfileId.value, billDirection.value] as const,
  ([from, to, dir]) => {
    const tenantSide = tenantSideProfileId.value;
    if (tenantSide == null) return;
    if (dir === 'they_owe' && from === tenantSide) rememberTenantSideProfile(from);
    if (dir === 'we_owe' && to === tenantSide) rememberTenantSideProfile(to);
  },
);

watch(fromProfileId, (id) => {
  void ensureProfileInOptions(id, 'from');
});
watch(toProfileId, (toId, prevTo) => {
  void ensureProfileInOptions(toId, 'to');
  const tenantSide = tenantSideProfileId.value;
  if (tenantSide != null && toId === tenantSide && prevTo !== toId) {
    lines.value = lines.value.filter((l) => l.line_kind !== 'stock');
    if (composePaperKind.value === 'condition') {
      composePaperKind.value = 'take';
    }
  }
});

watch(hasStockLines, (has) => {
  if (!has && composePaperKind.value === 'condition') {
    composePaperKind.value = 'take';
  }
});

const editInvoiceId = computed(() => {
  const raw = route.query.id;
  const id = Number(typeof raw === 'string' ? raw : '');
  return Number.isFinite(id) && id > 0 ? id : null;
});

const invoiceDate = ref(new Date().toISOString().slice(0, 10));
const dueDate = ref<string | null>(null);

const onDueDatePicked = (value: string | null) => {
  dueDate.value = value && value.length ? value : null;
};
const discountAmount = ref(0);
const note = ref('');
const removedItemIds = ref<number[]>([]);
const loadingExisting = ref(false);
const voidingDraft = ref(false);

const canVoidDraft = computed(() => editInvoiceId.value != null);

const profilesAreSame = computed(
  () =>
    !isWalkIn.value &&
    fromProfileId.value != null &&
    toProfileId.value != null &&
    fromProfileId.value === toProfileId.value,
);

type PartySide = 'from' | 'to';

const composePartyTypes: Database['public']['Enums']['profile_party_type'][] = [
  'tenant',
  'company',
  'customer',
  'vendor',
  'cargo',
  'courier',
  'investor',
];

const profilePartyCaption = (profile: CustomerProfile) => {
  const phone = profile.phone?.trim();
  const email = profile.email?.trim();
  if (phone && email) return `${phone} · ${email}`;
  return phone || email || '';
};

const profileTypeChipStyles: Record<
  Database['public']['Enums']['profile_party_type'],
  { label: string; color: string; textColor: string }
> = {
  customer: { label: 'Customer', color: 'blue-1', textColor: 'blue-9' },
  tenant: { label: 'Tenant', color: 'purple-1', textColor: 'purple-9' },
  vendor: { label: 'Vendor', color: 'orange-1', textColor: 'orange-9' },
  cargo: { label: 'Cargo', color: 'brown-1', textColor: 'brown-9' },
  courier: { label: 'Courier', color: 'teal-1', textColor: 'teal-9' },
  company: { label: 'Company', color: 'indigo-1', textColor: 'indigo-9' },
  investor: { label: 'Investor', color: 'cyan-1', textColor: 'cyan-9' },
};

const profileTypeChip = (profile: CustomerProfile) => {
  const styled = profileTypeChipStyles[profile.profile_type];
  if (styled) return styled;
  const label = profile.profile_type.replace(/_/g, ' ');
  return { label, color: 'grey-2', textColor: 'grey-8' };
};

const composeProfileOptions = (): CustomerProfile[] =>
  deskProfiles.value.filter(
    (p) => p.is_active !== false && composePartyTypes.includes(p.profile_type),
  );

const fetchProfileOptions = async (needle: string): Promise<CustomerProfile[]> => {
  if (!parentTenantId.value) return [];
  await ensureProfilesLoaded();
  const trimmed = needle.trim().toLowerCase();
  let rows = composeProfileOptions();
  if (trimmed) {
    rows = rows.filter((p) => {
      const name = (p.name ?? '').toLowerCase();
      const email = (p.email ?? '').toLowerCase();
      const phone = (p.phone ?? '').toLowerCase();
      return name.includes(trimmed) || email.includes(trimmed) || phone.includes(trimmed);
    });
  }
  return rows;
};

const mergeProfileIntoOptions = (
  list: { value: CustomerProfile[] },
  profile: CustomerProfile,
) => {
  if (list.value.some((p) => p.id === profile.id)) return;
  list.value = [profile, ...list.value];
};

const ensureProfileInOptions = async (id: number | null, side: PartySide) => {
  if (id == null) return;
  const list = side === 'from' ? fromProfileOptions : toProfileOptions;
  if (list.value.some((p) => p.id === id)) return;
  await ensureProfilesLoaded();
  const profile = profileById(id);
  if (profile) mergeProfileIntoOptions(list, profile);
};

const filterFromProfiles = async (val: string, update: (cb: () => void) => void) => {
  const rows = await fetchProfileOptions(val);
  update(() => {
    fromProfileOptions.value = rows;
    applyDefaultTenantSideProfile(rows);
    void ensureProfileInOptions(fromProfileId.value, 'from');
  });
};

const filterToProfiles = async (val: string, update: (cb: () => void) => void) => {
  const rows = await fetchProfileOptions(val);
  update(() => {
    toProfileOptions.value = rows;
    void ensureProfileInOptions(toProfileId.value, 'to');
  });
};

const resolveTenantSideProfile = async () => {
  const booksId = parentTenantId.value;
  const issuedId = tenantId.value;
  if (!booksId || !issuedId) return;

  await ensureProfilesLoaded();
  const tenantRows = composeProfileOptions().filter((p) => p.profile_type === 'tenant');
  const bySubject = (subjectId: number) =>
    tenantRows.find((p) => p.subject_id === subjectId) ?? null;

  let row: CustomerProfile | null = bySubject(issuedId);
  if (!row && booksId !== issuedId) {
    row = bySubject(booksId);
  }
  if (!row && tenantRows.length > 0) {
    row = tenantRows[0];
  }

  if (!row) return;

  tenantSideProfileId.value = row.id;
  mergeProfileIntoOptions(fromProfileOptions, row);

  if (!editInvoiceId.value) {
    fromProfileId.value = row.id;
  } else if (fromProfileId.value == null) {
    fromProfileId.value = row.id;
  }
};

const filterParentBills = async (val: string, update: (cb: () => void) => void) => {
  if (!parentTenantId.value) {
    update(() => {
      parentBillOptions.value = [];
    });
    return;
  }
  const needle = val.trim();
  let query = supabase
    .from('bills')
    .select('id, invoice_no, invoice_date')
    .eq('parent_tenant_id', parentTenantId.value)
    .eq('document_kind', 'standard')
    .eq('invoice_status', 'issued')
    .order('invoice_date', { ascending: false })
    .limit(25);
  if (needle) {
    query = query.ilike('invoice_no', `%${needle}%`);
  }
  const { data } = await query;
  update(() => {
    parentBillOptions.value =
      (data ?? []).map((row) => ({
        id: row.id,
        label: `${row.invoice_no ?? `#${row.id}`} · ${row.invoice_date ?? ''}`,
      })) ?? [];
  });
};

const lineMetaForPayload = (line: ComposeLine) =>
  line.line_kind === 'charge' && line.charge_type ? { charge_type: line.charge_type } : {};

const mapLineToPayloadItem = (line: ComposeLine) => {
  const item = {
    ...(line.id ? { id: line.id } : {}),
    line_kind: line.line_kind,
    name_snapshot: line.name.trim(),
    quantity: line.quantity,
    sell_price_amount: line.sell_price_amount,
    line_discount_amount: line.line_discount_amount || 0,
    line_meta: lineMetaForPayload(line),
  };
  if (line.line_kind === 'stock' && line.global_stock_id != null) {
    return { ...item, global_stock_id: line.global_stock_id };
  }
  return item;
};

const lineTotalAmount = (line: ComposeLine) =>
  Math.max(line.quantity * line.sell_price_amount - (line.line_discount_amount || 0), 0);

const settlementKindForKernel = (): BillSettlementKind | null => {
  if (billDirection.value === 'we_owe') return null;
  if (composePaperKind.value === 'walkin') return 'take';
  if (composePaperKind.value === 'condition' && !hasStockLines.value) return 'take';
  return composePaperKind.value === 'condition' ? 'condition' : 'take';
};

const isSourcePlugged = computed(
  () => !!sourceType.value && sourceType.value !== 'compose',
);

const persistBillMeta = async (billId: number) => {
  const parent = documentKind.value === 'standard' ? null : parentBillId.value;
  if (documentKind.value !== 'standard' && parent == null) {
    throw new Error('Choose the issued bill this note applies to.');
  }

  const letterheadId =
    billDirection.value === 'they_owe' ? fromProfileId.value : toProfileId.value;

  const channelMeta = {
    delivery_kind: billDirection.value === 'we_owe' ? 'take' : composePaperKind.value === 'walkin' ? 'take' : composePaperKind.value,
    letterhead_profile_id: letterheadId,
  };

  const patch: {
    document_kind: BillDocumentKind;
    parent_bill_id: number | null;
    from_profile_id: number | null;
    to_profile_id: number | null;
    settlement_kind: BillSettlementKind | null;
    channel_meta: { delivery_kind: string; letterhead_profile_id: number | null };
    profile_id?: number | null;
    invoice_type?: 'wholesale' | 'retail' | 'ap';
    source_type?: string;
    source_id?: string;
  } = {
    document_kind: documentKind.value,
    parent_bill_id: parent,
    from_profile_id: fromProfileId.value,
    to_profile_id: toProfileId.value,
    settlement_kind: settlementKindForKernel(),
    channel_meta: channelMeta,
  };

  if (billDirection.value === 'we_owe') {
    patch.invoice_type = 'ap';
    patch.profile_id = fromProfileId.value;
  } else if (!isWalkIn.value) {
    patch.profile_id = toProfileId.value;
    patch.invoice_type = 'wholesale';
  } else {
    patch.profile_id = null;
    patch.invoice_type = 'retail';
  }

  const { error } = await supabase.from('bills').update(patch).eq('id', billId);
  if (error) throw error;
};

const lineTotal = (line: ComposeLine) => lineTotalAmount(line);

const subtotal = computed(() => lines.value.reduce((s, l) => s + lineTotal(l), 0));
const estimatedTotal = computed(() =>
  Math.max(subtotal.value - (discountAmount.value || 0), 0),
);

const documentKindReady = computed(
  () => documentKind.value === 'standard' || parentBillId.value != null,
);

const canSave = computed(() => {
  if (!tenantId.value || !documentKindReady.value || profilesAreSame.value) return false;
  if (isWalkIn.value) return !!fromProfileId.value;
  if (billDirection.value === 'we_owe') {
    return !!fromProfileId.value && !!toProfileId.value;
  }
  return !!fromProfileId.value && !!toProfileId.value;
});
const lineIsValid = (line: ComposeLine) => {
  if (!line.name.trim()) return false;
  if (line.quantity <= 0) return false;
  if (line.sell_price_amount < 0) return false;
  if (line.line_kind === 'stock') {
    return line.global_stock_id != null;
  }
  return true;
};

const canIssue = computed(() => {
  if (!canSave.value || lines.value.length === 0 || !lines.value.every(lineIsValid)) {
    return false;
  }
  if (billDirection.value === 'we_owe' && stockLines.value.length > 0) return false;
  if (composePaperKind.value === 'condition' && !hasStockLines.value) return false;
  return true;
});

const addLineFromStock = (row: SalesInvoiceStockItem) => {
  if (row.available_atp <= 0) return;
  const existing = lines.value.find((l) => l.global_stock_id === row.global_stock_id);
  if (existing) {
    existing.quantity = Math.min(existing.quantity + 1, existing.available_atp ?? 0);
    return;
  }
  lines.value.push({
    key: `new-${row.global_stock_id}-${Date.now()}`,
    line_kind: 'stock',
    global_stock_id: row.global_stock_id,
    name: row.name,
    image_url: row.image_url,
    available_atp: row.available_atp,
    quantity: 1,
    sell_price_amount: row.suggested_sell_price,
    line_discount_amount: 0,
  });
};

const injectLegacyHeaderCharges = (
  mappedLines: ComposeLine[],
  header: { shipping?: number; wrapping?: number; print?: number },
) => {
  const hasChargeType = (type: string) =>
    mappedLines.some((l) => l.line_kind === 'charge' && l.charge_type === type);
  const pushCharge = (type: string, label: string, amount: number) => {
    if (amount <= 0 || hasChargeType(type)) return;
    mappedLines.push({
      key: `legacy-${type}-${Date.now()}`,
      line_kind: 'charge',
      name: label,
      quantity: 1,
      sell_price_amount: amount,
      line_discount_amount: 0,
      charge_type: type,
    });
  };
  pushCharge('shipping', 'Shipping', header.shipping ?? 0);
  pushCharge('wrapping', 'Wrapping', header.wrapping ?? 0);
  pushCharge('print', 'Print', header.print ?? 0);
};

const onChargeTypeChange = (line: ComposeLine, chargeType: string) => {
  line.charge_type = chargeType;
  const preset = chargeTypeLabel(chargeType);
  if (!line.name.trim() || chargeTypeOptions.some((o) => o.label === line.name.trim())) {
    line.name = preset;
  }
};

const onStockPickedFromPicker = (row: SalesInvoiceStockItem) => {
  addLineFromStock(row);
  stockLinePickerOpen.value = false;
};

const addBlankLine = (opt: AddLineMenuOption) => {
  if (opt.line_kind === 'stock') {
    stockLinePickerOpen.value = true;
    return;
  }
  lines.value.push({
    key: `manual-${opt.line_kind}-${Date.now()}`,
    line_kind: opt.line_kind,
    name: opt.line_kind === 'charge' ? chargeTypeLabel('shipping') : '',
    quantity: 1,
    sell_price_amount: 0,
    line_discount_amount: 0,
    charge_type: opt.line_kind === 'charge' ? 'shipping' : undefined,
  });
};

const removeLine = (index: number) => {
  const line = lines.value[index];
  if (line?.id) {
    removedItemIds.value.push(line.id);
  }
  lines.value.splice(index, 1);
};

const buildPayload = () => {
  const walkIn = isWalkIn.value;
  const weOwe = billDirection.value === 'we_owe';
  const invoiceType: 'wholesale' | 'retail' | 'ap' = weOwe
    ? 'ap'
    : walkIn
      ? 'retail'
      : 'wholesale';
  const retailMode: 'direct' | null = walkIn ? 'direct' : null;
  const deliveryKind: 'take' | 'condition' =
    weOwe || walkIn ? 'take' : composePaperKind.value === 'condition' ? 'condition' : 'take';
  const letterheadId = weOwe ? toProfileId.value : fromProfileId.value;
  let profileIdForRpc: number | undefined;
  if (weOwe) {
    profileIdForRpc = fromProfileId.value ?? undefined;
  } else if (!walkIn) {
    profileIdForRpc = toProfileId.value ?? undefined;
  }
  return {
    invoice: {
      invoice_type: invoiceType,
      profile_id: profileIdForRpc ?? 0,
      invoice_date: invoiceDate.value,
      due_date: dueDate.value || undefined,
      discount_amount: discountAmount.value || 0,
      shipping_charge: 0,
      wrapping_charge: 0,
      print_charge: 0,
      note: note.value.trim() || undefined,
      retail_billing_mode: retailMode,
      channel_meta: {
        delivery_kind: deliveryKind,
        letterhead_profile_id: letterheadId,
      },
    },
    items: lines.value.filter(lineIsValid).map(mapLineToPayloadItem),
    issue: false,
  };
};

const saveDraft = async () => {
  if (!canSave.value) return;
  const result = await composeMutation.mutateAsync({
    tenantId: tenantId.value,
    invoiceId: editInvoiceId.value,
    payload: buildPayload(),
    removeItemIds: removedItemIds.value,
    issue: false,
  });
  const savedId = result.invoice_id ?? editInvoiceId.value;
  if (savedId) {
    await persistBillMeta(savedId);
    await refreshBillSourcePlug(savedId);
  }
  const newId = result.invoice_id;
  if (newId && !editInvoiceId.value) {
    const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
    await router.replace({
      name: 'app-bill-compose-page',
      params: tenantSlug ? { tenantSlug } : {},
      query: { id: String(newId) },
    });
  }
  removedItemIds.value = [];
};

const goToBillsList = async () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  await router.push({
    name: 'app-bills-page',
    params: tenantSlug ? { tenantSlug } : {},
  });
};

const voidDraft = async () => {
  const id = editInvoiceId.value;
  if (!id || !canVoidDraft.value) return;
  const ok = await requestConfirmation(
    'This removes the draft bill. You cannot undo this.',
    'Void this draft?',
  );
  if (!ok) return;
  voidingDraft.value = true;
  try {
    await billsRepository.deleteDraftBill(id);
    showSuccessNotification('Draft voided.');
    await goToBillsList();
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Could not void draft.';
    showErrorNotification(message);
  } finally {
    voidingDraft.value = false;
  }
};

const issueConfirmCopy = () => {
  if (billDirection.value === 'we_owe') {
    return {
      title: 'Issue this payable bill?',
      body: 'No sales on this paper. Pay out later on Payments.',
    };
  }
  if (!hasStockLines.value) {
    return {
      title: 'Issue this bill?',
      body: 'Paper only — no inventory moves. Collect or pay on Payments.',
    };
  }
  if (composePaperKind.value === 'condition') {
    return {
      title: 'Issue this condition bill?',
      body: 'Stock moves to held. Sales count when this bill is paid. Collect on Payments.',
    };
  }
  return {
    title: 'Issue this bill?',
    body: 'Sellable stock will leave inventory when you issue. You can collect payment later on Payments.',
  };
};

const issueBill = async () => {
  if (!canIssue.value) return;
  const copy = issueConfirmCopy();
  const ok = await requestConfirmation(copy.body, copy.title);
  if (!ok) return;
  const result = await composeMutation.mutateAsync({
    tenantId: tenantId.value,
    invoiceId: editInvoiceId.value,
    payload: { ...buildPayload(), issue: true },
    removeItemIds: removedItemIds.value,
    issue: true,
  });
  const id = result.invoice_id ?? editInvoiceId.value;
  if (!id) return;
  await persistBillMeta(id);
  await refreshBillSourcePlug(id);
  removedItemIds.value = [];
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({
    name: 'app-bill-detail-page',
    params: {
      ...(tenantSlug ? { tenantSlug } : {}),
      billId: String(id),
    },
  });
};

const loadExisting = async (id: number) => {
  loadingExisting.value = true;
  try {
    const [bill, items, rawLinesRes] = await Promise.all([
      billsRepository.getBillById(id),
      billsRepository.listBillItems(id),
      supabase
        .from('bill_lines')
        .select(
          'id, line_kind, name_snapshot, quantity, sell_price_amount, line_discount_amount, global_stock_id, line_meta',
        )
        .eq('invoice_id', id)
        .order('id'),
    ]);
    if (rawLinesRes.error) throw rawLinesRes.error;
    const rawLines = rawLinesRes.data ?? [];
    const stockItemById = new Map(items.map((item) => [item.id, item]));
    if (!['draft', 'proforma_generated'].includes(bill.invoice_status)) {
      const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
      router.replace({
        name: 'app-bill-detail-page',
        params: {
          ...(tenantSlug ? { tenantSlug } : {}),
          billId: String(id),
        },
      });
      return;
    }
    const meta = bill.channel_meta as {
      delivery_kind?: string;
      letterhead_profile_id?: number;
    } | null | undefined;
    const deliveryKind = (meta?.delivery_kind ?? 'take').toLowerCase();
    const billRow = bill as {
      from_profile_id?: number | null;
      to_profile_id?: number | null;
      settlement_kind?: BillSettlementKind | null;
      document_kind?: BillDocumentKind;
      parent_bill_id?: number | null;
      source_type?: string | null;
      source_id?: string | null;
      source_key?: string | null;
    };
    applySourcePlugFromBill(billRow);
    documentKind.value = billRow.document_kind ?? 'standard';
    parentBillId.value = billRow.parent_bill_id ?? null;
    if (parentBillId.value) {
      const { data: parentRow } = await supabase
        .from('bills')
        .select('invoice_no')
        .eq('id', parentBillId.value)
        .maybeSingle();
      parentBillOptions.value = [
        {
          id: parentBillId.value,
          label: parentRow?.invoice_no?.trim() || `Bill #${parentBillId.value}`,
        },
      ];
    }

    await resolveTenantSideProfile();

    if (bill.invoice_type === 'ap') {
      fromProfileId.value = billRow.from_profile_id ?? bill.profile_id ?? null;
      toProfileId.value = billRow.to_profile_id ?? tenantSideProfileId.value;
    } else {
      fromProfileId.value =
        billRow.from_profile_id ?? meta?.letterhead_profile_id ?? tenantSideProfileId.value;
      toProfileId.value = billRow.to_profile_id ?? bill.profile_id ?? null;
    }

    invoiceDate.value = bill.invoice_date?.slice(0, 10) ?? invoiceDate.value;
    dueDate.value = bill.due_date?.slice(0, 10) ?? null;
    discountAmount.value = Number(bill.discount_amount ?? 0);
    note.value = bill.note ?? '';

    const mappedLines: ComposeLine[] = rawLines.map((row) => {
      const kind = (row.line_kind ?? 'stock') as ComposeLineKind;
      const stockItem = stockItemById.get(row.id);
      const lineMeta = row.line_meta as { charge_type?: string } | null;
      return {
        key: `item-${row.id}`,
        id: row.id,
        line_kind: kind,
        global_stock_id: row.global_stock_id ?? undefined,
        name: row.name_snapshot,
        image_url: stockItem?.image_url ?? null,
        available_atp: stockItem?.available_atp ?? row.quantity,
        quantity: Number(row.quantity),
        sell_price_amount: Number(row.sell_price_amount),
        line_discount_amount: Number(row.line_discount_amount ?? 0),
        charge_type: lineMeta?.charge_type,
      };
    });
    injectLegacyHeaderCharges(mappedLines, {
      shipping: Number(bill.shipping_charge ?? 0),
      wrapping: Number(bill.wrapping_charge ?? 0),
      print: Number(bill.print_charge ?? 0),
    });
    lines.value = mappedLines;

    const settle =
      billRow.settlement_kind ??
      (deliveryKind === 'condition' ? 'condition' : 'take');
    if (bill.invoice_type === 'retail' && bill.retail_billing_mode === 'direct') {
      composePaperKind.value = 'walkin';
    } else if (settle === 'condition') {
      composePaperKind.value = 'condition';
    } else {
      composePaperKind.value = 'take';
    }

    await ensureProfilesLoaded();
    const rows = composeProfileOptions();
    fromProfileOptions.value = rows;
    toProfileOptions.value = rows;
    const no = bill.invoice_no?.trim();
    composeBreadcrumbTitle.value = no || `Bill #${id}`;
  } finally {
    loadingExisting.value = false;
  }
};

watch(
  editInvoiceId,
  (id) => {
    if (!id) composeBreadcrumbTitle.value = 'New bill';
    if (id) void loadExisting(id);
  },
  { immediate: true },
);

const breadcrumbItems = computed(() => {
  const tenantSlug =
    (typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : null) ||
    authStore.tenantSlug ||
    undefined;
  return [
    {
      label: authStore.selectedTenant?.name || 'Workspace',
      icon: 'ph ph-buildings',
    },
    {
      label: 'Bills',
      to: {
        name: 'app-bills-page',
        ...(tenantSlug ? { params: { tenantSlug } } : {}),
      },
    },
    { label: composeBreadcrumbTitle.value },
  ];
});

watch(breadcrumbItems, (items) => setCustomBreadcrumbs(items), { immediate: true });
onBeforeUnmount(() => clearCustomBreadcrumbs());

const refreshComposeProfilePickers = async () => {
  if (!parentTenantId.value) return;
  await ensureProfilesLoaded();
  await resolveTenantSideProfile();
  const rows = composeProfileOptions();
  fromProfileOptions.value = rows;
  toProfileOptions.value = rows;
};

watch(parentTenantId, () => {
  void refreshComposeProfilePickers();
}, { immediate: true });
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.compose-card {
  max-width: 960px;
  margin: 0 auto;
  min-height: 100%;
  background: var(--tf-neutral-surface, #fff);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
}

.compose-sticky-toolbar {
  position: sticky;
  top: 0;
  z-index: 2;
  border-radius: 8px 8px 0 0;
}

.compose-party-card {
  background: var(--tf-neutral-surface-alt, #f8fafc);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
}

.compose-party-select :deep(.q-field__control) {
  min-height: 36px;
}

.compose-party-label {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome, #64748b);
  padding-right: 4px;
  white-space: nowrap;
}

body.body--dark .compose-party-card {
  background: #1c1c1c;
  border-color: #2e2e2e;
}

.compose-footer {
  border-top: 1px solid var(--tf-neutral-border, #e7e1d8);
  background: var(--tf-neutral-surface-alt, #f8fafc);
  border-radius: 0 0 8px 8px;
}

body.body--dark .compose-footer {
  background: #1c1c1c;
  border-color: #2e2e2e;
}

.compose-lines-empty {
  font-size: 13px;
  border: 1px dashed var(--tf-neutral-border, #e7e1d8);
  border-radius: 8px;
}

.compose-add-line-menu {
  min-width: 240px;
}

.compose-stock-picker-card {
  width: min(480px, 92vw);
  max-width: 480px;
}

.compose-kind-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: stretch;
  gap: 12px 20px;
  padding: 10px 12px;
  border-radius: var(--tf-radius-sm, 8px);
  background: var(--tf-neutral-surface-alt, #f8fafc);
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
}

body.body--dark .compose-kind-toolbar {
  background: #1c1c1c;
  border-color: #2e2e2e;
}

.compose-kind-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}

.compose-kind-heading {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome, #64748b);
  padding-left: 2px;
}

.compose-toolbar-segment {
  display: inline-flex;
  align-items: center;
  flex-wrap: nowrap;
  gap: 2px;
  padding: 2px;
  border-radius: var(--tf-radius-sm, 8px);
  background: #f1f5f9;
  flex-shrink: 0;
}

body.body--dark .compose-toolbar-segment {
  background: var(--tf-neutral-border);
}

.compose-toolbar-segment :deep(.compose-toolbar-btn) {
  min-height: 28px;
  height: 28px;
  padding: 0 10px;
  font-size: 12px;
  font-weight: 600;
  border-radius: 6px;
}

.compose-toolbar-segment :deep(.compose-toolbar-btn .q-icon) {
  font-size: 14px;
}

.compose-toolbar-segment :deep(.compose-toolbar-btn .q-icon.on-left) {
  margin-right: 4px;
}

.compose-toolbar-segment :deep(.compose-toolbar-btn .q-btn__content) {
  flex-wrap: nowrap;
  white-space: nowrap;
}

.compose-lifecycle-group {
  flex-shrink: 0;
}

.compose-document-chips {
  min-height: 28px;
}

.compose-document-segment :deep(.compose-toolbar-btn) {
  color: var(--tf-neutral-ink, #171412);
}

body.body--dark .compose-document-segment :deep(.compose-toolbar-btn) {
  color: var(--tf-neutral-ink, #f5f5f4);
}

.compose-document-chip {
  font-size: 12px;
  font-weight: 600;
  border-radius: 6px;
  background: var(--tf-neutral-surface, #fff) !important;
  color: var(--tf-neutral-ink, #171412) !important;
  border: 1px solid var(--tf-neutral-border, #e7e1d8);
}

body.body--dark .compose-document-chip {
  background: var(--tf-neutral-surface, #1c1917) !important;
  color: var(--tf-neutral-ink, #f5f5f4) !important;
  border-color: var(--tf-neutral-border, #2a2622);
}

.compose-parent-bill-select {
  min-width: 220px;
  max-width: 320px;
}

.totals-panel {
  min-width: 220px;
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 13px;
}
.total-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
}
.compose-lines-table th {
  font-size: 11px;
  color: var(--tf-neutral-chrome, #64748b);
}
.compose-line-item-cell {
  vertical-align: top;
  max-width: 320px;
}

.compose-note-section {
  max-width: 640px;
}
</style>
