<template>
  <span class="row items-center no-wrap">
    <q-icon :name="resolveTypeIcon(icon)" size="20px" class="q-mr-xs" />
    <span>{{ name }}</span>
  </span>
</template>

<script setup lang="ts">
import { resolveTypeIcon } from '../../type/utils/typeIcon';

defineProps<{
  name: string;
  icon?: string | null;
}>();
</script>
