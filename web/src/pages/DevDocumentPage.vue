<template>
  <q-layout view="hHh LpR lFr" class="theme-app doc-portal-layout">
    <!-- Top Header (Flat, no elevation, app scoped border) -->
    <q-header class="doc-header">
      <q-toolbar class="q-px-md doc-toolbar">
        <q-btn
          flat
          dense
          round
          icon="menu"
          aria-label="Toggle Navigation"
          class="q-mr-sm lt-md"
          @click="leftDrawerOpen = !leftDrawerOpen"
        />

        <div class="row items-center q-gutter-x-sm cursor-pointer" @click="selectFirstDoc">
          <q-avatar size="28px" class="doc-logo-avatar" icon="menu_book" />
          <div class="column">
            <span class="text-weight-bold text-subtitle2 leading-tight doc-title-text">TradeFlow Codex</span>
            <span class="text-caption doc-subtitle-text">
              Engineering Specs & Architecture
            </span>
          </div>
        </div>

        <q-space />

        <!-- Search Bar -->
        <q-input
          v-model="searchQuery"
          outlined
          dense
          rounded
          placeholder="Search specs, RPCs, schemas... (Press '/')"
          class="doc-search-input gt-xs q-mr-md"
          ref="searchInputRef"
          clearable
        >
          <template #prepend>
            <q-icon name="search" size="18px" class="doc-muted-icon" />
          </template>
          <template #append>
            <span class="doc-kbd-hint">/</span>
          </template>
        </q-input>

        <!-- Header Actions -->
        <div class="row items-center q-gutter-x-xs">
          <q-btn
            flat
            round
            dense
            :icon="isDark ? 'light_mode' : 'dark_mode'"
            :title="isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode'"
            @click="toggleDark"
            class="doc-action-btn"
          />

          <q-btn
            v-if="activeDoc && activeDoc.headings.length > 0"
            flat
            round
            dense
            icon="format_list_bulleted"
            :color="rightDrawerOpen ? 'primary' : ''"
            :title="rightDrawerOpen ? 'Hide Table of Contents' : 'Show Table of Contents'"
            @click="rightDrawerOpen = !rightDrawerOpen"
            class="doc-action-btn"
          >
            <q-badge color="primary" floating rounded style="font-size: 9px; padding: 2px 4px">
              {{ activeDoc.headings.length }}
            </q-badge>
          </q-btn>

          <q-btn
            flat
            round
            dense
            icon="open_in_new"
            title="Return to App"
            to="/app/dashboard"
            class="doc-action-btn"
          />
        </div>
      </q-toolbar>

      <!-- Badge Filter Row -->
      <div class="q-px-md q-py-xs row items-center q-gutter-xs overflow-auto no-wrap doc-filter-bar">
        <q-chip
          clickable
          :outline="selectedBadge !== null"
          :class="selectedBadge === null ? 'doc-chip--active' : 'doc-chip--inactive'"
          size="sm"
          class="text-weight-medium doc-badge-chip"
          @click="selectedBadge = null"
        >
          All ({{ allDocs.length }})
        </q-chip>
        <q-chip
          v-for="badge in badgeTypes"
          :key="badge.name"
          clickable
          :outline="selectedBadge !== badge.name"
          :class="selectedBadge === badge.name ? 'doc-chip--active' : 'doc-chip--inactive'"
          size="sm"
          class="text-weight-medium doc-badge-chip"
          @click="toggleBadgeFilter(badge.name)"
        >
          {{ badge.name }} ({{ countByBadge(badge.name) }})
        </q-chip>
      </div>
    </q-header>

    <!-- Left Navigation Drawer -->
    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above
      bordered
      :width="310"
      class="doc-sidebar-drawer"
    >
      <div class="q-pa-sm lt-sm">
        <q-input
          v-model="searchQuery"
          outlined
          dense
          rounded
          placeholder="Search documentation..."
          clearable
        >
          <template #prepend>
            <q-icon name="search" size="18px" />
          </template>
        </q-input>
      </div>

      <q-scroll-area class="fit q-py-xs">
        <div v-if="filteredCategoryGroups.length === 0" class="q-pa-lg text-center doc-empty-state">
          <q-icon name="find_in_page" size="40px" class="q-mb-sm doc-muted-icon" />
          <div class="text-weight-bold text-subtitle2">No specifications match</div>
          <div class="text-caption q-mt-xs text-grey-6">Try searching for different terms or reset filters.</div>
          <q-btn flat color="primary" label="Reset Search" class="q-mt-sm" size="sm" @click="resetFilters" />
        </div>

        <q-list padding dense class="doc-nav-tree">
          <template v-for="category in filteredCategoryGroups" :key="category.name">
            <q-item-label header class="text-weight-bold text-uppercase doc-category-header row items-center">
              <q-icon :name="category.icon" size="15px" class="q-mr-xs text-primary" />
              <span>{{ category.name }}</span>
              <q-space />
              <q-badge class="doc-count-badge">
                {{ category.docs.length }}
              </q-badge>
            </q-item-label>

            <!-- Subgroups / Feature Folders -->
            <template v-for="(docs, subName) in category.subgroups" :key="subName">
              <q-expansion-item
                v-if="subName !== 'General' && docs.length > 1"
                :default-opened="true"
                dense
                dense-toggle
                expand-separator
                header-class="doc-folder-header text-weight-bold text-caption"
              >
                <template #header>
                  <q-item-section avatar style="min-width: 22px">
                    <q-icon name="folder" size="15px" color="amber-8" />
                  </q-item-section>
                  <q-item-section>
                    <span class="text-weight-bold">{{ subName }}</span>
                  </q-item-section>
                  <q-item-section side>
                    <span class="text-caption doc-muted-text">{{ docs.length }}</span>
                  </q-item-section>
                </template>

                <q-item
                  v-for="doc in docs"
                  :key="doc.id"
                  clickable
                  v-ripple
                  :active="activeDoc?.id === doc.id"
                  active-class="doc-item--active"
                  class="doc-subitem q-pl-lg"
                  @click="selectDoc(doc)"
                >
                  <q-item-section avatar style="min-width: 16px">
                    <span class="doc-dot-indicator" :class="activeDoc?.id === doc.id ? 'bg-primary' : 'bg-grey-5'" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-body2 text-weight-medium doc-item-label">
                      {{ cleanDocTitle(doc.title) }}
                    </q-item-label>
                  </q-item-section>
                </q-item>
              </q-expansion-item>

              <!-- Single items or General -->
              <template v-else>
                <q-item
                  v-for="doc in docs"
                  :key="doc.id"
                  clickable
                  v-ripple
                  :active="activeDoc?.id === doc.id"
                  active-class="doc-item--active"
                  class="doc-item"
                  @click="selectDoc(doc)"
                >
                  <q-item-section avatar style="min-width: 22px">
                    <q-icon name="description" size="15px" :color="activeDoc?.id === doc.id ? 'primary' : 'grey-6'" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-body2 text-weight-medium doc-item-label">
                      {{ cleanDocTitle(doc.title) }}
                    </q-item-label>
                  </q-item-section>
                  <q-item-section side v-if="doc.badge">
                    <q-badge outline size="xs" class="doc-badge-pill">
                      {{ doc.badge }}
                    </q-badge>
                  </q-item-section>
                </q-item>
              </template>
            </template>
          </template>
        </q-list>
      </q-scroll-area>
    </q-drawer>

    <!-- Right-hand Table of Contents Drawer (On this page) -->
    <q-drawer
      v-if="activeDoc && activeDoc.headings.length > 0"
      side="right"
      v-model="rightDrawerOpen"
      show-if-above
      bordered
      :width="260"
      class="doc-toc-drawer"
    >
      <div class="q-pa-md fit column no-wrap">
        <div class="text-overline text-weight-bold doc-toc-header row items-center q-mb-sm">
          <q-icon name="format_list_bulleted" size="14px" class="q-mr-xs text-primary" />
          ON THIS PAGE
        </div>

        <q-scroll-area class="col">
          <q-list dense class="q-gutter-y-xs">
            <q-item
              v-for="heading in activeDoc.headings"
              :key="heading.id"
              clickable
              v-ripple
              dense
              class="doc-toc-item"
              :class="{ 'q-pl-md': heading.level === 3, 'q-pl-xs': heading.level === 2 }"
              @click="scrollToHeading(heading.id)"
            >
              <q-item-section>
                <q-item-label
                  class="text-caption text-weight-medium doc-toc-label"
                  :class="activeHeadingId === heading.id ? 'text-primary text-weight-bolder doc-toc-active' : 'doc-muted-text'"
                >
                  {{ heading.text }}
                </q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </q-scroll-area>
      </div>
    </q-drawer>

    <!-- Main Content Reader Surface -->
    <q-page-container class="doc-page-container">
      <q-page class="q-pa-md q-pa-lg-xl doc-reader-page" v-if="activeDoc">
        <div class="doc-content-wrapper">
          <!-- Document Header (Flat, app scope) -->
          <div class="doc-header-banner q-mb-lg q-pb-md">
            <!-- Breadcrumbs -->
            <q-breadcrumbs class="text-caption doc-breadcrumbs q-mb-sm">
              <q-breadcrumbs-el label="Codex" icon="menu_book" />
              <q-breadcrumbs-el :label="activeDoc.category" />
              <q-breadcrumbs-el v-if="activeDoc.subgroup" :label="activeDoc.subgroup" />
              <q-breadcrumbs-el :label="cleanDocTitle(activeDoc.title)" class="text-weight-bold" />
            </q-breadcrumbs>

            <!-- Document Title & Badges -->
            <div class="row items-center justify-between q-col-gutter-y-sm">
              <div class="col-12 col-md-8">
                <h1 class="text-h4 text-weight-bolder q-ma-none doc-main-title leading-tight">
                  {{ activeDoc.title }}
                </h1>
                <div class="row items-center q-gutter-x-sm q-mt-xs wrap">
                  <q-badge v-if="activeDoc.badge" class="doc-active-badge text-weight-bold">
                    {{ activeDoc.badge }}
                  </q-badge>
                  <span class="text-caption doc-muted-text row items-center">
                    <q-icon name="schedule" size="14px" class="q-mr-xs" />
                    {{ activeDoc.readingTimeMinutes }} min read ({{ activeDoc.wordCount }} words)
                  </span>
                  <span class="text-caption doc-muted-text">•</span>
                  <span class="text-caption doc-muted-text row items-center font-mono">
                    <q-icon name="folder_open" size="14px" class="q-mr-xs" />
                    {{ activeDoc.path }}
                  </span>
                </div>
              </div>

              <!-- Top Doc Actions -->
              <div class="row items-center q-gutter-x-xs">
                <q-btn-toggle
                  v-model="viewMode"
                  rounded
                  dense
                  unelevated
                  toggle-color="primary"
                  class="doc-view-toggle"
                  :options="[
                    { label: 'Rendered', value: 'rendered', icon: 'visibility' },
                    { label: 'Raw', value: 'raw', icon: 'code' },
                  ]"
                />

                <q-btn
                  flat
                  round
                  dense
                  icon="content_copy"
                  :color="copied ? 'positive' : ''"
                  :title="copied ? 'Copied to clipboard!' : 'Copy raw markdown'"
                  class="doc-action-btn"
                  @click="copyDocContent"
                />
              </div>
            </div>
          </div>

          <!-- Document Rendered Body -->
          <div v-if="viewMode === 'rendered'" class="doc-markdown-body" v-html="renderedHtml" />

          <!-- Document Raw Markdown View -->
          <div v-else class="doc-raw-container">
            <pre class="doc-raw-pre"><code>{{ activeDoc.rawContent }}</code></pre>
          </div>

          <!-- Bottom Continuous Navigation Cards (Flat, app scoped) -->
          <div class="row justify-between q-mt-xl q-pt-lg doc-nav-footer q-col-gutter-md">
            <div class="col-12 col-sm-6">
              <q-card
                v-if="prevDoc"
                flat
                class="cursor-pointer doc-nav-card"
                @click="selectDoc(prevDoc)"
              >
                <q-card-section class="q-pa-md">
                  <div class="text-caption doc-muted-text row items-center">
                    <q-icon name="arrow_back" size="14px" class="q-mr-xs" /> PREVIOUS SPEC
                  </div>
                  <div class="text-weight-bold text-subtitle1 q-mt-xs ellipsis doc-title-text">
                    {{ cleanDocTitle(prevDoc.title) }}
                  </div>
                  <div class="text-caption doc-muted-text ellipsis">
                    {{ prevDoc.category }}
                  </div>
                </q-card-section>
              </q-card>
            </div>

            <div class="col-12 col-sm-6">
              <q-card
                v-if="nextDoc"
                flat
                class="cursor-pointer doc-nav-card text-right"
                @click="selectDoc(nextDoc)"
              >
                <q-card-section class="q-pa-md">
                  <div class="text-caption doc-muted-text row items-center justify-end">
                    NEXT SPEC <q-icon name="arrow_forward" size="14px" class="q-ml-xs" />
                  </div>
                  <div class="text-weight-bold text-subtitle1 q-mt-xs ellipsis doc-title-text">
                    {{ cleanDocTitle(nextDoc.title) }}
                  </div>
                  <div class="text-caption doc-muted-text ellipsis">
                    {{ nextDoc.category }}
                  </div>
                </q-card-section>
              </q-card>
            </div>
          </div>
        </div>
      </q-page>
    </q-page-container>
  </q-layout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { marked } from 'marked';
