<template>
  <q-card flat bordered class="q-pa-md bg-white text-grey-9">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="text-subtitle1 text-weight-bold text-primary">Cost entries</div>
        <div class="text-caption text-grey-6">
          Enter product and cargo rates. Cargo weight is set on Match invoices.
        </div>
      </div>
      <q-badge v-if="isFinalized" color="orange" outline label="Revision mode" />
    </div>

    <q-banner v-if="isFinalized && canEdit" dense rounded class="bg-orange-1 text-orange-10 q-mb-md">
      Stock is already in. Saving updates item costs only — it does not pay anyone.
    </q-banner>

    <div v-if="loading" class="q-pa-md flex flex-center">
      <q-spinner color="primary" size="32px" />
    </div>

    <div v-else class="column q-gutter-y-md">
      <!-- Section Invoices (Purchase Matching) -->
      <div v-if="sections.length > 0" class="cost-section" data-test="cost-section-invoices">
        <div class="row items-center justify-between q-mb-sm">
          <div class="row items-center q-gutter-xs">
            <div class="text-subtitle2 text-weight-bold text-grey-8">Section Invoices (Purchase Matching)</div>
            <span class="text-caption text-grey-6">
              · {{ sections.length }} {{ sections.length === 1 ? 'section' : 'sections' }}
            </span>
          </div>
        </div>

        <div class="column q-gutter-y-sm">
          <div
            v-for="sec in sections"
            :key="sec.id"
            class="cost-entry-row q-pa-sm rounded-borders"
          >
            <div class="row items-center justify-between q-mb-xs">
              <div class="row items-center q-gutter-xs">
                <div
                  v-if="sec.color"
                  class="rounded-borders"
                  :style="{
                    width: '10px',
                    height: '10px',
                    backgroundColor: sec.color || '#9e9e9e',
                  }"
                />
                <span class="text-subtitle2 text-weight-bold text-grey-9">
                  {{ sec.title || (sec as any).name }}
                </span>
                <q-badge
                  v-if="sec.metadata?.invoice_number"
                  outline
                  color="primary"
                  class="q-px-xs text-weight-medium"
                  style="font-size: 11px"
                >
                  <q-icon name="ph ph-receipt" size="12px" class="q-mr-xs" />
                  Inv #{{ sec.metadata.invoice_number }}
                </q-badge>
                <span class="text-caption text-grey-6" style="font-size: 11px">
                  ({{ getSectionQty(sec.id) }} pcs · lines sum: {{ purchaseCurrencySymbol }}{{ getSectionCalculatedPurchase(sec.id).toFixed(2) }})
                </span>
              </div>

              <!-- Matched status / Discrepancy badge -->
              <div class="row items-center q-gutter-xs">
                <q-badge
                  v-if="getSectionDeltaById(sec.id) === 0"
                  color="green-1"
                  text-color="green-9"
                  class="q-pa-xs"
                >
                  ✓ Matched
                </q-badge>
                <q-badge
                  v-else
                  :color="getSectionDeltaById(sec.id) > 0 ? 'red-1' : 'orange-1'"
                  :text-color="getSectionDeltaById(sec.id) > 0 ? 'red-9' : 'orange-9'"
                  class="q-pa-xs"
                >
                  Discrepancy: {{ getSectionDeltaById(sec.id) > 0 ? '+' : '' }}{{ getSectionDeltaById(sec.id).toFixed(2) }} {{ purchaseCurrencySymbol }}
                </q-badge>
              </div>
            </div>

            <div class="row q-col-gutter-sm items-center">
              <div class="col-12 col-sm-8">
                <q-input
                  v-model.number="sectionInvoiceInputs[sec.id]"
                  type="number"
                  step="0.01"
                  min="0"
                  :label="sec.metadata?.invoice_number ? `Invoice #${sec.metadata.invoice_number} Total *` : 'Supplier Invoice Total *'"
                  dense
                  outlined
                  class="soft-input"
                  :prefix="purchaseCurrencySymbol"
                  :disable="!canEdit"
                  :hint="sec.metadata?.invoice_number ? `Enter total billed on Invoice #${sec.metadata.invoice_number}` : 'Enter total billed on supplier invoice for this section'"
                />
              </div>
              <div class="col-12 col-sm-4">
                <!-- Show Balance button when changed / delta !== 0 -->
                <q-btn
                  v-if="canEdit && getSectionDeltaById(sec.id) !== 0"
                  unelevated
                  no-caps
                  color="primary"
                  icon="ph ph-scales"
                  label="Balance"
                  class="full-width"
                  style="height: 40px; margin-top: -18px; border-radius: 8px"
                  :loading="balancingSectionId === sec.id"
                  @click="openSectionBalanceModal(sec)"
                >
                  <q-tooltip>Preview and balance {{ sec.title || (sec as any).name }} line prices to {{ sectionInvoiceInputs[sec.id] }} {{ purchaseCurrencySymbol }}</q-tooltip>
                </q-btn>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Product section -->
      <div class="cost-section" data-test="cost-section-product">
        <div class="row items-center justify-between q-mb-sm">
          <div class="text-subtitle2 text-weight-bold text-grey-8">Product</div>
          <q-btn
            v-if="canEdit"
            flat
            dense
            no-caps
            size="sm"
            color="primary"
            icon="ph ph-plus"
            label="Add rate"
            data-test="cost-entry-add-product"
            @click="addRow('product')"
          />
        </div>

        <div class="column q-gutter-y-sm">
          <div
            v-for="(row, idx) in productRows"
            :key="row.localKey"
            class="cost-entry-row q-pa-sm rounded-borders"
            data-test="cost-entry-row-product"
          >
            <div class="row items-center justify-between q-mb-xs">
              <span class="text-caption text-grey-6">Rate {{ idx + 1 }}</span>
              <q-btn
                v-if="canEdit && productRows.length > 1"
                flat
                dense
                round
                size="sm"
                icon="ph ph-trash"
                color="negative"
                data-test="cost-entry-remove"
                @click="removeRow(row.localKey)"
              >
                <q-tooltip>Remove rate</q-tooltip>
              </q-btn>
            </div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="row.amount"
                  type="number"
                  step="0.01"
                  min="0"
                  label="Amount *"
                  dense
                  outlined
                  class="soft-input"
                  :prefix="purchaseCurrencySymbol"
                  :disable="!canEdit"
                  hint="Purchase currency total for this FX slice"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="row.exchange_rate"
                  type="number"
                  step="0.0001"
                  min="0.0001"
                  label="Exchange rate → BDT *"
                  dense
                  outlined
                  class="soft-input"
                  :disable="!canEdit || isLocalShipment"
                  :hint="isLocalShipment ? 'Forced to 1.00 for local' : 'Rate to base currency'"
                />
              </div>
              <div class="col-12">
                <q-input
                  v-model="row.note"
                  type="text"
                  label="Notes / Remarks"
                  placeholder="e.g. Rate notes, remarks"
                  dense
                  outlined
                  class="soft-input"
                  :disable="!canEdit"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Cargo section -->
      <div class="cost-section" data-test="cost-section-cargo">
        <div class="row items-center justify-between q-mb-sm">
          <div class="text-subtitle2 text-weight-bold text-grey-8">Cargo</div>
          <q-btn
            v-if="canEdit"
            flat
            dense
            no-caps
            size="sm"
            color="primary"
            icon="ph ph-plus"
            label="Add rate"
            data-test="cost-entry-add-cargo"
            @click="addRow('cargo')"
          />
        </div>

        <div class="row q-col-gutter-sm q-mb-sm items-center">
          <div class="col-12 col-sm-4">
            <q-input
              v-model.number="localWeightKg"
              type="number"
              step="0.01"
              min="0"
              label="Cargo weight (kg) *"
              dense
              outlined
              class="soft-input"
              suffix="kg"
              :disable="!canEdit"
              hint="Total scale weight in kg"
              data-test="cost-entry-weight"
            />
          </div>
          <div class="col-12 col-sm-4">
            <!-- Distribute weight button only if discrepancy / difference exists -->
            <q-btn
              v-if="canEdit && localWeightKg > 0 && Math.abs(deltaKg) > 0.01 && shipmentItems.length"
              unelevated
              no-caps
              color="primary"
              icon="ph ph-scales"
              label="Distribute weight"
              class="full-width"
              style="height: 40px; margin-top: -18px; border-radius: 8px"
              :loading="applyingDistribution"
              data-test="cost-distribute-weight"
              @click="openWeightDistributionDialog"
            >
              <q-tooltip>Distribute {{ localWeightKg }} kg across lines (Δ {{ deltaKg > 0 ? '+' : '' }}{{ deltaKg.toFixed(2) }} kg)</q-tooltip>
            </q-btn>
            <!-- Matched badge if weight is equal -->
            <div
              v-else-if="localWeightKg > 0 && Math.abs(deltaKg) <= 0.01"
              class="row items-center q-gutter-xs"
              style="margin-top: -18px"
            >
              <q-badge color="green-1" text-color="green-9" class="q-pa-xs text-weight-medium">
                ✓ Weight matched ({{ estimatedLinesKg.toFixed(2) }} kg)
              </q-badge>
            </div>
          </div>
          <div class="col-12 col-sm-4">
            <div class="q-pa-xs px-sm-sm rounded-borders bg-grey-2 border row items-center justify-between" style="min-height: 40px; margin-top: -18px">
              <div>
                <div class="text-caption text-grey-7 text-weight-medium" style="font-size: 11px">Effective Cargo Rate</div>
                <div class="text-weight-bold text-primary" style="font-size: 12px">
                  <span v-if="effectivePerKg !== null">
                    {{ purchaseCurrencySymbol }} {{ effectivePerKg.toFixed(2) }} / kg
                  </span>
                  <span v-else class="text-grey-6">— / kg</span>
                </div>
              </div>
              <div v-if="effectiveBasePerKg !== null && !isLocalShipment" class="text-right">
                <div class="text-caption text-grey-6" style="font-size: 10px">In BDT</div>
                <div class="text-caption text-weight-bold text-grey-8" style="font-size: 11px">
                  {{ costCurrencySymbol }} {{ effectiveBasePerKg.toFixed(2) }} / kg
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="column q-gutter-y-sm">
          <div
            v-for="(row, idx) in cargoRows"
            :key="row.localKey"
            class="cost-entry-row q-pa-sm rounded-borders"
            data-test="cost-entry-row-cargo"
          >
            <div class="row items-center justify-between q-mb-xs">
              <span class="text-caption text-grey-6">Rate {{ idx + 1 }}</span>
              <q-btn
                v-if="canEdit && cargoRows.length > 1"
                flat
                dense
                round
                size="sm"
                icon="ph ph-trash"
                color="negative"
                data-test="cost-entry-remove"
                @click="removeRow(row.localKey)"
              >
                <q-tooltip>Remove rate</q-tooltip>
              </q-btn>
            </div>
            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="row.amount"
                  type="number"
                  step="0.01"
                  min="0"
                  label="Freight amount *"
                  dense
                  outlined
                  class="soft-input"
                  :prefix="purchaseCurrencySymbol"
                  :disable="!canEdit"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="row.exchange_rate"
                  type="number"
                  step="0.0001"
                  min="0.0001"
                  label="Exchange rate → BDT *"
                  dense
                  outlined
                  class="soft-input"
                  :disable="!canEdit || isLocalShipment"
                  :hint="isLocalShipment ? 'Forced to 1.00 for local' : undefined"
                />
              </div>
              <div class="col-12">
                <q-input
                  v-model="row.note"
                  type="text"
                  label="Notes / Remarks"
                  placeholder="e.g. Tranche notes, freight vendor invoice ref"
                  dense
                  outlined
                  class="soft-input"
                  :disable="!canEdit"
                />
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="row justify-end q-gutter-sm">
        <q-btn
          v-if="canEdit"
          flat
          no-caps
          color="grey-8"
          label="Reset"
          :disable="saving"
          @click="resetDrafts"
        />
        <q-btn
          v-if="canEdit"
          color="primary"
          unelevated
          no-caps
          :label="isFinalized ? 'Revise & re-stamp' : 'Save cost entries'"
          :loading="saving"
          data-test="cost-entry-save"
          @click="onSave"
        />
      </div>
    </div>

    <!-- Distribute Weight Dialog -->
    <q-dialog v-model="showDistributeDialog" persistent>
      <q-card style="min-width: 580px; max-width: 720px; width: 100%; border-radius: 12px">
        <q-card-section class="row items-center justify-between q-pb-none">
          <div class="row items-center q-gutter-sm">
            <q-avatar size="36px" color="primary" text-color="white" icon="ph ph-scales" />
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Distribute Cargo Weight</div>
              <div class="text-caption text-grey-6">
                Proportionally balance package weights across line items
              </div>
            </div>
          </div>
          <q-btn v-close-popup icon="ph ph-x" flat round dense color="grey-7" />
        </q-card-section>

        <q-card-section class="q-py-md">
          <!-- Summary Metric Cards -->
          <div class="row q-col-gutter-sm q-mb-md">
            <div class="col-4">
              <div class="q-pa-sm rounded-borders bg-grey-2 text-center">
                <div class="text-caption text-grey-7 text-weight-medium">Target Cargo Weight</div>
                <div class="text-h6 text-weight-bold text-primary">{{ localWeightKg.toFixed(2) }} kg</div>
              </div>
            </div>
            <div class="col-4">
              <div class="q-pa-sm rounded-borders bg-grey-2 text-center">
                <div class="text-caption text-grey-7 text-weight-medium">Current Line Total</div>
                <div class="text-h6 text-weight-bold text-grey-9">{{ estimatedLinesKg.toFixed(2) }} kg</div>
              </div>
            </div>
            <div class="col-4">
              <div
                class="q-pa-sm rounded-borders text-center"
                :class="deltaKg > 0 ? 'bg-red-1 text-red-9' : deltaKg < 0 ? 'bg-green-1 text-green-9' : 'bg-grey-2 text-grey-8'"
              >
                <div class="text-caption text-weight-medium">Adjustment (Delta)</div>
                <div class="text-h6 text-weight-bold">
                  {{ deltaKg > 0 ? `+${deltaKg.toFixed(2)}` : deltaKg.toFixed(2) }} kg
                </div>
              </div>
            </div>
          </div>

          <!-- Items Preview Table -->
          <div class="text-caption text-grey-8 text-weight-medium q-mb-xs">
            Line Items Preview ({{ distributionPreview.length }} items)
          </div>
          <div class="border rounded-borders overflow-hidden" style="max-height: 240px; overflow-y: auto">
            <q-markup-table dense flat separator="horizontal" class="bg-transparent">
              <thead>
                <tr class="bg-grey-2 text-grey-8 text-caption">
                  <th class="text-left">Product Item</th>
                  <th class="text-right">Qty</th>
                  <th class="text-right">Current (g)</th>
                  <th class="text-right">New (g)</th>
                  <th class="text-right">Change (g)</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in distributionPreview" :key="item.id">
                  <td class="text-left text-weight-medium text-grey-9 ellipsis" style="max-width: 220px">
                    {{ item.name }}
                  </td>
                  <td class="text-right text-grey-7">{{ item.qty }}</td>
                  <td class="text-right text-grey-7">{{ item.currentPkgWeight }}g</td>
                  <td class="text-right text-weight-bold text-primary">{{ item.newPkgWeight }}g</td>
                  <td
                    class="text-right text-weight-medium"
                    :class="item.perUnitDelta > 0 ? 'text-negative' : item.perUnitDelta < 0 ? 'text-positive' : 'text-grey-6'"
                  >
                    {{ item.perUnitDelta > 0 ? `+${item.perUnitDelta.toFixed(1)}` : item.perUnitDelta.toFixed(1) }}g
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </div>
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-px-md q-py-sm">
          <q-btn v-close-popup flat color="grey-8" label="Cancel" no-caps />
          <q-btn
            unelevated
            color="primary"
            icon="ph ph-check-circle"
            label="Apply & Distribute"
            no-caps
            :loading="applyingDistribution"
            @click="confirmDistributeWeight"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Match / Balance Section Dialog -->
    <q-dialog v-model="showSectionBalanceDialog" persistent>
      <q-card style="min-width: 580px; max-width: 720px; width: 100%; border-radius: 12px">
        <q-card-section class="row items-center justify-between q-pb-none">
          <div class="row items-center q-gutter-sm">
            <q-avatar size="36px" color="primary" text-color="white" icon="ph ph-scales" />
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">
                Balance Section Prices — {{ activeBalanceSection?.title || (activeBalanceSection as any)?.name }}
              </div>
              <div class="text-caption text-grey-6">
                Proportionally balance line item prices in this section to match the supplier invoice amount
              </div>
            </div>
          </div>
          <q-btn v-close-popup icon="ph ph-x" flat round dense color="grey-7" />
        </q-card-section>

        <q-card-section class="q-py-md">
          <!-- Summary Badges -->
          <div class="row q-col-gutter-sm q-mb-md">
            <div class="col-4">
              <div class="q-pa-sm rounded-borders bg-grey-2 text-center">
                <div class="text-caption text-grey-7">Current Lines Sum</div>
                <div class="text-subtitle2 text-weight-bold text-grey-9">
                  {{ purchaseCurrencySymbol }}{{ activeBalanceCalculatedSum.toFixed(2) }}
                </div>
              </div>
            </div>
            <div class="col-4">
              <div class="q-pa-sm rounded-borders bg-primary text-white text-center">
                <div class="text-caption" style="opacity: 0.9">Target Invoice</div>
                <div class="text-subtitle2 text-weight-bold">
                  {{ purchaseCurrencySymbol }}{{ activeBalanceTargetAmount.toFixed(2) }}
                </div>
              </div>
            </div>
            <div class="col-4">
              <div
                class="q-pa-sm rounded-borders text-center"
                :class="activeBalanceDelta > 0 ? 'bg-red-1 text-red-9' : activeBalanceDelta < 0 ? 'bg-green-1 text-green-9' : 'bg-grey-2 text-grey-8'"
              >
                <div class="text-caption text-weight-medium">Delta (Adjustment)</div>
                <div class="text-subtitle2 text-weight-bold">
                  {{ activeBalanceDelta > 0 ? `+${activeBalanceDelta.toFixed(2)}` : activeBalanceDelta.toFixed(2) }} {{ purchaseCurrencySymbol }}
                </div>
              </div>
            </div>
          </div>

          <!-- Line Items Price Adjustments Preview Table -->
          <div class="text-caption text-grey-8 text-weight-medium q-mb-xs">
            Line Items Price Adjustments ({{ activeBalancePreview.length }} items)
          </div>
          <div class="border rounded-borders overflow-hidden" style="max-height: 260px; overflow-y: auto">
            <q-markup-table dense flat separator="horizontal" class="bg-transparent">
              <thead>
                <tr class="bg-grey-2 text-grey-8 text-caption">
                  <th class="text-left">Product Item</th>
                  <th class="text-right">Qty</th>
                  <th class="text-right">Current Unit</th>
                  <th class="text-right">New Unit</th>
                  <th class="text-right">Unit Change</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in activeBalancePreview" :key="item.id">
                  <td class="text-left text-weight-medium text-grey-9 ellipsis" style="max-width: 220px">
                    {{ item.name }}
                  </td>
                  <td class="text-right text-grey-7">{{ item.qty }}</td>
                  <td class="text-right text-grey-7">{{ purchaseCurrencySymbol }}{{ item.currentPrice.toFixed(4) }}</td>
                  <td class="text-right text-weight-bold text-primary">{{ purchaseCurrencySymbol }}{{ item.newPrice.toFixed(4) }}</td>
                  <td
                    class="text-right text-weight-medium"
                    :class="item.perUnitDelta > 0 ? 'text-negative' : item.perUnitDelta < 0 ? 'text-positive' : 'text-grey-6'"
                  >
                    {{ item.perUnitDelta > 0 ? `+${item.perUnitDelta.toFixed(4)}` : item.perUnitDelta.toFixed(4) }}
                  </td>
                </tr>
              </tbody>
            </q-markup-table>
          </div>
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-px-md q-py-sm">
          <q-btn v-close-popup flat color="grey-8" label="Cancel" no-caps />
          <q-btn
            unelevated
            color="primary"
            icon="ph ph-check-circle"
            label="Confirm & Apply Balance"
            no-caps
            :loading="balancingSectionId !== null"
            @click="confirmSectionBalance"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-card>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import type {
  CostEntryDraft,
  CostEntriesSavePayload,
  GlobalShipmentCostEntry,
  ShipmentCostPayeeType,
} from '../types/shipmentCostEntry';
import type { ShipmentSection } from '../types/shipmentSection';
import { showErrorNotification, showSuccessNotification, showWarningNotification } from 'src/utils/appFeedback';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { computePackageWeightAdjustments } from '../utils/weightBalance';
import { computePurchasePriceAdjustments } from '../utils/purchaseBalance';
import { globalShipmentRepository } from '../repositories/globalShipmentRepository';

