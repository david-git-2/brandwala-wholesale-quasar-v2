<template>
  <q-page class="q-pa-md thrift-settings-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="text-h6 text-weight-bold">Thrift Settings</div>
        <div class="text-caption text-grey-8">Default purchase price applied to new stock entries</div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1" style="max-width: 480px;">
      <q-card-section class="q-gutter-md">
        <q-input
          v-model.number="form.default_purchase_price_gbp"
          type="number"
          step="0.01"
          min="0"
          outlined
          dense
          label="Default purchase price (GBP) *"
          prefix="£"
          class="soft-input"
          :rules="[val => val >= 0 || 'Cannot be negative']"
        />
        <div class="row justify-end">
          <q-btn
            color="primary"
            no-caps
            size="sm"
            class="pill-btn slim-btn"
            label="Save Settings"
            :loading="settingsStore.loading"
            @click="save"
          />
        </div>
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftSettingsStore } from '../stores/thriftSettingsStore';
import { useQuasar } from 'quasar';

const $q = useQuasar();
const authStore = useAuthStore();
const settingsStore = useThriftSettingsStore();

const form = ref({ default_purchase_price_gbp: 0 });

onMounted(async () => {
  if (!authStore.tenantId) return;
  await settingsStore.loadSettings(authStore.tenantId);
  form.value.default_purchase_price_gbp = settingsStore.defaultPurchasePriceGbp;
});

async function save() {
  if (!authStore.tenantId) return;
  try {
    await settingsStore.saveSettings(authStore.tenantId, form.value.default_purchase_price_gbp);
    $q.notify({ type: 'positive', message: 'Settings saved' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
  }
}
</script>

<style scoped>
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
}
.hero-surface { border-radius: 16px; }
.pill-btn { border-radius: 999px; }
.slim-btn { min-height: 32px; }
.soft-input :deep(.q-field__control) { border-radius: 12px; }
</style>
