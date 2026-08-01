<template>
  <q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
    <q-card flat bordered class="vendor-wallet-dialog font-sans">
      <!-- Header -->
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div class="row items-center q-gutter-x-sm">
          <q-avatar size="36px" class="bg-primary-soft text-primary">
            <q-icon name="ph ph-wallet" size="20px" />
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bold text-grey-9">
              {{ vendor?.name || 'Vendor' }} Wallet
            </div>
            <div class="text-caption text-grey-7">
              Market: <strong>{{ vendor?.market_code }}</strong> • Code: <strong>{{ vendor?.code }}</strong>
            </div>
          </div>
        </div>
        <q-btn flat round dense icon="ph ph-x" v-close-popup aria-label="Close" />
      </q-card-section>

      <q-separator />

      <!-- Body Section -->
      <q-card-section class="q-pa-md">
        <!-- Loading Skeleton -->
        <div v-if="isAccountLoading" class="row q-col-gutter-sm">
          <div v-for="n in 3" :key="n" class="col-12 col-sm-4">
            <q-card flat bordered class="q-pa-md">
              <q-skeleton type="text" width="60%" class="q-mb-xs" />
              <q-skeleton type="text" width="80%" height="28px" class="q-mb-xs" />
              <q-skeleton type="text" width="90%" height="12px" />
            </q-card>
          </div>
        </div>

        <!-- 3 Pockets View -->
        <template v-else>
          <WalletAccountCard
            :account="account"
            entity-type="vendor"
            :entity-name="vendor?.name || ''"
            :allow-actions="false"
          />
        </template>
      </q-card-section>

      <q-separator />

      <!-- Actions Footer -->
      <q-card-actions align="between" class="q-px-md q-py-sm">
        <q-btn
          flat
          no-caps
          color="primary"
          icon="ph ph-arrow-square-out"
          label="Open Full Universal Wallet Page"
          class="text-weight-bold"
          @click="onClickOpenFullWallet"
        />
        <q-btn flat no-caps label="Close" color="grey-7" v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter, useRoute } from 'vue-router';

import WalletAccountCard from 'src/modules/wallet/components/WalletAccountCard.vue';
import { useWalletAccounts } from 'src/modules/wallet/composables/useWalletAccounts';
import type { Vendor } from '../types';

const props = defineProps<{
  modelValue: boolean;
  vendor: Vendor | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const router = useRouter();
const route = useRoute();

const vendorId = computed(() => props.vendor?.id ?? 0);
const { account, isAccountLoading } = useWalletAccounts('vendor', vendorId);

const onClickOpenFullWallet = () => {
  if (!props.vendor) return;
  emit('update:modelValue', false);

  const tenantSlug = route.params.tenantSlug;
  void router.push({
    name: 'app-universal-wallet-page',
    params: { tenantSlug },
    query: { entity_type: 'vendor', entity_id: props.vendor.id },
  });
};
</script>

<style scoped>
.vendor-wallet-dialog {
  width: 700px;
  max-width: 95vw;
  border-radius: 14px;
}

.bg-primary-soft {
  background: rgba(var(--q-primary-rgb, 59, 130, 246), 0.1) !important;
}
</style>
