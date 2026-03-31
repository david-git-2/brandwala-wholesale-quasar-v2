<template>
  <q-page class="row items-center justify-center">
    <div class="dashboard-word">Dashboard</div>
    {{ authStore.user }}
  </q-page>
</template>

<script setup lang="ts">
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const authStore = useAuthStore();
</script>

<style scoped>
.dashboard-word {
  font-size: clamp(2.5rem, 7vw, 5rem);
  font-weight: 700;
  letter-spacing: 0.04em;
  color: #24303d;
}
</style>
