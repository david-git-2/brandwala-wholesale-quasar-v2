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
              <div class="text-h4 text-weight-bolder q-mt-xs bw-tabular" :class="availableBalanceClass">
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
                <div class="text-subtitle1 text-weight-bold text-amber-9 bw-tabular">
                  ৳{{ formatCurrency(account?.pending_balance ?? 0) }}
                </div>
              </div>
              <div v-if="(account?.locked_balance ?? 0) !== 0" class="text-right">
                <div class="text-caption text-grey-6">On Hold (Locked)</div>
                <div class="text-subtitle1 text-weight-bold text-grey-8 bw-tabular">
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
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { UniversalWalletEntityType, UniversalWalletLedgerEntry, WalletAccount } from '../types';
import { getEntityTypeFromSlug, getSlugFromEntityType } from '../utils/walletSlugMap';
import { walletBooksTenantId } from '../utils/walletBooksTenantId';
import UniversalWalletPageSkeleton from '../components/UniversalWalletPageSkeleton.vue';
import UniversalWalletLedgerTable from '../components/UniversalWalletLedgerTable.vue';
import WalletActionModal, { type WalletModalActionType, type WalletActionPayload } from '../components/WalletActionModal.vue';
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
    return walletBooksTenantId(authStore.selectedTenant);
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

const account = ref<WalletAccount | null>(null);
const isAccountLoading = ref(false);

async function refetchAccount() {
  isAccountLoading.value = true;
  try {
    const tenantId = authStore.selectedTenant?.id || 1;
    const detail = await walletRepository.getDetailForStaff(
      tenantId,
      effectiveEntityType.value,
      effectiveEntityId.value,
    );
    if (!detail.success) {
      throw new Error(detail.error || 'Failed to load wallet detail');
    }
    loadedEntityName.value = detail.entity?.name || 'Wallet';
    account.value = {
      tenant_id: detail.books_tenant_id || walletBooksTenantId(authStore.selectedTenant),
      entity_type: effectiveEntityType.value,
      entity_id: effectiveEntityId.value,
      currency_code: detail.account?.currency_code || 'BDT',
      available_balance: Number(detail.account?.available_balance || 0),
      pending_balance: Number(detail.account?.pending_balance || 0),
      locked_balance: Number(detail.account?.locked_balance || 0),
      total_balance: Number(detail.account?.total_balance || 0),
    };
  } finally {
    isAccountLoading.value = false;
  }
}

const { ledgerEntries, isFetching: isLedgerFetching, refetch: refetchLedger } = useWalletQuery(
  () => effectiveEntityType.value,
  () => effectiveEntityId.value,
  () => searchQuery.value,
);

const filteredEntries = computed(() => ledgerEntries.value);

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
    const result = await walletRepository.recordManualTransaction({
      action_type: payload.actionType,
      primary_entity_type: payload.entityType,
      primary_entity_id: payload.entityId,
      amount: payload.amount,
      currency_code: payload.currency,
      exchange_rate: payload.exchangeRate,
      category: payload.category,
      payment_method: payload.paymentMethod,
      reference_id: payload.referenceId || null,
      note: payload.note || null,
      counterparty_entity_type: payload.targetEntityType || null,
      counterparty_entity_id: payload.targetEntityId || null,
      target_bucket: 'available',
    });

    if (result.success === false) {
      throw new Error(String(result.error || 'Transaction failed'));
    }

    $q.notify({
      type: 'positive',
      message: `Successfully recorded ${payload.actionType.toUpperCase()} of ${payload.currency} ${payload.amount.toLocaleString()} (৳${payload.baseAmount.toLocaleString()} BDT)!`,
      icon: 'ph ph-check-circle',
      position: 'top',
      timeout: 2500,
    });

    isActionModalOpen.value = false;
    await refetchAccount();
    await refetchLedger();
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
  $q.dialog({
    title: 'Reverse transaction',
    message: 'Enter a reason for this reversal.',
    prompt: {
      model: '',
      type: 'text',
      isValid: (val: string) => Boolean(val && val.trim().length > 0),
    },
    cancel: true,
    persistent: true,
  }).onOk((reason: string) => {
    void (async () => {
      try {
        const result = await walletRepository.reverseLedgerEntry({
          ledger_entry_id: entry.id,
          reason: reason.trim(),
        });
        if (result.success === false) {
          throw new Error(String(result.error || 'Reversal failed'));
        }
        $q.notify({
          type: 'positive',
          message: 'Transaction reversed.',
          icon: 'ph ph-check-circle',
          position: 'top',
        });
        await refetchAccount();
        await refetchLedger();
      } catch (err: any) {
        $q.notify({
          type: 'negative',
          message: err.message || 'Failed to reverse transaction.',
          icon: 'ph ph-warning',
          position: 'top',
        });
      }
    })();
  });
}

async function initializePage() {
  isInitialLoading.value = true;
  await refetchAccount();
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
