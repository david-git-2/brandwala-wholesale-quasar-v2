<template>
  <q-page class="receive-shipment-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Header -->
    <div class="receive-top-section bg-white border-bottom q-px-lg q-py-md shrink-0 shadow-xs">
      <div class="row items-center justify-between wrap q-gutter-y-sm">
        <div class="row items-center q-gutter-sm col-grow" style="min-width: 0">
          <q-btn
            icon="ph ph-arrow-left"
            flat
            round
            dense
            color="grey-8"
            @click="goBack"
          >
            <q-tooltip>Back to shipment</q-tooltip>
          </q-btn>
          <div class="ellipsis">
            <div class="text-subtitle1 text-weight-bolder text-grey-9 ellipsis">
              Receive &amp; post to stock
            </div>
            <div class="text-caption text-grey-7 ellipsis">
              {{ shipmentName }}
              <span v-if="extras.length">
                · {{ totalExtraQty }} unit<span v-if="totalExtraQty !== 1">s</span> on
                {{ extras.length }} sellable split<span v-if="extras.length !== 1">s</span>
              </span>
            </div>
          </div>
        </div>

        <div class="row items-center q-gutter-md no-wrap">
          <q-banner
            v-if="extras.length"
            dense
            rounded
            class="bg-blue-1 text-blue-10 q-py-xs q-px-sm"
            style="max-width: 420px"
          >
            Posting marks the shipment <strong>Received</strong> and puts units in the default bin.
          </q-banner>
          <div class="row items-center q-gutter-md text-caption text-grey-7">
            <span>
              Extra qty:
              <span class="text-weight-bold text-primary">{{ totalExtraQty }}</span>
            </span>
          </div>
          <q-btn
            flat
            label="Cancel"
            color="grey-8"
            no-caps
            dense
            class="rounded-sq-btn"
            style="border-radius: 8px"
            @click="goBack"
          />
          <q-btn
            color="primary"
            unelevated
            icon="ph ph-check-circle"
            label="Post to Stock"
            no-caps
            dense
            class="rounded-sq-btn text-weight-bold"
            style="border-radius: 8px"
            :loading="submitting"
            :disable="!isValid || submitting"
            @click="onConfirmReceive"
          />
        </div>
      </div>

      <q-banner v-if="error" class="bg-negative text-white rounded-borders q-mt-sm q-py-xs">
        <template #avatar>
          <q-icon name="ph ph-warning-circle" size="20px" />
        </template>
        {{ error }}
      </q-banner>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="col row justify-center items-center bg-white">
      <q-spinner color="primary" size="3em" />
      <div class="text-grey-7 q-ml-md">Loading shipment lines...</div>
    </div>

    <!-- Table -->
    <div
      v-else
      class="receive-table-section col overflow-auto q-pa-none bg-white hide-native-scrollbar"
      style="overflow-x: auto; overflow-y: auto"
    >
      <q-markup-table flat class="receive-post-table shipment-items-markup-table bg-white">
        <thead>
          <tr>
            <th class="receive-post-table__sl">#</th>
            <th class="receive-post-table__img">Image</th>
            <th class="receive-post-table__name">Product</th>
            <th class="receive-post-table__code">Code</th>
            <th class="receive-post-table__qty text-right">Qty</th>
            <th class="receive-post-table__impact">Stock impact</th>
            <th class="receive-post-table__reason">Land reason</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(row, index) in extras"
            :key="`extra-${row.id}`"
            class="receive-post-table__row"
          >
            <td class="receive-post-table__sl text-center font-mono text-weight-bold text-grey-7">
              {{ index + 1 }}
            </td>

            <td class="receive-post-table__img">
              <div class="receive-post-table__thumb">
                <SmartImage
                  :src="row.image_url"
                  :alt="row.item_name"
                  img-class="receive-post-table__thumb-img"
                  fallback-icon="ph ph-t-shirt"
                />
              </div>
            </td>

            <td class="receive-post-table__name">
              <div class="receive-post-table__product-name">{{ row.item_name }}</div>
            </td>

            <td class="receive-post-table__code font-mono text-caption">
              <span v-if="row.product_code" class="text-grey-9">{{ row.product_code }}</span>
              <span v-else class="text-grey-5">—</span>
            </td>

            <td class="receive-post-table__qty text-right font-mono text-weight-bold">
              {{ row.quantity }}
            </td>
            <td class="receive-post-table__impact text-center text-caption">
              {{ formatOutcomeKind(row.kind) }}
            </td>
            <td class="receive-post-table__reason text-center text-caption">
              {{ formatOutcomeReason(row.reason) }}
            </td>
          </tr>

          <tr
            v-for="(row, index) in vendorCreditRows"
            :key="`vc-${row.id}`"
            class="receive-post-table__row receive-post-table__row--vendor-credit"
          >
            <td class="receive-post-table__sl text-center font-mono text-weight-bold text-grey-7">
              {{ extras.length + index + 1 }}
            </td>

            <td class="receive-post-table__img">
              <div class="receive-post-table__thumb">
                <SmartImage
                  :src="row.image_url"
                  :alt="row.item_name"
                  img-class="receive-post-table__thumb-img"
                  fallback-icon="ph ph-t-shirt"
                />
              </div>
            </td>

            <td class="receive-post-table__name">
              <div class="receive-post-table__product-name">{{ row.item_name }}</div>
            </td>

            <td class="receive-post-table__code font-mono text-caption">
              <span v-if="row.product_code" class="text-grey-9">{{ row.product_code }}</span>
              <span v-else class="text-grey-5">—</span>
            </td>

            <td class="receive-post-table__qty text-right font-mono text-weight-bold">
              {{ row.quantity }}
            </td>
            <td class="receive-post-table__impact text-center text-caption text-teal-9">
              Vendor credit
            </td>
            <td class="receive-post-table__reason text-center text-caption">
              {{ purchaseCurrencySymbol }}{{ formatMoney(row.previous_purchase_price) }}
              → {{ formatMoney(row.new_purchase_price) }}
              <span class="text-teal-9 text-weight-medium">
                (−{{ purchaseCurrencySymbol }}{{ formatMoney(row.credit_amount) }})
              </span>
            </td>
          </tr>

          <tr v-if="extras.length === 0 && vendorCreditRows.length === 0">
            <td colspan="7" class="text-center text-grey-6 q-py-xl">
              Add receive extras on the shipment line page first (not ordered paper rows).
            </td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import SmartImage from 'src/components/SmartImage.vue';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import {
  globalShipmentRepository,
  type ShipmentItemOutcome,
  type ShipmentOutcomeVendorCredit,
} from '../repositories/globalShipmentRepository';
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { showSuccessNotification, showErrorNotification, requestConfirmation } from 'src/utils/appFeedback';
import { formatOutcomeKind, formatOutcomeReason } from '../constants/shipmentOutcomeLabels';
import {
  findLandSplitQtyMismatches,
  formatLandSplitQtyGuardMessage,
} from '../utils/landSplitQtyGuard';