import { getAllDocs, groupDocsByCategory, type DocItem, type DocCategoryGroup } from 'src/lib/docsLoader';

const $q = useQuasar();
const route = useRoute();
const router = useRouter();

// State
const leftDrawerOpen = ref(true);
const rightDrawerOpen = ref(true);
const searchQuery = ref('');
const selectedBadge = ref<string | null>(null);
const viewMode = ref<'rendered' | 'raw'>('rendered');
const copied = ref(false);
const searchInputRef = ref<{ focus: () => void } | null>(null);
const activeHeadingId = ref<string>('');

const allDocs = ref<DocItem[]>(getAllDocs());
const activeDoc = ref<DocItem | null>(allDocs.value[0] || null);

// Quasar Dark Mode integration
const isDark = computed(() => $q.dark.isActive);

function toggleDark() {
  $q.dark.toggle();
}

// Badge types with standard tags
const badgeTypes = [
  { name: 'PRD' },
  { name: 'Data Model' },
  { name: 'API Contract' },
  { name: 'TDD' },
  { name: 'Matrix' },
  { name: 'Architecture' },
  { name: 'Fix Plan' },
  { name: 'Plan' },
];

function countByBadge(badgeName: string): number {
  return allDocs.value.filter((d) => d.badge === badgeName).length;
}

