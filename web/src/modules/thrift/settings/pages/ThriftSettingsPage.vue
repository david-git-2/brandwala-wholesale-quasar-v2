<template>
  <q-page class="q-pa-md thrift-settings-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="text-h6 text-weight-bold">Thrift Settings</div>
        <div class="text-caption text-grey-8">
          Configure defaults and ops cost inputs for Thrift vertical
        </div>
      </q-card-section>
    </q-card>

    <div class="row q-col-gutter-md">
      <div class="col-12 col-md-6">
        <q-card flat class="floating-surface shadow-1 h-100">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold q-mb-md text-primary">
              Registration Defaults
            </div>
            <q-form @submit.prevent="save" class="q-gutter-md">
              <q-input
                v-model.number="form.defaultOriginUnitPrice"
                type="number"
                step="0.01"
                min="0"
                outlined
                dense
                label="Default origin unit price *"
                class="soft-input"
                :rules="[(val) => val >= 0 || 'Cannot be negative']"
              />
              <div class="text-caption text-grey-7">
                Currency symbols come from the shipment when registering stock items.
              </div>
            </q-form>
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 col-md-6">
        <q-card flat class="floating-surface shadow-1 h-100">
          <q-card-section class="q-gutter-md">
            <div class="text-subtitle1 text-weight-bold text-primary">Ops Unit Costs</div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="form.handTagUnitCost"
                  type="number"
                  step="0.01"
                  min="0"
                  outlined
                  dense
                  label="Hand-tag unit cost"
                  class="soft-input"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="form.handTagUnitCurrencyId"
                  :options="currencies"
                  option-value="id"
                  :option-label="currencyOptionLabel"
                  emit-value
                  map-options
                  outlined
                  dense
                  label="Hand-tag currency"
                  class="soft-input"
                  clearable
                />
              </div>
            </div>

            <div class="row q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-input
                  v-model.number="form.stickerUnitCost"
                  type="number"
                  step="0.01"
                  min="0"
                  outlined
                  dense
                  label="Sticker unit cost"
                  class="soft-input"
                />
              </div>
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="form.stickerUnitCurrencyId"
                  :options="currencies"
                  option-value="id"
                  :option-label="currencyOptionLabel"
                  emit-value
                  map-options
                  outlined
                  dense
                  label="Sticker currency"
                  class="soft-input"
                  clearable
                />
              </div>
            </div>

            <div class="text-caption text-grey-7">
              These values populate the ops cost portion of the landed unit cost formula.
            </div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <div class="row justify-end q-mt-md q-mr-sm">
      <q-btn
        color="primary"
        no-caps
        size="sm"
        class="pill-btn slim-btn"
        label="Save Settings"
        :loading="updateSettingsMutation.isPending.value"
        @click="save"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watchEffect } from 'vue';
import { storeToRefs } from 'pinia';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import {
  useThriftSettingsQuery,
  useUpdateThriftSettingsMutation,
} from '../composables/useThriftSettingsQuery';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { useTenantPreferenceStore } from 'src/modules/tenant/stores/tenantPreferenceStore';
import { useQuasar } from 'quasar';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';

const $q = useQuasar();
const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const preferenceStore = useTenantPreferenceStore();

const { data: settings } = useThriftSettingsQuery(tenantId);
const { data: currenciesData } = useThriftCurrenciesQuery();
const currencies = computed(() => currenciesData.value || []);
const updateSettingsMutation = useUpdateThriftSettingsMutation(tenantId);

const form = ref({
  defaultOriginUnitPrice: 0,
  handTagUnitCost: null as number | null,
  handTagUnitCurrencyId: null as number | null,
  stickerUnitCost: null as number | null,
  stickerUnitCurrencyId: null as number | null,
});

watchEffect(() => {
  if (tenantId.value) {
    void preferenceStore.ensureLoaded(tenantId.value);
  }
  if (settings.value) {
    form.value.defaultOriginUnitPrice = settings.value.default_origin_unit_price ?? 0;
    form.value.handTagUnitCost = settings.value.hand_tag_unit_cost ?? null;
    form.value.handTagUnitCurrencyId =
      settings.value.hand_tag_unit_currency_id || preferenceStore.thriftDefaultCostCurrencyId;
    form.value.stickerUnitCost = settings.value.sticker_unit_cost ?? null;
    form.value.stickerUnitCurrencyId =
      settings.value.sticker_unit_currency_id || preferenceStore.thriftDefaultCostCurrencyId;
  }
});

function currencyOptionLabel(option: ThriftCurrency) {
  return `${option.code} (${option.symbol}) — ${option.name}`;
}

async function save() {
  if (!authStore.tenantId) return;
  if (form.value.defaultOriginUnitPrice < 0) {
    $q.notify({ type: 'negative', message: 'Default origin unit price cannot be negative' });
    return;
  }

  try {
    await updateSettingsMutation.mutateAsync({
      defaultOriginUnitPrice: form.value.defaultOriginUnitPrice,
      handTagUnitCost: form.value.handTagUnitCost,
      handTagUnitCurrencyId: form.value.handTagUnitCurrencyId,
      stickerUnitCost: form.value.stickerUnitCost,
      stickerUnitCurrencyId: form.value.stickerUnitCurrencyId,
    });
    $q.notify({ type: 'positive', message: 'Settings saved successfully' });
  } catch (err: unknown) {
    $q.notify({ type: 'negative', message: (err as Error).message || 'Save failed' });
  }
}
</script>

<style scoped>
.hero-surface {
  border-radius: 16px;
}
.pill-btn {
  border-radius: 999px;
}
.slim-btn {
  min-height: 32px;
}
.soft-input :deep(.q-field__control) {
  border-radius: 12px;
}
.h-100 {
  height: 100%;
}
</style>