const props = defineProps<{
  entries: GlobalShipmentCostEntry[];
  loading?: boolean;
  saving?: boolean;
  canEdit: boolean;
  isFinalized: boolean;
  isLocalShipment: boolean;
  /** Initial cargo invoice weight from shipment header */
  cargoKg: number;
  purchaseCurrencySymbol: string;
  costCurrencySymbol: string;
  goodsPurchaseTotal?: number;
  goodsQuantityTotal?: number;
}>();

const emit = defineEmits<{
  save: [payload: CostEntriesSavePayload];
  'weight-distributed': [];
}>();

const shipmentStore = useGlobalShipmentStore();

const drafts = ref<CostEntryDraft[]>([]);
const localWeightKg = ref<number>(
  props.cargoKg > 0 ? Math.round(props.cargoKg * 100) / 100 : 0,
);

const showDistributeDialog = ref(false);
const applyingDistribution = ref(false);

const sections = computed(() => shipmentStore.currentShipmentSections || []);
const shipmentItems = computed(() => shipmentStore.currentShipmentItems || []);

const sectionInvoiceInputs = ref<Record<number, number>>({});
const balancingSectionId = ref<number | null>(null);

const showSectionBalanceDialog = ref(false);
const activeBalanceSection = ref<ShipmentSection | null>(null);

