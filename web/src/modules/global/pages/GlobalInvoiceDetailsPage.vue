<template>
  <q-page class="q-pa-md">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
      <q-card-section class="q-py-sm">
        <div class="row items-center justify-between q-col-gutter-sm">
          <div class="col">
            <div class="text-h6 text-weight-bold text-black">Global Invoice Details</div>
            <div class="text-caption text-grey-8">Invoice editor coming in a follow-up release</div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <q-card flat class="floating-surface shadow-1 q-pa-md text-grey-7">
      Invoice #{{ route.params.id }} — detail view placeholder.
    </q-card>
  </q-page>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router'

const route = useRoute()
</script>