interface PutawayExtraRow extends ShipmentItemOutcome {
  item_name: string;
  product_code: string | null;
  image_url: string | null;
}

interface VendorCreditDisplayRow extends ShipmentOutcomeVendorCredit {
  product_code: string | null;
  image_url: string | null;
}

const route = useRoute();
const router = useRouter();
const shipmentStore = useGlobalShipmentStore();
const { currentPurchaseCurrencySymbol: purchaseCurrencySymbol } = useInboundShipmentCalculations();

const shipmentId = computed(() => Number(route.params.id));
const loading = ref(false);
const submitting = ref(false);
const error = ref<string | null>(null);

const extras = ref<PutawayExtraRow[]>([]);
const vendorCreditRows = ref<VendorCreditDisplayRow[]>([]);

const formatMoney = (value: number) => Number(value).toFixed(2);

const shipmentName = computed(() => shipmentStore.currentShipment?.name || `#${shipmentId.value}`);

const totalExtraQty = computed(() =>
  extras.value.reduce((sum, row) => sum + (Number(row.quantity) || 0), 0),
);

const isValid = computed(() => extras.value.some((row) => row.kind === 'sellable' && row.quantity > 0));

onMounted(async () => {
  if (!shipmentId.value || isNaN(shipmentId.value)) {
    error.value = 'Invalid shipment ID';
    return;
  }

  loading.value = true;
  error.value = null;
  try {
    await shipmentStore.fetchShipmentDetails(shipmentId.value);
    const shipment = shipmentStore.currentShipment;

    if (!shipment) {
      error.value = 'Shipment not found.';
      return;
    }

    if (shipment.status === 'cancelled') {
      error.value = 'Cancelled shipments cannot post stock.';
      showErrorNotification(error.value);
      goBack();
      return;
    }

    const loadedItems = shipmentStore.currentShipmentItems || [];

    if (loadedItems.length === 0) {
      error.value = 'Shipment has no line items.';
      return;
    }

    const outcomes = await globalShipmentRepository.listShipmentItemOutcomes(
      loadedItems.map((item) => item.id),
    );
    const qtyIssues = findLandSplitQtyMismatches(loadedItems, outcomes);
    if (qtyIssues.length > 0) {
      error.value = formatLandSplitQtyGuardMessage(qtyIssues);
      extras.value = [];
      vendorCreditRows.value = [];
      return;
    }
    const itemById = new Map(loadedItems.map((item) => [item.id, item]));
    extras.value = outcomes
      .filter((row) => row.reason !== 'ordered' && row.kind === 'sellable' && row.quantity > 0)
      .map((row) => {
        const line = itemById.get(row.shipment_item_id);
        return {
          ...row,
          item_name: line?.name ?? 'Line',
          product_code: line?.product_code ?? null,
          image_url: line?.image_url ?? null,
        };
      });

    const credits = await globalShipmentRepository.listShipmentOutcomeVendorCredits(
      shipmentId.value,
    );
    vendorCreditRows.value = credits.map((row) => {
      const line = itemById.get(row.shipment_item_id);
      return {
        ...row,
        product_code: line?.product_code ?? null,
        image_url: line?.image_url ?? null,
      };
    });
  } catch (err: unknown) {
    error.value = err instanceof Error ? err.message : 'Failed to load shipment details';
  } finally {
    loading.value = false;
  }
});

