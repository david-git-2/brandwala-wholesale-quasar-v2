<template>
  <q-layout view="hHh lpR fFf" class="documentation-layout theme-app">
    <!-- Top Header -->
    <q-header elevated class="doc-header bg-white text-dark">
      <q-toolbar class="q-px-lg">
        <!-- Toggle Left Drawer Button (Mobile/Tablet) -->
        <q-btn
          flat
          round
          dense
          icon="menu"
          class="lt-md q-mr-md"
          color="primary"
          @click="leftDrawerOpen = !leftDrawerOpen"
        />

        <q-avatar size="32px" class="q-mr-sm">
          <img src="/tradeflowbd-logo.png" alt="TradeflowBD Logo" />
        </q-avatar>

        <q-toolbar-title
          class="text-weight-bold text-subtitle1 flex items-center no-wrap ink-color"
        >
          <span>TradeflowBD Wholesale Docs</span>
          <q-badge
            :color="currentScope === 'platform' ? 'purple-7' : 'teal-7'"
            class="q-ml-sm text-caption uppercase text-weight-bold"
          >
            {{ currentScope === 'platform' ? 'Platform Docs' : 'Workspace Docs' }}
          </q-badge>
        </q-toolbar-title>

        <q-space />

        <!-- Close Tab Action -->
        <q-btn
          flat
          dense
          color="grey-7"
          label="Close"
          icon="close"
          class="rounded-borders q-px-sm"
          @click="closeTab"
        />
      </q-toolbar>
    </q-header>

    <!-- Quasar Left Drawer: Article list & Search -->
    <q-drawer
      v-model="leftDrawerOpen"
      side="left"
      show-if-above
      bordered
      :width="280"
      class="bg-grey-1"
    >
      <div class="q-pa-md full-height column no-wrap">
        <!-- Drawer Header -->
        <div class="text-subtitle1 text-weight-bold ink-color flex items-center gap-xs q-mb-md">
          <q-icon name="article" color="primary" size="xs" />
          <span>Articles</span>
        </div>

        <!-- Search Input -->
        <q-input
          v-model="search"
          dense
          outlined
          placeholder="Search articles..."
          class="search-input q-mb-md bg-white"
        >
          <template v-slot:append>
            <q-icon name="search" size="xs" color="grey-6" />
          </template>
        </q-input>

        <!-- Scrollable list of articles -->
        <q-scroll-area class="col-grow">
          <q-list class="q-py-xs">
            <template v-if="filteredDocs.length > 0">
              <q-item
                v-for="doc in filteredDocs"
                :key="doc.key"
                clickable
                :active="activeDocKey === doc.key"
                active-class="active-doc-item"
                class="doc-item q-mb-xs rounded-borders"
                @click="onSelectDoc(doc)"
              >
                <q-item-section avatar class="min-width-icon">
                  <q-icon
                    :name="doc.moduleKey ? 'extension' : 'description'"
                    :color="activeDocKey === doc.key ? 'white' : 'grey-7'"
                    size="sm"
                  />
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-subtitle2 text-weight-bold ellipsis">{{
                    doc.title
                  }}</q-item-label>
                  <q-item-label
                    caption
                    :class="activeDocKey === doc.key ? 'text-blue-1' : 'text-grey-7'"
                    class="ellipsis-2-lines"
                  >
                    {{ doc.description }}
                  </q-item-label>
                </q-item-section>
              </q-item>
            </template>
            <q-item v-else>
              <q-item-section class="text-center text-grey-6 q-py-md">
                No documents found
              </q-item-section>
            </q-item>
          </q-list>
        </q-scroll-area>
      </div>
    </q-drawer>

    <!-- Center Reading View Container -->
    <q-page-container class="bg-grey-2 doc-page-container">
      <div class="q-pa-lg flex flex-center">
        <div class="reading-width">
          <router-view />
        </div>
      </div>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { DOCUMENTATION_REGISTRY, type DocItem } from '../utils/docRegistry';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

const search = ref('');
const leftDrawerOpen = ref(false);

const currentScope = computed<'app' | 'platform'>(() => {
  return route.path.startsWith('/platform') ? 'platform' : 'app';
});

const activeDocKey = computed(() => {
  return (route.params.docKey as string) || '';
});

const availableDocs = computed(() => {
  const scope = currentScope.value;
  return DOCUMENTATION_REGISTRY.filter((doc) => {
    if (scope === 'platform') {
      return doc.scope === 'platform' || doc.scope === 'both' || doc.scope === 'app';
    }

    // App Scope
    if (doc.scope === 'platform') {
      return false;
    }

    if (!doc.moduleKey) {
      return true;
    }

    return authStore.activeModuleKeys.includes(doc.moduleKey);
  });
});

const filteredDocs = computed(() => {
  const term = search.value.trim().toLowerCase();
  if (!term) return availableDocs.value;

  return availableDocs.value.filter(
    (doc) => doc.title.toLowerCase().includes(term) || doc.description.toLowerCase().includes(term),
  );
});

const navigateToDoc = (docKey: string) => {
  const tenantSlug = authStore.tenantSlug;
  if (currentScope.value === 'platform') {
    void router.push(`/platform/documentation/${docKey}`);
  } else {
    void router.push(
      tenantSlug ? `/${tenantSlug}/app/documentation/${docKey}` : `/app/documentation/${docKey}`,
    );
  }
};

const onSelectDoc = (doc: DocItem) => {
  navigateToDoc(doc.key);
  // Close left drawer on mobile/tablet viewports after selecting
  if (typeof window !== 'undefined' && window.innerWidth < 1024) {
    leftDrawerOpen.value = false;
  }
};

const closeTab = () => {
  if (typeof window !== 'undefined') {
    window.close();
  }
};

const ensureSelectedDoc = () => {
  if (!activeDocKey.value && availableDocs.value.length > 0) {
    const firstDoc = availableDocs.value[0];
    if (firstDoc) {
      navigateToDoc(firstDoc.key);
    }
  }
};

watch(
  availableDocs,
  () => {
    ensureSelectedDoc();
  },
  { immediate: true },
);

onMounted(() => {
  ensureSelectedDoc();
});
</script>

<style lang="scss">
.documentation-layout {
  height: 100vh;
  overflow: hidden;
  background: var(--bw-brand-base, #f6f8fa);
  color: var(--bw-brand-ink, #1f2937);
}

.doc-header {
  border-bottom: 1px solid var(--bw-theme-border, rgba(31, 41, 55, 0.08)) !important;
  backdrop-filter: blur(8px);
}

.doc-page-container {
  height: 100vh;
  overflow-y: auto;
}

.reading-width {
  width: 100%;
  max-width: 860px;
}

.search-input {
  .q-field__control {
    border-radius: 8px !important;
  }
}

.min-width-icon {
  min-width: 32px !important;
  padding-right: 8px !important;
}

.doc-item {
  transition: all 0.2s ease;
  border-radius: 8px;

  &:hover {
    background: var(--bw-theme-primary-soft);
  }

  &.active-doc-item {
    background: var(--bw-theme-primary) !important;
    color: white !important;
  }
}

.active-badge {
  background: rgba(15, 118, 110, 0.1);
  padding: 4px 10px;
  border-radius: 6px;
}

.bg-surface-soft {
  background-color: var(--bw-theme-primary-soft);
}

.border-bottom {
  border-bottom: 1px solid var(--bw-theme-border);
}

.ink-color {
  color: var(--bw-theme-ink);
}
</style>
