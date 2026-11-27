<template>
  <footer class="landing-footer">
    <div class="landing-wrap landing-footer__inner row items-center justify-between">
      <span class="landing-footer__brand">{{ landingCopy.brand }}</span>
      <nav class="row q-gutter-md" aria-label="Footer">
        <router-link :to="HELP_PATH">{{ landingCopy.footer.help }}</router-link>
        <router-link :to="SIGN_IN_PATH">{{ landingCopy.footer.signIn }}</router-link>
      </nav>
      <p class="landing-footer__copy">{{ landingCopy.footer.copyright }}</p>
    </div>
  </footer>
</template>

<script setup lang="ts">
import { HELP_PATH, SIGN_IN_PATH, landingCopy } from '../content';
</script>

<style scoped>
.landing-footer {
  border-top: 1px solid var(--tf-neutral-border);
}

.landing-footer__inner {
  padding-block: 1.25rem;
  gap: 0.75rem;
}

.landing-footer__brand {
  font-weight: 600;
}

.landing-footer a {
  color: var(--tf-neutral-muted);
  text-decoration: none;
  font-size: 0.875rem;
}

.landing-footer a:hover,
.landing-footer a:focus-visible {
  color: var(--tf-neutral-ink);
}

.landing-footer a:focus-visible {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}

.landing-footer__copy {
  margin: 0;
  font-size: var(--tf-text-meta);
  color: var(--tf-neutral-chrome-text);
}

@media (max-width: 767px) {
  .landing-footer__inner {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
