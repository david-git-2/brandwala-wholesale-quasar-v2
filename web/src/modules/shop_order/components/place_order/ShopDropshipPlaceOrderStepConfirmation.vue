<template>
  <div class="column q-gutter-y-md dropship-wizard-confirmation">
    <q-card flat bordered class="dropship-wizard-confirmation__terms">
      <q-card-section class="q-pa-md">
        <div class="text-subtitle2 text-weight-bold q-mb-sm">
          {{ $t('shop.dropship_terms_title') }}
        </div>
        <div class="text-body2 text-grey-8 dropship-wizard-confirmation__scroll">
          {{ $t('shop.dropship_terms_body') }}
        </div>
      </q-card-section>
    </q-card>
    <q-checkbox
      v-model="termsAccepted"
      dense
      :label="$t('shop.dropship_terms_checkbox')"
    />
  </div>
</template>

<script setup lang="ts">
const termsAccepted = defineModel<boolean>('termsAccepted', { required: true });
</script>

<style scoped>
.dropship-wizard-confirmation__scroll {
  max-height: min(50vh, 320px);
  overflow-y: auto;
  white-space: pre-line;
}
</style>