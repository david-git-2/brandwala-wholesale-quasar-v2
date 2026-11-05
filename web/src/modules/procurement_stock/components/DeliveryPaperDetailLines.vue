<template>
  <q-markup-table flat bordered dense class="delivery-paper-lines">
    <thead>
      <tr>
        <th class="text-left">Product</th>
        <th class="text-right">Sell / unit</th>
        <th class="text-center">Need</th>
        <th class="text-center">Remaining</th>
        <th class="text-center tf-ops-col-tint--qty">Packed</th>
        <th
          v-for="col in visibleOutcomeColumns"
          :key="col.field"
          class="text-center"
          :class="col.tintClass"
        >
          {{ col.header }}
        </th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="item in items" :key="`${item.source_type}-${item.source_id}`">
        <td class="delivery-paper-lines__product">
          <div class="row items-center no-wrap q-gutter-x-sm">
            <SmartImage
              :src="item.image_url"
              :alt="item.name"
              img-class="delivery-paper-lines__thumb"
              fallback-class="delivery-paper-lines__thumb-fallback"
              :enable-edit="false"
            />
            <div class="min-width-0">
              <div class="text-body2 text-weight-medium ellipsis">{{ item.name }}</div>
              <div v-if="item.product_code" class="text-caption font-mono text-grey-7 ellipsis">
                {{ item.product_code }}
              </div>
            </div>
          </div>
        </td>
        <td class="text-right font-mono delivery-paper-lines__sell-cell">
          <div>{{ formatUnitSellPrice(item) }}</div>
          <div class="text-caption text-grey-7">{{ sellPriceHint(item) }}</div>
        </td>
        <td class="text-center font-mono">{{ needQty(item) }}</td>
        <td class="text-center font-mono">{{ remainingQty(item) }}</td>
        <td class="text-center tf-ops-col-tint--qty delivery-paper-lines__packed-cell q-pa-xs">
          <q-btn
            unelevated
            no-caps
            dense
            class="delivery-paper-lines__packed-btn"
            :class="
              canPickStock && isPickComplete(item)
                ? 'delivery-paper-lines__packed-btn--complete'
                : 'delivery-paper-lines__packed-btn--pending'
            "
            :color="canPickStock ? (isPickComplete(item) ? 'positive' : 'primary') : 'grey-7'"
            :outline="!canPickStock"
            :disable="!canPickStock"
            icon="ph ph-package"
            :label="packedCellLabel(item)"
            @click.stop="onPackedClick(item)"
          />
          <div
            v-if="paperStockLots(item).length"
            class="delivery-paper-pick-list text-caption text-grey-7 text-left q-mt-xs"
          >
            <div
              v-for="pick in paperStockLots(item)"
              :key="pick.globalStockId"
              class="ellipsis"
            >
              {{ pick.shipmentName || pick.globalStockId }} · {{ pick.quantity }}
            </div>
          </div>
        </td>
        <td
          v-for="col in visibleOutcomeColumns"
          :key="col.field"
          class="text-center q-pa-xs"
          :class="col.tintClass"
        >
          <q-input
            v-if="canEditOutcomeQty"
            :model-value="getDraft(item)[col.field]"
            type="number"
            min="0"
            dense
            outlined
            hide-bottom-space
            input-class="font-mono text-center"
            class="delivery-paper-status-qty"
            :aria-label="col.label"
            @update:model-value="(v) => emit('status-qty', item, col.field, v)"
          />
          <span v-else class="font-mono">{{ getDraft(item)[col.field] }}</span>
        </td>
      </tr>
    </tbody>
  </q-markup-table>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import SmartImage from 'src/components/SmartImage.vue';
import type {
  DeliveryPaperDetailItem,
  DeliveryPaperStatus,
} from '../repositories/procurementDemandRepository';
import type { DeliveryPaperLineDraft } from '../composables/useDeliveryPaperDetail';
import type { DeliveryPaperStatusQty } from '../utils/deliveryPaperStatusQty';
import {
  deliveryPaperLinePackedDisplayQty,
  deliveryPaperStockLotsFromItem,
} from '../utils/deliveryPaperStatusQty';
import { deliveryPaperVisibleOutcomeFields } from '../utils/deliveryPaperEditRules';
import { getItemNeedQuantity } from '../repositories/procurementDemandRepository';
import {
  getDeliveryPaperLinePickCap,
  getDeliveryPaperLineRemainingToPack,
} from '../utils/deliveryPaperRemainingQty';
import {
  deliveryPaperSellPriceHint,
  formatDeliveryPaperUnitSellPrice,
} from '../utils/deliveryPaperUnitSellPrice';

