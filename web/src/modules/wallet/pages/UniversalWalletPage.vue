<template>
  <q-page class="q-pa-md">
    <div class="q-gutter-y-md">
      <!-- Page Header -->
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col-xs-12 col-sm-8">
          <div class="text-overline text-primary text-weight-bold">FINANCIAL LEDGER</div>
          <h1 class="text-h5 text-weight-bold q-my-none text-ink">Universal Wallet Ledger</h1>
          <div class="text-caption text-muted">
            Single &amp; Double-entry multi-currency financial ledger across tenant, customers, vendors, couriers, and middle-men.
          </div>
        </div>
        <div class="col-xs-12 col-sm-4 text-right">
          <!-- Entity Type Switcher Tabs -->
          <q-card flat bordered class="q-pa-xs surface-card inline-block">
            <q-btn-toggle
              v-model="activeTab"
              flat
              dense
              no-caps
              toggle-color="primary"
              toggle-text-color="white"
              class="entity-toggle"
              :options="[
                { label: 'Tenant', value: 'tenant', icon: 'ph ph-buildings' },
                { label: 'Customer', value: 'customer', icon: 'ph ph-user' },
                { label: 'Vendor', value: 'vendor', icon: 'ph ph-storefront' },
                { label: 'Courier', value: 'courier', icon: 'ph ph-truck' },
                { label: 'Middleman', value: 'middleman', icon: 'ph ph-users-three' },
              ]"
            />
          </q-card>
        </div>
      </section>

      <!-- Sub-Bar for External Entity Selection -->
      <q-card v-if="activeTab !== 'tenant'" flat bordered class="q-pa-md surface-card">
        <div class="row items-center q-col-gutter-md">
          <div class="col-xs-12 col-sm-4">
            <q-input
              v-model.number="selectedEntityId"
              type="number"
              outlined
              dense
              min="1"
              :label="`${activeTab.toUpperCase()} Entity ID`"
              hint="Enter specific profile or partner ID"
            >
              <template #prepend>
                <q-icon name="ph ph-hash" size="xs" />
              </template>
            </q-input>
          </div>
          <div class="col-xs-12 col-sm-8 text-caption text-muted">
            <q-icon name="ph ph-info" class="q-mr-xs text-primary" />
            Viewing target ledger for <strong>{{ activeTab.toUpperCase() }} #{{ selectedEntityId }}</strong>.
          </div>
        </div>
      </q-card>

      <!-- Embedded Universal Wallet Component -->
      <UniversalWallet
        :key="`${activeTab}-${effectiveEntityId}`"
        :entity-type="activeTab"
        :entity-id="effectiveEntityId"
        :allow-adjustment="true"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { UniversalWalletEntityType } from '../types';
import UniversalWallet from '../components/UniversalWallet.vue';

const authStore = useAuthStore();
const activeTab = ref<UniversalWalletEntityType>('tenant');
const selectedEntityId = ref<number>(1);

const effectiveEntityId = computed(() => {
  if (activeTab.value === 'tenant') {
    return authStore.selectedTenant?.id ?? 1;
  }
  return selectedEntityId.value || 1;
});
</script>

<style scoped>
.text-ink {
  color: var(--bw-theme-ink);
}

.text-muted {
  color: var(--bw-theme-muted);
}

.surface-card {
  background: var(--bw-theme-surface);
  border-color: var(--bw-theme-border);
  border-radius: 10px;
}

.entity-toggle {
  border-radius: 8px;
}
</style>
