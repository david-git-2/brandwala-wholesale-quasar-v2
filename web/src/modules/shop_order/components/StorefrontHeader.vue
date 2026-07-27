<template>
  <section class="row items-center justify-between q-col-gutter-md">
    <div class="col">
      <div class="row items-center q-gutter-x-sm">
        <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" @click="$emit('back')" />
        <div>
          <div class="text-overline text-primary">Wholesale Storefront</div>
          <h1 class="text-h5 text-weight-bold q-my-none">{{ shopName }}</h1>
        </div>
      </div>
    </div>
    <div v-if="$q.screen.xs" class="col-auto row items-center q-gutter-sm">
      <q-btn
        flat
        round
        dense
        color="primary"
        icon="ph ph-funnel-simple"
        @click="$emit('open-filter')"
      >
        <q-badge v-if="activeFilterCount > 0" color="primary" floating rounded>
          {{ activeFilterCount }}
        </q-badge>
        <q-tooltip>{{ $t('shop.filters') }}</q-tooltip>
      </q-btn>
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  shopName: string;
  activeFilterCount: number;
}>();

defineEmits<{
  (e: 'back'): void;
  (e: 'open-filter'): void;
}>();
</script>