function toggleBadgeFilter(badgeName: string) {
  selectedBadge.value = selectedBadge.value === badgeName ? null : badgeName;
}

function resetFilters() {
  searchQuery.value = '';
  selectedBadge.value = null;
}

function cleanDocTitle(title: string): string {
  let cleaned = title.replace(/^#+\s*/, '').trim();
  if (cleaned.startsWith('[Feature Name] — ')) {
    cleaned = cleaned.replace('[Feature Name] — ', '');
  }
  return cleaned || title;
}

// Filtered category groups based on search & badge
const filteredCategoryGroups = computed<DocCategoryGroup[]>(() => {
  const q = searchQuery.value.toLowerCase().trim();
  const b = selectedBadge.value;

  const filtered = allDocs.value.filter((doc) => {
    if (b && doc.badge !== b) return false;
    if (!q) return true;
    return (
      doc.title.toLowerCase().includes(q) ||
      doc.path.toLowerCase().includes(q) ||
      doc.category.toLowerCase().includes(q) ||
      (doc.subgroup && doc.subgroup.toLowerCase().includes(q)) ||
      (doc.summary && doc.summary.toLowerCase().includes(q)) ||
      doc.rawContent.toLowerCase().includes(q)
    );
  });

  return groupDocsByCategory(filtered);
});

// Previous & Next navigation
const prevDoc = computed<DocItem | null>(() => {
  if (!activeDoc.value) return null;
  const idx = allDocs.value.findIndex((d) => d.id === activeDoc.value?.id);
  return idx > 0 ? (allDocs.value[idx - 1] ?? null) : null;
});

const nextDoc = computed<DocItem | null>(() => {
  if (!activeDoc.value) return null;
  const idx = allDocs.value.findIndex((d) => d.id === activeDoc.value?.id);
  return idx >= 0 && idx < allDocs.value.length - 1 ? (allDocs.value[idx + 1] ?? null) : null;
});

// Render markdown to HTML with GitHub alerts & anchor headings
const renderedHtml = computed(() => {
  if (!activeDoc.value) return '';

  const raw = activeDoc.value.rawContent;

  const parsed = marked.parse(raw, {
    gfm: true,
    breaks: true,
  }) as string;

  // Post-process HTML for GitHub Alerts
  return parsed.replace(
    /<blockquote>\s*<p>\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\](?:\s*<br\s*\/?>)?([\s\S]*?)<\/p>\s*<\/blockquote>/gi,
    (_match, type, content) => {
      const upperType = type.toUpperCase();
      let icon = 'info';
      let label = 'NOTE';
      if (upperType === 'TIP') {
        icon = 'tips_and_updates';
        label = 'TIP';
      } else if (upperType === 'IMPORTANT') {
        icon = 'priority_high';
        label = 'IMPORTANT';
      } else if (upperType === 'WARNING') {
        icon = 'warning';
        label = 'WARNING';
      } else if (upperType === 'CAUTION') {
        icon = 'dangerous';
        label = 'CAUTION';
      }

      return `<div class="doc-alert doc-alert--${upperType.toLowerCase()}">
        <div class="doc-alert__header">
          <span class="material-icons doc-alert__icon">${icon}</span>
          <span class="doc-alert__title">${label}</span>
        </div>
        <div class="doc-alert__body">${content}</div>
      </div>`;
    }
  );
});

