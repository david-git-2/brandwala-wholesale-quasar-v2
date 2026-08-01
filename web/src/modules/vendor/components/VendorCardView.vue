<template>
  <div class="row q-col-gutter-md">
    <div v-for="vendor in vendors" :key="vendor.id" class="col-12 col-sm-6 col-md-4">
      <q-card
        flat
        bordered
        class="vendor-card cursor-pointer floating-surface shadow-1 full-height column justify-between"
        @click="$emit('select', vendor)"
      >
        <q-card-section class="q-pb-xs">
          <div class="row items-center justify-between no-wrap q-mb-xs">
            <div class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
              {{ vendor.name }}
            </div>
            <q-chip dense square color="primary" text-color="white" class="vendor-code-chip text-caption">
              {{ vendor.code }}
            </q-chip>
          </div>

          <div class="text-caption text-grey-7 q-mb-sm row items-center q-gutter-x-xs">
            <q-icon name="ph ph-storefront" size="14px" color="primary" />
            <span>Market: <strong>{{ vendor.market_code }}</strong></span>
          </div>

          <div v-if="vendor.email" class="text-caption text-grey-8 ellipsis row items-center q-gutter-x-xs q-mb-xs">
            <q-icon name="ph ph-envelope-simple" size="14px" color="grey-6" />
            <span>{{ vendor.email }}</span>
          </div>

          <div v-if="vendor.phone" class="text-caption text-grey-8 ellipsis row items-center q-gutter-x-xs">
            <q-icon name="ph ph-phone" size="14px" color="grey-6" />
            <span>{{ vendor.phone }}</span>
          </div>
        </q-card-section>

        <q-card-actions class="q-pt-none q-px-md q-pb-md row justify-between items-center">
          <span class="text-caption text-grey-6">ID: #{{ vendor.id }}</span>
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-wallet"
            label="Wallet"
            class="wallet-btn"
            @click.stop="$emit('wallet', vendor)"
          >
            <q-tooltip>Open Universal Wallet</q-tooltip>
          </q-btn>
        </q-card-actions>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { Vendor } from '../types';

defineProps<{
  vendors: Vendor[];
}>();

defineEmits<{
  (e: 'select', vendor: Vendor): void;
  (e: 'wallet', vendor: Vendor): void;
}>();
</script>

<style scoped>
.vendor-card {
  border-radius: 12px;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}

.vendor-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08) !important;
}

.vendor-code-chip {
  border-radius: 6px;
}

.wallet-btn {
  border-radius: 6px;
}
</style>