const openSectionBalanceModal = (sec: ShipmentSection) => {
  activeBalanceSection.value = sec;
  showSectionBalanceDialog.value = true;
};

const activeBalanceTargetAmount = computed(() => {
  if (!activeBalanceSection.value) return 0;
  const secId = activeBalanceSection.value.id;
  return Number(sectionInvoiceInputs.value[secId]) || 0;
});

const activeBalanceCalculatedSum = computed(() => {
  if (!activeBalanceSection.value) return 0;
  return getSectionCalculatedPurchase(activeBalanceSection.value.id);
});

const activeBalanceDelta = computed(() => {
  return Math.round((activeBalanceTargetAmount.value - activeBalanceCalculatedSum.value) * 100) / 100;
});

const activeBalanceItems = computed(() => {
  if (!activeBalanceSection.value) return [];
  const secId = activeBalanceSection.value.id;
  return shipmentItems.value.filter((i) => i.section_id === secId);
});

const activeBalancePreview = computed(() => {
  const items = activeBalanceItems.value;
  const target = activeBalanceTargetAmount.value;
  if (!items.length || !target || target <= 0) return [];
  try {
    const inputItems = items.map((i) => ({
      id: i.id,
      name: i.name,
      purchase_price: i.purchase_price || 0,
      ordered_quantity: i.ordered_quantity || 0,
    }));
    const adjustments = computePurchasePriceAdjustments(inputItems, target);
    return items.map((item) => {
      const adj = adjustments.find((a) => a.itemId === item.id);
      const currentPrice = item.purchase_price || 0;
      const newPrice = adj ? adj.newPurchasePrice : currentPrice;
      const perUnitDelta = adj ? adj.perUnitDelta : 0;
      return {
        id: item.id,
        name: item.name,
        qty: item.ordered_quantity || 0,
        currentPrice,
        newPrice,
        perUnitDelta,
      };
    });
  } catch {
    return [];
  }
});

