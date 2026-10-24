<template>
  <q-layout view="hHh Lpr lFf" class="docs-layout theme-docs">
    <q-header bordered class="docs-layout__header">
      <q-toolbar class="docs-layout__toolbar">
        <q-btn
          flat
          dense
          round
          :ripple="false"
          icon="ph ph-list"
          aria-label="Open documentation navigation"
          class="docs-layout__icon-btn"
          @click="leftOpen = !leftOpen"
        />
        <q-toolbar-title>
          <router-link to="/docs" class="docs-layout__product">
            Platform guide
          </router-link>
          <div v-if="crumb" class="docs-layout__crumb">{{ crumb }}</div>
        </q-toolbar-title>
        <q-btn
          v-if="showPageTocMobile"
          flat
          dense
          round
          :ripple="false"
          icon="ph ph-list-bullets"
          aria-label="On this page"
          class="docs-layout__icon-btn"
          @click="tocDrawerOpen = true"
        />
        <q-btn
          flat
          dense
          round
          :ripple="false"
          icon="ph ph-magnifying-glass"
          aria-label="Open search"
          class="docs-layout__icon-btn"
          @click="searchOpen = true"
        />
        <q-btn
          flat
          dense
          round
          :ripple="false"
          :icon="darkMode ? 'ph ph-sun' : 'ph ph-moon'"
          :aria-label="darkMode ? 'Switch to light mode' : 'Switch to dark mode'"
          class="docs-layout__icon-btn"
          @click="toggleDark($event)"
        />
      </q-toolbar>
    </q-header>

    <q-drawer
      v-model="leftOpen"
      show-if-above
      bordered
      :width="272"
      class="docs-layout__drawer"
    >
      <DocsNavList />
    </q-drawer>

    <q-page-container class="docs-layout__page">
      <div class="docs-layout__main" :class="{ 'docs-layout__main--with-toc': showPageToc }">
        <div class="docs-layout__content">
          <router-view :key="route.fullPath" />
        </div>
        <aside v-if="showPageToc" class="docs-layout__aside" aria-label="Page outline">
          <DocsToc :items="tocDisplayItems" />
        </aside>
      </div>
    </q-page-container>

    <q-drawer
      v-model="tocDrawerOpen"
      side="right"
      bordered
      overlay
      :width="300"
      class="docs-layout__toc-drawer"
    >
      <div class="docs-layout__toc-drawer-inner">
        <DocsToc :items="tocDisplayItems" />
      </div>
    </q-drawer>

    <q-dialog v-model="searchOpen">
      <q-card class="docs-search">
        <q-card-section>
          <q-input
            v-model="searchQuery"
            outlined
            dense
            autofocus
            placeholder="Search the guide"
            @keyup.esc="searchOpen = false"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" />
            </template>
          </q-input>
        </q-card-section>
        <q-list>
          <q-item
            v-for="item in searchHits"
            :key="item.name"
            clickable
            :to="item.path"
            v-close-popup
          >
            <q-item-section>{{ item.label }}</q-item-section>
          </q-item>
        </q-list>
      </q-card>
    </q-dialog>
  </q-layout>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useRoute } from 'vue-router';
import { useAppearance } from 'src/composables/useAppearance';
import DocsNavList from '../components/DocsNavList.vue';
import DocsToc from '../components/DocsToc.vue';
import { flattenDocsNav, findDocsNavContext } from '../content/nav';
import { provideDocsToc, type DocsTocItem } from '../composables/useDocsToc';

const $q = useQuasar();
const route = useRoute();
const { darkMode, setDarkMode } = useAppearance();
const toc = provideDocsToc();
const tocItems = computed(() => toc.items.value);
const tocDisplayItems = ref<DocsTocItem[]>([]);

const leftOpen = ref(true);
const searchOpen = ref(false);
const searchQuery = ref('');
const tocDrawerOpen = ref(false);

const pageSupportsOutline = computed(() => {
  if (route.name === 'docs-overview') return true;
  const md = route.meta.docsMd;
  return typeof md === 'string' && md.length > 0;
});

const showPageToc = computed(() => $q.screen.gt.md && pageSupportsOutline.value);
const showPageTocMobile = computed(() => !$q.screen.gt.md && pageSupportsOutline.value);

watch(tocItems, (items) => {
  if (items.length > 0) {
    tocDisplayItems.value = items;
  }
});

watch(
  () => route.fullPath,
  () => {
    tocDrawerOpen.value = false;
    toc.clearAllOwners();
  },
);

const crumb = computed(() => {
  const ctx = findDocsNavContext(typeof route.name === 'string' ? route.name : null);
  if (!ctx.current) return '';
  if (ctx.current.group) return `${ctx.current.group} / ${ctx.current.label}`;
  return ctx.current.label;
});

