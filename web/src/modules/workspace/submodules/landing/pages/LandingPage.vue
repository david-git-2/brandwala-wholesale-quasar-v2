<template>
  <q-page class="landing-page theme-app column">
    <main>
      <LandingHero />
      <LandingFlow />
      <LandingWho />
      <LandingCta />
    </main>
    <LandingFooter />
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue';
import LandingCta from '../components/LandingCta.vue';
import LandingFlow from '../components/LandingFlow.vue';
import LandingFooter from '../components/LandingFooter.vue';
import LandingHero from '../components/LandingHero.vue';
import LandingWho from '../components/LandingWho.vue';
import { landingSeo } from '../content';
import '../landing.css';

const previousTitle = document.title;

function upsertMeta(selector: string, attrs: Record<string, string>) {
  let el = document.head.querySelector(selector) as HTMLMetaElement | null;
  if (!el) {
    el = document.createElement('meta');
    document.head.appendChild(el);
  }
  Object.entries(attrs).forEach(([key, value]) => {
    el.setAttribute(key, value);
  });
}

onMounted(() => {
  document.title = landingSeo.title;
  upsertMeta('meta[name="description"]', { name: 'description', content: landingSeo.description });
  upsertMeta('meta[property="og:title"]', { property: 'og:title', content: landingSeo.title });
  upsertMeta('meta[property="og:description"]', {
    property: 'og:description',
    content: landingSeo.description,
  });
  upsertMeta('meta[property="og:type"]', { property: 'og:type', content: 'website' });
});

onUnmounted(() => {
  document.title = previousTitle;
});
</script>

<style scoped>
.landing-page {
  min-height: 100vh;
  padding: 0;
  overflow-x: clip;
  background: var(--tf-neutral-canvas);
  color: var(--tf-neutral-ink);
  font-family: var(--tf-font-ui);
}
</style>
