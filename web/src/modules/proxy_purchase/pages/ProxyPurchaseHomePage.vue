<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center justify-end q-pb-sm flex-shrink-0">
      <q-btn
        flat
        round
        dense
        color="primary"
        icon="ph ph-gear"
        :ripple="false"
        aria-label="Settings"
        :to="{ name: 'proxy-purchase-config-page' }"
      />
    </div>

    <div class="col flex flex-center min-h-0">
      <tf-empty-state
        title="No lines yet"
        message="Line list and filters will be added in a later step."
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
</script>