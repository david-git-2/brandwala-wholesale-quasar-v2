<template>
  <q-card
    flat
    bordered
    class="bill-list-card cursor-pointer"
    :class="{ 'bill-list-card--compact': compact }"
    @click="$emit('open', row)"
  >
    <q-card-section class="row items-start q-pa-md bill-list-card__section">
      <div class="col min-width-0 overflow-hidden">
        <div class="row items-center q-mb-xs bill-list-card__title-row">
          <span class="text-weight-bold text-slate-900 bill-list-card__invoice-no">{{
            row.invoice_no
          }}</span>
          <span
            class="bill-list-card__chip q-ml-sm"
            :class="`bill-list-card__chip--${chipSlug}`"
          >
            {{ chipLabel }}
          </span>
        </div>
        <div class="text-caption text-slate-600 bill-list-card__parties">
          {{ partyLine }}
        </div>
      </div>
      <div class="col-auto text-right q-pl-sm bill-list-card__amount">
        <div class="text-weight-bold text-slate-900">
          {{ formatMoney(row.total_amount) }}
          <span class="text-caption text-weight-medium text-slate-500">{{ currencyCode }}</span>
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { BillListRow } from '../types/billList';

const props = withDefaults(
  defineProps<{ row: BillListRow; compact?: boolean }>(),
  { compact: false },
);

defineEmits<{ open: [row: BillListRow] }>();

const currencyCode = computed(() => (props.row.currency_code ?? 'BDT').toUpperCase());

const chipSlug = computed(() => props.row.list_status ?? 'due');

const chipLabel = computed(() => {
  const s = chipSlug.value;
  if (s === 'draft') return 'Draft';
  if (s === 'due') return 'Due';
  if (s === 'partial') return 'Partial';
  if (s === 'paid') return 'Paid';
  if (s === 'voided') return 'Voided';
  return s;
});

const partyLine = computed(() => {
  const from = props.row.from_profile_name?.trim() || '—';
  const to = props.row.to_profile_name?.trim() || props.row.profile_name?.trim() || '—';
  return `${from} → ${to}`;
});

const formatMoney = (amount: number) => {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '0.00';
  return n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};
</script>

<style scoped lang="scss">
.bill-list-card {
  border-radius: 8px;
  transition: box-shadow 0.15s ease;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
  width: 100%;
  box-sizing: border-box;

  &:hover {
    box-shadow: 0 2px 8px rgb(15 23 42 / 8%);
  }
}

.bill-list-card--compact {
  max-width: 100%;
}

.bill-list-card__section {
  min-width: 0;
  max-width: 100%;
}

.bill-list-card__title-row {
  flex-wrap: wrap;
  gap: 4px;
  min-width: 0;
}

.bill-list-card__invoice-no {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
}

.bill-list-card__parties {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
}

.bill-list-card__amount {
  flex-shrink: 0;
  max-width: 45%;
}

.bill-list-card__chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 52px;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.02em;
  line-height: 1.2;
  flex-shrink: 0;
}

.bill-list-card__chip--draft {
  background: rgb(241 245 249);
  color: rgb(71 85 105);
}
.bill-list-card__chip--due {
  background: rgb(254 243 199);
  color: rgb(146 64 14);
}
.bill-list-card__chip--partial {
  background: rgb(219 234 254);
  color: rgb(29 78 216);
}
.bill-list-card__chip--paid {
  background: rgb(220 252 231);
  color: rgb(21 128 61);
}
.bill-list-card__chip--voided {
  background: rgb(254 226 226);
  color: rgb(185 28 28);
}
</style>