function selectDoc(doc: DocItem) {
  activeDoc.value = doc;
  void router.replace({ query: { doc: doc.id } });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function selectFirstDoc() {
  if (allDocs.value[0]) {
    selectDoc(allDocs.value[0]);
  }
}

function copyDocContent() {
  if (!activeDoc.value) return;
  void navigator.clipboard.writeText(activeDoc.value.rawContent);
  copied.value = true;
  setTimeout(() => {
    copied.value = false;
  }, 2000);
}

function scrollToHeading(id: string) {
  activeHeadingId.value = id;
  const el = document.getElementById(id);
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
}

// Keyboard shortcuts (Slash for search)
function handleGlobalKeydown(e: KeyboardEvent) {
  if (e.key === '/' && document.activeElement?.tagName !== 'INPUT' && document.activeElement?.tagName !== 'TEXTAREA') {
    e.preventDefault();
    searchInputRef.value?.focus();
  }
}

// Inject heading IDs after render
watch(renderedHtml, () => {
  void nextTick(() => {
    const headings = document.querySelectorAll('.doc-markdown-body h2, .doc-markdown-body h3');
    headings.forEach((h) => {
      const text = h.textContent?.trim() || '';
      const slug = text
        .toLowerCase()
        .replace(/[^\w\s-]/g, '')
        .trim()
        .replace(/\s+/g, '-');
      h.setAttribute('id', slug);
    });
  });
});

onMounted(() => {
  window.addEventListener('keydown', handleGlobalKeydown);

  // Read initial query param if present
  const docQuery = route.query.doc as string | undefined;
  if (docQuery) {
    const found = allDocs.value.find((d) => d.id === docQuery || d.path.includes(docQuery));
    if (found) {
      activeDoc.value = found;
    }
  }
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleGlobalKeydown);
});
</script>

