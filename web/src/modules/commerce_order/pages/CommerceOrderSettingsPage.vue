<template>
  <q-page class="q-pa-md commerce-order-settings-page">
    <!-- Hero / Header Card -->
    <q-card flat class="hero-surface floating-surface shadow-1 q-mb-md q-pa-md">
      <div class="row items-center justify-between">
        <div class="text-h6 text-weight-bold text-black">Commerce Order Settings</div>
      </div>
    </q-card>

    <q-card flat class="floating-surface shadow-1 q-pa-lg">
      <div v-if="loading" class="row justify-center q-py-xl">
        <q-spinner-dots size="40px" color="primary" />
      </div>

      <q-form v-else @submit="saveSettings" class="q-gutter-y-md">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-sm-6">
            <q-input
              v-model.number="form.default_cod_percent"
              type="number"
              step="0.01"
              outlined
              dense
              class="soft-input"
              label="Default COD Percentage"
              placeholder="e.g. 1.00 for 1%"
              :rules="[val => val >= 0 || 'Must be >= 0', val => val <= 100 || 'Must be <= 100']"
            >
              <template #prepend>
                <q-icon name="percent" color="primary" />
              </template>
            </q-input>
          </div>

          <div class="col-12 col-sm-6">
            <q-input
              v-model.number="form.default_delivery_charge"
              type="number"
              step="0.01"
              outlined
              dense
              class="soft-input"
              label="Default Delivery Charge"
              placeholder="e.g. 60.00"
              :rules="[val => val >= 0 || 'Must be >= 0']"
            >
              <template #prepend>
                <q-icon name="local_shipping" color="primary" />
              </template>
            </q-input>
          </div>

          <div class="col-12 col-sm-6">
            <q-input
              v-model.number="form.default_wrapping_charge"
              type="number"
              step="0.01"
              outlined
              dense
              class="soft-input"
              label="Default Wrapping Charge"
              placeholder="e.g. 15.00"
              :rules="[val => val >= 0 || 'Must be >= 0']"
            >
              <template #prepend>
                <q-icon name="redeem" color="primary" />
              </template>
            </q-input>
          </div>

          <div class="col-12 col-sm-6">
            <q-input
              v-model.number="form.default_invoice_print_charge"
              type="number"
              step="0.01"
              outlined
              dense
              class="soft-input"
              label="Default Invoice Print Charge"
              placeholder="e.g. 5.00"
              :rules="[val => val >= 0 || 'Must be >= 0']"
            >
              <template #prepend>
                <q-icon name="print" color="primary" />
              </template>
            </q-input>
          </div>
        </div>

        <div class="row justify-end q-mt-md">
          <q-btn
            type="submit"
            color="primary"
            label="Save Settings"
            no-caps
            unelevated
            class="pill-btn slim-btn"
            :loading="saving"
          />
        </div>
      </q-form>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { commerceOrderService } from '../services/commerceOrderService'
import { showSuccessNotification, showWarningDialog } from 'src/utils/appFeedback'

const authStore = useAuthStore()

// State
const loading = ref(true)
const saving = ref(false)

const form = reactive({
  default_cod_percent: 0,
  default_delivery_charge: 0,
  default_wrapping_charge: 0,
  default_invoice_print_charge: 0,
})

const loadSettings = async () => {
  if (!authStore.tenantId) return
  loading.value = true
  try {
    const res = await commerceOrderService.getCommerceOrderSettings(authStore.tenantId)
    if (res.success && res.data) {
      form.default_cod_percent = Number(res.data.default_cod_percent) || 0
      form.default_delivery_charge = Number(res.data.default_delivery_charge) || 0
      form.default_wrapping_charge = Number(res.data.default_wrapping_charge) || 0
      form.default_invoice_print_charge = Number(res.data.default_invoice_print_charge) || 0
    }
  } finally {
    loading.value = false
  }
}

const saveSettings = async () => {
  if (!authStore.tenantId) return
  saving.value = true
  try {
    const res = await commerceOrderService.upsertCommerceOrderSettings(authStore.tenantId, {
      default_cod_percent: form.default_cod_percent,
      default_delivery_charge: form.default_delivery_charge,
      default_wrapping_charge: form.default_wrapping_charge,
      default_invoice_print_charge: form.default_invoice_print_charge,
    })
    if (res.success) {
      showSuccessNotification('Commerce order settings saved successfully.')
    } else {
      showWarningDialog(res.error || 'Failed to save settings.')
    }
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  void loadSettings()
})
</script>

<style scoped>
.commerce-order-settings-page {
  background: transparent;
  color: #000;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.hero-surface {
  border-radius: 16px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}

.pill-btn {
  border-radius: 999px;
}

.slim-btn {
  min-height: 36px;
  padding-left: 16px;
  padding-right: 16px;
}

</style>
