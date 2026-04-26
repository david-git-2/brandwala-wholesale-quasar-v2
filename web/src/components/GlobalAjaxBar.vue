<template>
  <q-ajax-bar
    ref="bar"
    position="top"
    color="primary"
    size="6px"
    skip-hijack
  />
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useGlobalNetworkActivity } from 'src/composables/useGlobalNetworkActivity'

const bar = ref<{ start: () => void; stop: () => void } | null>(null)
const { isActive } = useGlobalNetworkActivity()

watch(
  isActive,
  (loading) => {
    if (loading) {
      bar.value?.start()
      return
    }
    bar.value?.stop()
  },
  { immediate: true },
)
</script>
