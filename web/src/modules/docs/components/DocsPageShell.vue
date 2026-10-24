<template>
  <q-page class="docs-page-shell">
    <div class="docs-page-shell__inner">
      <header v-if="!hideHeader && (title || lead)" class="docs-page-shell__header">
        <h1 v-if="title" class="docs-page-shell__title">{{ title }}</h1>
        <p v-if="lead" class="docs-page-shell__lead">{{ lead }}</p>
      </header>
      <div class="docs-page-shell__body">
        <slot />
      </div>
      <DocsPager />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import DocsPager from './DocsPager.vue';

withDefaults(
  defineProps<{
    title?: string;
    lead?: string;
    wide?: boolean;
    hideHeader?: boolean;
  }>(),
  { wide: false, hideHeader: false, title: '' },
);
</script>

<style scoped>
.docs-page-shell {
  min-width: 0;
  overflow-x: hidden;
  background: var(--tf-theme-base);
}

.docs-page-shell__inner {
  max-width: 760px;
  width: 100%;
  min-width: 0;
  margin: 0 auto;
  padding: 40px 32px 96px;
  box-sizing: border-box;
}

.docs-page-shell__title {
  margin: 0 0 16px;
  font-size: 30px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
  color: var(--tf-theme-heading, var(--tf-theme-ink));
}

.docs-page-shell__lead {
  margin: 0 0 16px;
  font-size: 16px;
  line-height: 1.65;
  color: var(--tf-theme-muted);
}

.docs-page-shell__body {
  overflow: visible;
}

@media (max-width: 767px) {
  .docs-page-shell__inner {
    padding: 24px 16px 64px;
  }
}
</style>
