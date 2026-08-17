<template>
  <h1 class="text-h5 text-weight-bold q-my-none">
    {{ greeting }}
  </h1>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps<{
  customerName: string;
}>();

const { t } = useI18n();

const greeting = computed(() => {
  const hour = new Date().getHours();
  const key =
    hour < 12
      ? 'customer_dashboard.greeting_morning'
      : hour < 17
        ? 'customer_dashboard.greeting_afternoon'
        : 'customer_dashboard.greeting_evening';
  return t(key, { name: props.customerName });
});
</script>
