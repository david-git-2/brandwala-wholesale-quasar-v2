<template>
  <div
    class="profile-pay-row"
    :class="{ 'profile-pay-row--reverted': reverted }"
  >
    <div class="row items-center no-wrap q-gutter-sm">
      <div class="col min-width-0">
        <div class="row items-center q-gutter-xs">
          <div class="text-body2 text-weight-medium ellipsis text-grey-9 col">
            {{ fromToLine }}
          </div>
          <TfStatusBadge v-if="reverted" status="cancelled" label="Reverted" />
        </div>
        <div class="text-caption text-grey-7 q-mt-xs ellipsis-2-lines">
          {{ metaLine }}
        </div>
      </div>
      <div class="col-auto row items-center no-wrap q-gutter-xs shrink-0">
        <div
          class="row items-baseline no-wrap q-gutter-xs profile-pay-row__amount-line"
          :class="inflow ? 'text-positive' : 'text-negative'"
        >
          <span class="profile-pay-row__amount-sign text-h6 text-weight-bold">{{ amountParts.sign }}</span>
          <span class="profile-pay-row__currency text-h6 text-weight-bold">{{ amountParts.symbol }}</span>
          <span class="profile-pay-row__amount text-h6 text-weight-bold">{{ amountParts.amount }}</span>
        </div>
        <TfBtn
          v-if="canRevert"
          variant="danger-trigger"
          size="sm"
          dense
          label="Revert"
          :loading="revertLoading"
          @click="$emit('revert', row)"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import TfStatusBadge from 'src/components/ui/TfStatusBadge.vue';
import type { PayListRow } from '../repositories/paysRepository';
import {
  type PayAmountDisplayMode,
  payFromToLine,
  payIsInflowForProfile,
  paySignedAmountParts,
  payTransactionMetaLine,
} from '../utils/payListDisplay';

const props = withDefaults(
  defineProps<{
    row: PayListRow;
    viewedProfileId: number | null;
    viewedProfileDisplayName: string;
    amountMode?: PayAmountDisplayMode;
    currencySymbols?: Map<string, string>;
    canRevert?: boolean;
    revertLoading?: boolean;
  }>(),
  {
    amountMode: 'original',
    currencySymbols: undefined,
  },
);

defineEmits<{ revert: [row: PayListRow] }>();

const fromToLine = computed(() =>
  payFromToLine(props.row, props.viewedProfileId, props.viewedProfileDisplayName),
);

const amountParts = computed(() =>
  paySignedAmountParts(
    props.row,
    props.viewedProfileId,
    props.amountMode,
    props.currencySymbols,
  ),
);

const inflow = computed(() => payIsInflowForProfile(props.row, props.viewedProfileId));

const metaLine = computed(() =>
  payTransactionMetaLine(props.row, props.amountMode, props.currencySymbols),
);

const reverted = computed(() => !!props.row.reverted_at);
</script>

<style scoped lang="scss">
@import 'src/modules/sales_invoice/styles/invoice-list.scss';

.profile-pay-row {
  padding: 10px 12px;
  border-bottom: 1px solid var(--tf-neutral-border, #e7e1d8);
}

.profile-pay-row--reverted {
  opacity: 0.85;
}

.profile-pay-row__amount-line {
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.profile-pay-row__amount,
.profile-pay-row__currency,
.profile-pay-row__amount-sign {
  font-variant-numeric: tabular-nums;
}

.min-width-0 {
  min-width: 0;
}

.ellipsis-2-lines {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
