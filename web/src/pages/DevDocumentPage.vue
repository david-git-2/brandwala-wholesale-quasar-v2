<template>
  <q-layout view="hHh LpR lFr" class="doc-portal-slate">
    <!-- Top Header: Minimalist, clean white/slate with 1px border -->
    <q-header class="doc-slate-header">
      <q-toolbar class="q-px-lg doc-slate-toolbar">
        <q-btn
          flat
          dense
          round
          icon="menu"
          aria-label="Toggle Navigation"
          class="q-mr-sm lt-md doc-nav-toggle"
          @click="leftDrawerOpen = !leftDrawerOpen"
        />

        <!-- Brand Icon + Title + Pill Badge (exact match to Next.js layout) -->
        <div class="row items-center q-gutter-x-sm cursor-pointer no-wrap" @click="selectFirstDoc">
          <div class="doc-brand-circle">
            <span>T</span>
          </div>
          <div class="row items-center q-gutter-x-sm no-wrap">
            <span class="doc-brand-heading">TradeFlow Codex</span>
            <span class="doc-pill-tag gt-xs">Feature Specs Codex</span>
          </div>
        </div>

        <q-space />

        <!-- Right Header Actions: Minimalist text/ghost buttons -->
        <div class="row items-center q-gutter-x-md no-wrap">
          <!-- Dark Mode Toggle Button with Icon + Label -->
          <button class="doc-header-link-btn" @click="toggleDark">
            <q-icon :name="isDark ? 'light_mode' : 'dark_mode'" size="15px" class="q-mr-xs" />
            <span>{{ isDark ? 'Light' : 'Dark' }}</span>
          </button>

          <!-- Design System Link -->
          <router-link to="/dev/document" class="doc-header-link gt-xs">
            Design System
          </router-link>

          <!-- Return to App Link with Arrow -->
          <router-link to="/app/dashboard" class="doc-header-link row items-center">
            <span>App</span>
            <q-icon name="open_in_new" size="13px" class="q-ml-xs" />
          </router-link>

          <!-- TOC Toggle on smaller screens -->
          <q-btn
            v-if="activeDoc && activeDoc.headings.length > 0"
            flat
            round
            dense
            icon="format_list_bulleted"
            :color="rightDrawerOpen ? 'primary' : ''"
            class="lt-lg doc-icon-btn"
            title="Toggle Table of Contents"
            @click="rightDrawerOpen = !rightDrawerOpen"
          />
        </div>
      </q-toolbar>
    </q-header>

    <!-- Left Navigation Drawer -->
    <q-drawer
      v-model="leftDrawerOpen"
      show-if-above
      :width="290"
      class="doc-slate-sidebar"
    >
      <div class="column fit no-wrap justify-between">
        <!-- Top Search + Badge Filter Area -->
        <div class="q-pa-md doc-sidebar-header">
          <!-- Big comfortable search input -->
          <div class="doc-search-wrapper">
            <q-icon name="search" size="17px" class="doc-search-icon" />
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Search specs, actions, schemas..."
              class="doc-slate-input"
            />
            <button
              v-if="searchQuery"
              class="doc-clear-btn"
              @click="searchQuery = ''"
            >
              ✕
            </button>
          </div>

          <!-- Wrapped Filter Badges -->
          <div class="row items-center q-gutter-xs q-mt-sm doc-filter-chips">
            <button
              class="doc-filter-badge"
              :class="{ 'doc-filter-badge--active': selectedBadge === null }"
              @click="selectedBadge = null"
            >
              All
            </button>
            <button
              v-for="badge in badgeTypes"
              :key="badge.name"
              class="doc-filter-badge"
              :class="{ 'doc-filter-badge--active': selectedBadge === badge.name }"
              @click="toggleBadgeFilter(badge.name)"
            >
              {{ badge.name }}
            </button>
          </div>
        </div>

        <!-- Scrollable Tree -->
        <q-scroll-area class="col q-px-sm doc-sidebar-scroll">
          <div v-if="filteredCategoryGroups.length === 0" class="q-pa-lg text-center doc-empty-state">
            <div class="text-weight-medium text-caption text-grey-6">No matching documents</div>
            <button class="doc-reset-btn q-mt-xs" @click="resetFilters">Reset filters</button>
          </div>

          <div class="doc-tree-stack q-pb-md">
            <template v-for="category in filteredCategoryGroups" :key="category.name">
              <!-- Category Header with Emoji / Clean Icon -->
              <div class="doc-section-header">
                <span class="doc-section-emoji">{{ getCategoryEmoji(category.name) }}</span>
                <span class="doc-section-title">{{ category.name }}</span>
              </div>

              <!-- Subgroups / Feature Folders -->
              <template v-for="(docs, subName) in category.subgroups" :key="subName">
                <!-- Multi-doc Subgroup with Hierarchy Guides -->
                <div v-if="subName !== 'General' && docs.length > 1" class="doc-folder-group">
                  <div
                    class="doc-folder-row"
                    role="button"
                    tabindex="0"
                    @click="toggleFolder(subName)"
                  >
                    <div class="row items-center q-gutter-x-xs ellipsis">
                      <q-icon
                        :name="isFolderExpanded(subName) ? 'folder_open' : 'folder'"
                        size="15px"
                        class="doc-folder-icon"
                      />
                      <span class="doc-folder-label ellipsis">{{ subName }}</span>
                    </div>
                    <q-icon
                      :name="isFolderExpanded(subName) ? 'expand_more' : 'chevron_right'"
                      size="14px"
                      class="doc-chevron-icon"
                    />
                  </div>

                  <!-- Folder Children with Vertical Guide Line -->
                  <div v-show="isFolderExpanded(subName)" class="doc-tree-children">
                    <div
                      v-for="doc in docs"
                      :key="doc.id"
                      class="doc-tree-child-item"
                      :class="{ 'doc-tree-child-item--active': activeDoc?.id === doc.id }"
                      @click="selectDoc(doc)"
                    >
                      <span class="doc-child-title ellipsis">{{ getDocTreeSlug(doc) }}</span>
                      <span
                        v-if="doc.badge"
                        class="doc-tag-micro"
                        :class="`doc-tag-micro--${getBadgeClass(doc.badge)}`"
                      >
                        {{ doc.badge }}
                      </span>
                    </div>
                  </div>
                </div>

                <!-- Single items or General category -->
                <template v-else>
                  <div
                    v-for="doc in docs"
                    :key="doc.id"
                    class="doc-tree-item"
                    :class="{ 'doc-tree-item--active': activeDoc?.id === doc.id }"
                    @click="selectDoc(doc)"
                  >
                    <span class="doc-item-title ellipsis">{{ cleanDocTitle(doc.title) }}</span>
                    <span
                      v-if="doc.badge"
                      class="doc-tag-micro"
                      :class="`doc-tag-micro--${getBadgeClass(doc.badge)}`"
                    >
                      {{ doc.badge }}
                    </span>
                  </div>
                </template>
              </template>
            </template>
          </div>
        </q-scroll-area>

        <!-- Sidebar Fixed Footer -->
        <div class="doc-sidebar-footer row items-center justify-between">
          <span class="doc-footer-label">TradeFlow Specs</span>
          <span class="doc-footer-count">{{ allDocs.length }} Documents</span>
        </div>
      </div>
    </q-drawer>

    <!-- Right-hand Table of Contents: Completely Borderless Floating Column -->
    <q-drawer
      v-if="activeDoc && activeDoc.headings.length > 0"
      side="right"
      v-model="rightDrawerOpen"
      show-if-above
      :width="240"
      class="doc-slate-toc-drawer"
    >
      <div class="q-pa-lg fit column no-wrap justify-between">
        <div class="column no-wrap">
          <div class="doc-toc-headline">ON THIS PAGE</div>

          <q-scroll-area class="doc-toc-scroll q-mt-sm">
            <nav class="doc-toc-nav">
              <a
                v-for="heading in activeDoc.headings"
                :key="heading.id"
                :href="`#${heading.id}`"
                class="doc-toc-anchor"
                :class="{
                  'doc-toc-anchor--active': activeHeadingId === heading.id,
                  'doc-toc-anchor--h3': heading.level === 3,
                }"
                @click.prevent="scrollToHeading(heading.id)"
              >
                <span v-if="heading.level === 2" class="doc-toc-bullet">•</span>
                <span class="doc-toc-text ellipsis">{{ heading.text }}</span>
              </a>
            </nav>
          </q-scroll-area>
        </div>

        <!-- Back to Top Link -->
        <div class="doc-back-top-wrapper">
          <button class="doc-back-top-btn" @click="scrollToTop">
            <q-icon name="arrow_upward" size="13px" class="q-mr-xs" />
            <span>Back to top</span>
          </button>
        </div>
      </div>
    </q-drawer>

    <!-- Main Content Canvas -->
    <q-page-container class="doc-main-container">
      <q-page class="q-pa-md q-pa-xl-lg doc-prose-page" v-if="activeDoc">
        <div class="doc-prose-wrapper">
          <!-- Rendered Prose View -->
          <article
            class="doc-slate-prose"
            v-html="renderedHtml"
            @click="handleProseClick"
          />

          <!-- Bottom Previous / Next Spec Cards -->
          <footer class="row justify-between q-mt-xl q-pt-xl doc-slate-pagination q-col-gutter-md">
            <div class="col-12 col-sm-6">
              <div
                v-if="prevDoc"
                class="doc-pag-card cursor-pointer"
                role="button"
                tabindex="0"
                @click="selectDoc(prevDoc)"
              >
                <div class="doc-pag-sub">← PREVIOUS</div>
                <div class="doc-pag-title ellipsis">{{ cleanDocTitle(prevDoc.title) }}</div>
              </div>
            </div>

            <div class="col-12 col-sm-6">
              <div
                v-if="nextDoc"
                class="doc-pag-card doc-pag-card--next cursor-pointer text-right"
                role="button"
                tabindex="0"
                @click="selectDoc(nextDoc)"
              >
                <div class="doc-pag-sub">NEXT →</div>
                <div class="doc-pag-title ellipsis">{{ cleanDocTitle(nextDoc.title) }}</div>
              </div>
            </div>
          </footer>
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

