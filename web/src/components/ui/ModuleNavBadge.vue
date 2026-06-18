<template>
  <q-chip
    dense
    square
    outline
    :color="chipColor"
    :text-color="chipTextColor"
    class="module-nav-badge text-weight-bold text-uppercase"
    style="font-size: 10px; letter-spacing: 0.06em;"
  >
    <q-icon v-if="icon" :name="icon" size="14px" class="q-mr-xs" />
    {{ label }}
  </q-chip>
</template>

<script setup lang="ts">
import { computed } from 'vue'

import type { ModuleNavFamily } from 'src/modules/navigation/moduleRegistry'

const props = defineProps<{
  family: ModuleNavFamily
}>()

const label = computed(() => {
  switch (props.family) {
    case 'global':
      return 'Global module'
    case 'tenant_stock':
      return 'Tenant module'
    default:
      return 'Module'
  }
})

const icon = computed(() => {
  switch (props.family) {
    case 'global':
      return 'public'
    case 'tenant_stock':
      return 'domain'
    default:
      return undefined
  }
})

const chipColor = computed(() => (props.family === 'global' ? 'primary' : 'grey-7'))
const chipTextColor = computed(() => (props.family === 'global' ? 'primary' : 'grey-8'))
</script>
