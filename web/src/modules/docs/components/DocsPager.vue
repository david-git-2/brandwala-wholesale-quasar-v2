<template>
  <footer class="docs-pager">
    <div class="docs-pager__row">
      <router-link
        v-if="previous"
        :to="previous.path"
        class="docs-pager__card"
      >
        <span class="docs-pager__dir">Previous</span>
        <span class="docs-pager__title">{{ previous.label }}</span>
      </router-link>
      <span v-else />
      <router-link
        v-if="next"
        :to="next.path"
        class="docs-pager__card docs-pager__card--next"
      >
        <span class="docs-pager__dir">Next</span>
        <span class="docs-pager__title">{{ next.label }}</span>
      </router-link>
    </div>
    <p v-if="sourceLabel" class="docs-pager__edit">
      <span class="docs-pager__edit-link" :title="sourceLabel">Edit this page</span>
    </p>
  </footer>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { findDocsNavContext } from '../content/nav';

const route = useRoute();
const ctx = computed(() => findDocsNavContext(typeof route.name === 'string' ? route.name : null));
const previous = computed(() => ctx.value.previous);
const next = computed(() => ctx.value.next);
const sourceLabel = computed(() => {
  const file = route.meta.docsMd;
  if (typeof file === 'string' && file) {
    return `web/src/modules/docs/content/md/${file}`;
  }
  if (route.name === 'docs-overview') {
    return 'web/src/modules/docs/content/md/what-is-tradeflow.md';
  }
  return '';
});
</script>

<style scoped>
.docs-pager {
  margin-top: 48px;
  padding-top: 24px;
  border-top: 1px solid var(--tf-theme-border);
}

.docs-pager__row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.docs-pager__card {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
  padding: 12px 16px;
  border: 1px solid var(--tf-theme-border);
  border-radius: var(--tf-radius-sm);
  text-decoration: none;
  color: var(--tf-theme-ink);
  background: transparent;
}

.docs-pager__card--next {
  text-align: right;
}

.docs-pager__card:hover {
  background: var(--tf-hover-bg);
}

.docs-pager__card:focus-visible {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}

.docs-pager__dir {
  font-size: 12px;
  color: var(--tf-theme-muted);
}

.docs-pager__title {
  font-size: 14px;
  font-weight: 600;
}

.docs-pager__edit {
  margin: 16px 0 0;
}

.docs-pager__edit-link {
  font-size: 13px;
  color: var(--tf-theme-primary);
  cursor: default;
}

@media (max-width: 767px) {
  .docs-pager__row {
    grid-template-columns: 1fr;
  }

  .docs-pager__card--next {
    text-align: left;
  }
}
</style>
