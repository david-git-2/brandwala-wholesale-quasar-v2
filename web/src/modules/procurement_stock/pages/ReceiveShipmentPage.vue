<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <div class="receive-toolbar row items-center justify-between no-wrap q-px-xs shrink-0">
        <div class="row items-center q-gutter-sm col" style="min-width: 0">
          <q-btn
            icon="ph ph-arrow-left"
            flat
            round
            dense
            color="grey-8"
            aria-label="Back to shipment"
            @click="goBack"
          >
            <q-tooltip>Back to shipment</q-tooltip>
          </q-btn>
          <div class="ellipsis" style="min-width: 0">
            <div class="text-subtitle2 text-weight-bold ellipsis" style="color: var(--tf-neutral-ink)">
              Post to warehouse
            </div>
            <div class="text-caption ellipsis" style="color: var(--tf-neutral-muted)">
              {{ shipmentName }}
            </div>
          </div>
        </div>

        <div class="row items-center q-gutter-sm no-wrap shrink-0">
          <TfBtn variant="tertiary" label="Cancel" @click="goBack" />
          <TfBtn
            variant="primary"
            icon="ph ph-check-circle"
            label="Post to stock"
            :loading="submitting"
            :disable="!isValid || submitting || loading"
            @click="onConfirmReceive"
          />
        </div>
      </div>

      <div
        v-if="!loading && !error && (extras.length || vendorCreditRows.length)"
        class="receive-summary row items-center q-gutter-sm q-px-xs shrink-0 wrap"
      >
        <div class="receive-hint row items-center no-wrap q-gutter-x-xs">
          <q-icon name="ph ph-info" size="16px" aria-hidden="true" />
          <span>
            Sets shipment to <strong>Received</strong> and puts units in the default put-away bin.
          </span>
        </div>
        <q-space class="gt-xs" />
        <div class="row items-center q-gutter-sm no-wrap">
          <span class="receive-stat">
            <span class="receive-stat__label">Lines</span>
            <span class="receive-stat__value">{{ extras.length }}</span>
          </span>
          <span class="receive-stat">
            <span class="receive-stat__label">Units</span>
            <span class="receive-stat__value tf-num">{{ totalExtraQty }}</span>
          </span>
          <span v-if="vendorCreditRows.length" class="receive-stat">
            <span class="receive-stat__label">Credits</span>
            <span class="receive-stat__value">{{ vendorCreditRows.length }}</span>
          </span>
        </div>
      </div>

      <q-banner
        v-if="error"
        class="tf-status-banner bg-negative text-white flex-shrink-0"
        dense
        rounded
      >
        <template #avatar>
          <q-icon name="ph ph-warning-circle" />
        </template>
        <span class="receive-error-text">{{ error }}</span>
      </q-banner>

      <div
        v-if="loading"
        class="col row justify-center items-center receive-panel"
      >
        <q-spinner color="primary" size="2.5em" />
        <span class="q-ml-sm text-caption" style="color: var(--tf-neutral-muted)">
          Loading receive lines…
        </span>
      </div>

      <div
        v-else
        class="col overflow-auto receive-panel hide-native-scrollbar"
      >
        <TfEmptyState
          v-if="extras.length === 0 && vendorCreditRows.length === 0 && !error"
          icon="ph ph-package"
          title="Nothing to post yet"
          message="Add sellable land splits on the shipment line sheet, then set status to Received."
        >
          <TfBtn variant="secondary" label="Back to shipment" @click="goBack" />
        </TfEmptyState>

        <q-markup-table
          v-else-if="extras.length || vendorCreditRows.length"
          flat
          bordered
          dense
          class="receive-post-table full-width"
        >
          <thead>
            <tr>
              <th class="receive-post-table__sl">#</th>
              <th class="receive-post-table__img">Image</th>
              <th class="receive-post-table__name">Product</th>
              <th class="receive-post-table__code">Code</th>
              <th class="receive-post-table__qty text-right">Qty</th>
              <th class="receive-post-table__impact">Impact</th>
              <th class="receive-post-table__reason">Land reason</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(row, index) in extras"
              :key="`extra-${row.id}`"
            >
              <td class="receive-post-table__sl text-center tf-num text-weight-medium">
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
              <td class="receive-post-table__code font-mono">
                <span v-if="row.product_code">{{ row.product_code }}</span>
                <span v-else class="text-grey-6">—</span>
              </td>
              <td class="receive-post-table__qty text-right tf-num text-weight-bold">
                {{ row.quantity }}
              </td>
              <td class="receive-post-table__impact">
                <TfStatusBadge status="received" label="Goes to stock" />
              </td>
              <td class="receive-post-table__reason text-caption">
                {{ formatOutcomeReason(row.reason) }}
              </td>
            </tr>

            <tr
              v-for="(row, index) in vendorCreditRows"
              :key="`vc-${row.id}`"
              class="receive-post-table__row--vendor-credit"
            >
              <td class="receive-post-table__sl text-center tf-num text-weight-medium">
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
              <td class="receive-post-table__code font-mono">
                <span v-if="row.product_code">{{ row.product_code }}</span>
                <span v-else class="text-grey-6">—</span>
              </td>
              <td class="receive-post-table__qty text-right tf-num text-weight-bold">
                {{ row.quantity }}
              </td>
              <td class="receive-post-table__impact">
                <TfStatusBadge status="attention" label="Vendor credit" />
              </td>
              <td class="receive-post-table__reason text-caption">
                {{ purchaseCurrencySymbol }}{{ formatMoney(row.previous_purchase_price) }}
                → {{ formatMoney(row.new_purchase_price) }}
                <span class="text-weight-medium" style="color: var(--tf-success)">
                  (−{{ purchaseCurrencySymbol }}{{ formatMoney(row.credit_amount) }})
                </span>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import SmartImage from 'src/components/SmartImage.vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import {
  globalShipmentRepository,
  type ShipmentItemOutcome,
  type ShipmentOutcomeVendorCredit,
} from '../repositories/globalShipmentRepository';
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { showSuccessNotification, showErrorNotification, requestConfirmation } from 'src/utils/appFeedback';
import { formatOutcomeReason } from '../constants/shipmentOutcomeLabels';
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
.receive-panel {
  background: var(--tf-neutral-surface);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
}

