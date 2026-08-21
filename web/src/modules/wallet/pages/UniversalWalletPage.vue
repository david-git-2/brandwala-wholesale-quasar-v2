<template>
  <q-page class="wallet-page-container q-pa-md" style="min-height: calc(100vh - 55px)">
    <UniversalWalletPageSkeleton v-if="isInitialLoading || isAccountLoading" />

    <div v-else class="q-gutter-y-md">
      <!-- 1. Header with Entity & 4 Action Buttons -->
      <section class="row items-center justify-between q-col-gutter-sm">
        <!-- Back button & Entity Info -->
        <div class="col-auto row items-center q-gutter-x-sm">
          <q-btn
            flat
            round
            dense
            icon="ph ph-arrow-left"
            color="grey-8"
            @click="navigateBack"
          >
            <q-tooltip>Back to List</q-tooltip>
          </q-btn>
          <q-avatar size="36px" color="grey-3" text-color="grey-9" class="text-weight-bold">
            <q-icon :name="entityIcon" size="20px" />
          </q-avatar>
          <div>
            <div class="row items-center q-gutter-x-xs">
              <q-chip
                dense
                square
                size="11px"
                class="bg-primary-soft text-primary text-weight-bold uppercase tracking-wider"
              >
                {{ entityTypeLabel }}
              </q-chip>
            </div>
            <div class="text-h6 text-weight-bolder text-grey-9 q-my-none leading-tight">
              {{ loadedEntityName || 'Wallet' }}
            </div>
          </div>
        </div>

        <!-- 4 Action Buttons -->
        <div class="col-auto row items-center q-gutter-x-sm">
          <!-- Button 1: Pay -->
          <q-btn
            unelevated
            no-caps
            color="primary"
            icon="ph ph-arrow-up-right"
            label="Pay"
            class="text-weight-bold q-px-md rounded-btn"
            @click="onActionClick('pay')"
          >
            <q-tooltip>Pay Cash Out / Settle Bill</q-tooltip>
          </q-btn>

          <!-- Button 2: Deposit -->
          <q-btn
            unelevated
            no-caps
            color="teal-8"
            icon="ph ph-plus-circle"
            label="Deposit"
            class="text-weight-bold q-px-md rounded-btn"
            @click="onActionClick('deposit')"
          >
            <q-tooltip>Deposit Cash In / Top Up</q-tooltip>
          </q-btn>

          <!-- Button 3: Credit -->
          <q-btn
            unelevated
            no-caps
            color="indigo-8"
            icon="ph ph-tag"
            label="Credit"
            class="text-weight-bold q-px-md rounded-btn"
            @click="onActionClick('credit')"
          >
            <q-tooltip>Store Credit / Non-Cash IOU</q-tooltip>
          </q-btn>

          <!-- Button 4: Withdraw -->
          <q-btn
            unelevated
            no-caps
            color="positive"
            icon="ph ph-bank"
            label="Withdraw"
            class="text-weight-bold q-px-md rounded-btn"
            @click="onActionClick('withdraw')"
          >
            <q-tooltip>Withdraw / Bank Payout</q-tooltip>
          </q-btn>
        </div>
      </section>

      <!-- 2. Consolidated Wallet Balance Card -->
      <section>
        <q-card flat bordered class="q-pa-md rounded-borders bg-white shadow-soft">
          <div class="row items-center justify-between">
            <div>
              <div class="text-caption text-weight-bold text-grey-7 uppercase tracking-wider">
                💵 Available Wallet Balance
              </div>
              <div class="text-h4 text-weight-bolder q-mt-xs font-mono" :class="availableBalanceClass">
                ৳{{ formatCurrency(account?.available_balance ?? 0) }}
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                Real-time available spendable/withdrawable balance
              </div>
            </div>

            <!-- Secondary Buckets if any (Pending / Locked) -->
            <div class="row items-center q-gutter-x-md">
              <div v-if="(account?.pending_balance ?? 0) !== 0" class="text-right">
                <div class="text-caption text-grey-6">In Transit (Pending)</div>
                <div class="text-subtitle1 text-weight-bold text-amber-9 font-mono">
                  ৳{{ formatCurrency(account?.pending_balance ?? 0) }}
                </div>
              </div>
              <div v-if="(account?.locked_balance ?? 0) !== 0" class="text-right">
                <div class="text-caption text-grey-6">On Hold (Locked)</div>
                <div class="text-subtitle1 text-weight-bold text-grey-8 font-mono">
                  ৳{{ formatCurrency(account?.locked_balance ?? 0) }}
                </div>
              </div>
            </div>
          </div>
        </q-card>
      </section>

      <!-- 3. Transaction List & History -->
      <section>
        <!-- Toolbar for search & refresh -->
        <div class="row items-center justify-between q-mb-sm">
          <div class="text-subtitle1 text-weight-bold text-grey-9">
            Transaction History
          </div>
          <div class="row items-center q-gutter-x-sm">
            <q-input
              v-model="searchQuery"
              outlined
              rounded
              dense
              placeholder="Search reference, note..."
              class="bg-white"
              style="width: 250px"
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" color="grey-6" />
              </template>
            </q-input>
            <q-btn
              flat
              dense
              round
              icon="ph ph-arrows-clockwise"
              color="grey-7"
              :loading="isLedgerFetching"
              @click="() => { refetchAccount(); refetchLedger(); }"
            >
              <q-tooltip>Refresh Ledger</q-tooltip>
            </q-btn>
          </div>
        </div>

        <UniversalWalletLedgerTable
          :entries="filteredEntries"
          @revert="onRevertClick"
        />
      </section>
    </div>

    <!-- Unified Wallet Action Modal (Pay / Deposit / Credit / Withdraw) -->
    <WalletActionModal
      v-model="isActionModalOpen"
      :action-type="activeActionType"
      :entity-type="effectiveEntityType"
      :entity-id="effectiveEntityId"
      :entity-name="loadedEntityName"
      :available-balance="account?.available_balance || 0"
      :submitting="isSubmittingAction"
      @submit="handleActionSubmit"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useQuasar } from 'quasar';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { UniversalWalletEntityType, UniversalWalletLedgerEntry } from '../types';
