<template>
  <q-drawer
    :model-value="modelValue"
    side="right"
    overlay
    bordered
    :width="540"
    class="bg-white"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="column full-height">
      <!-- Header -->
      <div class="q-pa-md border-bottom row items-center justify-between bg-grey-1">
        <div class="row items-center">
          <q-avatar size="36px" color="primary" text-color="white" class="q-mr-sm text-weight-bold">
            {{ getInitials(profileName) }}
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bold text-grey-9">{{ profileName }}</div>
            <div class="text-caption text-grey-7">Billing Profile Details & Wallet Ledger</div>
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" @click="$emit('update:modelValue', false)" />
      </div>

      <!-- Content -->
      <div class="col scroll q-pa-md q-gutter-y-md">
        <!-- Net Balance Card -->
        <q-card flat bordered class="bg-gradient-primary text-white q-pa-md">
          <div class="text-caption text-uppercase opacity-80">Wallet Net Balance</div>
          <div class="text-h4 text-weight-bolder q-my-xs">
            {{ formatBdt(netBalance) }}
          </div>
          <div class="row items-center justify-between text-caption q-mt-sm opacity-90">
            <span>
              Status:
              <strong v-if="netBalance > 0" class="text-positive">Credit Available (Owed)</strong>
              <strong v-else-if="netBalance < 0" class="text-warning">Debt Outstanding</strong>
              <strong v-else>Settled (0.00 BDT)</strong>
            </span>
          </div>
        </q-card>

        <!-- Profile Metadata Summary -->
        <q-card flat bordered class="q-pa-sm">
          <div class="row q-col-gutter-sm text-caption">
            <div class="col-6">
              <span class="text-grey-7">Email:</span>
              <div class="text-weight-medium text-grey-9">{{ email || '—' }}</div>
            </div>
            <div class="col-6">
              <span class="text-grey-7">Phone:</span>
              <div class="text-weight-medium text-grey-9">{{ phone || '—' }}</div>
            </div>
          </div>
        </q-card>

        <!-- Ledger Transactions Header -->
        <div class="row items-center justify-between">
          <div class="text-subtitle2 text-weight-bold text-grey-9">
            <q-icon name="ph ph-clock-counter-clockwise" size="18px" class="q-mr-xs text-primary" />
            Wallet Transaction Ledger
          </div>
          <q-btn
            flat
            dense
            no-caps
            icon="ph ph-arrows-clockwise"
            label="Refresh"
            class="text-caption"
            @click="onRefresh"
          />
        </div>

        <!-- Ledger List -->
        <div v-if="isLoading" class="row justify-center q-py-lg">
          <q-spinner color="primary" size="2.5em" />
        </div>

        <div v-else-if="!ledgerEntries || ledgerEntries.length === 0" class="text-center text-grey-7 q-py-xl border-all-1 rounded-borders">
          <q-icon name="ph ph-receipt" size="36px" color="grey-5" class="q-mb-xs" />
          <div>No wallet transactions recorded yet.</div>
        </div>

        <q-list v-else separator bordered class="rounded-borders">
          <q-item v-for="entry in ledgerEntries" :key="entry.id" class="q-py-md">
            <q-item-section avatar>
              <q-avatar
                size="32px"
                :color="getTypeMeta(entry).color"
                text-color="white"
                :icon="getTypeMeta(entry).icon"
              />
            </q-item-section>

            <q-item-section>
              <q-item-label class="text-weight-bold text-subtitle2 text-grey-9">
                {{ getTypeMeta(entry).label }}
              </q-item-label>
              <q-item-label caption class="text-grey-7">
                {{ formatDate(entry.created_at) }}
                <span v-if="entry.source_id"> • {{ entry.source_id }}</span>
              </q-item-label>
            </q-item-section>

            <q-item-section side class="text-right">
              <q-item-label
                class="text-weight-bold text-subtitle2"
                :class="getTypeMeta(entry).isCredit ? 'text-positive' : 'text-negative'"
              >
                {{ getTypeMeta(entry).isCredit ? '+' : '-' }}{{ formatBdt(entry.amount) }}
              </q-item-label>
              <q-item-label caption class="text-grey-6">
                Bal: {{ formatBdt(entry.balance_after) }}
              </q-item-label>
            </q-item-section>
          </q-item>
        </q-list>
      </div>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useWalletQuery } from 'src/modules/wallet/composables/useWalletQuery';

const props = defineProps<{
  modelValue: boolean;
  tenantId: number | null;
  billingProfileId: number | null;
  profileName: string;
  email?: string | null | undefined;
  phone?: string | null | undefined;
  netBalance: number;
}>();

defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const entityId = computed(() => props.billingProfileId ?? 0);

const { ledgerEntries, isLoading, refetch } = useWalletQuery('customer', entityId);

const onRefresh = () => {
  void refetch();
};

const formatBdt = (val: number) =>
  new Intl.NumberFormat('en-BD', { style: 'currency', currency: 'BDT' }).format(val);

const formatDate = (iso: string) => new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });

const getInitials = (name: string) => (name ? name.split(' ').map((n) => n[0]).join('').substring(0, 2).toUpperCase() : 'BP');

const getTypeMeta = (entry: { type: string; metadata: Record<string, unknown> }) => {
  const txType = entry.metadata?.['transaction_type'] as string | undefined;
  const isCredit = entry.type === 'credit';
  switch (txType) {
    case 'dropship_profit':
      return { label: 'Dropship Profit', color: 'positive', icon: 'ph ph-trend-up', isCredit };
    case 'payment_received':
      return { label: 'Payment Received', color: 'positive', icon: 'ph ph-arrow-down-left', isCredit };
    case 'invoice_billed':
      return { label: 'Invoice Billed', color: 'negative', icon: 'ph ph-receipt', isCredit };
    case 'payout_paid':
      return { label: 'Payout Paid', color: 'blue-8', icon: 'ph ph-hand-coins', isCredit };
    case 'dropship_return_fee':
      return { label: 'Return Fee', color: 'negative', icon: 'ph ph-arrow-counter-clockwise', isCredit };
    default:
      return { label: (entry.metadata?.['label'] as string | undefined) || 'Adjustment', color: 'grey-7', icon: 'ph ph-sliders-horizontal', isCredit };
  }
};
</script>

<style scoped>
.bg-gradient-primary {
  background: linear-gradient(135deg, #1976d2 0%, #1565c0 100%);
}
.border-bottom {
  border-bottom: 1px solid #e0e0e0;
}
.border-all-1 {
  border: 1px solid #e0e0e0;
}
.opacity-80 {
  opacity: 0.8;
}
.opacity-90 {
  opacity: 0.9;
}
</style>