const goBack = () => {
  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { tenantSlug, id: shipmentId.value },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { id: shipmentId.value },
    });
  }
};

const onConfirmReceive = async () => {
  if (!isValid.value || submitting.value) return;

  const confirmed = await requestConfirmation(
    `Post unposted sellable extras to the default put-away bin for ${shipmentName.value}? (${totalExtraQty.value} pcs on ${extras.value.length} row(s))`,
    'Post to stock',
    'Post',
  );

  if (!confirmed) return;

  submitting.value = true;
  error.value = null;

  try {
    const stockRows = extras.value.map((row) => ({
      outcome_id: row.id,
      location_id: null,
    }));

    const result = await shipmentStore.postOutcomeStock(shipmentId.value, stockRows);

    if (result.stock_rows_posted === 0) {
      showErrorNotification('Nothing new to post. Extras may already be on the shelf.');
      return;
    }

    showSuccessNotification(
      `Posted ${result.stock_rows_posted} lot row(s). Shipment is Received. Stamped ${result.items_stamped} line cost(s).`,
    );

    goBack();
  } catch (err: unknown) {
    error.value = err instanceof Error ? err.message : 'Failed to confirm receive stock';
  } finally {
    submitting.value = false;
  }
};
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
.border-grey {
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}
.shrink-0 {
  flex-shrink: 0;
}
.avatar-soft-sq {
  border-radius: 6px;
}
.text-xxs {
  font-size: 11px;
}
.font-mono {
  font-family: monospace;
}
.rounded-sq-btn {
  border-radius: 8px;
}
.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}
.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
}

.receive-post-table {
  width: 100%;
  min-width: 880px;
  table-layout: fixed;
}

.receive-post-table thead tr th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: #fff;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  color: var(--bw-neutral-chrome, #64748b);
  padding: 8px 6px !important;
  border-bottom: 1px solid var(--bw-theme-border, #e2e8f0);
  vertical-align: bottom;
}

.receive-post-table tbody td {
  padding: 6px !important;
  vertical-align: top;
  border-bottom: 1px solid var(--bw-theme-border, #e2e8f0);
}

.receive-post-table__sl {
  width: 36px;
}
.receive-post-table__img {
  width: 1in;
}
.receive-post-table__name {
  width: auto;
  min-width: 200px;
}
.receive-post-table__code {
  width: 110px;
}
.receive-post-table__qty {
  width: 72px;
}
.receive-post-table__impact {
  width: 120px;
}
.receive-post-table__row--vendor-credit {
  background: rgba(13, 148, 136, 0.06);
}

.receive-post-table__reason {
  width: 120px;
}

.receive-post-table__thumb {
  width: 1in;
  height: 1in;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid var(--bw-theme-border, #e2e8f0);
  background: var(--bw-neutral-surface-subtle, #f1f5f9);
}

.receive-post-table__thumb :deep(.receive-post-table__thumb-img),
.receive-post-table__thumb :deep(img) {
  width: 100% !important;
  height: 100% !important;
  object-fit: contain !important;
}

.receive-post-table__product-name {
  font-size: 13px;
  font-weight: 650;
  line-height: 1.35;
  color: var(--bw-theme-ink, #171412);
  word-break: break-word;
}

.shipment-items-markup-table th,
.shipment-items-markup-table td {
  padding: 4px 4px !important;
}

.shipment-items-markup-table th.bw-ops-col-tint--qty,
.shipment-items-markup-table td.bw-ops-col-tint--qty {
  background-color: #d0e6ff !important;
  box-shadow: inset 2px 0 0 #2563eb;
}

.shipment-items-markup-table th.bw-ops-col-tint--received,
.shipment-items-markup-table td.bw-ops-col-tint--received {
  background-color: #daf3e4 !important;
  box-shadow: inset 2px 0 0 #059669;
}

.shipment-items-markup-table tr.row-variance td {
  background-color: #fff7ed !important;
}

.shipment-items-markup-table tr:hover td {
  filter: brightness(0.98);
}

:deep(.inline-edit-input input[type='number']::-webkit-outer-spin-button),
:deep(.inline-edit-input input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

:deep(.inline-edit-input input[type='number']) {
  -moz-appearance: textfield;
  appearance: textfield;
}

:deep(.inline-edit-input .q-field__control) {
  height: 28px !important;
  min-height: 28px !important;
  padding: 0 4px !important;
}

:deep(.excel-cell-input .q-field__control) {
  border-radius: 0 !important;
  border: none !important;
  background-color: transparent !important;
  transition: all 0.1s ease-in-out;
}

:deep(.excel-cell-input .q-field__control:before),
:deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

:deep(.excel-cell-input:hover .q-field__control) {
  background-color: rgba(255, 255, 255, 0.4) !important;
}

:deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: #ffffff !important;
  border: 1.5px solid #059669 !important;
  box-shadow: 0 0 0 1px #059669 !important;
}
</style>