import { getEntityTypeFromSlug, getSlugFromEntityType } from '../utils/walletSlugMap';
import UniversalWalletPageSkeleton from '../components/UniversalWalletPageSkeleton.vue';
import UniversalWalletLedgerTable from '../components/UniversalWalletLedgerTable.vue';
import WalletActionModal, { type WalletModalActionType, type WalletActionPayload } from '../components/WalletActionModal.vue';
import { useWalletAccounts } from '../composables/useWalletAccounts';
import { useWalletQuery } from '../composables/useWalletQuery';
import { walletRepository } from '../repositories/walletRepository';

const $q = useQuasar();
const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

const isInitialLoading = ref<boolean>(true);
const loadedEntityName = ref<string>('');
const searchQuery = ref<string>('');

const effectiveEntityType = computed<UniversalWalletEntityType>(() => {
  if (route.name === 'app-wallet-company-detail' || route.params.tenantId != null) {
    return 'tenant';
  }
  const typeParam = (route.params.walletType as string) || '';
  if (typeParam === 'company') return 'tenant';
  const mapped = getEntityTypeFromSlug(typeParam);
  if (mapped) return mapped;
  return (typeParam as UniversalWalletEntityType) || 'tenant';
});

const effectiveEntityId = computed<number>(() => {
  if (effectiveEntityType.value === 'tenant') {
    if (route.params.tenantId) return Number(route.params.tenantId);
    return authStore.selectedTenant?.id || 1;
  }
  return Number(route.params.entityId) || 1;
});

const walletSlug = computed<string>(() => {
  return getSlugFromEntityType(effectiveEntityType.value) || 'company';
});

const entityTypeLabel = computed<string>(() => {
  switch (effectiveEntityType.value) {
    case 'tenant':        return 'Company Wallet';
    case 'customer':      return 'Customer Wallet';
    case 'vendor':        return 'Supplier Wallet';
    case 'cargo_company': return 'Cargo Wallet';
    case 'courier':       return 'Courier Wallet';
    case 'investor':      return 'Investor Wallet';
    default:              return 'Entity Wallet';
  }
});

const entityIcon = computed<string>(() => {
  switch (effectiveEntityType.value) {
    case 'tenant':        return 'ph ph-buildings';
    case 'customer':      return 'ph ph-user';
    case 'vendor':        return 'ph ph-storefront';
    case 'cargo_company': return 'ph ph-airplane-tilt';
    case 'courier':       return 'ph ph-moped';
    case 'investor':      return 'ph ph-chart-line-up';
    default:              return 'ph ph-wallet';
  }
});

// Balance query
const { account, isAccountLoading, refetchAccount } = useWalletAccounts(
  () => effectiveEntityType.value,
  () => effectiveEntityId.value,
);

// Ledger entries query
const { ledgerEntries, isFetching: isLedgerFetching, refetch: refetchLedger } = useWalletQuery(
  () => effectiveEntityType.value,
  () => effectiveEntityId.value,
);

const filteredEntries = computed(() => {
  if (!searchQuery.value.trim()) return ledgerEntries.value;
  const q = searchQuery.value.toLowerCase().trim();
  return ledgerEntries.value.filter((entry) => {
    const note = entry.metadata?.note?.toLowerCase() || '';
    const srcId = String(entry.source_id || '').toLowerCase();
    const srcType = entry.source_type?.toLowerCase() || '';
    const section = entry.metadata?.section?.toLowerCase() || '';
    return note.includes(q) || srcId.includes(q) || srcType.includes(q) || section.includes(q);
  });
});

const availableBalanceClass = computed(() => {
  const bal = account.value?.available_balance ?? 0;
  if (bal > 0) return 'text-positive';
  if (bal < 0) return 'text-negative';
  return 'text-grey-9';
});

