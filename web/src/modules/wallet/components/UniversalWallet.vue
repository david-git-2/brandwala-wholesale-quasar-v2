<template>
  <div class="universal-wallet-container">
    <UniversalWalletSkeleton v-if="isLoading" />

    <div v-else class="q-gutter-y-md">
      <!-- Header -->
      <UniversalWalletHeader
        :entity-type="entityType"
        :entity-id="entityId"
        :entity-name="entityName"
        :allow-adjustment="allowAdjustment"
        @open-adjustment="showAdjustmentDialog = true"
        @open-payment="showPaymentDialog = true"
        @open-remittance="showRemittanceDialog = true"
      >
        <template #actions>
          <slot name="header-actions" />
        </template>
      </UniversalWalletHeader>

      <!-- KPI Cards -->
      <UniversalWalletKPICards
        :totals="totals"
        :entity-type="entityType"
        :currency-code="currencyCode"
      />

      <!-- Toolbar -->
      <UniversalWalletToolbar
        v-model:search="searchQuery"
        v-model:type="typeFilter"
        v-model:section="sectionFilter"
        :entries="ledgerEntries"
        @refresh="refetch"
      />

      <!-- Ledger Table -->
      <UniversalWalletLedgerTable
        :entries="filteredEntries"
      />
    </div>

    <!-- Record Payment Dialog (Customer) -->
    <q-dialog v-model="showPaymentDialog" persistent>
      <q-card style="min-width: 380px" class="q-pa-sm surface-dialog">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Record Payment</div>
          <div class="text-caption text-muted">
            Record an incoming payment from {{ entityName || `#${entityId}` }}.
          </div>
        </q-card-section>
        <q-card-section class="q-gutter-y-md">
          <q-input
            v-model.number="quickAmount"
            label="Amount Received *"
            outlined
            dense
            type="number"
            min="0.01"
            step="any"
          />
          <q-input
            v-model="quickNote"
            label="Reference / Note"
            outlined
            dense
            type="textarea"
            rows="2"
          />
        </q-card-section>
        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat label="Cancel" color="grey" v-close-popup />
          <q-btn
            unelevated
            label="Record Payment"
            color="positive"
            :loading="adjustMutation.isPending.value"
            :disable="!quickAmount || quickAmount <= 0"
            @click="handleQuickAction('payment_received')"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Record Remittance Dialog (Courier) -->
    <q-dialog v-model="showRemittanceDialog" persistent>
      <q-card style="min-width: 380px" class="q-pa-sm surface-dialog">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Record Remittance</div>
          <div class="text-caption text-muted">
            Record a COD remittance from {{ entityName || `#${entityId}` }}.
          </div>
        </q-card-section>
        <q-card-section class="q-gutter-y-md">
          <q-input
            v-model.number="quickAmount"
            label="Amount Remitted *"
            outlined
            dense
            type="number"
            min="0.01"
            step="any"
          />
          <q-input
            v-model="quickNote"
            label="Reference / Note"
            outlined
            dense
            type="textarea"
            rows="2"
          />
        </q-card-section>
        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat label="Cancel" color="grey" v-close-popup />
          <q-btn
            unelevated
            label="Record Remittance"
            color="positive"
            :loading="adjustMutation.isPending.value"
            :disable="!quickAmount || quickAmount <= 0"
            @click="handleQuickAction('cod_holding')"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Manual Adjustment Dialog -->
    <q-dialog v-model="showAdjustmentDialog" persistent>
      <q-card style="min-width: 380px" class="q-pa-sm surface-dialog">
        <q-card-section>
          <div class="text-h6 text-weight-bold">Adjust Wallet Balance</div>
          <div class="text-caption text-muted">
            Record a manual adjustment transaction for ID #{{ entityId }}.
          </div>
        </q-card-section>

        <q-card-section class="q-gutter-y-md">
          <q-select
            v-model="adjType"
            label="Transaction Type *"
            outlined
            dense
            emit-value
            map-options
            :options="[
              { label: 'Credit (Money IN / Add Balance)', value: 'credit' },
              { label: 'Debit (Money OUT / Deduct Balance)', value: 'debit' }
            ]"
          />

          <q-input
            v-model.number="adjAmount"
            label="Amount *"
            outlined
            dense
            type="number"
            min="0.01"
            step="any"
          />

          <q-input
            v-model="adjNote"
            label="Adjustment Reason / Note"
            outlined
            dense
            type="textarea"
            rows="2"
          />
        </q-card-section>

        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn flat label="Cancel" color="grey" v-close-popup />
          <q-btn
            unelevated
            label="Submit Adjustment"
            color="primary"
            :loading="adjustMutation.isPending.value"
            :disable="!adjAmount || adjAmount <= 0"
            @click="handleAdjustmentSubmit"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useWalletQuery } from '../composables/useWalletQuery';
