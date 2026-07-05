<template>
  <q-page class="q-pa-md costing-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1 q-pa-md">
      <AppPageHeader
        title="Profit Report"
        subtitle="Generate time-period capital summaries and profit earnings reports"
      />
    </q-card>

    <q-card flat class="floating-surface shadow-1 q-pa-md q-mb-md">
      <div class="row q-col-gutter-md items-end">
        <div class="col-12 col-sm-4">
          <q-input v-model="startDate" label="Start Date" outlined dense readonly>
            <template #append>
              <q-icon name="event" class="cursor-pointer">
                <q-popup-proxy ref="startPopup" cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="startDate" mask="YYYY-MM-DD" @update:model-value="() => startPopup?.hide()">
                    <div class="row items-center justify-end">
                      <q-btn v-close-popup label="Close" color="primary" flat />
                    </div>
                  </q-date>
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
        </div>

        <div class="col-12 col-sm-4">
          <q-input v-model="endDate" label="End Date" outlined dense readonly>
            <template #append>
              <q-icon name="event" class="cursor-pointer">
                <q-popup-proxy ref="endPopup" cover transition-show="scale" transition-hide="scale">
                  <q-date v-model="endDate" mask="YYYY-MM-DD" @update:model-value="() => endPopup?.hide()">
                    <div class="row items-center justify-end">
                      <q-btn v-close-popup label="Close" color="primary" flat />
                    </div>
                  </q-date>
                </q-popup-proxy>
              </q-icon>
            </template>
          </q-input>
        </div>

        <div class="col-12 col-sm-4">
          <q-btn
            color="primary"
            label="Generate Report"
            class="full-width"
            unelevated
            :loading="loading"
            @click="generateReport"
          />
        </div>
      </div>
    </q-card>

    <q-banner v-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <template v-if="report">
      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-6 col-md-4" v-for="card in reportCards" :key="card.label">
          <q-card flat class="floating-surface shadow-1 q-pa-md" :class="card.class">
            <div class="text-caption text-grey-7">{{ card.label }}</div>
            <div class="text-h6 text-weight-bold">{{ formatCurrency(card.value) }}</div>
          </q-card>
        </div>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import type { QPopupProxy } from 'quasar'

import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { investorPortalService } from '../services/investorPortalService'

const authStore = useAuthStore()

const startPopup = ref<QPopupProxy | null>(null)
const endPopup = ref<QPopupProxy | null>(null)

const getFirstDayOfMonth = () => {
  const d = new Date()
  return new Date(d.getFullYear(), d.getMonth(), 1).toISOString().slice(0, 10)
}

const getToday = () => new Date().toISOString().slice(0, 10)

const startDate = ref(getFirstDayOfMonth())
const endDate = ref(getToday())
const loading = ref(false)
const error = ref<string | null>(null)
const report = ref<any | null>(null)

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('en-BD', { style: 'currency', currency: 'BDT', maximumFractionDigits: 0 }).format(
    Number(value ?? 0),
  )

const reportCards = computed(() => {
  if (!report.value) return []

  return [
    { label: 'Starting Balance', value: report.value.starting_balance },
    { label: 'Deposits in Period', value: report.value.deposits_sum },
    { label: 'Profit Earned in Period', value: report.value.profit_earned_sum },
    { label: 'Withdrawals in Period', value: report.value.withdrawals_sum },
    { label: 'Ending Balance', value: report.value.ending_balance, class: 'bg-indigo-1 text-indigo-9' },
  ]
})

const generateReport = async () => {
  loading.value = true
  error.value = null
  report.value = null

  const tenantId = authStore.tenantId
  const investorId = authStore.member?.id

  if (!tenantId || !investorId) {
    error.value = 'Auth session context invalid.'
    loading.value = false
    return
  }

  const result = await investorPortalService.getCapitalReport(
    tenantId,
    investorId,
    startDate.value,
    endDate.value
  )

  if (!result.success) {
    error.value = result.error ?? 'Failed to generate report.'
  } else {
    report.value = result.data
  }
  loading.value = false
}
</script>
