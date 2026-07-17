<template>
  <GlobalAjaxBar />
  <router-view />
</template>

<script setup lang="ts">
import GlobalAjaxBar from 'src/components/GlobalAjaxBar.vue';
import { useDynamicFavicon } from 'src/composables/useDynamicFavicon';

// Swap the browser tab icon to the scope-coloured brand mark on every navigation
useDynamicFavicon();
</script>
