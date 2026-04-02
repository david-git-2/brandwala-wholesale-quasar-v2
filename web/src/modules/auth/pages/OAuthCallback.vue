<template>
  <div class="callback-stage" :class="`theme-${scope}`">
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
  --callback-border: var(--bw-theme-border, rgb(95 70 43 / 0.12));
  --callback-surface: color-mix(in srgb, var(--bw-theme-surface, white) 90%, white 10%);
  --callback-ink: var(--bw-theme-ink, #281f17);
  --callback-muted: var(--bw-theme-muted, #6d5a48);
  width: 100%;
  display: flex;
  justify-content: center;
}

.callback-stage__card {
  width: min(100%, 28rem);
  padding: 2rem;
  border-radius: 1.75rem;
  border: 1px solid var(--callback-border);
  background: linear-gradient(180deg, var(--callback-surface), var(--bw-theme-base, #f5ece2));
  text-align: center;
}

.callback-stage__title {
  margin-top: 1rem;
  font-size: 1.35rem;
  font-weight: 700;
  color: var(--callback-ink);
}

.callback-stage__copy {
  margin-top: 0.55rem;
  color: var(--callback-muted);
  line-height: 1.6;
}
</style>