function formatCurrency(val: number): string {
  return (val || 0).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function navigateBack() {
  if (effectiveEntityType.value === 'tenant') {
    void router.push({
      name: 'app-wallet-home-page',
      params: route.params,
    });
  } else {
    void router.push({
      name: 'app-wallet-entity-list-page',
      params: {
        ...route.params,
        walletType: walletSlug.value,
      },
    });
  }
}

const isActionModalOpen = ref<boolean>(false);
const activeActionType = ref<WalletModalActionType>('pay');
const isSubmittingAction = ref<boolean>(false);

function onActionClick(action: WalletModalActionType) {
  activeActionType.value = action;
  isActionModalOpen.value = true;
}

async function handleActionSubmit(payload: WalletActionPayload) {
  isSubmittingAction.value = true;
  try {
    // Movement type:
    // 'pay' -> 'debit' (Cash Out)
    // 'withdraw' -> 'debit' (Cash Out to Bank)
    // 'deposit' -> 'credit' (Cash In)
    // 'credit' -> 'credit' (Store Credit In)
    const movementType = payload.actionType === 'pay' || payload.actionType === 'withdraw'
      ? 'debit'
      : 'credit';

    const sourceType = payload.actionType === 'pay'
      ? 'vendor_purchase'
      : payload.actionType === 'withdraw'
        ? 'payout'
        : 'adjustment';

    await walletRepository.recordTransaction({
      entity_type: payload.entityType,
      entity_id: payload.entityId,
      type: movementType,
      amount: payload.amount,
      currency_code: payload.currency,
      exchange_rate: payload.exchangeRate,
      source_type: sourceType,
      source_id: payload.referenceId || null,
      target_bucket: 'available',
      metadata: {
        section: payload.category,
        method: payload.paymentMethod,
        trx_id: payload.referenceId || undefined,
        note: payload.note || undefined,
        action_type: payload.actionType,
        base_amount: payload.baseAmount,
        payee_type: payload.targetEntityType || undefined,
        payee_id: payload.targetEntityId || undefined,
        recorded_by: authStore.user?.email || 'admin',
      },
    });

    $q.notify({
      type: 'positive',
      message: `Successfully recorded ${payload.actionType.toUpperCase()} of ${payload.currency} ${payload.amount.toLocaleString()} (৳${payload.baseAmount.toLocaleString()} BDT)!`,
      icon: 'ph ph-check-circle',
      position: 'top',
      timeout: 2500,
    });

    isActionModalOpen.value = false;
    void refetchAccount();
    void refetchLedger();
  } catch (err: any) {
    console.error('[UniversalWalletPage] Action failed:', err);
    $q.notify({
      type: 'negative',
      message: err.message || `Failed to record ${payload.actionType}.`,
      icon: 'ph ph-warning',
      position: 'top',
      timeout: 3000,
    });
  } finally {
    isSubmittingAction.value = false;
  }
}

function onRevertClick(entry: UniversalWalletLedgerEntry) {
  $q.notify({
    type: 'warning',
    message: `Revert requested for transaction #${entry.id.slice(0, 8)}. Cause & revert workflow will be configured next.`,
    icon: 'ph ph-arrow-counter-clockwise',
    position: 'top',
    timeout: 2500,
  });
}

async function fetchEntityName() {
  const type = effectiveEntityType.value;
  const id = effectiveEntityId.value;

  if (type === 'tenant') {
    loadedEntityName.value = authStore.selectedTenant?.name || 'Our Company';
    return;
  }

  try {
    if (type === 'customer') {
      const { data } = await supabase
        .from('billing_profiles')
        .select('name')
        .eq('id', id)
        .maybeSingle();
      loadedEntityName.value = data?.name || `Customer #${id}`;
    } else if (type === 'vendor') {
      const { data } = await supabase
        .from('vendors')
        .select('name')
        .eq('id', id)
        .maybeSingle();
      loadedEntityName.value = data?.name || `Vendor #${id}`;
    } else if (type === 'cargo_company') {
      const { data } = await supabase
        .from('cargo_companies')
        .select('name')
        .eq('id', id)
        .maybeSingle();
      loadedEntityName.value = data?.name || `Cargo #${id}`;
    } else if (type === 'courier') {
      const { data } = await supabase
        .from('courier_services')
        .select('name')
        .or(`wallet_entity_id.eq.${id},id.eq.${id}`)
        .maybeSingle();
      loadedEntityName.value = data?.name || `Courier #${id}`;
    } else if (type === 'investor') {
      const { data } = await supabase
        .from('investors')
        .select('name')
        .eq('id', id)
        .maybeSingle();
      loadedEntityName.value = data?.name || `Investor #${id}`;
    }
  } catch (err) {
    console.error('[UniversalWalletPage] Failed to fetch entity name:', err);
    loadedEntityName.value = `Entity #${id}`;
  }
}

async function initializePage() {
  isInitialLoading.value = true;
  await fetchEntityName();
  isInitialLoading.value = false;
}

watch(
  [() => route.params.walletType, () => route.params.entityId, () => route.params.tenantId],
  () => {
    void initializePage();
  },
);

onMounted(() => {
  void initializePage();
});
</script>

<style scoped lang="scss">
.rounded-btn {
  border-radius: 8px;
}
.shadow-soft {
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}
</style>
