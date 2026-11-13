<template>
  <div class="row q-gutter-sm wrap items-center profile-cashbook-actions">
    <TfBtn
      variant="secondary"
      size="sm"
      icon="ph ph-arrow-down"
      label="Deposit"
      data-test="profile-cashbook-deposit"
      @click="emit('deposit')"
    />
    <TfBtn
      variant="secondary"
      size="sm"
      icon="ph ph-arrow-up"
      label="Withdraw"
      data-test="profile-cashbook-withdraw"
      @click="emit('withdraw')"
    />
    <TfBtn
      variant="secondary"
      size="sm"
      icon="ph ph-map-pin"
      label="Locations"
      data-test="profile-cashbook-locations"
      @click="emit('locations')"
    />
  </div>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';

const emit = defineEmits<{
  deposit: [];
  withdraw: [];
  locations: [];
}>();
</script>
