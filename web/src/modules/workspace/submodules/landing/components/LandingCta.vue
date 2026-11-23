<template>
  <section class="landing-cta">
    <div class="landing-wrap landing-section">
      <h2 class="landing-h2">{{ landingCopy.cta.h2 }}</h2>
      <p class="landing-body">{{ landingCopy.cta.accessNote }}</p>
      <div class="row q-gutter-sm q-mb-sm">
        <TfBtn :label="landingCopy.cta.signIn" :to="SIGN_IN_PATH" size="md" />
        <TfBtn
          variant="secondary"
          :label="landingCopy.cta.request"
          :href="CONTACT_HREF"
          size="md"
        />
      </div>
      <p class="landing-body">
        <router-link :to="HELP_PATH">{{ landingCopy.cta.helpHint }}</router-link>
      </p>
    </div>
  </section>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import { CONTACT_HREF, HELP_PATH, SIGN_IN_PATH, landingCopy } from '../content';
</script>

<style scoped>
.landing-cta {
  background: var(--tf-neutral-surface);
  border-top: 1px solid var(--tf-neutral-border);
}
</style>
