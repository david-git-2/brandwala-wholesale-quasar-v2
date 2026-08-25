<template>
  <div class="simplified-wallet-container q-gutter-y-md">
    <!-- Action Toolbar Bar -->
    <div class="row items-center justify-between q-py-xs">
      <div class="row items-center q-gutter-x-sm">
        <q-avatar size="32px" class="bg-primary-soft text-primary">
          <q-icon name="ph ph-wallet" size="18px" />
        </q-avatar>
        <div>
          <div class="text-subtitle1 text-weight-bold text-ink">
            {{ entityName || 'Account' }} Wallet Overview
          </div>
          <div class="text-caption text-grey-7">Your 3 money pockets in real-time</div>
        </div>
      </div>

      <div class="row items-center q-gutter-sm">
        <q-btn
          outline
          color="primary"
          icon="ph ph-plus-circle"
          label="Add Money"
          no-caps
          dense
          class="text-weight-bold q-px-md rounded-borders"
          @click="$emit('open-deposit')"
        />
        <q-btn
          unelevated
          color="positive"
          icon="ph ph-bank"
          label="Withdraw Cash"
          no-caps
          dense
          class="text-weight-bold q-px-md rounded-borders"
          @click="$emit('open-withdraw')"
        />
        <q-btn
          flat
          color="grey-8"
          icon="ph ph-export"
          label="Statement"
          no-caps
          dense
          class="text-weight-medium q-px-md rounded-borders"
          @click="$emit('open-statement')"
        />
      </div>
    </div>

    <!-- The 3-Bucket Status Cards -->
    <div class="row q-col-gutter-md">
      <!-- Bucket 1: Available -->
      <div class="col-xs-12 col-sm-4">
        <q-card flat bordered class="bucket-pill-card q-pa-md rounded-borders bg-surface shadow-1">
          <div class="row items-center justify-between">
            <span class="text-caption text-weight-bold text-positive uppercase tracking-wider">💵 Money You Have</span>
            <q-avatar size="28px" class="bg-positive-soft text-positive">
              <q-icon name="ph ph-check-circle" size="16px" />
            </q-avatar>
          </div>
          <div class="text-h4 text-weight-bolder text-positive q-my-xs bw-tabular">
            ৳{{ formatCurrency(account?.available_balance ?? 0) }}
          </div>
          <div class="text-caption text-grey-7">
            Ready to withdraw to your bank account right now.
          </div>
        </q-card>
      </div>

      <!-- Bucket 2: Pending -->
      <div class="col-xs-12 col-sm-4">
        <q-card flat bordered class="bucket-pill-card q-pa-md rounded-borders bg-surface shadow-1">
          <div class="row items-center justify-between">
            <span class="text-caption text-weight-bold text-amber-9 uppercase tracking-wider">🚚 Money Coming Soon</span>
            <q-avatar size="28px" class="bg-warning-soft text-warning">
              <q-icon name="ph ph-truck" size="16px" />
            </q-avatar>
          </div>
          <div class="text-h4 text-weight-bolder text-amber-9 q-my-xs bw-tabular">
            ৳{{ formatCurrency(account?.pending_balance ?? 0) }}
          </div>
          <div class="text-caption text-grey-7">
            Earnings from active deliveries coming soon as couriers remit cash.
          </div>
        </q-card>
      </div>

      <!-- Bucket 3: Locked -->
      <div class="col-xs-12 col-sm-4">
        <q-card flat bordered class="bucket-pill-card q-pa-md rounded-borders bg-surface shadow-1">
          <div class="row items-center justify-between">
            <span class="text-caption text-weight-bold text-grey-8 uppercase tracking-wider">🔒 Money On Hold</span>
            <q-avatar size="28px" class="bg-grey-2 text-grey-7">
              <q-icon name="ph ph-lock-key" size="16px" />
            </q-avatar>
          </div>
          <div class="text-h4 text-weight-bolder text-grey-8 q-my-xs bw-tabular">
            ৳{{ formatCurrency(account?.locked_balance ?? 0) }}
          </div>
          <div class="text-caption text-grey-7">
            Funds saved for return claims, disputes, or security collateral.
          </div>
        </q-card>
      </div>
    </div>

    <!-- Level 3: Simple Activity Feed -->
    <q-card flat bordered class="activity-feed-card rounded-borders">
      <q-card-section class="row items-center justify-between q-py-md">
        <div>
          <div class="text-subtitle1 text-weight-bold text-ink">Recent Wallet Transactions</div>
          <div class="text-caption text-muted">Plain-English timeline of money movements for {{ entityName }}</div>
        </div>
        <div class="row items-center q-gutter-x-xs">
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-sliders-horizontal"
            :label="showAdvanced ? 'Hide Raw Audit Ledger' : 'Show Raw Audit Ledger'"
            class="text-weight-bold text-caption"
            @click="showAdvanced = !showAdvanced"
          />
        </div>
      </q-card-section>

      <q-separator />

      <!-- Simple Feed List -->
      <div v-if="isLoading" class="q-pa-md q-gutter-y-sm">
        <q-skeleton height="48px" square class="rounded-borders" v-for="n in 3" :key="n" />
      </div>

      <template v-else>
        <q-list v-if="ledgerEntries.length > 0" separator class="activity-list">
          <q-item v-for="entry in displayedEntries" :key="entry.id" class="q-py-md">
            <!-- Icon Section -->
            <q-item-section avatar>
              <q-avatar
                size="38px"
                :class="getBadgeClass(entry)"
                class="text-weight-bold"
              >
                <q-icon :name="getIconName(entry)" size="18px" />
              </q-avatar>
            </q-item-section>

            <!-- Main Details -->
            <q-item-section>
              <q-item-label class="text-weight-bold text-ink row items-center q-gutter-x-sm">
                <span>{{ getFriendlyTitle(entry) }}</span>
                <q-chip
                  dense
                  flat
                  size="xs"
                  class="text-weight-bold uppercase"
                  :class="getBucket(entry) === 'available' ? 'bg-positive-soft text-positive' : getBucket(entry) === 'pending' ? 'bg-warning-soft text-warning' : 'bg-grey-3 text-grey-8'"
                >
                  {{ getBucketLabel(entry) }}
                </q-chip>
              </q-item-label>

              <q-item-label caption class="text-muted row items-center q-gutter-x-sm q-mt-xs">
                <span>{{ formatDate(entry.created_at) }}</span>
                <span v-if="getOrderId(entry)">• Order #{{ getOrderId(entry) }}</span>
                <span class="text-weight-medium">
                  • {{ entry.type === 'credit' ? 'Money Added (+ Credit)' : 'Money Paid (- Debit)' }}
                </span>
              </q-item-label>
            </q-item-section>

            <!-- Amount Section -->
            <q-item-section side class="text-right">
              <div
                class="text-subtitle1 text-weight-bolder bw-tabular"
                :class="entry.type === 'credit' ? 'text-positive' : 'text-negative'"
              >
                {{ entry.type === 'credit' ? '+ Money In' : '- Money Out' }} ৳{{ formatCurrency(Math.abs(entry.amount)) }}
              </div>
              <div class="text-caption text-grey-6 bw-tabular">
                Remaining: ৳{{ formatCurrency(entry.balance_after) }}
              </div>
            </q-item-section>
          </q-item>
        </q-list>

        <!-- Empty State -->
        <div v-else class="q-pa-xl text-center">
          <q-avatar size="48px" class="bg-grey-2 text-grey-6 q-mb-sm">
            <q-icon name="ph ph-receipt" size="24px" />
          </q-avatar>
          <div class="text-subtitle2 text-weight-bold text-grey-8">No wallet activity recorded yet</div>
          <div class="text-caption text-grey-6">Transactions will appear here automatically when orders or payments are processed.</div>
        </div>
      </template>

      <!-- Advanced Ledger Accordion / Dropdown inside simplified view -->
      <q-slide-transition>
        <div v-if="showAdvanced" class="bg-grey-1 q-pa-md border-top">
          <div class="text-caption text-weight-bold text-grey-8 q-mb-sm row items-center justify-between">
            <span>Raw Double-Entry Accounting Ledger (Audit Trail)</span>
            <span class="text-mono text-grey-6">Total Records: {{ ledgerEntries.length }}</span>
          </div>
          <UniversalWalletLedgerTable
            :entries="ledgerEntries"
          />
        </div>
      </q-slide-transition>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import type {
  UniversalWalletEntityType,
  UniversalWalletLedgerEntry,
  WalletAccount,
} from '../types';
import { useWalletQuery } from '../composables/useWalletQuery';
import UniversalWalletLedgerTable from './UniversalWalletLedgerTable.vue';