const confirmSectionBalance = async () => {
  if (!activeBalanceSection.value) return;
  const secId = activeBalanceSection.value.id;
  const shipId = shipmentStore.currentShipment?.id;
  const target = activeBalanceTargetAmount.value;
  if (!shipId || target == null || target <= 0) {
    showErrorNotification('Please enter a valid invoice total amount (> 0).');
    return;
  }

  const items = activeBalanceItems.value;
  if (!items.length) {
    showErrorNotification('No line items found in this section to balance.');
    return;
  }

  try {
    balancingSectionId.value = secId;
    const inputItems = items.map((i) => ({
      id: i.id,
      name: i.name,
      purchase_price: i.purchase_price || 0,
      ordered_quantity: i.ordered_quantity || 0,
    }));
    const adjustments = computePurchasePriceAdjustments(inputItems, target);

    await globalShipmentRepository.applyPurchaseBalance(
      shipId,
      adjustments.map((adj) => ({
        item_id: adj.itemId,
        purchase_price: adj.newPurchasePrice,
      })),
    );
    await shipmentStore.fetchShipmentDetails(shipId);

    // Sync input to target
    sectionInvoiceInputs.value[secId] = Math.round(target * 100) / 100;

    const secName =
      activeBalanceSection.value?.title ||
      (activeBalanceSection.value as any)?.name ||
      `Section #${secId}`;
    showSuccessNotification(
      `Section "${secName}" prices successfully balanced to ${target.toFixed(2)} ${props.purchaseCurrencySymbol}.`,
    );
    showSectionBalanceDialog.value = false;
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to balance section.');
  } finally {
    balancingSectionId.value = null;
  }
};

