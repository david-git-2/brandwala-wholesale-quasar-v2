<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section>
        <div class="text-overline">Platform</div>
        <h1 class="text-h5 q-my-none">Global Reference Data</h1>
        <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
          Manage platform-wide catalogs used across tenants.
        </p>
      </section>

      <div class="row q-col-gutter-md">
        <div v-for="card in cards" :key="card.to" class="col-12 col-sm-6 col-md-3">
          <q-card flat bordered class="cursor-pointer" @click="go(card.to)">
            <q-card-section>
              <q-icon :name="card.icon" size="28px" color="primary" />
              <div class="text-subtitle1 q-mt-sm">{{ card.title }}</div>
              <div class="text-body2 text-grey-7">{{ card.caption }}</div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'

const router = useRouter()

const cards = [
  { title: 'Markets', caption: 'ISO country markets', icon: 'public', to: '/platform/reference/markets' },
  { title: 'Currencies', caption: 'Global currencies', icon: 'payments', to: '/platform/reference/currencies' },
  { title: 'Payment Methods', caption: 'BD and international', icon: 'account_balance_wallet', to: '/platform/reference/payment-methods' },
  { title: 'Units of Measure', caption: 'Weight, count, volume', icon: 'straighten', to: '/platform/reference/units' },
] as const

const go = (to: string) => {
  void router.push(to)
}
</script>
