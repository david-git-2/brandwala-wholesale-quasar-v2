<template>
  <q-page class="bw-page">
    <section class="bw-page__stack" style="min-width: 0">
      <AppPageHeader
        eyebrow="Procurement & Stock"
        title="Movements"
        subtitle="Post location and availability transfers — coming soon"
      />
      <q-card flat bordered class="q-pa-lg">
        <div class="text-body1 text-grey-8">
          Warehouse movement documents (location transfer, availability transfer, return inbound)
          will live here. Stock balances stay read-only on Warehouse.
        </div>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
</script>
