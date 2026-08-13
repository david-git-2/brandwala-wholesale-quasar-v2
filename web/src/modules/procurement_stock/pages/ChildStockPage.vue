<template>
  <q-page class="bw-page">
    <section class="bw-page__stack" style="min-width: 0">
      <AppPageHeader
        eyebrow="Procurement & Stock"
        title="Stock"
        subtitle="Stock available to this sister concern — coming soon"
      />
      <q-card flat bordered class="q-pa-lg">
        <div class="text-body1 text-grey-8">
          Child ATP and assigned-batch stock view will replace soft allocations here.
        </div>
      </q-card>
    </section>
  </q-page>
</template>

<script setup lang="ts">
import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
</script>