.receive-toolbar {
  border-bottom: 1px solid var(--tf-neutral-border);
  padding-bottom: 6px;
}

.receive-hint {
  flex: 1 1 280px;
  min-width: 0;
  padding: 6px 10px;
  font-size: 12px;
  line-height: 1.4;
  color: var(--tf-neutral-muted);
  background: var(--tf-info-soft);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
}

.receive-hint .q-icon {
  color: var(--tf-info);
  flex-shrink: 0;
}

.receive-stat {
  display: inline-flex;
  align-items: baseline;
  gap: 6px;
  padding: 4px 10px;
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
  background: var(--tf-neutral-surface);
}

.receive-stat__label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text);
}

.receive-stat__value {
  font-size: 14px;
  font-weight: 700;
  color: var(--tf-neutral-ink);
}

.receive-error-text {
  white-space: pre-line;
}

.font-mono {
  font-family: var(--tf-font-mono, monospace);
  font-size: 12px;
}

.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
}

.receive-post-table {
  min-width: 720px;
  table-layout: fixed;
}

.receive-post-table thead tr th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: var(--tf-neutral-surface);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text);
  padding: 8px !important;
  border-bottom: 1px solid var(--tf-neutral-border);
  vertical-align: bottom;
}

.receive-post-table tbody td {
  padding: 8px !important;
  vertical-align: middle;
  border-bottom: 1px solid var(--tf-neutral-border);
}

.receive-post-table__sl {
  width: 40px;
}

.receive-post-table__img {
  width: 72px;
}

.receive-post-table__name {
  min-width: 160px;
}

.receive-post-table__code {
  width: 112px;
}

.receive-post-table__qty {
  width: 72px;
}

.receive-post-table__impact {
  width: 140px;
}

.receive-post-table__reason {
  width: min(220px, 28vw);
}

.receive-post-table__row--vendor-credit {
  background: color-mix(in srgb, var(--tf-success) 8%, var(--tf-neutral-surface));
}

.receive-post-table__thumb {
  width: 56px;
  height: 56px;
  border-radius: var(--tf-radius-sm);
  overflow: hidden;
  border: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-canvas);
}

.receive-post-table__thumb :deep(.receive-post-table__thumb-img),
.receive-post-table__thumb :deep(img) {
  width: 100% !important;
  height: 100% !important;
  object-fit: contain !important;
}

.receive-post-table__product-name {
  font-size: 13px;
  font-weight: 600;
  line-height: 1.35;
  color: var(--tf-neutral-ink);
  word-break: break-word;
}
</style>