const productRows = computed(() => drafts.value.filter((d) => d.cost_type === 'product'));
const cargoRows = computed(() => drafts.value.filter((d) => d.cost_type === 'cargo'));

const getSectionCalculatedPurchase = (sectionId?: number | null) => {
  const items = shipmentItems.value;
  return items
    .filter((i) => (i.section_id ?? null) === (sectionId ?? null))
    .reduce((sum, i) => sum + (i.purchase_price || 0) * (i.ordered_quantity || 0), 0);
};

const getSectionQty = (sectionId?: number | null) => {
  const items = shipmentItems.value;
  return items
    .filter((i) => (i.section_id ?? null) === (sectionId ?? null))
    .reduce((sum, i) => sum + (i.ordered_quantity || 0), 0);
};

const getSectionDeltaById = (secId: number) => {
  const calculated = getSectionCalculatedPurchase(secId);
  const entered =
    sectionInvoiceInputs.value[secId] !== undefined
      ? Number(sectionInvoiceInputs.value[secId]) || 0
      : calculated;
  return Math.round((entered - calculated) * 100) / 100;
};

// Keep sectionInvoiceInputs in sync with calculated values if unedited
watch(
  () => [sections.value, shipmentItems.value],
  () => {
    for (const sec of sections.value) {
      const calc = Math.round(getSectionCalculatedPurchase(sec.id) * 100) / 100;
      if (sectionInvoiceInputs.value[sec.id] === undefined) {
        sectionInvoiceInputs.value[sec.id] = calc;
      }
    }
  },
  { immediate: true, deep: true },
);