const searchHits = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  const items = flattenDocsNav();
  if (!q) return items;
  return items.filter((item) => item.label.toLowerCase().includes(q));
});

async function toggleDark(event: Event) {
  const next = !darkMode.value;
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const origin =
    (event.target as HTMLElement | null)?.closest?.('button') ??
    (event.currentTarget as HTMLElement | null);
  const doc = document as Document & {
    startViewTransition?: (cb: () => void | Promise<void>) => { finished: Promise<void> };
  };

  if (reduced || !origin || !doc.startViewTransition) {
    await setDarkMode(next);
    return;
  }

  const rect = origin.getBoundingClientRect();
  const x = rect.left + rect.width / 2;
  const y = rect.top + rect.height / 2;
  const radius = Math.hypot(
    Math.max(x, window.innerWidth - x),
    Math.max(y, window.innerHeight - y),
  );
  const root = document.documentElement;
  root.style.setProperty('--docs-theme-x', `${x}px`);
  root.style.setProperty('--docs-theme-y', `${y}px`);
  root.style.setProperty('--docs-theme-r', `${radius}px`);
  root.classList.add('docs-theme-morph');
  root.classList.toggle('docs-theme-morph--to-light', !next);

  try {
    const transition = doc.startViewTransition(() => setDarkMode(next));
    await transition.finished;
  } finally {
    root.classList.remove('docs-theme-morph', 'docs-theme-morph--to-light');
  }
}

function onKeydown(event: KeyboardEvent) {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
    event.preventDefault();
    searchOpen.value = true;
  }
}

onMounted(() => {
  window.addEventListener('keydown', onKeydown);
});

onUnmounted(() => {
  window.removeEventListener('keydown', onKeydown);
});
</script>

<style scoped>
.docs-layout {
  background: var(--tf-theme-base);
  color: var(--tf-theme-ink);
}

.docs-layout__header {
  background: var(--tf-theme-base);
  color: var(--tf-theme-heading, var(--tf-theme-ink));
}

.docs-layout__toolbar {
  min-height: 56px;
}

.docs-layout__product {
  color: var(--tf-theme-heading, var(--tf-theme-ink));
  text-decoration: none;
}

.docs-layout__product:hover {
  color: var(--tf-theme-primary);
}

.docs-layout__crumb {
  font-size: 12px;
  color: var(--tf-theme-muted);
}

.docs-layout__icon-btn {
  color: var(--tf-theme-ink);
}

.docs-layout__product:focus-visible,
.docs-layout__icon-btn:focus-visible {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}

.docs-layout__drawer {
  background: var(--tf-theme-base);
}

.docs-layout__page {
  background: var(--tf-theme-base);
}

.docs-layout__main {
  display: block;
  min-width: 0;
}

.docs-layout__main--with-toc {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(200px, 260px);
  align-items: start;
  gap: 0 8px;
  max-width: 1280px;
  margin: 0 auto;
  padding-right: 8px;
  box-sizing: border-box;
}

.docs-layout__content {
  min-width: 0;
}

.docs-layout__aside {
  min-width: 0;
}

.docs-layout__toc-drawer {
  background: var(--tf-theme-base);
}

.docs-layout__toc-drawer-inner {
  padding: 16px;
}

.docs-layout__toc-drawer-inner :deep(.docs-toc) {
  border-left: 0;
  padding-left: 0;
  max-height: none;
}

.docs-search {
  min-width: 320px;
  background: var(--tf-theme-surface);
  color: var(--tf-theme-ink);
}

</style>

<style>
html.docs-theme-morph::view-transition-old(root),
html.docs-theme-morph::view-transition-new(root) {
  animation: none;
  mix-blend-mode: normal;
}

html.docs-theme-morph::view-transition-new(root) {
  z-index: 2;
  animation: docs-theme-reveal 560ms cubic-bezier(0.22, 1, 0.36, 1) both;
}

html.docs-theme-morph.docs-theme-morph--to-light::view-transition-old(root) {
  z-index: 2;
  animation: docs-theme-reveal 560ms cubic-bezier(0.22, 1, 0.36, 1) both reverse;
}

html.docs-theme-morph.docs-theme-morph--to-light::view-transition-new(root) {
  z-index: 1;
  animation: none;
}

@keyframes docs-theme-reveal {
  from {
    clip-path: circle(0px at var(--docs-theme-x) var(--docs-theme-y));
  }
  to {
    clip-path: circle(var(--docs-theme-r) at var(--docs-theme-x) var(--docs-theme-y));
  }
}
</style>
