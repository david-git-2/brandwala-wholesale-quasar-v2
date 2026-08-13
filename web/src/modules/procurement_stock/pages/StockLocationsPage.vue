<template>
  <q-page class="bw-page">
    <section class="bw-page__stack" style="min-width: 0">
      <AppPageHeader
        eyebrow="Procurement & Stock"
        title="Locations"
        subtitle="Warehouse bins and zones — coming soon"
      />
      <q-card flat bordered class="q-pa-lg">
        <div class="text-body1 text-grey-8">
          Manage stock locations (e.g. MAIN, RETURNS). Receive put-away and movements will use this
          catalog.
        </div>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
</script>