const estimatedLinesKg = computed(() => {
  let totalGm = 0;
  for (const item of shipmentItems.value) {
    const qty = item.ordered_quantity || 0;
    totalGm += ((item.product_weight || 0) + (item.package_weight || 0)) * qty;
  }
  return Math.round((totalGm / 1000) * 100) / 100;
});

const deltaKg = computed(() => {
  return Math.round((localWeightKg.value - estimatedLinesKg.value) * 100) / 100;
});

const distributionPreview = computed(() => {
  if (localWeightKg.value <= 0 || !shipmentItems.value.length) return [];
  try {
    const inputItems = shipmentItems.value.map((item) => ({
      id: item.id,
      name: item.name,
      product_weight: item.product_weight || 0,
      package_weight: item.package_weight || 0,
      ordered_quantity: item.ordered_quantity || 0,
    }));
    const adjustments = computePackageWeightAdjustments(inputItems, localWeightKg.value);
    return shipmentItems.value.map((item) => {
      const adj = adjustments.find((a) => a.itemId === item.id);
      const currentPkg = item.package_weight || 0;
      const newPkg = adj ? adj.newPackageWeight : currentPkg;
      const perUnitDelta = adj ? adj.perUnitDelta : 0;
      return {
        id: item.id,
        name: item.name,
        qty: item.ordered_quantity || 0,
        currentPkgWeight: currentPkg,
        newPkgWeight: newPkg,
        perUnitDelta,
      };
    });
  } catch {
    return [];
  }
});

