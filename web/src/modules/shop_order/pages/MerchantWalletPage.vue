<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline text-primary">Merchant portal</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Merchant wallet</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Available balance, pending profit, and ledger history for your dropship account.
          </p>
        </div>
        <div class="col-auto row q-gutter-sm">
          <q-btn
            outline
            color="primary"
            no-caps
            icon="ph ph-arrow-left"
            label="My Orders"
            :to="{ name: 'shop-orders-page' }"
          />
        </div>
      </section>

      <MerchantWalletSkeleton v-if="isLoading" />

      <template v-else-if="isError">
        <q-banner class="bg-negative text-white rounded-borders" rounded>
          {{ errorMessage }}
        </q-banner>
      </template>

      <template v-else>
        <SimplifiedWalletView
          :account="accountAdapter"
          entity-type="customer"
          :entity-id="summary?.billing_profile_id || 1"
          entity-name="Merchant Account"
          :allow-transfer="false"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useMerchantWalletQuery } from '../composables/useMerchantWalletQuery';
import MerchantWalletSkeleton from '../components/MerchantWalletSkeleton.vue';
import SimplifiedWalletView from 'src/modules/wallet/components/SimplifiedWalletView.vue';
import { parseSupabaseError } from 'src/utils/appFeedback';
import type { WalletAccount } from 'src/modules/wallet/types';

const { summary, isLoading, isError, error } = useMerchantWalletQuery(true);

const errorMessage = computed(() =>
  parseSupabaseError(error.value, 'Unable to load merchant wallet'),
);

const accountAdapter = computed<WalletAccount | null>(() => {
  if (!summary.value) return null;
  const avail = summary.value.available_balance || 0;
  const pend = summary.value.pending_balance || 0;
  const lock = summary.value.locked_balance || 0;
  return {
    id: summary.value.billing_profile_id || 1,
    tenant_id: 1,
    entity_type: 'customer',
    entity_id: summary.value.billing_profile_id || 1,
    currency_code: summary.value.currency || 'BDT',
    available_balance: avail,
    pending_balance: pend,
    locked_balance: lock,
    total_balance: avail + pend + lock,
  };
});
</script>
