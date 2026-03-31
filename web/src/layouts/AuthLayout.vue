<template>
  <q-layout view="hHh lpR fFf">
    <q-page-container>
      <q-page class="flex flex-center">
        <div class="auth-wrapper">
          <router-view />
        </div>
      </q-page>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
// no logic needed
</script>

<style scoped>
.auth-wrapper {
  width: 100%;
  max-width: 400px;
  padding: 24px;
}
</style>