// Layout state
const leftDrawerOpen = ref(true);
const rightDrawerOpen = ref(true);
const searchQuery = ref('');
const selectedBadge = ref<string | null>(null);
const activeHeadingId = ref<string>('');
const expandedFolders = ref<Record<string, boolean>>({});

const allDocs = ref<DocItem[]>(getAllDocs());
const activeDoc = ref<DocItem | null>(allDocs.value[0] || null);

// Quasar Dark Mode integration
const isDark = computed(() => $q.dark.isActive);

function toggleDark() {
  $q.dark.toggle();
}

// Category Emojis from Image 1
function getCategoryEmoji(cat: string): string {
  if (cat.includes('Architecture')) return '🏛️';
  if (cat.includes('Features')) return '🪪';
  if (cat.includes('Operations')) return '📦';
  if (cat.includes('System') || cat.includes('Fixes')) return '🛠️';
  return '📖';
}

// Badge types with color classes matching Image 1
const badgeTypes = [
  { name: 'PRD' },
  { name: 'Schema' },
  { name: 'API Contract' },
  { name: 'TDD' },
  { name: 'Matrix' },
  { name: 'Architecture' },
];

function getBadgeClass(badge: string): string {
  const lower = badge.toLowerCase();
  if (lower.includes('prd')) return 'blue';
  if (lower.includes('schema') || lower.includes('data')) return 'green';
  if (lower.includes('api') || lower.includes('contract')) return 'orange';
  if (lower.includes('tdd')) return 'purple';
  if (lower.includes('matrix') || lower.includes('stub')) return 'amber';
  return 'gray';
}

