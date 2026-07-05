<template>
  <div class="row q-col-gutter-md">
    <div
      v-for="card in items"
      :key="card.label"
      :class="card.class || 'col-12 col-sm-6 col-md-3'"
    >
      <q-card flat bordered class="q-pa-md h-full bg-white text-black">
        <div class="text-caption text-grey-7 text-uppercase tracking-wider">
          {{ card.label }}
        </div>
        <div class="text-h5 text-weight-bolder q-mt-xs text-primary" :class="card.valueClass">
          {{ formatCurrency(card.value) }}
        </div>
        <div v-if="card.caption" class="text-caption text-grey-5 q-mt-xs">
          {{ card.caption }}
        </div>
      </q-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatAmountBdt } from 'src/utils/currency'

defineProps<{
  items: Array<{
    label: string
    value: number
    caption?: string
    class?: string
    valueClass?: string
  }>
}>()

const formatCurrency = (val: number) => formatAmountBdt(val)
</script>
