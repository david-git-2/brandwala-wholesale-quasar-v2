<template>
  <img
    class="app-logo-mark"
    :src="src"
    alt=""
    decoding="async"
    aria-hidden="true"
  />
</template>

<script setup lang="ts">
import { computed } from 'vue';
import {
  BRAND_LOGO_MARK_BY_SCOPE,
  type BrandLogoScope,
} from 'src/constants/brandAssets';

const props = defineProps<{
  onDark?: boolean;
  scope?: BrandLogoScope;
}>();

function detectScope(): BrandLogoScope {
  const cl = document.body.classList;
  if (cl.contains('theme-platform')) return 'platform';
  if (cl.contains('theme-shop')) return 'shop';
  if (cl.contains('theme-investor')) return 'investor';
  return 'app';
}

const src = computed(() => BRAND_LOGO_MARK_BY_SCOPE[props.scope ?? detectScope()]);
</script>

<style scoped>
.app-logo-mark {
  display: block;
  width: 1em;
  height: 1em;
  object-fit: contain;
}
</style>
