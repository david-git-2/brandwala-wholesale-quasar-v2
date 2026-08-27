<template>
  <q-card flat class="tenant-danger-card floating-surface shadow-1 q-mt-md">
    <q-card-section class="q-pa-md">
      <div class="row items-center justify-between q-col-gutter-sm">
        <div class="col-12 col-sm-auto row items-center no-wrap q-gutter-sm">
          <q-avatar size="36px" color="red-1" text-color="negative" font-size="20px" square class="rounded-borders">
            <q-icon name="ph ph-warning-octagon" />
          </q-avatar>
          <div>
            <div class="row items-center q-gutter-xs">
              <span class="text-subtitle2 text-weight-bold text-negative">Danger Zone</span>
              <q-badge color="red-2" text-color="negative" class="text-caption text-weight-bold">Restricted</q-badge>
            </div>
            <div class="text-caption text-grey-7">
              Destructive organizational actions for clean-slate resets and test data wiping.
            </div>
          </div>
        </div>
      </div>
    </q-card-section>

    <q-separator class="danger-separator" />

    <q-card-section class="q-pa-md">
      <div class="row items-center justify-between q-col-gutter-md">
        <div class="col-12 col-md-8">
          <div class="text-subtitle2 text-weight-bold text-grey-9">Purge Operational Data (Clean Slate)</div>
          <div class="text-caption text-grey-7 q-mt-xs">
            Permanently wipes all inbound shipments, global warehouse stocks, sales invoices, shop orders, carts, and ledger transactions.
            Master products, categories, stock locations, vendors, and user memberships are strictly preserved.
          </div>
        </div>
        <div class="col-12 col-md-4 text-right">
          <q-btn
            outline
            dense
            no-caps
            color="negative"
            icon="ph ph-trash"
            label="Reset Operational Data"
            class="pill-btn slim-btn q-px-md"
            @click="emit('open-purge-modal')"
          />
        </div>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import type { Tenant } from '../types';

defineProps<{
  tenant: Tenant;
}>();

const emit = defineEmits<{
  (e: 'open-purge-modal'): void;
}>();
</script>

<style scoped>
.tenant-danger-card {
  border-radius: 12px;
  border: 1px solid rgba(229, 57, 53, 0.25);
  background: rgba(255, 255, 255, 0.7);
}

.danger-separator {
  background: rgba(229, 57, 53, 0.15);
}

.pill-btn {
  border-radius: 8px;
}

.slim-btn {
  min-height: 32px;
}
</style>
