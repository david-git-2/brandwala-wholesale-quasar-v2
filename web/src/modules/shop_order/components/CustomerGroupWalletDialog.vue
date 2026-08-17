<template>
  <q-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)">
    <q-card flat bordered class="customer-wallet-dialog">
      <q-card-section class="row items-center justify-between q-pb-sm">
        <div class="row items-center q-gutter-x-sm">
          <q-avatar size="36px" class="bg-primary-soft text-primary">
            <q-icon name="ph ph-wallet" size="20px" />
          </q-avatar>
          <div>
            <div class="text-subtitle1 text-weight-bold text-grey-9">
              {{ $t('shop_admin.access_wallet_title', { name: groupName }) }}
            </div>
            <div class="text-caption text-grey-7">
              {{ $t('shop_admin.access_wallet_subtitle') }}
            </div>
          </div>
        </div>
        <q-btn
          flat
          round
          dense
          icon="ph ph-x"
          v-close-popup
          :aria-label="$t('shop_admin.cancel')"
        />
      </q-card-section>

      <q-separator />

      <q-card-section class="q-pa-md">
        <div v-if="!billingProfileId" class="column items-center text-center q-pa-lg text-grey-7">
          <q-icon name="ph ph-wallet" size="36px" color="grey-5" class="q-mb-sm" />
          <div>{{ $t('shop_admin.access_wallet_no_profile') }}</div>
        </div>

        <div v-else-if="isAccountLoading" class="row q-col-gutter-sm">
          <div v-for="n in 3" :key="n" class="col-12 col-sm-4">
            <q-card flat bordered class="q-pa-md">
              <q-skeleton type="text" width="60%" class="q-mb-xs" />
              <q-skeleton type="text" width="80%" height="28px" class="q-mb-xs" />
              <q-skeleton type="text" width="90%" height="12px" />
            </q-card>
          </div>
        </div>

        <WalletAccountCard
          v-else
          :account="account"
          entity-type="customer"
          :entity-name="groupName"
          :allow-actions="false"
        />
      </q-card-section>

      <q-separator />

      <q-card-actions align="between" class="q-px-md q-py-sm">
        <q-btn
          v-if="billingProfileId"
          flat
          no-caps
          color="primary"
          icon="ph ph-arrow-square-out"
          :label="$t('shop_admin.access_wallet_open_full')"
          class="text-weight-bold"
          @click="onClickOpenFullWallet"
        />
        <q-space v-else />
        <q-btn flat no-caps :label="$t('shop_admin.cancel')" color="grey-7" v-close-popup />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import WalletAccountCard from 'src/modules/wallet/components/WalletAccountCard.vue';
import { useWalletAccount } from 'src/modules/wallet/composables/useWalletAccount';

const props = defineProps<{
  modelValue: boolean;
  groupName: string;
  billingProfileId: number | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const router = useRouter();
const route = useRoute();

const profileId = computed(() => props.billingProfileId ?? 0);
const { account, isAccountLoading } = useWalletAccount('customer', profileId);

const onClickOpenFullWallet = () => {
  if (!props.billingProfileId) return;
  emit('update:modelValue', false);
  void router.push({
    name: 'app-universal-wallet-page',
    params: {
      tenantSlug: route.params.tenantSlug,
      walletType: 'customers',
      entityId: String(props.billingProfileId),
    },
  });
};
</script>

<style scoped>
.customer-wallet-dialog {
  width: 700px;
  max-width: 95vw;
  border-radius: 14px;
}

.bg-primary-soft {
  background: var(--bw-theme-primary-soft, rgba(59, 130, 246, 0.1)) !important;
}
</style>
