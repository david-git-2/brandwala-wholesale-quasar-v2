<template>
  <div class="callback-stage">
    <div class="callback-stage__card">
      <q-spinner-ball color="primary" size="42px" />
      <div class="callback-stage__title">Finishing sign-in</div>
      <div class="callback-stage__copy">
        Checking your access for the selected route and preparing the workspace.
      </div>
    </div>
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
.callback-stage {
  width: 100%;
  display: flex;
  justify-content: center;
}

.callback-stage__card {
  width: min(100%, 28rem);
  padding: 2rem;
  border-radius: 1.75rem;
  border: 1px solid rgba(95, 70, 43, 0.12);
  background: linear-gradient(180deg, rgba(255, 252, 248, 0.92), rgba(245, 236, 226, 0.82));
  text-align: center;
}

.callback-stage__title {
  margin-top: 1rem;
  font-size: 1.35rem;
  font-weight: 700;
  color: #281f17;
}

.callback-stage__copy {
  margin-top: 0.55rem;
  color: #6d5a48;
  line-height: 1.6;
}
</style>