<style lang="scss">
/* Layout Container using App Scoped Color Variables */
.doc-portal-layout {
  min-height: 100vh;
  background-color: var(--bw-theme-surface);
  color: var(--bw-theme-ink);
  font-family: var(--bw-font-ui);
}

/* Header: Flat, border-only, zero drop shadow */
.doc-header {
  background-color: var(--bw-theme-surface) !important;
  color: var(--bw-theme-ink) !important;
  border-bottom: 1px solid var(--bw-theme-border);
  box-shadow: none !important;
}

.doc-toolbar {
  min-height: 52px;
}

.doc-logo-avatar {
  background-color: var(--bw-theme-primary);
  color: #ffffff;
}

.doc-title-text {
  color: var(--bw-theme-ink);
}

.doc-subtitle-text {
  color: var(--bw-theme-muted);
  font-size: 10px;
  margin-top: -2px;
}

.doc-muted-icon {
  color: var(--bw-theme-muted);
}

.doc-muted-text {
  color: var(--bw-theme-muted);
}

.doc-kbd-hint {
  font-size: 11px;
  font-weight: 700;
  padding: 1px 5px;
  border-radius: 4px;
  background: var(--bw-theme-border);
  color: var(--bw-theme-ink);
}

.doc-action-btn {
  color: var(--bw-theme-muted);
  &:hover {
    color: var(--bw-theme-ink);
  }
}

.doc-filter-bar {
  border-top: 1px solid var(--bw-theme-border);
  background-color: var(--bw-theme-base);
}

