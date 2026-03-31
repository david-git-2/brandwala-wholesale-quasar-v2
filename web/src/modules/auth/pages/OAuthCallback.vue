<template>
  <div class="q-pa-xl flex flex-center" style="min-height: 100vh;">
    <q-card class="callback-card">
      <q-card-section class="text-center">
        <div class="text-h6">Finishing sign in...</div>
        <div class="text-body2 text-grey-7 q-mt-sm">
          Checking your access and sending you to the right place.
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useRoute } from 'vue-router'

import { useOAuthLogin, type AuthScope } from '../composables/useOAuthLogin'

const route = useRoute()
const scope = (route.query.scope as AuthScope | undefined) ?? 'app'
const { processLoginResult } = useOAuthLogin(scope)

onMounted(() => {
  void processLoginResult()
})
</script>

<style scoped>
.callback-card {
  width: 100%;
  max-width: 360px;
  border-radius: 16px;
}
</style>
