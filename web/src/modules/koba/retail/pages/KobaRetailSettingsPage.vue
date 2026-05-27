<template>
  <q-page class="q-pa-md bw-page">
    <div class="row items-center q-mb-md q-gutter-sm">
      <q-btn flat round icon="arrow_back" color="grey-8" :to="{ name: 'app-koba-retail-page' }" />
      <div>
        <div class="text-h5 text-weight-bold">Retail Settings</div>
        <div class="text-caption text-grey-7">Configure commission rules and charges</div>
      </div>
    </div>

    <div v-if="settingsStore.loading && !settingsStore.settings" class="flex flex-center q-pa-xl">
      <q-spinner color="primary" size="3em" />
    </div>

    <div v-else-if="settingsStore.error && !settingsStore.settings" class="text-negative text-center q-pa-md">
      {{ settingsStore.error }}
    </div>

    <div v-else-if="settingsStore.settings" class="row q-col-gutter-md">
      <!-- Left Column: Core Charges & Profit Splits -->
      <div class="col-12 col-md-6">
        <q-card flat bordered class="q-mb-md auth-card">
          <q-card-section>
            <div class="text-h6 text-weight-bold q-mb-sm">Core Charges</div>
            <div class="q-gutter-md">
              <q-input
                v-model.number="form.cod_charge_pct"
                type="number"
                label="COD Charge (%)"
                outlined dense
                suffix="%"
              />
              <q-input
                v-model.number="form.gateway_charge_flat"
                type="number"
                label="Gateway Charge (Flat)"
                outlined dense
                prefix="৳"
                hint="Implicit deduction from gross commission"
              />
              <q-input
                v-model.number="form.packing_charge_flat"
                type="number"
                label="Packing Charge (Flat)"
                outlined dense
                prefix="৳"
              />
              <q-input
                v-model.number="form.invoice_charge_flat"
                type="number"
                label="Invoice Charge (Flat)"
                outlined dense
                prefix="৳"
              />
            </div>
          </q-card-section>
        </q-card>

        <q-card flat bordered class="auth-card">
          <q-card-section>
            <div class="text-h6 text-weight-bold q-mb-sm">Extra Profit Share</div>
            <div class="row q-col-gutter-sm">
              <div class="col-6">
                <q-input
                  v-model.number="form.extra_profit_user_pct"
                  type="number"
                  label="User Share (%)"
                  outlined dense
                  suffix="%"
                />
              </div>
              <div class="col-6">
                <q-input
                  v-model.number="form.extra_profit_company_pct"
                  type="number"
                  label="Company Share (%)"
                  outlined dense
                  suffix="%"
                />
              </div>
            </div>
          </q-card-section>
        </q-card>
      </div>

      <!-- Right Column: Delivery Rates -->
      <div class="col-12 col-md-6">
        <q-card flat bordered class="auth-card full-height">
          <q-card-section>
            <div class="text-h6 text-weight-bold q-mb-sm">Delivery Rates</div>
            <div class="text-caption text-grey-7 q-mb-md">Map specific districts to delivery charges. Use "default" for all other locations.</div>
            
            <q-list separator class="q-mb-md">
              <q-item v-for="(rate, key) in form.delivery_rates" :key="key" class="q-px-none">
                <q-item-section>
                  <q-input v-model="rateKeys[key]" label="Location/District" outlined dense :disable="key === 'default'" @blur="updateRateKey(key)" />
                </q-item-section>
                <q-item-section>
                  <q-input v-model.number="form.delivery_rates[key]" type="number" label="Charge" outlined dense prefix="৳" />
                </q-item-section>
                <q-item-section side>
                  <q-btn flat round color="negative" icon="delete" size="sm" :disable="key === 'default'" @click="removeRate(key)" />
                </q-item-section>
              </q-item>
            </q-list>

            <q-btn outline color="primary" icon="add" label="Add Location" class="w-full" no-caps @click="addRate" />
          </q-card-section>
        </q-card>
      </div>

      <div class="col-12 flex justify-end q-mt-lg">
        <q-btn
          color="primary"
          label="Save Settings"
          icon="save"
          unelevated
          class="q-px-xl"
          no-caps
          :loading="settingsStore.loading"
          @click="onSave"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, reactive } from 'vue'
import { useQuasar } from 'quasar'
import { useKobaSettingsStore } from 'src/modules/koba/retail/stores/kobaSettingsStore'

const $q = useQuasar()
const settingsStore = useKobaSettingsStore()

const form = reactive({
  cod_charge_pct: 1,
  gateway_charge_flat: 20,
  packing_charge_flat: 37,
  invoice_charge_flat: 1,
  extra_profit_user_pct: 90,
  extra_profit_company_pct: 10,
  delivery_rates: {} as Record<string, number>
})

// To handle key edits
const rateKeys = ref<Record<string, string>>({})

onMounted(async () => {
  await settingsStore.fetchSettings()
  if (settingsStore.settings) {
    form.cod_charge_pct = settingsStore.settings.cod_charge_pct
    form.gateway_charge_flat = settingsStore.settings.gateway_charge_flat
    form.packing_charge_flat = settingsStore.settings.packing_charge_flat
    form.invoice_charge_flat = settingsStore.settings.invoice_charge_flat
    form.extra_profit_user_pct = settingsStore.settings.extra_profit_user_pct
    form.extra_profit_company_pct = settingsStore.settings.extra_profit_company_pct
    form.delivery_rates = JSON.parse(JSON.stringify(settingsStore.settings.delivery_rates || {}))
    
    // Ensure default exists
    if (!form.delivery_rates['default']) {
      form.delivery_rates['default'] = 110
    }

    Object.keys(form.delivery_rates).forEach(k => {
      rateKeys.value[k] = k
    })
  }
})

function updateRateKey(oldKey: string) {
  const newKey = rateKeys.value[oldKey]
  if (newKey && newKey !== oldKey) {
    form.delivery_rates[newKey] = form.delivery_rates[oldKey]
    delete form.delivery_rates[oldKey]
    rateKeys.value[newKey] = newKey
    delete rateKeys.value[oldKey]
  }
}

function addRate() {
  const newKey = 'New Location ' + Object.keys(form.delivery_rates).length
  form.delivery_rates[newKey] = 100
  rateKeys.value[newKey] = newKey
}

function removeRate(key: string) {
  delete form.delivery_rates[key]
  delete rateKeys.value[key]
}

async function onSave() {
  const success = await settingsStore.updateSettings({
    cod_charge_pct: form.cod_charge_pct,
    gateway_charge_flat: form.gateway_charge_flat,
    packing_charge_flat: form.packing_charge_flat,
    invoice_charge_flat: form.invoice_charge_flat,
    extra_profit_user_pct: form.extra_profit_user_pct,
    extra_profit_company_pct: form.extra_profit_company_pct,
    delivery_rates: form.delivery_rates
  })

  if (success) {
    $q.notify({ type: 'positive', message: 'Settings updated successfully.' })
  } else {
    $q.notify({ type: 'negative', message: settingsStore.error || 'Failed to update settings.' })
  }
}
</script>

<style scoped>
.auth-card {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.95);
}
.w-full {
  width: 100%;
}
</style>
