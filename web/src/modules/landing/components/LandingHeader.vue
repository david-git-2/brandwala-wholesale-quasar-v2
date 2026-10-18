<template>
  <header class="landing-header">
    <router-link to="/" class="landing-header__brand">
      <AppLogoMark scope="app" class="landing-header__mark" />
      {{ landingCopy.brand }}
    </router-link>
    <nav class="landing-header__nav" aria-label="Page">
      <a class="landing-header__flow" href="#flow">{{ landingCopy.header.howItWorks }}</a>
      <router-link :to="HELP_PATH">{{ landingCopy.header.help }}</router-link>
    </nav>
    <router-link class="landing-header__signin" :to="SIGN_IN_PATH">
      {{ landingCopy.header.signIn }}
    </router-link>
  </header>
</template>

<script setup lang="ts">
import AppLogoMark from 'src/components/brand/AppLogoMark.vue';
import { HELP_PATH, SIGN_IN_PATH, landingCopy } from '../content';
</script>

<style scoped>
.landing-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.landing-header__brand {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  color: var(--tf-neutral-ink);
  text-decoration: none;
  font-size: 0.8125rem;
  font-weight: 600;
  letter-spacing: -0.02em;
}

.landing-header__brand:focus-visible,
.landing-header__nav a:focus-visible,
.landing-header__signin:focus-visible {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}

.landing-header__mark {
  font-size: 1rem;
}

.landing-header__nav {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-left: auto;
}

.landing-header__nav a {
  color: var(--tf-neutral-muted);
  text-decoration: none;
  font-size: 0.8125rem;
}

.landing-header__nav a:hover,
.landing-header__nav a:focus-visible {
  color: var(--tf-neutral-ink);
}

.landing-header__signin {
  flex-shrink: 0;
  padding: 0.125rem 0.5rem;
  border-radius: var(--tf-radius-sm);
  background: var(--tf-theme-primary);
  color: var(--tf-theme-on-primary);
  text-decoration: none;
  font-size: 0.75rem;
  font-weight: 600;
  line-height: 1.4;
}

@media (max-width: 767px) {
  .landing-header__flow {
    display: none;
  }
}
</style>