const openWeightDistributionDialog = () => {
  if (localWeightKg.value <= 0) {
    showWarningNotification('Please enter a valid cargo weight (> 0 kg) first.');
    return;
  }
  if (!shipmentItems.value.length) {
    showWarningNotification('No shipment line items available to distribute weight across.');
    return;
  }
  showDistributeDialog.value = true;
};

const confirmDistributeWeight = async () => {
  const shipId = shipmentStore.currentShipment?.id;
  if (!shipId || localWeightKg.value <= 0) return;

  try {
    applyingDistribution.value = true;
    await shipmentStore.updateShipment(shipId, {
      received_weight: localWeightKg.value,
    });
    await shipmentStore.applyWeightBalance(shipId);
    showSuccessNotification(
      `Weight (${localWeightKg.value} kg) successfully distributed across ${shipmentItems.value.length} lines.`,
    );
    showDistributeDialog.value = false;
    emit('weight-distributed');
  } catch (err: unknown) {
    showErrorNotification((err as Error).message || 'Failed to distribute weight.');
  } finally {
    applyingDistribution.value = false;
  }
};

const newLocalKey = () => `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

const emptyRow = (costType: 'product' | 'cargo'): CostEntryDraft => {
  const ship = shipmentStore.currentShipment;
  let entity_type: ShipmentCostPayeeType | null = null;
  let entity_id: number | null = null;
  if (costType === 'product' && ship?.vendor_id) {
    entity_type = 'vendor';
    entity_id = ship.vendor_id;
  } else if (costType === 'cargo' && ship?.cargo_company_id) {
    entity_type = 'cargo_company';
    entity_id = ship.cargo_company_id;
  }
  return {
    localKey: newLocalKey(),
    id: null,
    cost_type: costType,
    amount: 0,
    exchange_rate: 1,
    payment_source: null,
    entity_type,
    entity_id,
    per_kg_rate: null,
    note: null,
    section_id: null,
  };
};

const totalCargoFreight = computed(() => {
  return cargoRows.value.reduce((sum, r) => sum + (Number(r.amount) || 0), 0);
});

const totalCargoBaseCost = computed(() => {
  return cargoRows.value.reduce(
    (sum, r) => sum + (Number(r.amount) || 0) * (Number(r.exchange_rate) || 1),
    0,
  );
});

const effectivePerKg = computed(() => {
  const w = localWeightKg.value;
  const f = totalCargoFreight.value;
  if (!Number.isFinite(w) || w <= 0 || !Number.isFinite(f) || f <= 0) return null;
  return Math.round((f / w) * 10000) / 10000;
});

const effectiveBasePerKg = computed(() => {
  const w = localWeightKg.value;
  const b = totalCargoBaseCost.value;
  if (!Number.isFinite(w) || w <= 0 || !Number.isFinite(b) || b <= 0) return null;
  return Math.round((b / w) * 10000) / 10000;
});

const entryToDraft = (entry: GlobalShipmentCostEntry): CostEntryDraft => {
  const meta = (entry.metadata as Record<string, unknown> | null) ?? {};
  const note = typeof meta.note === 'string' ? meta.note : null;
  const section_id = (entry as { section_id?: number | null }).section_id ?? null;
  return {
    localKey: `id-${entry.id}`,
    id: entry.id,
    cost_type: entry.cost_type,
    amount: Number(entry.amount) || 0,
    exchange_rate: props.isLocalShipment ? 1 : Number(entry.exchange_rate) || 1,
    payment_source: null,
    entity_type: entry.cost_type === 'product' ? 'vendor' : 'cargo_company',
    entity_id: entry.cost_type === 'product'
      ? (shipmentStore.currentShipment?.vendor_id ?? null)
      : (shipmentStore.currentShipment?.cargo_company_id ?? null),
    per_kg_rate: null,
    note,
    section_id,
  };
};

const ensureDayOneShape = (rows: CostEntryDraft[]): CostEntryDraft[] => {
  const next = [...rows];
  if (!next.some((r) => r.cost_type === 'product')) next.push(emptyRow('product'));
  if (!next.some((r) => r.cost_type === 'cargo')) next.push(emptyRow('cargo'));
  return next;
};

const resetDrafts = () => {
  localWeightKg.value = props.cargoKg > 0 ? Math.round(props.cargoKg * 100) / 100 : 0;

  if (!props.entries.length) {
    drafts.value = [emptyRow('product'), emptyRow('cargo')];
    return;
  }

  const mapped = props.entries
    .filter((e) => e.cost_type === 'product' || e.cost_type === 'cargo')
    .map(entryToDraft);

  drafts.value = ensureDayOneShape(mapped);
};

watch(
  () => props.entries,
  () => resetDrafts(),
  { immediate: true, deep: true },
);

watch(
  () => props.cargoKg,
  (newVal) => {
    localWeightKg.value = newVal > 0 ? Math.round(newVal * 100) / 100 : 0;
  },
);

watch(
  () => props.isLocalShipment,
  (local) => {
    if (!local) return;
    for (const row of drafts.value) {
      row.exchange_rate = 1;
    }
  },
);

const addRow = (costType: 'product' | 'cargo') => {
  drafts.value.push(emptyRow(costType));
};

const removeRow = (localKey: string) => {
  const row = drafts.value.find((d) => d.localKey === localKey);
  if (!row) return;
  const sameType = drafts.value.filter((d) => d.cost_type === row.cost_type);
  if (sameType.length <= 1) return;
  drafts.value = drafts.value.filter((d) => d.localKey !== localKey);
};

const onSave = () => {
  for (const row of drafts.value) {
    if (row.amount == null || row.amount < 0) {
      showErrorNotification('Amount must be ≥ 0');
      return;
    }
    if (!row.exchange_rate || row.exchange_rate <= 0) {
      showErrorNotification('Exchange rate must be > 0');
      return;
    }
  }

  if (!productRows.value.length || !cargoRows.value.length) {
    showErrorNotification('Day one requires at least one product and one cargo rate.');
    return;
  }

  const unifiedPerKg = effectivePerKg.value;
  const draftsOut = drafts.value.map((d) => {
    const isProduct = d.cost_type === 'product';
    const entType = isProduct ? 'vendor' : 'cargo_company';
    const entId = isProduct
      ? (shipmentStore.currentShipment?.vendor_id ?? null)
      : (shipmentStore.currentShipment?.cargo_company_id ?? null);
    return {
      ...d,
      exchange_rate: props.isLocalShipment ? 1 : d.exchange_rate,
      per_kg_rate: isProduct ? null : unifiedPerKg,
      section_id: d.section_id ?? null,
      payment_source: null,
      entity_type: entType as ShipmentCostPayeeType,
      entity_id: entId,
    };
  });

  const w = localWeightKg.value;
  emit('save', {
    drafts: draftsOut,
    received_weight: w > 0 ? w : null,
  });
};

defineExpose({ resetDrafts });
</script>

<style scoped>
.cost-section {
  padding: 0.75rem;
  border: 1px solid color-mix(in srgb, var(--bw-theme-border, #e0e0e0) 100%, transparent);
  border-radius: 10px;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, var(--bw-theme-base, #f5f5f5));
}

.cost-entry-row {
  border: 1px solid color-mix(in srgb, var(--bw-theme-border, #e0e0e0) 80%, transparent);
  background: var(--bw-theme-surface, #fff);
}
</style>
