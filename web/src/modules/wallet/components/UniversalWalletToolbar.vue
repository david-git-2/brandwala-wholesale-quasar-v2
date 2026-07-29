<template>
  <q-card flat bordered class="toolbar-card">
    <div class="q-pa-sm">
      <!-- Row 1: Search + Type + Refresh -->
      <div class="row items-center q-col-gutter-sm">
        <div class="col-xs-12 col-sm-6 col-md-5">
          <q-input
            v-model="searchQuery"
            dense
            outlined
            placeholder="Search by source ID or note..."
            class="soft-input"
            clearable
          >
            <template #prepend>
              <q-icon name="search" size="xs" />
            </template>
          </q-input>
        </div>

        <div class="col-xs-6 col-sm-3 col-md-2">
          <q-select
            v-model="typeFilter"
            dense
            outlined
            emit-value
            map-options
            :options="typeOptions"
            label="Type"
            class="soft-input"
          />
        </div>

        <div class="col-xs-6 col-sm-3 col-md-5 text-right">
          <q-btn
            flat
            round
            dense
            icon="refresh"
            color="primary"
            @click="$emit('refresh')"
          >
            <q-tooltip>Refresh Ledger</q-tooltip>
          </q-btn>
        </div>
      </div>

      <!-- Row 2: Section Chip Filter -->
      <div v-if="availableSections.length > 0" class="row items-center q-mt-sm q-gutter-xs">
        <span class="text-caption text-weight-bold text-muted q-mr-xs">Category:</span>
        <q-chip
          dense
          clickable
          unelevated
          :class="sectionFilter.length === 0 ? 'chip-active' : 'chip-inactive'"
          @click="sectionFilter = []"
        >
          All
        </q-chip>
        <q-chip
          v-for="sec in availableSections"
          :key="sec.value"
          dense
          clickable
          unelevated
          :class="[sectionChipColor(sec.value), isSectionActive(sec.value) ? 'chip-selected' : 'chip-inactive']"
          @click="toggleSection(sec.value)"
        >
          {{ sec.label }}
        </q-chip>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { UniversalWalletLedgerEntry } from '../types';

const searchQuery = defineModel<string>('search', { default: '' });
const typeFilter = defineModel<string>('type', { default: 'all' });
const sectionFilter = defineModel<string[]>('section', { default: () => [] });

const props = defineProps<{
  entries: UniversalWalletLedgerEntry[];
}>();

defineEmits<{
  (e: 'refresh'): void;
}>();

const typeOptions = [
  { label: 'All Types', value: 'all' },
  { label: 'Credit (IN)', value: 'credit' },
  { label: 'Debit (OUT)', value: 'debit' },
];

const SECTION_LABELS: Record<string, string> = {
  receivable: 'Invoice Billed',
  payout_earned: 'Profit Earned',
  cod_holding: 'COD Collected',
  delivery_fee: 'Delivery Fee',
  revenue: 'Revenue',
  adjustment: 'Manual Adjustment',
  payment_received: 'Payment Received',
  intercompany: 'Intercompany',
};

const SECTION_CHIP_COLORS: Record<string, string> = {
  receivable: 'chip-orange',
  payout_earned: 'chip-green',
  cod_holding: 'chip-blue',
  delivery_fee: 'chip-grey',
  revenue: 'chip-teal',
  adjustment: 'chip-purple',
  payment_received: 'chip-green',
  intercompany: 'chip-grey',
};

const availableSections = computed(() => {
  const seen = new Set<string>();
  for (const e of props.entries) {
    const sec: string | undefined = e.metadata?.section;
    if (sec) seen.add(sec);
  }
  return [...seen].map((s) => ({ value: s, label: SECTION_LABELS[s] ?? s }));
});

const sectionChipColor = (section: string) => SECTION_CHIP_COLORS[section] ?? 'chip-grey';
const isSectionActive = (section: string) => sectionFilter.value.includes(section);

const toggleSection = (section: string) => {
  const idx = sectionFilter.value.indexOf(section);
  if (idx === -1) {
    sectionFilter.value = [...sectionFilter.value, section];
  } else {
    sectionFilter.value = sectionFilter.value.filter((s) => s !== section);
  }
};
</script>

<style scoped>
.toolbar-card {
  background: var(--bw-theme-surface);
  border-color: var(--bw-theme-border);
  border-radius: 10px;
}

.text-muted { color: #64748b; }

.chip-active   { background: #0f172a !important; color: #ffffff !important; border-radius: 8px; }
.chip-inactive { background: rgba(100, 116, 139, 0.08) !important; color: #64748b !important; border-radius: 8px; }
.chip-selected { opacity: 1; box-shadow: 0 0 0 2px currentColor; }

.chip-orange { background: rgba(249, 115, 22, 0.12) !important; color: #ea580c !important; border-radius: 8px; }
.chip-green  { background: rgba(16, 185, 129, 0.12) !important; color: #059669 !important; border-radius: 8px; }
.chip-blue   { background: rgba(37, 99, 235, 0.12)  !important; color: #2563eb !important; border-radius: 8px; }
.chip-grey   { background: rgba(100, 116, 139, 0.1) !important; color: #475569 !important; border-radius: 8px; }
.chip-teal   { background: rgba(13, 148, 136, 0.12) !important; color: #0d9488 !important; border-radius: 8px; }
.chip-purple { background: rgba(139, 92, 246, 0.12) !important; color: #7c3aed !important; border-radius: 8px; }
</style>