function toggleBadgeFilter(badgeName: string) {
  selectedBadge.value = selectedBadge.value === badgeName ? null : badgeName;
}

function resetFilters() {
  searchQuery.value = '';
  selectedBadge.value = null;
}

function isFolderExpanded(folder: string): boolean {
  return expandedFolders.value[folder] ?? true;
}

function toggleFolder(folder: string) {
  expandedFolders.value[folder] = !isFolderExpanded(folder);
}

function cleanDocTitle(title: string): string {
  let cleaned = title.replace(/^#+\s*/, '').trim();
  if (cleaned.startsWith('[Feature Name] — ')) {
    cleaned = cleaned.replace('[Feature Name] — ', '');
  }
  return cleaned || title;
}

// Generate short tree slug (e.g. "01-prd", "02-data-model") for folder children
function getDocTreeSlug(doc: DocItem): string {
  const fileName = doc.path.split('/').pop()?.replace(/\.md$/, '') || '';
  if (/^0\d-/.test(fileName)) {
    return fileName;
  }
  if (doc.badge) {
    if (doc.badge === 'PRD') return '01-prd';
    if (doc.badge === 'Data Model' || doc.badge === 'Schema') return '02-data-model';
    if (doc.badge === 'API Contract') return '03-api-contract';
    if (doc.badge === 'TDD') return '04-tdd';
    if (doc.badge === 'Matrix') return '05-matrix';
    if (doc.badge === 'Fix Plan') return 'fix-plan';
  }
  return fileName || cleanDocTitle(doc.title);
}

// Filtered category groups for sidebar navigation
const filteredCategoryGroups = computed<DocCategoryGroup[]>(() => {
  const q = searchQuery.value.toLowerCase().trim();
  const b = selectedBadge.value;

  const filtered = allDocs.value.filter((doc) => {
    if (b) {
      if (b === 'Schema' && doc.badge !== 'Schema' && doc.badge !== 'Data Model') return false;
      if (b !== 'Schema' && doc.badge !== b) return false;
    }
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

// Render markdown to HTML formatted to match Next.js typography & tables
const renderedHtml = computed(() => {
  if (!activeDoc.value) return '';

  const raw = activeDoc.value.rawContent;

  const parsed = marked.parse(raw, {
    gfm: true,
    breaks: true,
  }) as string;

  // Post-process table code cells into pill badges matching Image 1
  let enhanced = parsed.replace(
    /<td>\s*<code>([^<]+)<\/code>\s*<\/td>/gi,
    '<td><span class="doc-table-command">$1</span></td>'
  );

  // Post-process GitHub alerts
  enhanced = enhanced.replace(
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

      return `<div class="doc-slate-alert doc-slate-alert--${upperType.toLowerCase()}">
        <div class="doc-slate-alert__header">
          <span class="material-icons doc-slate-alert__icon">${icon}</span>
          <span class="doc-slate-alert__title">${label}</span>
        </div>
        <div class="doc-slate-alert__body">${content}</div>
      </div>`;
    }
  );

  return enhanced;
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

function scrollToHeading(id: string) {
  activeHeadingId.value = id;
  const el = document.getElementById(id);
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
}

function scrollToTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function handleProseClick(e: MouseEvent) {
  const target = e.target as HTMLElement | null;
  const link = target?.closest('a') as HTMLAnchorElement | null;
  if (link) {
    const href = link.getAttribute('href');
    if (href && href.startsWith('#')) {
      e.preventDefault();
      scrollToHeading(href.slice(1));
    }
  }
}

// Scroll Spy for TOC
function handleWindowScroll() {
  const headings = document.querySelectorAll<HTMLElement>('.doc-slate-prose h2, .doc-slate-prose h3');
  const scrollPos = window.scrollY + 100;
  let currentId = '';
  headings.forEach((h) => {
    if (h.offsetTop <= scrollPos) {
      currentId = h.id;
    }
  });
  if (currentId) {
    activeHeadingId.value = currentId;
  }
}

// Inject heading IDs
watch(renderedHtml, () => {
  void nextTick(() => {
    const headings = document.querySelectorAll<HTMLElement>('.doc-slate-prose h2, .doc-slate-prose h3');
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
  window.addEventListener('scroll', handleWindowScroll, { passive: true });

  const docQuery = route.query.doc as string | undefined;
  if (docQuery) {
    const found = allDocs.value.find((d) => d.id === docQuery || d.path.includes(docQuery));
    if (found) {
      activeDoc.value = found;
    }
  }
});

onUnmounted(() => {
  window.removeEventListener('scroll', handleWindowScroll);
});
</script>

<style lang="scss">
/* Root Slate Theme matching Next.js / Tailwind Slate Palette */
.doc-portal-slate {
  min-height: 100vh;
  background-color: #ffffff;
  color: #0f172a;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
}

body.body--dark .doc-portal-slate {
  background-color: #09090b;
  color: #f4f4f5;
}

/* Header */
.doc-slate-header {
  background-color: #ffffff !important;
  color: #0f172a !important;
  border-bottom: 1px solid #e2e8f0;
  box-shadow: none !important;
  position: sticky;
  top: 0;
  z-index: 100;
}

body.body--dark .doc-slate-header {
  background-color: #09090b !important;
  color: #f4f4f5 !important;
  border-bottom: 1px solid #27272a;
}

.doc-slate-toolbar {
  height: 54px;
  min-height: 54px;
}

.doc-brand-circle {
  width: 28px;
  height: 28px;
  border-radius: 6px;
  background-color: var(--bw-brand-accent, #0d6b5c);
  color: #ffffff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 15px;
}

.doc-brand-heading {
  font-size: 15px;
  font-weight: 700;
  color: #0f172a;
  letter-spacing: -0.01em;
}

body.body--dark .doc-brand-heading {
  color: #f4f4f5;
}

.doc-pill-tag {
  font-size: 11px;
  font-weight: 500;
  padding: 2px 8px;
  border-radius: 999px;
  background-color: #f1f5f9;
  border: 1px solid #e2e8f0;
  color: #64748b;
}

body.body--dark .doc-pill-tag {
  background-color: #18181b;
  border-color: #27272a;
  color: #a1a1aa;
}

.doc-header-link-btn {
  display: inline-flex;
  align-items: center;
  font-size: 13px;
  font-weight: 500;
  padding: 4px 10px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
  background: #ffffff;
  color: #334155;
  cursor: pointer;
  transition: all 0.15s ease;

  &:hover {
    background-color: #f8fafc;
    color: #0f172a;
  }
}

body.body--dark .doc-header-link-btn {
  background: #18181b;
  border-color: #27272a;
  color: #d4d4d8;

  &:hover {
    background-color: #27272a;
    color: #ffffff;
  }
}

.doc-header-link {
  font-size: 13px;
  font-weight: 500;
  color: #64748b;
  text-decoration: none;
  transition: color 0.15s ease;

  &:hover {
    color: #0f172a;
  }
}

body.body--dark .doc-header-link {
  color: #a1a1aa;
  &:hover {
    color: #f4f4f5;
  }
}

/* Sidebar */
.doc-slate-sidebar {
  background-color: #ffffff !important;
  border-right: 1px solid #e2e8f0 !important;
}

body.body--dark .doc-slate-sidebar {
  background-color: #09090b !important;
  border-right: 1px solid #27272a !important;
}

.doc-sidebar-header {
  border-bottom: 1px solid #f1f5f9;
}

body.body--dark .doc-sidebar-header {
  border-bottom: 1px solid #18181b;
}

.doc-search-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 6px 10px;
  transition: border-color 0.15s ease;

  &:focus-within {
    border-color: var(--bw-brand-accent, #0d6b5c);
    box-shadow: 0 0 0 2px color-mix(in srgb, var(--bw-brand-accent, #0d6b5c) 15%, transparent);
  }
}

body.body--dark .doc-search-wrapper {
  background: #18181b;
  border-color: #27272a;
}

.doc-search-icon {
  color: #94a3b8;
  margin-right: 6px;
}

.doc-slate-input {
  border: none;
  background: transparent;
  outline: none;
  font-size: 12.5px;
  width: 100%;
  color: #0f172a;

  &::placeholder {
    color: #94a3b8;
  }
}

body.body--dark .doc-slate-input {
  color: #f4f4f5;
}

.doc-clear-btn {
  border: none;
  background: transparent;
  color: #94a3b8;
  font-size: 11px;
  cursor: pointer;
}

.doc-filter-chips {
  flex-wrap: wrap;
  gap: 5px;
}

.doc-filter-badge {
  font-size: 11px;
  font-weight: 500;
  padding: 2px 7px;
  border-radius: 5px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
  color: #64748b;
  cursor: pointer;
  transition: all 0.12s ease;

  &:hover {
    background: #f1f5f9;
    color: #0f172a;
  }

  &--active {
    background: #0f172a !important;
    border-color: #0f172a !important;
    color: #ffffff !important;
  }
}

body.body--dark .doc-filter-badge {
  background: #18181b;
  border-color: #27272a;
  color: #a1a1aa;

  &--active {
    background: #f4f4f5 !important;
    border-color: #f4f4f5 !important;
    color: #09090b !important;
  }
}

/* Sidebar Tree Section */
.doc-section-header {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: #64748b;
  margin-top: 18px;
  margin-bottom: 6px;
  padding: 0 10px;
  display: flex;
  align-items: center;
  gap: 6px;
}

body.body--dark .doc-section-header {
  color: #a1a1aa;
}

.doc-folder-group {
  margin-bottom: 2px;
}

.doc-folder-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 5px 8px;
  border-radius: 6px;
  cursor: pointer;
  color: #334155;
  transition: background 0.12s ease;

  &:hover {
    background-color: #f1f5f9;
  }
}

body.body--dark .doc-folder-row {
  color: #d4d4d8;
  &:hover {
    background-color: #18181b;
  }
}

.doc-folder-icon {
  color: var(--bw-brand-accent, #0d6b5c);
}

.doc-folder-label {
  font-size: 12.5px;
  font-weight: 600;
}

.doc-chevron-icon {
  color: #94a3b8;
}

/* Indent Guide Line connecting child items */
.doc-tree-children {
  margin-left: 15px;
  padding-left: 10px;
  border-left: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
  gap: 1px;
  margin-top: 2px;
  margin-bottom: 4px;
}

body.body--dark .doc-tree-children {
  border-left-color: #27272a;
}

.doc-tree-child-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 4px 8px;
  border-radius: 5px;
  cursor: pointer;
  color: #64748b;
  font-size: 12px;
  font-weight: 500;
  transition: all 0.1s ease;

  &:hover {
    background-color: #f8fafc;
    color: #0f172a;
  }

  &--active {
    background-color: color-mix(in srgb, var(--bw-brand-accent, #0d6b5c) 10%, transparent) !important;
    color: var(--bw-brand-accent, #0d6b5c) !important;
    font-weight: 600;
  }
}

body.body--dark .doc-tree-child-item {
  color: #a1a1aa;
  &:hover {
    background-color: #18181b;
    color: #f4f4f5;
  }

  &--active {
    background-color: color-mix(in srgb, var(--bw-brand-accent, #4db8a4) 18%, transparent) !important;
    color: var(--bw-brand-accent, #4db8a4) !important;
  }
}

.doc-tree-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 5px 10px;
  border-radius: 6px;
  cursor: pointer;
  color: #334155;
  font-size: 12.5px;
  font-weight: 500;
  margin-bottom: 2px;
  transition: all 0.1s ease;

  &:hover {
    background-color: #f8fafc;
    color: #0f172a;
  }

  &--active {
    background-color: color-mix(in srgb, var(--bw-brand-accent, #0d6b5c) 10%, transparent) !important;
    color: var(--bw-brand-accent, #0d6b5c) !important;
    font-weight: 600;
  }
}

body.body--dark .doc-tree-item {
  color: #d4d4d8;
  &:hover {
    background-color: #18181b;
    color: #f4f4f5;
  }

  &--active {
    background-color: color-mix(in srgb, var(--bw-brand-accent, #4db8a4) 18%, transparent) !important;
    color: var(--bw-brand-accent, #4db8a4) !important;
  }
}

/* Color-coded micro badges matching Next.js */
.doc-tag-micro {
  font-size: 9px;
  font-weight: 600;
  padding: 1px 5px;
  border-radius: 4px;
  text-transform: uppercase;
  letter-spacing: 0.02em;

  &--blue {
    background-color: #eff6ff;
    color: #2563eb;
    border: 1px solid #bfdbfe;
  }

  &--green {
    background-color: #f0fdf4;
    color: #16a34a;
    border: 1px solid #bbf7d0;
  }

  &--orange {
    background-color: #fff7ed;
    color: #ea580c;
    border: 1px solid #fed7aa;
  }

  &--purple {
    background-color: #faf5ff;
    color: #9333ea;
    border: 1px solid #e9d5ff;
  }

  &--amber {
    background-color: #fffbeb;
    color: #d97706;
    border: 1px solid #fde68a;
  }

  &--gray {
    background-color: #f8fafc;
    color: #64748b;
    border: 1px solid #e2e8f0;
  }
}

body.body--dark .doc-tag-micro {
  &--blue { background: rgba(37, 99, 235, 0.15); border-color: rgba(37, 99, 235, 0.3); color: #60a5fa; }
  &--green { background: rgba(22, 163, 74, 0.15); border-color: rgba(22, 163, 74, 0.3); color: #4ade80; }
  &--orange { background: rgba(234, 88, 12, 0.15); border-color: rgba(234, 88, 12, 0.3); color: #fb923c; }
  &--purple { background: rgba(147, 51, 234, 0.15); border-color: rgba(147, 51, 234, 0.3); color: #c084fc; }
  &--amber { background: rgba(217, 119, 6, 0.15); border-color: rgba(217, 119, 6, 0.3); color: #fcd34d; }
  &--gray { background: #18181b; border-color: #27272a; color: #a1a1aa; }
}

/* Sidebar Footer */
.doc-sidebar-footer {
  border-top: 1px solid #e2e8f0;
  padding: 10px 14px;
  font-size: 11px;
  color: #94a3b8;
}

body.body--dark .doc-sidebar-footer {
  border-top-color: #27272a;
}

/* Completely Borderless Floating Right TOC */
.doc-slate-toc-drawer {
  background-color: transparent !important;
  border: none !important;
  border-left: none !important;
  box-shadow: none !important;
}

.doc-toc-headline {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.05em;
  color: #64748b;
  margin-bottom: 8px;
}

body.body--dark .doc-toc-headline {
  color: #a1a1aa;
}

.doc-toc-scroll {
  height: calc(100vh - 160px);
}

.doc-toc-nav {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.doc-toc-anchor {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 12.5px;
  line-height: 1.4;
  color: #64748b;
  text-decoration: none;
  transition: color 0.15s ease;

  &:hover {
    color: #0f172a;
  }

  &--active {
    color: var(--bw-brand-accent, #0d6b5c) !important;
    font-weight: 600;
  }

  &--h3 {
    padding-left: 14px;
    font-size: 12px;
  }
}

body.body--dark .doc-toc-anchor {
  color: #a1a1aa;
  &:hover { color: #f4f4f5; }
  &--active { color: var(--bw-brand-accent, #4db8a4) !important; }
}

.doc-toc-bullet {
  font-size: 14px;
  color: #94a3b8;
}

.doc-back-top-btn {
  border: none;
  background: transparent;
  color: #94a3b8;
  font-size: 12px;
  cursor: pointer;
  display: flex;
  align-items: center;
  padding: 0;

  &:hover {
    color: var(--bw-brand-accent, #0d6b5c);
  }
}

/* Main Prose Area */
.doc-main-container {
  background-color: #ffffff;
}

body.body--dark .doc-main-container {
  background-color: #09090b;
}

.doc-prose-page {
  display: flex;
  justify-content: center;
}

.doc-prose-wrapper {
  max-width: 860px;
  width: 100%;
}

/* Prose Typography matching Next.js / Tailwind Typography */
.doc-slate-prose {
  font-size: 15px;
  line-height: 1.75;
  color: #334155;

  h1, h2, h3, h4 {
    color: #0f172a;
    font-weight: 700;
    line-height: 1.3;
    letter-spacing: -0.02em;
  }

  h1 {
    font-size: 1.8rem;
    margin-top: 1em;
    margin-bottom: 0.6em;
  }

  h2 {
    font-size: 1.35rem;
    margin-top: 2em;
    margin-bottom: 0.5em;
  }

  h3 {
    font-size: 1.15rem;
    margin-top: 1.6em;
    margin-bottom: 0.4em;
  }

  p {
    margin-top: 0.6em;
    margin-bottom: 1.2em;
  }

  ul, ol {
    margin-top: 0.5em;
    margin-bottom: 1.2em;
    padding-left: 1.4em;
  }

  li {
    margin-bottom: 0.35em;
  }

  /* Inline code chip */
  code {
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    font-size: 0.85em;
    background-color: #f1f5f9;
    border: 1px solid #e2e8f0;
    color: #0f172a;
    padding: 2px 6px;
    border-radius: 5px;
    font-weight: 500;
  }

  /* Code blocks */
  pre {
    background-color: #0f172a;
    color: #e2e8f0;
    border-radius: 8px;
    padding: 1rem 1.25rem;
    overflow-x: auto;
    font-size: 13px;
    line-height: 1.6;
    margin: 1.4em 0;

    code {
      background: transparent;
      border: none;
      color: inherit;
      padding: 0;
    }
  }

  /* Tables matching Next.js Table in Image 1 */
  table {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
    margin: 1.8em 0;
    font-size: 13.5px;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    overflow: hidden;

    th, td {
      padding: 10px 16px;
      border-bottom: 1px solid #e2e8f0;
      border-right: 1px solid #e2e8f0;
      text-align: left;

      &:last-child {
        border-right: none;
      }
    }

    tr:last-child td {
      border-bottom: none;
    }

    th {
      background-color: #f8fafc;
      font-weight: 600;
      color: #0f172a;
      font-size: 12.5px;
    }

    tr:hover td {
      background-color: #f8fafc;
    }
  }

  /* Table command pills matching Image 1 */
  .doc-table-command {
    display: inline-block;
    background-color: #f1f5f9;
    border: 1px solid #e2e8f0;
    padding: 2px 8px;
    border-radius: 6px;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 12px;
    color: #0f172a;
    font-weight: 500;
  }

  a {
    color: var(--bw-brand-accent, #0d6b5c);
    text-decoration: none;
    font-weight: 500;

    &:hover {
      text-decoration: underline;
    }
  }
}

body.body--dark .doc-slate-prose {
  color: #cbd5e1;

  h1, h2, h3, h4 { color: #f8fafc; }

  code {
    background-color: #18181b;
    border-color: #27272a;
    color: #f4f4f5;
  }

  table {
    border-color: #27272a;

    th, td {
      border-color: #27272a;
    }

    th {
      background-color: #18181b;
      color: #f8fafc;
    }

    tr:hover td {
      background-color: #18181b;
    }
  }

  .doc-table-command {
    background-color: #18181b;
    border-color: #27272a;
    color: #f4f4f5;
  }

  a {
    color: var(--bw-brand-accent, #4db8a4);
  }
}

/* Callouts */
.doc-slate-alert {
  border-radius: 8px;
  padding: 12px 16px;
  margin: 1.4em 0;
  border-left: 3px solid;

  &__header {
    display: flex;
    align-items: center;
    font-weight: 600;
    font-size: 12px;
    margin-bottom: 4px;
  }

  &__icon {
    font-size: 16px;
    margin-right: 6px;
  }

  &__body {
    font-size: 13.5px;
    line-height: 1.6;
    p:last-child { margin-bottom: 0; }
  }

  &--note { background-color: #eff6ff; border-color: #2563eb; color: #1e3a8a; }
  &--tip { background-color: #f0fdf4; border-color: #16a34a; color: #14532d; }
  &--important { background-color: #faf5ff; border-color: #9333ea; color: #581c87; }
  &--warning { background-color: #fffbeb; border-color: #d97706; color: #78350f; }
  &--caution { background-color: #fef2f2; border-color: #dc2626; color: #7f1d1d; }
}

body.body--dark .doc-slate-alert {
  &--note { background-color: rgba(37, 99, 235, 0.1); border-color: #3b82f6; color: #93c5fd; }
  &--tip { background-color: rgba(22, 163, 74, 0.1); border-color: #22c55e; color: #86efac; }
  &--important { background-color: rgba(147, 51, 234, 0.1); border-color: #a855f7; color: #d8b4fe; }
  &--warning { background-color: rgba(217, 119, 6, 0.1); border-color: #f59e0b; color: #fde68a; }
  &--caution { background-color: rgba(220, 38, 38, 0.1); border-color: #ef4444; color: #fca5a5; }
}

/* Pagination Cards */
.doc-slate-pagination {
  border-top: 1px solid #e2e8f0;
}

body.body--dark .doc-slate-pagination {
  border-top-color: #27272a;
}

.doc-pag-card {
  padding: 12px 16px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  background: #ffffff;
  transition: all 0.15s ease;

  &:hover {
    border-color: var(--bw-brand-accent, #0d6b5c);
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
  }
}

body.body--dark .doc-pag-card {
  background: #09090b;
  border-color: #27272a;

  &:hover {
    border-color: var(--bw-brand-accent, #4db8a4);
  }
}

.doc-pag-sub {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.05em;
  color: #94a3b8;
}

.doc-pag-title {
  font-size: 13.5px;
  font-weight: 600;
  color: #0f172a;
  margin-top: 4px;
}

body.body--dark .doc-pag-title {
  color: #f8fafc;
}
</style>