.doc-badge-chip {
  border-radius: 6px;
  font-size: 11px;
}

.doc-chip--active {
  background-color: var(--bw-theme-primary) !important;
  color: #ffffff !important;
}

.doc-chip--inactive {
  background-color: transparent !important;
  border: 1px solid var(--bw-theme-border) !important;
  color: var(--bw-theme-muted) !important;
}

/* Sidebar Drawer */
.doc-sidebar-drawer {
  background-color: var(--bw-theme-base) !important;
  color: var(--bw-theme-ink) !important;
  border-right: 1px solid var(--bw-theme-border) !important;
}

.doc-category-header {
  font-size: 11px;
  letter-spacing: 0.5px;
  color: var(--bw-theme-muted) !important;
  padding-top: 14px;
  padding-bottom: 4px;
}

.doc-count-badge {
  background-color: var(--bw-theme-border);
  color: var(--bw-theme-ink);
  font-size: 10px;
}

.doc-item, .doc-subitem {
  border-radius: 6px;
  margin: 1px 6px;
  min-height: 32px;
  color: var(--bw-theme-ink);
  transition: background-color 0.15s ease;

  &:hover {
    background-color: rgba(var(--bw-theme-primary-rgb), 0.08);
  }
}

.doc-item-label {
  white-space: normal;
  word-break: break-word;
  line-height: 1.35;
  padding: 3px 0;
}

.doc-item--active {
  background-color: rgba(var(--bw-theme-primary-rgb), 0.14) !important;
  color: var(--bw-theme-primary) !important;
  font-weight: 700;
}

