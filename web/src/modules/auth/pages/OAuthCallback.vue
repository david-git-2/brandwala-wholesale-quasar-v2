<template>
  <AppTradeFlowLoadingScreen
    fullscreen
    :scope="scope"
    :tagline="isRedirectingToApp ? 'Opening Thrift App…' : 'Finishing sign-in'"
    :aria-label="isRedirectingToApp ? 'Opening Thrift App' : 'Finishing sign-in'"
  >
    <template v-if="isRedirectingToApp && appRedirectUrl">
      <q-btn
        color="primary"
        unelevated
        no-caps
        class="q-px-lg q-py-sm font-semibold q-mt-md"
        :href="appRedirectUrl"
        label="Open Thrift App"
      />
      <div class="text-caption text-grey-6 q-mt-sm">
        If the app didn't open automatically, click the button above.
      </div>
    </template>
  </AppTradeFlowLoadingScreen>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';

import AppTradeFlowLoadingScreen from 'src/components/brand/AppTradeFlowLoadingScreen.vue';
import { useOAuthLogin, type AuthScope } from '../composables/useOAuthLogin';

const route = useRoute();
const scope = (route.query.scope as AuthScope | undefined) ?? 'app';
const tenantSlug =
  typeof route.query.tenant_slug === 'string' ? route.query.tenant_slug.trim() : null;
const { processLoginResult } = useOAuthLogin(scope, { tenantSlug });

const isRedirectingToApp = ref(false);
const appRedirectUrl = ref('');

onMounted(() => {
  document.getElementById('app-splash')?.remove();

  const appRedirect = route.query.app_redirect;

  if (appRedirect === 'thrift') {
    isRedirectingToApp.value = true;

    const code = route.query.code as string | undefined;
    const thriftTenantSlug = (route.query.tenant_slug as string) || 'thrift';

    if (code) {
      const isAndroid = /Android/i.test(navigator.userAgent);
      if (isAndroid) {
        appRedirectUrl.value = `intent://auth-callback?code=${encodeURIComponent(code)}&scope=app&tenant_slug=${encodeURIComponent(thriftTenantSlug)}#Intent;scheme=com.brandwala.thriftapp;package=com.brandwala.thriftapp;end`;
      } else {
        appRedirectUrl.value = `com.brandwala.thriftapp://auth-callback?code=${encodeURIComponent(code)}&scope=app&tenant_slug=${encodeURIComponent(thriftTenantSlug)}`;
      }
      window.location.href = appRedirectUrl.value;
      return;
    }
  }

  void processLoginResult();
});
</script>
