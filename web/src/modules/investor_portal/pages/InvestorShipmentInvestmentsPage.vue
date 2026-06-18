<template>
  <q-page class="q-pa-md costing-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1 q-pa-md">
      <AppPageHeader
        title="Shipment investments"
        subtitle="Cost-share and computed profit per shipment"
      />
    </q-card>

    <PageInitialLoader v-if="loading" message="Loading investments..." />

    <q-banner v-else-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <q-card v-else flat class="floating-surface shadow-1 q-pa-md">
      <q-list separator v-if="investments.length">
        <q-item v-for="item in investments" :key="item.id">
          <q-item-section>
            <q-item-label>Shipment #{{ item.shipment_id }}</q-item-label>
            <q-item-label caption>
              Share {{ item.cost_share_pct ?? 0 }}% · Status {{ item.profit_status }}
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-item-label>{{ formatCurrency(item.computed_profit) }}</q-item-label>
            <q-item-label caption>profit</q-item-label>
          </q-item-section>
        </q-item>
      </q-list>
      <div v-else class="text-grey-7">No shipment investments found.</div>
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvestorPortalStore } from '../stores/investorPortalStore'

const authStore = useAuthStore()
const investorPortalStore = useInvestorPortalStore()

const loading = ref(true)
const error = ref<string | null>(null)

const investments = computed(() => investorPortalStore.portfolio?.active_investments ?? [])

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('en-BD', { style: 'currency', currency: 'BDT', maximumFractionDigits: 0 }).format(
    Number(value ?? 0),
  )

onMounted(async () => {
  const investorId = authStore.member?.id
  if (!investorId) {
    error.value = 'Investor account not linked.'
    loading.value = false
    return
  }

  const result = await investorPortalStore.loadPortfolio(investorId)
  if (!result.success) {
    error.value = result.error ?? 'Failed to load investments.'
  }
  loading.value = false
})
</script>