.doc-dot-indicator {
  display: inline-block;
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.doc-badge-pill {
  border-color: var(--bw-theme-border);
  color: var(--bw-theme-muted);
}

/* TOC Right Drawer */
.doc-toc-drawer {
  background-color: var(--bw-theme-base) !important;
  color: var(--bw-theme-ink) !important;
  border-left: 1px solid var(--bw-theme-border) !important;
}

.doc-toc-header {
  font-size: 11px;
  letter-spacing: 0.5px;
  color: var(--bw-theme-muted);
}

.doc-toc-item {
  border-radius: 4px;
  min-height: 24px;
  padding-top: 2px;
  padding-bottom: 2px;

  &:hover {
    background-color: rgba(var(--bw-theme-primary-rgb), 0.06);
  }
}

.doc-toc-label {
  white-space: normal;
  word-break: break-word;
  line-height: 1.35;
  padding: 2px 0;
}

.doc-toc-active {
  color: var(--bw-theme-primary) !important;
}

/* Main Page Content */
.doc-page-container {
  background-color: var(--bw-theme-surface) !important;
}

.doc-reader-page {
  display: flex;
  justify-content: center;
}

.doc-content-wrapper {
  max-width: 880px;
  width: 100%;
}

.doc-header-banner {
  border-bottom: 1px solid var(--bw-theme-border);
}

.doc-breadcrumbs {
  color: var(--bw-theme-muted);
}

.doc-main-title {
  color: var(--bw-theme-ink);
  font-size: 2rem;
}

.doc-active-badge {
  background-color: var(--bw-theme-primary);
  color: #ffffff;
}

.doc-view-toggle {
  border: 1px solid var(--bw-theme-border);
}

/* Continuous Navigation Cards */
.doc-nav-footer {
  border-top: 1px solid var(--bw-theme-border);
}

.doc-nav-card {
  border-radius: 8px;
  background-color: var(--bw-theme-base) !important;
  border: 1px solid var(--bw-theme-border);
  box-shadow: none !important;
  transition: border-color 0.15s ease, background-color 0.15s ease;

  &:hover {
    border-color: var(--bw-theme-primary);
    background-color: rgba(var(--bw-theme-primary-rgb), 0.04) !important;
  }
}

/* Markdown Aesthetics with App Colors */
.doc-markdown-body {
  font-size: 15px;
  line-height: 1.75;
  color: var(--bw-theme-ink);

  h1, h2, h3, h4, h5, h6 {
    color: var(--bw-theme-ink);
    font-weight: 700;
    line-height: 1.3;
    margin-top: 1.8em;
    margin-bottom: 0.6em;
    scroll-margin-top: 75px;
  }

  h1 { font-size: 1.85rem; border-bottom: 1px solid var(--bw-theme-border); padding-bottom: 0.3em; }
  h2 { font-size: 1.45rem; border-bottom: 1px solid var(--bw-theme-border); padding-bottom: 0.25em; }
  h3 { font-size: 1.2rem; }
  h4 { font-size: 1.05rem; }

  p, ul, ol {
    margin-top: 0.6em;
    margin-bottom: 1em;
  }

  li {
    margin-bottom: 0.3em;
  }

  /* Inline Code */
  code {
    font-family: var(--bw-font-mono);
    font-size: 0.88em;
    padding: 0.2em 0.4em;
    border-radius: 4px;
    background-color: var(--bw-theme-base);
    border: 1px solid var(--bw-theme-border);
    color: var(--bw-theme-primary);
  }

  /* Code Blocks */
  pre {
    background-color: #0f172a;
    color: #f8fafc;
    border-radius: 8px;
    padding: 1rem 1.25rem;
    overflow-x: auto;
    font-family: var(--bw-font-mono);
    font-size: 13px;
    line-height: 1.6;
    margin: 1.2em 0;
    border: 1px solid rgba(255, 255, 255, 0.1);

    code {
      background: transparent;
      padding: 0;
      border: none;
      color: inherit;
      font-size: inherit;
    }
  }

  /* Tables: Flat, app border */
  table {
    width: 100%;
    border-collapse: collapse;
    margin: 1.2em 0;
    font-size: 13.5px;

    th, td {
      border: 1px solid var(--bw-theme-border);
      padding: 8px 12px;
      text-align: left;
    }

    th {
      background-color: var(--bw-theme-base);
      font-weight: 600;
      color: var(--bw-theme-ink);
    }

    tr:nth-child(even) {
      background-color: rgba(var(--bw-theme-primary-rgb), 0.02);
    }
  }

  /* Blockquotes / Alerts */
  blockquote {
    border-left: 4px solid var(--bw-theme-primary);
    margin: 1em 0;
    padding: 0.5em 1em;
    background-color: rgba(var(--bw-theme-primary-rgb), 0.05);
    border-radius: 0 6px 6px 0;
    color: var(--bw-theme-ink);
  }

  hr {
    border: 0;
    height: 1px;
    background: var(--bw-theme-border);
    margin: 2em 0;
  }

  a {
    color: var(--bw-theme-primary);
    text-decoration: none;
    font-weight: 500;

    &:hover {
      text-decoration: underline;
    }
  }
}

/* GitHub Alert Callouts */
.doc-alert {
  border-radius: 8px;
  padding: 12px 16px;
  margin: 1.2em 0;
  border-left: 4px solid;

  .doc-alert__header {
    display: flex;
    align-items: center;
    font-weight: 700;
    font-size: 13px;
    margin-bottom: 6px;
    letter-spacing: 0.5px;
  }

  .doc-alert__icon {
    font-size: 18px;
    margin-right: 6px;
  }

  .doc-alert__body {
    font-size: 14px;
    line-height: 1.6;

    p:last-child {
      margin-bottom: 0;
    }
  }

  &--note {
    background-color: var(--bw-info-soft, #eff6ff);
    border-color: var(--bw-info, #3b82f6);
    color: var(--bw-theme-ink);
  }

  &--tip {
    background-color: var(--bw-success-soft, #f0fdf4);
    border-color: var(--bw-success, #22c55e);
    color: var(--bw-theme-ink);
  }

  &--important {
    background-color: rgba(168, 85, 247, 0.12);
    border-color: #a855f7;
    color: var(--bw-theme-ink);
  }

  &--warning {
    background-color: var(--bw-warning-soft, #fffbeb);
    border-color: var(--bw-warning, #f59e0b);
    color: var(--bw-theme-ink);
  }

  &--caution {
    background-color: var(--bw-error-soft, #fef2f2);
    border-color: var(--bw-error, #ef4444);
    color: var(--bw-theme-ink);
  }
}

.doc-raw-container {
  background-color: #0f172a;
  border-radius: 8px;
  padding: 1rem;
  overflow-x: auto;
  border: 1px solid var(--bw-theme-border);
}

.doc-raw-pre {
  margin: 0;
  color: #f8fafc;
  font-family: var(--bw-font-mono);
  font-size: 13px;
  line-height: 1.5;
}
</style>