import { useWalletMath } from '../composables/useWalletMath';
import { useAdjustWalletBalanceMutation } from '../composables/useWalletMutations';
import type { UniversalWalletEntityType } from '../types';

import UniversalWalletSkeleton from './skeletons/UniversalWalletSkeleton.vue';
import UniversalWalletHeader from './UniversalWalletHeader.vue';
import UniversalWalletKPICards from './UniversalWalletKPICards.vue';
import UniversalWalletToolbar from './UniversalWalletToolbar.vue';
import UniversalWalletLedgerTable from './UniversalWalletLedgerTable.vue';

const props = withDefaults(
  defineProps<{
    entityType: UniversalWalletEntityType;
    entityId: number;
    entityName?: string;
    allowAdjustment?: boolean;
    currencyCode?: string;
  }>(),
  {
    entityName: '',
    allowAdjustment: false,
    currencyCode: 'BDT',
  },
);

// TanStack Data Fetching
const { ledgerEntries, isLoading, refetch } = useWalletQuery(
  () => props.entityType,
  () => props.entityId,
);

// Computed KPI math
const { totals } = useWalletMath(ledgerEntries);

// Filtering & Search Toolbar state
const searchQuery = ref('');
const typeFilter = ref('all');
const sectionFilter = ref<string[]>([]);

const filteredEntries = computed(() => {
  let entries = ledgerEntries.value;

  if (typeFilter.value !== 'all') {
    entries = entries.filter((e) => e.type === typeFilter.value);
  }

  if (sectionFilter.value.length > 0) {
    entries = entries.filter((e) => sectionFilter.value.includes(e.metadata?.section ?? ''));
  }

  if (searchQuery.value.trim()) {
    const q = searchQuery.value.trim().toLowerCase();
    entries = entries.filter((e) => {
      const matchSourceId = e.source_id ? e.source_id.toLowerCase().includes(q) : false;
      const matchSourceType = e.source_type ? e.source_type.toLowerCase().includes(q) : false;
      const matchNote = e.metadata?.note ? String(e.metadata.note).toLowerCase().includes(q) : false;
      const matchTrx = e.metadata?.trx_id ? String(e.metadata.trx_id).toLowerCase().includes(q) : false;

      return matchSourceId || matchSourceType || matchNote || matchTrx;
    });
  }

  return entries;
});

// Quick action dialogs (Payment / Remittance)
const showPaymentDialog = ref(false);
const showRemittanceDialog = ref(false);
const quickAmount = ref<number | null>(null);
const quickNote = ref('');

const handleQuickAction = (section: string) => {
  if (!quickAmount.value || quickAmount.value <= 0) return;
  adjustMutation.mutate(
    {
      entity_type: props.entityType,
      entity_id: props.entityId,
      type: 'credit',
      amount: quickAmount.value,
      currency_code: props.currencyCode,
      exchange_rate: 1.0,
      source_type: 'adjustment',
      source_id: `QA-${Date.now().toString().slice(-6)}`,
      metadata: { section, ...(quickNote.value ? { note: quickNote.value } : {}) },
    },
    {
      onSuccess: () => {
        showPaymentDialog.value = false;
        showRemittanceDialog.value = false;
        quickAmount.value = null;
        quickNote.value = '';
      },
    },
  );
};

// Balance Adjustment Modal State & Mutation
const showAdjustmentDialog = ref(false);
const adjType = ref<'credit' | 'debit'>('credit');
const adjAmount = ref<number | null>(null);
const adjNote = ref('');

const adjustMutation = useAdjustWalletBalanceMutation();

const handleAdjustmentSubmit = () => {
  if (!adjAmount.value || adjAmount.value <= 0) return;

  adjustMutation.mutate(
    {
      entity_type: props.entityType,
      entity_id: props.entityId,
      type: adjType.value,
      amount: adjAmount.value,
      currency_code: props.currencyCode,
      exchange_rate: 1.0,
      source_type: 'adjustment',
      source_id: `ADJ-${Date.now().toString().slice(-6)}`,
      metadata: adjNote.value ? { note: adjNote.value } : {},
    },
    {
      onSuccess: () => {
        showAdjustmentDialog.value = false;
        adjAmount.value = null;
        adjNote.value = '';
      },
    },
  );
};
</script>

<style scoped>
.surface-dialog {
  background: var(--bw-theme-surface);
  border-radius: 12px;
}

.text-muted {
  color: var(--bw-theme-muted);
}
</style>
