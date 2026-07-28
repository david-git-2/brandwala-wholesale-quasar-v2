<template>
  <q-card flat bordered class="q-pa-sm toolbar-card">
    <div class="row items-center q-col-gutter-sm">
      <div class="col-xs-12 col-sm-5 col-md-4">
        <q-input
          v-model="searchQuery"
          dense
          outlined
          placeholder="Search by source ID or note..."
          class="soft-input"
          clearable
        >
          <template #prepend>
            <q-icon name="search" size="xs" />
          </template>
        </q-input>
      </div>

      <div class="col-xs-6 col-sm-3 col-md-2">
        <q-select
          v-model="typeFilter"
          dense
          outlined
          emit-value
          map-options
          :options="typeOptions"
          label="Type"
          class="soft-input"
        />
      </div>

      <div class="col-xs-6 col-sm-3 col-md-2">
        <q-select
          v-model="sourceFilter"
          dense
          outlined
          emit-value
          map-options
          :options="sourceOptions"
          label="Source"
          class="soft-input"
        />
      </div>

      <div class="col-xs-12 col-sm-1 col-md-4 text-right">
        <q-btn
          flat
          round
          dense
          icon="refresh"
          color="primary"
          @click="$emit('refresh')"
        >
          <q-tooltip>Refresh Ledger</q-tooltip>
        </q-btn>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
const searchQuery = defineModel<string>('search', { default: '' });
const typeFilter = defineModel<string>('type', { default: 'all' });
const sourceFilter = defineModel<string>('source', { default: 'all' });

defineEmits<{
  (e: 'refresh'): void;
}>();

const typeOptions = [
  { label: 'All Types', value: 'all' },
  { label: 'Credit (IN)', value: 'credit' },
  { label: 'Debit (OUT)', value: 'debit' },
];

const sourceOptions = [
  { label: 'All Sources', value: 'all' },
  { label: 'Shop Order', value: 'shop_order' },
  { label: 'Vendor Purchase', value: 'vendor_purchase' },
  { label: 'Payout', value: 'payout' },
  { label: 'Adjustment', value: 'adjustment' },
];
</script>

<style scoped>
.toolbar-card {
  background: var(--bw-theme-surface);
  border-color: var(--bw-theme-border);
  border-radius: 10px;
}
</style>
