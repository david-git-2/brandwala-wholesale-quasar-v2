<template>
  <section class="landing-wrap landing-section landing-hero">
    <LandingHeader />
    <div class="landing-hero__grid">
      <div>
        <p class="landing-label">{{ landingCopy.hero.eyebrow }}</p>
        <h1 class="landing-hero__h1">{{ landingCopy.hero.h1 }}</h1>
        <p v-for="line in landingCopy.hero.subhead" :key="line" class="landing-body">
          {{ line }}
        </p>
        <div class="row q-gutter-sm q-mb-md">
          <TfBtn :label="landingCopy.hero.primaryCta" :to="SIGN_IN_PATH" size="md" />
          <TfBtn
            variant="secondary"
            :label="landingCopy.hero.requestCta"
            :href="CONTACT_HREF"
            size="md"
          />
        </div>
        <p class="landing-hero__note">{{ landingCopy.hero.accessNote }}</p>
      </div>
      <HeroShipmentPreview />
    </div>
  </section>
</template>

<script setup lang="ts">
import TfBtn from 'src/components/ui/TfBtn.vue';
import { CONTACT_HREF, SIGN_IN_PATH, landingCopy } from '../content';
import LandingHeader from './LandingHeader.vue';
import HeroShipmentPreview from './previews/HeroShipmentPreview.vue';
</script>

<style scoped>
.landing-hero {
  padding-top: 0.75rem;
}

.landing-hero__grid {
  margin-top: 1.5rem;
}

.landing-hero__h1 {
  margin: 0 0 1rem;
  font-size: clamp(1.75rem, 5vw, 2.5rem);
  font-weight: 600;
  line-height: 1.15;
  letter-spacing: -0.03em;
  color: var(--tf-neutral-ink);
}

.landing-hero__note {
  margin: 0;
  font-size: var(--tf-text-meta);
  color: var(--tf-neutral-chrome-text);
}

.landing-hero__grid {
  display: grid;
  gap: 2rem;
}

@media (min-width: 768px) {
  .landing-hero__grid {
    grid-template-columns: 1fr 1fr;
    align-items: start;
  }
}
</style>
