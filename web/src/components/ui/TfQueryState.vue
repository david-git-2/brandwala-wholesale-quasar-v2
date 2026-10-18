<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue';
import TfEmptyState from './TfEmptyState.vue';
import TfSkeletonRows from './TfSkeletonRows.vue';

const props = withDefaults(
  defineProps<{
    isLoading?: boolean;
    isError?: boolean;
    isEmpty?: boolean;
    emptyTitle?: string;
    emptyMessage?: string;
    errorMessage?: string;
    rows?: number;
    cols?: number;
  }>(),
  { emptyTitle: 'Nothing here yet', errorMessage: 'Could not load data.', rows: 8, cols: 4 },
);
const emit = defineEmits<{ retry: [] }>();

const online = ref(navigator.onLine);
const setOnline = () => (online.value = navigator.onLine);
window.addEventListener('online', setOnline);
window.addEventListener('offline', setOnline);
onBeforeUnmount(() => {
  window.removeEventListener('online', setOnline);
  window.removeEventListener('offline', setOnline);
});
const state = computed(() => {
  if (props.isError && !online.value) return 'offline';
  if (props.isError) return 'error';
  if (props.isLoading) return 'loading';
  if (props.isEmpty) return 'empty';
  return 'ok';
});
</script>

<template>
  <TfSkeletonRows v-if="state === 'loading'" :rows="rows" :cols="cols" />
  <TfEmptyState
    v-else-if="state === 'offline'"
    icon="ph ph-wifi-slash"
    title="You are offline"
    message="Check your connection, then retry."
  >
    <q-btn unelevated no-caps dense label="Retry" :ripple="false" @click="emit('retry')" />
  </TfEmptyState>
  <TfEmptyState
    v-else-if="state === 'error'"
    icon="ph ph-warning-circle"
    title="Something went wrong"
    :message="errorMessage"
  >
    <q-btn unelevated no-caps dense label="Retry" :ripple="false" @click="emit('retry')" />
  </TfEmptyState>
  <TfEmptyState v-else-if="state === 'empty'" :title="emptyTitle" :message="emptyMessage">
    <slot name="empty-action" />
  </TfEmptyState>
  <slot v-else />
</template>