const props = defineProps<{
  account: WalletAccount | null;
  entityType: UniversalWalletEntityType;
  entityId: number;
  entityName: string;
  allowTransfer?: boolean;
}>();

defineEmits<{
  (e: 'open-transfer'): void;
  (e: 'open-statement'): void;
  (e: 'open-withdraw'): void;
  (e: 'open-deposit'): void;
}>();

const showAdvanced = ref(false);

const { ledgerEntries, isLoading } = useWalletQuery(
  () => props.entityType,
  () => props.entityId,
);

const displayedEntries = computed(() => {
  return ledgerEntries.value.slice(0, 10);
});

function formatCurrency(val: number | undefined | null): string {
  if (val === undefined || val === null || isNaN(val)) return '0.00';
  return Number(val).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function formatDate(dateStr: string): string {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function getBucket(entry: UniversalWalletLedgerEntry): string {
  return (entry.metadata as Record<string, any>)?.bucket || 'available';
}

function getBucketLabel(entry: UniversalWalletLedgerEntry): string {
  const b = getBucket(entry);
  if (b === 'pending') return 'In Transit';
  if (b === 'locked') return 'Security Hold';
  return 'Available Cash';
}

function getOrderId(entry: UniversalWalletLedgerEntry): string | null {
  if (entry.source_type === 'shop_order' && entry.source_id) {
    return entry.source_id;
  }
  const metaOrder = (entry.metadata as Record<string, any>)?.order_id;
  return metaOrder ? String(metaOrder) : null;
}

function getBadgeClass(entry: UniversalWalletLedgerEntry): string {
  if (entry.type === 'credit') {
    return 'bg-positive-soft text-positive';
  }
  return 'bg-negative-soft text-negative';
}

function getIconName(entry: UniversalWalletLedgerEntry): string {
  if (entry.type === 'credit') {
    return 'ph ph-arrow-down-left';
  }
  return 'ph ph-arrow-up-right';
}

function getFriendlyTitle(entry: UniversalWalletLedgerEntry): string {
  const meta = entry.metadata as Record<string, any> | undefined;
  if (meta?.note) return String(meta.note);
  if (meta?.description) return String(meta.description);
  const orderId = getOrderId(entry);
  if (orderId) return `Profit Settlement (Order #${orderId})`;
  if (entry.source_type === 'payout') return 'Bank Payout Transfer';
  if (entry.source_type === 'adjustment') return 'Balance Adjustment';
  return entry.source_type ? `${entry.source_type.replace('_', ' ')}` : 'Wallet Transaction';
}
</script>

<style scoped lang="scss">
.hero-balance-card {
  border-radius: 12px;
  background: var(--q-surface, #ffffff);
}

.bucket-pill-card {
  border-radius: 10px;
  background: #ffffff;
  transition: transform 0.15s ease, box-shadow 0.15s ease;

  &:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
  }
}

.pocket-explainer-card {
  border: 1px solid rgba(147, 197, 253, 0.5);
}

.activity-feed-card {
  border-radius: 12px;
}

.border-top {
  border-top: 1px solid rgba(0, 0, 0, 0.08);
}
</style>

