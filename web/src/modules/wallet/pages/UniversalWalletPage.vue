<template>
  <q-page class="wallet-page-container q-pa-md bg-grey-1" style="min-height: calc(100vh - 55px)">
    <UniversalWalletPageSkeleton v-if="isInitialLoading" />

    <div v-else class="q-gutter-y-md">
      <!-- Detail Page Header -->
      <section class="row items-center justify-between q-col-gutter-md">
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
            <h1 class="text-h5 text-weight-bolder text-grey-9 q-my-none">
              {{ loadedEntityName || 'Wallet Detail' }}
            </h1>
          </div>
        </div>

        <div class="col-auto row items-center q-gutter-x-sm">
          <!-- Accountant View Toggle Link -->
          <q-btn
            flat
            dense
            no-caps
            :icon="isAccountantView ? 'ph ph-sparkle' : 'ph ph-sliders-horizontal'"
            :label="isAccountantView ? 'Simplified View' : 'Accountant View'"
            color="grey-8"
            class="bg-white q-px-sm rounded-borders border-grey-3"
            @click="isAccountantView = !isAccountantView"
          />

          <LearnMoreHelpBtn
            guide-id="universal_wallet"
            label="Help Center"
            icon="ph ph-question-mark"
            color="primary"
            class="bg-primary-soft text-weight-bold q-px-sm rounded-borders"
          />
        </div>
      </section>

      <!-- Default: Simplified View -->
      <section v-if="!isAccountantView">
        <SimplifiedWalletView
          :key="`simp-${effectiveEntityType}-${effectiveEntityId}`"
          :account="account"
          :entity-type="effectiveEntityType"
          :entity-id="effectiveEntityId"
          :entity-name="loadedEntityName"
          :allow-transfer="true"
          @open-transfer="isTransferModalOpen = true"
          @open-deposit="isDepositModalOpen = true"
          @open-withdraw="isWithdrawModalOpen = true"
          @open-statement="isAccountantView = true; activeSubView = 'statement'"
        />
      </section>

      <!-- Accountant / Advanced View (Hidden behind link) -->
      <section v-else class="q-gutter-y-md">
        <div class="row items-center justify-between bg-white q-pa-xs rounded-borders border-grey-3">
          <q-btn-toggle
            v-model="activeSubView"
            dense
            unelevated
            toggle-color="primary"
            toggle-text-color="white"
            text-color="grey-8"
            class="bg-grey-2 q-pa-xs rounded-borders"
            no-caps
            :options="[
              { label: 'Ledger Audit', value: 'overview', icon: 'ph ph-chart-pie-slice' },
              { label: 'Account Statement', value: 'statement', icon: 'ph ph-receipt' },
              { label: 'Platform Reports', value: 'reports', icon: 'ph ph-trend-up' },
            ]"
          />

          <q-btn
            unelevated
            color="primary"
            icon="ph ph-arrows-left-right"
            label="Transfer Buckets"
            no-caps
            dense
            class="text-weight-bold q-px-md rounded-borders"
            @click="isTransferModalOpen = true"
          />
        </div>

        <!-- Accountant View 1: Ledger Audit -->
        <div v-if="activeSubView === 'overview'" class="q-gutter-y-md">
          <WalletAccountCard
            :key="`acc-${effectiveEntityType}-${effectiveEntityId}`"
            :account="account"
            :entity-type="effectiveEntityType"
            :entity-name="loadedEntityName"
            @open-transfer="isTransferModalOpen = true"
          />

          <UniversalWallet
            :key="`ledger-${effectiveEntityType}-${effectiveEntityId}`"
            :entity-type="effectiveEntityType"
            :entity-id="effectiveEntityId"
            :entity-name="loadedEntityName"
            :allow-adjustment="true"
          />
        </div>

        <!-- Accountant View 2: Account Statement -->
        <div v-else-if="activeSubView === 'statement'">
          <WalletStatementView
            :key="`stmt-${effectiveEntityType}-${effectiveEntityId}`"
            :entity-type="effectiveEntityType"
            :entity-id="effectiveEntityId"
            :entity-name="loadedEntityName"
          />
        </div>

        <!-- Accountant View 3: Platform Reports -->
        <div v-else-if="activeSubView === 'reports'">
          <WalletReportsView />
        </div>
      </section>
    </div>

    <!-- Bucket Transfer Modal -->
    <WalletTransferModal
      v-model="isTransferModalOpen"
      :entity-type="effectiveEntityType"
      :entity-id="effectiveEntityId"
      :entity-name="loadedEntityName"
      @transferred="onTransactionCompleted"
    />

    <!-- Deposit Modal -->
    <WalletDepositModal
      v-model="isDepositModalOpen"
      :entity-type="effectiveEntityType"
      :entity-id="effectiveEntityId"
      :entity-name="loadedEntityName"
      @deposited="onTransactionCompleted"
    />

    <!-- Withdraw Modal -->
    <WalletWithdrawModal
      v-model="isWithdrawModalOpen"
      :entity-type="effectiveEntityType"
      :entity-id="effectiveEntityId"
      :entity-name="loadedEntityName"
      :available-balance="account?.available_balance || 0"
      @withdrawn="onTransactionCompleted"
    />
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { UniversalWalletEntityType } from '../types';
import { getEntityTypeFromSlug, getSlugFromEntityType } from '../utils/walletSlugMap';
import UniversalWallet from '../components/UniversalWallet.vue';
import UniversalWalletPageSkeleton from '../components/UniversalWalletPageSkeleton.vue';
import WalletAccountCard from '../components/WalletAccountCard.vue';
import WalletTransferModal from '../components/WalletTransferModal.vue';
import WalletDepositModal from '../components/WalletDepositModal.vue';
import WalletWithdrawModal from '../components/WalletWithdrawModal.vue';
import WalletStatementView from '../components/WalletStatementView.vue';
import WalletReportsView from '../components/WalletReportsView.vue';
import SimplifiedWalletView from '../components/SimplifiedWalletView.vue';
import LearnMoreHelpBtn from 'src/modules/help/components/LearnMoreHelpBtn.vue';
import { useWalletAccounts } from '../composables/useWalletAccounts';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

const isInitialLoading = ref<boolean>(true);
const isAccountantView = ref<boolean>(false);
const activeSubView = ref<'overview' | 'statement' | 'reports'>('overview');
const loadedEntityName = ref<string>('');

const isTransferModalOpen = ref<boolean>(false);
const isDepositModalOpen = ref<boolean>(false);
const isWithdrawModalOpen = ref<boolean>(false);

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

const { account, refetchAccount } = useWalletAccounts(
  () => effectiveEntityType.value,
  () => effectiveEntityId.value,
);

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

function onTransactionCompleted() {
  void refetchAccount();
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
.border-grey-3 {
  border: 1px solid #e2e8f0;
}
</style>
