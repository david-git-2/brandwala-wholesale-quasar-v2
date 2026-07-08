<template>
  <div class="callback-stage" :class="`theme-${scope}`">
    <div class="callback-stage__card">
      <template v-if="isRedirectingToApp">
        <q-spinner-tail color="primary" size="42px" />
        <div class="callback-stage__title">Opening Thrift App...</div>
        <div class="callback-stage__copy">
          You are being redirected back to the Thrift application.
        </div>
        <div v-if="appRedirectUrl" class="q-mt-lg">
          <q-btn
            color="primary"
            unelevated
            no-caps
            class="q-px-lg q-py-sm font-semibold"
            :href="appRedirectUrl"
            label="Open Thrift App"
          />
          <div class="text-caption text-grey-6 q-mt-sm">
            If the app didn't open automatically, click the button above.
          </div>
        </div>
      </template>
      <template v-else>
        <q-spinner-tail color="primary" size="42px" />
        <div class="callback-stage__title">Finishing sign-in</div>
        <div class="callback-stage__copy">
          Checking your access for the selected route and preparing the workspace.
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useOAuthLogin, type AuthScope } from '../composables/useOAuthLogin';

const route = useRoute();
const scope = (route.query.scope as AuthScope | undefined) ?? 'app';
const { processLoginResult } = useOAuthLogin(scope);

const isRedirectingToApp = ref(false);
const appRedirectUrl = ref('');

onMounted(() => {
  const appRedirect = route.query.app_redirect;

  if (appRedirect === 'thrift') {
    isRedirectingToApp.value = true;

    // ── PKCE code passthrough ──────────────────────────────────────────
    // The native app called signInWithOAuth({ skipBrowserRedirect: true })
    // which stored the PKCE code_verifier in the app's WebView storage.
    // We must NOT exchange the code here (the web page doesn't have the
    // code_verifier). Instead, pass the raw `code` straight back to the
    // app so IT can call exchangeCodeForSession().
    const code = route.query.code as string | undefined;
    const tenantSlug = (route.query.tenant_slug as string) || 'thrift';

    if (code) {
      const isAndroid = /Android/i.test(navigator.userAgent);
      if (isAndroid) {
        appRedirectUrl.value = `intent://auth-callback?code=${encodeURIComponent(code)}&scope=app&tenant_slug=${encodeURIComponent(tenantSlug)}#Intent;scheme=com.brandwala.thriftapp;package=com.brandwala.thriftapp;end`;
      } else {
        appRedirectUrl.value = `com.brandwala.thriftapp://auth-callback?code=${encodeURIComponent(code)}&scope=app&tenant_slug=${encodeURIComponent(tenantSlug)}`;
      }
      window.location.href = appRedirectUrl.value;
      return;
    }
  }

  void processLoginResult();
});
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