const props = defineProps<{
  items: DeliveryPaperDetailItem[];
  lineDrafts: Record<string, DeliveryPaperLineDraft>;
  canPickStock: boolean;
  canEditOutcomeQty: boolean;
  paperStatus: DeliveryPaperStatus | null;
  itemDraftKey: (item: DeliveryPaperDetailItem) => string;
}>();

const emit = defineEmits<{
  (e: 'status-qty', item: DeliveryPaperDetailItem, field: keyof DeliveryPaperStatusQty, value: string | number | null): void;
  (e: 'pick-stock', item: DeliveryPaperDetailItem): void;
}>();

const OUTCOME_COLUMN_DEFS: Array<{
  field: keyof DeliveryPaperStatusQty;
  header: string;
  label: string;
  tintClass: string;
}> = [
  { field: 'accepted', header: 'Accepted', label: 'Accepted quantity', tintClass: 'tf-ops-col-tint--accept' },
  {
    field: 'conditioned',
    header: 'Condition',
    label: 'Condition quantity',
    tintClass: 'tf-ops-col-tint--condition',
  },
  { field: 'rejected', header: 'Rejected', label: 'Rejected quantity', tintClass: 'tf-ops-col-tint--reject' },
];

const visibleOutcomeColumns = computed(() => {
  const visible = new Set(deliveryPaperVisibleOutcomeFields(props.paperStatus));
  return OUTCOME_COLUMN_DEFS.filter((col) => visible.has(col.field as 'accepted' | 'conditioned' | 'rejected'));
});

const needQty = (item: DeliveryPaperDetailItem) => getItemNeedQuantity(item);
const remainingQty = (item: DeliveryPaperDetailItem) =>
  getDeliveryPaperLineRemainingToPack(item, packedQty(item));
const formatUnitSellPrice = formatDeliveryPaperUnitSellPrice;
const sellPriceHint = deliveryPaperSellPriceHint;

const packedQty = (item: DeliveryPaperDetailItem) =>
  deliveryPaperLinePackedDisplayQty(item, getDraft(item));

const paperStockLots = (item: DeliveryPaperDetailItem) => deliveryPaperStockLotsFromItem(item);

const pickCap = (item: DeliveryPaperDetailItem): number => getDeliveryPaperLinePickCap(item);

const isPickComplete = (item: DeliveryPaperDetailItem): boolean => {
  const cap = pickCap(item);
  const picked = Math.max(0, Math.trunc(packedQty(item)));
  return cap > 0 && picked >= cap;
};

const pickStockButtonLabel = (item: DeliveryPaperDetailItem): string => {
  const cap = pickCap(item);
  const picked = Math.max(0, Math.trunc(packedQty(item)));
  if (picked <= 0) return 'Pick stock';
  if (isPickComplete(item)) return `Picked ${picked}`;
  if (cap > 0) return `Pick stock · ${picked}/${cap}`;
  return `Edit picks · ${picked}`;
};

const packedCellLabel = (item: DeliveryPaperDetailItem): string => {
  if (!props.canPickStock) {
    const n = packedQty(item);
    return n > 0 ? `Packed ${n}` : '—';
  }
  return pickStockButtonLabel(item);
};

const onPackedClick = (item: DeliveryPaperDetailItem) => {
  if (!props.canPickStock) return;
  emit('pick-stock', item);
};

const getDraft = (item: DeliveryPaperDetailItem): DeliveryPaperLineDraft =>
  props.lineDrafts[props.itemDraftKey(item)] ?? {
    packed: 0,
    accepted: 0,
    conditioned: 0,
    rejected: 0,
    stockPicks: [],
  };
</script>

<style scoped>
.delivery-paper-lines__thumb,
.delivery-paper-lines__thumb-fallback {
  width: 40px;
  height: 40px;
  border-radius: var(--tf-radius-sm);
}

.delivery-paper-status-qty {
  width: 72px;
}

.delivery-paper-lines__packed-cell {
  vertical-align: middle;
}

.delivery-paper-lines__packed-btn {
  width: 100%;
  min-width: 96px;
  max-width: 140px;
  font-size: 11px;
  font-weight: 600;
}

.delivery-paper-lines__packed-btn--pending {
  font-weight: 650;
}

.delivery-paper-pick-list {
  max-width: 140px;
  margin-left: auto;
  margin-right: auto;
}
</style>
