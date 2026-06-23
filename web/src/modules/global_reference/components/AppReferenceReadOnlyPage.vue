<template>
  <q-page class="q-pa-md">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="text-h6 text-weight-bold">{{ title }}</div>
        <div class="text-caption text-grey-8">{{ caption }}</div>
      </q-card-section>
    </q-card>
    <q-card flat class="floating-surface shadow-1">
      <q-table flat :rows="rows" :columns="columns" row-key="id" :loading="loading" />
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar'

defineProps<{
  title: string
  caption: string
  columns: QTableColumn[]
  rows: Record<string, unknown>[]
  loading: boolean
}>()
</script>

<style scoped>
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
}
.hero-surface { border-radius: 16px; }
</style>
