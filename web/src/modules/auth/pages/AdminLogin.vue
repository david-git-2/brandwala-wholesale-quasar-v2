<template>
  <div class="q-pa-md flex flex-center" style="height: 100vh;">
    <q-card class="my-card" style="width: 350px;">
      <img src="https://cdn.quasar.dev/img/mountains.jpg" />

      <q-card-section>
        <q-banner
          v-if="loginErrorMessage"
          class="bg-negative text-white q-mb-md"
          rounded
          dense
        >
          {{ loginErrorMessage }}
        </q-banner>

        <div class="text-h6 text-center">{{ title }}</div>
      </q-card-section>

      <q-card-section>
        <q-btn
          color="primary"
          :label="isLoading ? 'Connecting...' : 'Login with Google'"
          class="full-width"
          icon="login"
          :loading="isLoading"
          @click="handleGoogleLogin"
        />
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

import { useOAuthLogin } from '../composables/useOAuthLogin'

const route = useRoute()
const { handleGoogleLogin, isLoading, title } = useOAuthLogin()

const loginErrorMessage = computed(() => {
  const error = route.query.login_error

  if (error === 'no_membership') {
    return 'We could not find access for this account. Please sign in with an approved Google account.'
  }

  return ''
})
</script>

<style scoped>
.my-card {
  border-radius: 16px;
}
</style>
