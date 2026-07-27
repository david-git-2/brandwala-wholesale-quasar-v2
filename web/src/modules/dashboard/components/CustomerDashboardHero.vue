<template>
  <q-card flat class="hero-card q-pa-md q-pa-sm-lg q-pa-md-xl text-white relative-position overflow-hidden">
    <div class="row items-center justify-between q-col-gutter-md">
      <div class="col-12 col-md-7 z-index-1">
        <div class="text-overline text-blue-2 text-weight-bold tracking-wider">{{ tenantName }}</div>
        <h1 class="text-h4 text-sm-h3 text-weight-bold q-my-xs q-my-sm-sm leading-tight">
          {{ $t('customer_dashboard.welcome', { name: customerName }) }}
        </h1>
        <p class="text-body2 text-sm-subtitle1 text-blue-1 q-mb-md q-mb-sm-lg opacity-90">
          {{ $t('customer_dashboard.welcome_sub') }}
        </p>

        <!-- Global Product Search Bar -->
        <div class="search-bar-wrap full-width">
          <q-input
            v-model="searchModel"
            outlined
            dense
            bg-color="white"
            :placeholder="$t('customer_dashboard.search_placeholder')"
            class="search-input soft-input shadow-2"
            @keydown.enter="$emit('search')"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" color="grey-6" />
            </template>
            <template #append>
              <q-btn
                color="primary"
                unelevated
                no-caps
                :label="$t('customer_dashboard.search_btn')"
                class="q-px-md search-btn"
                @click="$emit('search')"
              />
            </template>
          </q-input>
        </div>
      </div>

      <div class="col-12 col-md-5 z-index-1 text-right gt-sm">
        <q-icon name="ph ph-storefront" size="140px" class="opacity-20 q-mr-lg" />
      </div>
    </div>
    <div class="hero-bg-overlay"></div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{
  tenantName: string;
  customerName: string;
  searchQuery: string;
}>();

const emit = defineEmits<{
  (e: 'update:searchQuery', value: string): void;
  (e: 'search'): void;
}>();

const searchModel = computed({
  get: () => props.searchQuery,
  set: (val: string) => emit('update:searchQuery', val),
});
</script>

<style scoped>
.hero-card {
  background: linear-gradient(135deg, var(--q-primary) 0%, #1565c0 100%);
  border-radius: 16px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
}

.hero-bg-overlay {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  background-image: radial-gradient(circle at 80% 20%, rgba(255, 255, 255, 0.15) 0%, transparent 50%);
  pointer-events: none;
}

.search-bar-wrap {
  max-width: 540px;
  width: 100%;
}

.search-input :deep(.q-field__control) {
  border-radius: 30px !important;
  padding-right: 0px !important;
}

.search-btn {
  border-radius: 0 30px 30px 0;
  height: 40px;
}

.z-index-1 {
  position: relative;
  z-index: 1;
}

.opacity-90 {
  opacity: 0.9;
}

.opacity-20 {
  opacity: 0.2;
}

.tracking-wider {
  letter-spacing: 0.05em;
}

.leading-tight {
  line-height: 1.25;
}
</style>
