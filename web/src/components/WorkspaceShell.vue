<template>
  <q-layout
    view="hHh lpR fFf"
    class="workspace-shell"
    :class="[...themeClasses, { 'workspace-shell--mini': isMini }]"
  >
    <q-header :reveal="$q.screen.lt.md" class="workspace-shell__header">
      <q-toolbar class="workspace-shell__toolbar">
        <q-btn
          v-if="!useMobileBottomNav"
          flat
          round
          dense
          icon="ph ph-list"
          class="workspace-shell__menu"
          @click="toggleDrawerOrPin"
        />

        <q-btn v-else-if="!useHeaderProfile" flat round dense class="workspace-shell__menu" padding="none">
          <q-avatar size="32px" class="workspace-shell__avatar">
            <img
              v-if="userAvatarUrl"
              :src="userAvatarUrl"
              class="workspace-shell__avatar-image"
              referrerpolicy="no-referrer"
              alt=""
            />
            <span v-else class="workspace-shell__avatar-fallback">{{ userInitials }}</span>
          </q-avatar>
          <q-menu style="min-width: 200px">
            <q-list dense class="q-py-xs">
              <q-item-label
                header
                class="text-uppercase text-weight-bold text-grey-7"
                style="font-size: 10px; letter-spacing: 0.1em"
                >Session Info</q-item-label
              >
              <q-item v-if="currentRoleLabel">
                <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                  <q-icon name="ph ph-shield" size="xs" color="grey-6" />
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-caption text-weight-medium">Role</q-item-label>
                  <q-item-label caption>{{ currentRoleLabel }}</q-item-label>
                </q-item-section>
              </q-item>
              <q-item v-if="contextLabel && contextValue">
                <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                  <q-icon name="ph ph-buildings" size="xs" color="grey-6" />
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-caption text-weight-medium">{{
                    contextLabel
                  }}</q-item-label>
                  <q-item-label caption>{{ contextValue }}</q-item-label>
                </q-item-section>
              </q-item>

              <q-separator class="q-my-xs" />
              <q-item-label
                header
                class="text-uppercase text-weight-bold text-grey-7"
                style="font-size: 10px; letter-spacing: 0.1em"
                >Appearance</q-item-label
              >
              <q-item clickable @click="toggleDarkMode">
                <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                  <q-icon :name="darkMode ? 'dark_mode' : 'light_mode'" size="xs" color="grey-6" />
                </q-item-section>
                <q-item-section>Dark Mode</q-item-section>
                <q-item-section side>
                  <q-toggle :model-value="darkMode" @update:model-value="toggleDarkMode" dense />
                </q-item-section>
              </q-item>
              <q-item clickable @click="toggleDensity">
                <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                  <q-icon name="ph ph-list" size="xs" color="grey-6" />
                </q-item-section>
                <q-item-section>Compact Rows</q-item-section>
                <q-item-section side>
                  <q-toggle
                    :model-value="density === 'compact'"
                    @update:model-value="toggleDensity"
                    dense
                  />
                </q-item-section>
              </q-item>

              <!-- About System -->
              <q-separator class="q-my-xs" />
              <q-item clickable v-close-popup @click="showAboutDialog = true">
                <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                  <q-icon name="ph ph-info" size="xs" color="primary" />
                </q-item-section>
                <q-item-section class="text-caption text-weight-medium">About System</q-item-section>
              </q-item>

              <q-separator class="q-my-xs" />
              <q-item clickable v-close-popup @click="handleLogout">
                <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                  <q-icon name="ph ph-sign-out" size="xs" color="grey-7" />
                </q-item-section>
                <q-item-section class="text-grey-8 text-weight-medium">Sign out</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>

        <div class="workspace-shell__header-divider gt-xs" />

        <div class="workspace-shell__context">
          <slot name="header-left" />
        </div>

        <div
          v-if="$slots['header-center']"
          class="workspace-shell__center"
          :class="{ 'workspace-shell__center--shop': theme === 'shop', 'gt-sm': theme !== 'shop' }"
        >
          <slot name="header-center" />
        </div>

        <q-space />

        <div class="workspace-shell__actions">
          <slot name="header-extra" />
        </div>
      </q-toolbar>
    </q-header>

    <q-drawer
      v-if="!useMobileBottomNav"
      v-model="drawerOpen"
      :mini="isMini"
      @mouseenter="miniState = false"
      @mouseleave="miniState = true"
      :mini-width="58"
      :width="250"
      show-if-above
      bordered
      class="workspace-shell__drawer"
    >
      <div class="workspace-shell__drawer-inner column full-height">
        <div class="workspace-shell__drawer-top row items-center justify-between">
          <div
            v-show="!isMini"
            class="workspace-shell__drawer-brand row items-center no-wrap"
          >
            <AppLogoMark :scope="theme" class="workspace-shell__app-mark" />
            <div class="workspace-shell__drawer-title ellipsis">
              {{ theme === 'app' ? 'Desk' : 'Navigation' }}
            </div>
          </div>
          <AppLogoMark
            v-show="isMini"
            :scope="theme"
            class="workspace-shell__app-mark workspace-shell__app-mark--mini"
          />
          <q-btn
            v-show="!isMini"
            flat
            round
            dense
            icon="ph ph-push-pin"
            size="sm"
            class="workspace-shell__pin-btn"
            :class="{ 'workspace-shell__pin-btn--pinned': navPinned }"
            @click="togglePin"
          >
            <q-tooltip>{{ navPinned ? 'Collapse sidebar' : 'Pin sidebar' }}</q-tooltip>
          </q-btn>
        </div>

        <q-scroll-area class="col fit workspace-shell__drawer-scroll">
          <div class="workspace-shell__nav q-py-xs">
            <q-list class="workspace-shell__nav-list">
              <template v-for="link in links" :key="link.to || link.title">
                <!-- Labeled nav group (flat children, not collapsible) -->
                <template v-if="link.navGroup && link.children?.length">
                  <div
                    v-if="!isMini"
                    class="workspace-shell__nav-sub-header workspace-shell__nav-group-label"
                  >
                    {{ translateTitle(link.title) }}
                  </div>

                  <q-item
                    v-for="child in link.children"
                    :key="child.to ?? child.title"
                    clickable
                    :to="child.target ? undefined : child.to"
                    :href="child.target ? child.to : undefined"
                    :target="child.target"
                    class="workspace-shell__nav-item workspace-shell__nav-group-child"
                    :class="{
                      'workspace-shell__nav-item--active': isNavGroupChildActive(
                        child.to,
                        link.children,
                      ),
                    }"
                  >
                    <q-item-section avatar style="min-width: 36px">
                      <q-icon :name="child.icon" size="20px" />
                    </q-item-section>

                    <q-item-section>
                      <q-item-label class="text-weight-medium">{{ translateTitle(child.title) }}</q-item-label>
                    </q-item-section>

                    <q-tooltip
                      v-if="isMini"
                      anchor="center right"
                      self="center left"
                      :offset="[10, 10]"
                    >
                      {{ translateTitle(child.title) }}
                    </q-tooltip>
                  </q-item>
                </template>

                <!-- Group with children (expansion item) -->
                <q-expansion-item
                  v-else-if="link.children?.length"
                  :model-value="expandedGroups[link.title] ?? false"
                  @update:model-value="(val) => (expandedGroups[link.title] = !!val)"
                  :icon="link.icon"
                  :label="translateTitle(link.title)"
                  class="workspace-shell__nav-item workspace-shell__nav-group"
                  :header-class="['workspace-shell__nav-header', { 'workspace-shell__nav-item--active': isGroupActive(link) }]"
                  expand-separator
                  dense
                >
                  <template #header>
                    <q-item-section avatar style="min-width: 36px">
                      <q-icon :name="link.icon" size="20px" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-weight-medium">{{ translateTitle(link.title) }}</q-item-label>
                    </q-item-section>
                    <q-tooltip v-if="isMini" anchor="center right" self="center left" :offset="[10, 10]">
                      {{ translateTitle(link.title) }}
                    </q-tooltip>
                  </template>

                  <div class="workspace-shell__nav-sub-list">
                    <template v-for="(child, idx) in link.children" :key="child.to ?? child.title">
                      <div
                        v-if="shouldShowSectionHeader(link, child, idx)"
                        class="workspace-shell__nav-sub-header"
                      >
                        {{ child.section }}
                      </div>

                      <q-item
                        clickable
                        :to="child.to!"
                        class="workspace-shell__nav-sub-item"
                        :class="{ 'workspace-shell__nav-item--active': isLinkActive(child.to) }"
                      >
                        <q-item-section v-if="child.icon" avatar class="q-pr-none" style="min-width: 28px">
                          <q-icon :name="child.icon" size="16px" color="grey-6" class="sub-item-icon" />
                        </q-item-section>
                        <q-item-section>
                          <q-item-label class="text-weight-medium">{{ translateTitle(child.title) }}</q-item-label>
                        </q-item-section>
                      </q-item>
                    </template>
                  </div>
                </q-expansion-item>

                <!-- Single link item -->
                <q-item
                  v-else-if="link.to"
                  clickable
                  :to="link.target ? undefined : link.to"
                  :href="link.target ? link.to : undefined"
                  :target="link.target"
                  class="workspace-shell__nav-item"
                  :class="{ 'workspace-shell__nav-item--active': isLinkActive(link.to) }"
                >
                  <q-item-section avatar style="min-width: 36px">
                    <q-icon :name="link.icon" size="20px" />
                  </q-item-section>

                  <q-item-section>
                    <q-item-label class="text-weight-medium">{{ translateTitle(link.title) }}</q-item-label>
                  </q-item-section>

                  <q-tooltip
                    v-if="isMini"
                    anchor="center right"
                    self="center left"
                    :offset="[10, 10]"
                  >
                    {{ translateTitle(link.title) }}
                  </q-tooltip>
                </q-item>
              </template>
            </q-list>
          </div>
        </q-scroll-area>

        <div class="workspace-shell__drawer-bottom q-pa-xs border-top">
          <q-btn
            flat
            dense
            no-caps
            class="workspace-shell__logout full-width"
            @click="handleLogout"
          >
            <div class="row items-center justify-center no-wrap q-gutter-x-sm">
              <q-icon name="ph ph-sign-out" size="18px" color="grey-7" />
              <span v-if="!isMini" class="text-grey-8 text-weight-medium text-caption">Sign out</span>
            </div>
            <q-tooltip v-if="isMini" anchor="center right" self="center left" :offset="[10, 10]">
              Sign out
            </q-tooltip>
          </q-btn>
        </div>
      </div>
    </q-drawer>

    <q-footer v-if="useMobileBottomNav" :reveal="$q.screen.xs" elevated class="workspace-shell__bottom-nav">
      <nav class="workspace-shell__bottom-nav-inner" aria-label="Shop navigation">
        <template v-for="link in links" :key="link.to || link.title">
          <q-btn
            v-if="link.children?.length"
            flat
            dense
            no-caps
            stack
            class="workspace-shell__bottom-nav-item"
            :class="{
              'workspace-shell__bottom-nav-item--active': isBottomNavGroupActive(link),
            }"
            :icon="link.icon"
            :label="translateTitle(link.title)"
          >
            <q-menu anchor="top middle" self="bottom middle" :offset="[0, 8]">
              <q-list dense style="min-width: 160px" class="q-py-xs">
                <q-item
                  v-for="child in link.children"
                  :key="child.to ?? child.title"
                  clickable
                  :to="child.to!"
                  exact
                  v-close-popup
                  active-class="workspace-shell__nav-item--active"
                >
                  <q-item-section>
                    <q-item-label>{{ translateTitle(child.title) }}</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>

          <q-btn
            v-else-if="link.to"
            flat
            dense
            no-caps
            stack
            class="workspace-shell__bottom-nav-item"
            :class="{
              'workspace-shell__bottom-nav-item--active': isBottomNavLinkActive(link),
            }"
            :icon="link.icon"
            :label="translateTitle(link.title)"
            :to="link.target ? undefined : link.to"
            :href="link.target ? link.to : undefined"
            :target="link.target"
          />
        </template>
      </nav>
    </q-footer>

    <q-page-container class="workspace-shell__page-container">
      <slot />
    </q-page-container>

    <!-- Command Palette Dialog -->
    <q-dialog
      v-model="showCommandPalette"
      position="top"
      class="command-palette-dialog"
      @show="onPaletteShow"
      @hide="onPaletteHide"
    >
      <q-card
        style="width: 580px; max-width: 90vw; margin-top: 10vh"
        class="command-palette-card shadow-5"
      >
        <div class="command-palette-search-row q-px-md q-py-xs">
          <q-input
            ref="searchInputRef"
            v-model="searchQuery"
            placeholder="Search pages or type to filter..."
            borderless
            dense
            autofocus
            class="command-palette-input full-width"
            @keydown="onInputKeydown"
          >
            <template #prepend>
              <q-icon name="ph ph-magnifying-glass" size="18px" class="command-palette-search-icon" />
            </template>
            <template #append>
              <q-btn
                v-if="searchQuery"
                flat
                round
                dense
                icon="ph ph-x"
                size="sm"
                @click="searchQuery = ''"
              />
              <kbd class="command-palette-esc-kbd q-ml-xs">ESC</kbd>
            </template>
          </q-input>
        </div>

        <div class="command-palette-sep" />

        <q-scroll-area style="height: 300px">
          <q-list v-if="filteredLinks.length" class="q-py-xs">
            <q-item
              v-for="(link, idx) in filteredLinks"
              :key="link.to || link.title"
              clickable
              :active="idx === activeIndex"
              active-class="command-palette-item--active"
              class="command-palette-item q-mx-sm q-my-xs rounded-borders"
              @click="navigate(link)"
              @mouseenter="activeIndex = idx"
            >
              <q-item-section avatar>
                <q-icon :name="link.icon" size="sm" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium">
                  <span v-html="highlightMatch(translateTitle(link.title), searchQuery)"></span>
                </q-item-label>
                <q-item-label v-if="link.caption" caption>
                  <span v-html="highlightMatch(translateCaption(link.title, link.caption), searchQuery)"></span>
                </q-item-label>
              </q-item-section>
              <q-item-section side v-if="link.parentTitle">
                <q-badge outline color="primary" size="sm">
                  <span v-html="highlightMatch(translateTitle(link.parentTitle), searchQuery)"></span>
                </q-badge>
              </q-item-section>
            </q-item>
          </q-list>
          <div v-else class="flex flex-center text-grey-6 q-pa-lg">
            <q-icon name="ph ph-magnifying-glass-minus" size="md" />
            <div class="q-ml-sm">No matching pages found</div>
          </div>
        </q-scroll-area>
      </q-card>
    </q-dialog>

    <!-- ── Sign-out confirmation dialog ───────────────────── -->
    <q-dialog v-model="showLogoutDialog" persistent class="signout-dialog">
      <div class="signout-card">
        <!-- Avatar + identity -->
        <div class="signout-card__identity">
          <div class="signout-card__avatar">
            <img v-if="userAvatarUrl" :src="userAvatarUrl" referrerpolicy="no-referrer" alt="" />
            <span v-else>{{ userInitials }}</span>
          </div>
          <div class="signout-card__user">
            <div class="signout-card__name">{{ userName }}</div>
            <div class="signout-card__email">{{ userEmail }}</div>
          </div>
        </div>

        <!-- Divider -->
        <div class="signout-card__sep" aria-hidden="true" />

        <!-- Meta pills -->
        <div class="signout-card__meta">
          <span v-if="currentRoleLabel" class="signout-card__pill">
            <q-icon name="ph ph-shield" size="0.8rem" />
            {{ currentRoleLabel }}
          </span>
          <span v-if="contextValue" class="signout-card__pill">
            <q-icon name="ph ph-buildings" size="0.8rem" />
            {{ contextValue }}
          </span>
        </div>

        <!-- Message -->
        <p class="signout-card__message">
          You’ll be signed out of this workspace. Your data stays safe.
        </p>

        <!-- Actions -->
        <div class="signout-card__actions">
          <button
            class="signout-card__btn signout-card__btn--cancel"
            @click="showLogoutDialog = false"
          >
            Stay signed in
          </button>
          <button class="signout-card__btn signout-card__btn--confirm" @click="confirmLogout">
            <q-icon name="ph ph-sign-out" size="1rem" />
            Sign out
          </button>
        </div>
      </div>
    </q-dialog>

    <AboutSystemDialog v-model="showAboutDialog" />
  </q-layout>
</template>

<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import type { QInput } from 'quasar';
import { useI18n } from 'vue-i18n';

import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useAppearance } from 'src/composables/useAppearance';
import AboutSystemDialog from 'src/components/navigation/AboutSystemDialog.vue';
import AppLogoMark from 'src/components/brand/AppLogoMark.vue';

const showAboutDialog = ref(false);

export interface WorkspaceLink {
  title: string;
  caption: string;
  icon: string;
  to?: string;
  target?: string;
  section?: string | undefined;
  /** Flat labeled section in the sidebar (label + always-visible children). */
  navGroup?: boolean;
  children?: WorkspaceLink[];
}

const props = defineProps<{
  logoutTo: string;
  theme: 'platform' | 'app' | 'shop' | 'investor';
  links: WorkspaceLink[];
  useHeaderProfile?: boolean;
}>();

const WORKSPACE_THEME_CLASSES = ['theme-platform', 'theme-app', 'theme-shop', 'theme-investor'];

const drawerOpen = ref(false);
const showLogoutDialog = ref(false);
const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

const $q = useQuasar();
const { navPinned, setNavPinned, darkMode, setDarkMode, density, setDensity } = useAppearance();
const miniState = ref(true);

const i18n = useI18n();

const getTransKey = (title: string) => {
  return title.toLowerCase().replace(/\s+/g, '_');
};

const translateTitle = (title: string) => {
  const key = `navigation.${getTransKey(title)}`;
  return i18n.te(key) ? i18n.t(key) : title;
};

const translateCaption = (title: string, defaultCaption: string) => {
  const key = `navigation.${getTransKey(title)}_caption`;
  return i18n.te(key) ? i18n.t(key) : defaultCaption;
};

const useMobileBottomNav = computed(() => props.theme === 'shop' && $q.screen.xs);

const isMini = computed(
  () => !useMobileBottomNav.value && !navPinned.value && miniState.value && !$q.screen.lt.md,
);

const isPathMatch = (currentPath: string, to: string): boolean => {
  if (currentPath === to) {
    return true;
  }
  // Match nested subroutes (e.g. /bw/app/procurement/shipment matches /bw/app/procurement/shipment/14)
  if (to === '/app' || to === '/app/' || to === '/shop' || to === '/shop/') {
    return false;
  }
  return currentPath.startsWith(`${to}/`);
};

/** Among sibling nav links, only the longest matching path is active (avoids /shop matching /shop/orders). */
const resolveActiveNavTo = (links: WorkspaceLink[], currentPath: string): string | null => {
  let bestMatch: string | null = null;

  for (const link of links) {
    if (!link.to || !isPathMatch(currentPath, link.to)) {
      continue;
    }
    if (!bestMatch || link.to.length > bestMatch.length) {
      bestMatch = link.to;
    }
  }

  return bestMatch;
};

const isLinkActive = (to?: string): boolean => {
  if (!to) return false;
  return isPathMatch(route.path, to);
};

const isNavGroupChildActive = (to?: string, siblings?: WorkspaceLink[]): boolean => {
  if (!to || !siblings?.length) {
    return false;
  }
  return resolveActiveNavTo(siblings, route.path) === to;
};

const isGroupActive = (link: WorkspaceLink): boolean => {
  if (!link.children?.length) return false;
  return link.children.some((child) => isLinkActive(child.to));
};

const isBottomNavLinkActive = (link: WorkspaceLink) => {
  if (!link.to || link.target) return false;
  return isLinkActive(link.to);
};

const isBottomNavGroupActive = (link: WorkspaceLink) => isGroupActive(link);

const shouldShowSectionHeader = (link: WorkspaceLink, child: WorkspaceLink, idx: number): boolean => {
  if (!child.section) return false;
  if (idx === 0) return true;
  if (!link.children) return false;
  return link.children[idx - 1]?.section !== child.section;
};

const NAV_EXPANDED_GROUPS_KEY = `bw-nav-expanded-groups:${props.theme}`;

const readPersistedExpandedGroups = (): Record<string, boolean> => {
  if (typeof sessionStorage === 'undefined') return {};
  try {
    const raw = sessionStorage.getItem(NAV_EXPANDED_GROUPS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as unknown;
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {};
    return parsed as Record<string, boolean>;
  } catch {
    return {};
  }
};

const expandedGroups = ref<Record<string, boolean>>(readPersistedExpandedGroups());

watch(
  expandedGroups,
  (value) => {
    if (typeof sessionStorage === 'undefined') return;
    try {
      sessionStorage.setItem(NAV_EXPANDED_GROUPS_KEY, JSON.stringify(value));
    } catch {
      // ignore quota / private mode
    }
  },
  { deep: true },
);

/** Open the group that owns the current page. Never force-close other groups. */
const autoExpandActiveGroup = () => {
  for (const link of props.links) {
    if (!link.children?.length) continue;
    const hasActiveChild = link.children.some((child) => isLinkActive(child.to));
    if (hasActiveChild) {
      expandedGroups.value[link.title] = true;
    }
  }
};

watch(
  () => [route.path, props.links] as const,
  () => {
    autoExpandActiveGroup();
  },
  { immediate: true, deep: true },
);

const togglePin = () => {
  void setNavPinned(!navPinned.value, authStore.membershipId);
};

const toggleDrawerOrPin = () => {
  if (useMobileBottomNav.value) {
    return;
  }
  if ($q.screen.lt.md) {
    drawerOpen.value = !drawerOpen.value;
  } else {
    void setNavPinned(!navPinned.value, authStore.membershipId);
  }
};

watch(useMobileBottomNav, (enabled) => {
  if (enabled) {
    drawerOpen.value = false;
  }
});

const toggleDarkMode = () => {
  void setDarkMode(!darkMode.value, authStore.membershipId);
};

const toggleDensity = () => {
  const nextDensity = density.value === 'compact' ? 'comfortable' : 'compact';
  void setDensity(nextDensity, authStore.membershipId);
};

const showCommandPalette = ref(false);
const searchQuery = ref('');
const activeIndex = ref(0);
const searchInputRef = ref<QInput | null>(null);

interface FlattenedLink {
  title: string;
  caption: string;
  icon: string;
  to?: string;
  target?: string | undefined;
  parentTitle?: string | undefined;
}

const flattenedLinks = computed(() => {
  const result: FlattenedLink[] = [];

  const traverse = (items: WorkspaceLink[], parentTitle?: string) => {
    for (const item of items) {
      if (item.children && item.children.length > 0) {
        traverse(item.children, item.title);
      } else if (item.to) {
        result.push({
          title: item.title,
          caption: item.caption,
          icon: item.icon,
          to: item.to,
          target: item.target,
          parentTitle,
        });
      }
    }
  };

  traverse(props.links);
  return result;
});

const escapeHtml = (value: string) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

const highlightMatch = (text: string, rawQuery: string) => {
  const query = rawQuery.trim();
  if (!query || !text) return escapeHtml(text);

  const lowerText = text.toLowerCase();
  const lowerQuery = query.toLowerCase();
  let result = '';
  let cursor = 0;

  while (cursor < text.length) {
    const matchIndex = lowerText.indexOf(lowerQuery, cursor);
    if (matchIndex === -1) {
      result += escapeHtml(text.slice(cursor));
      break;
    }
    result += escapeHtml(text.slice(cursor, matchIndex));
    result += `<mark class="command-palette-match">${escapeHtml(
      text.slice(matchIndex, matchIndex + query.length),
    )}</mark>`;
    cursor = matchIndex + query.length;
  }

  return result;
};

const filteredLinks = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) {
    return flattenedLinks.value;
  }
  return flattenedLinks.value
    .map((link) => {
      const title = translateTitle(link.title).toLowerCase();
      const caption = translateCaption(link.title, link.caption ?? '').toLowerCase();
      const parentTitle = link.parentTitle ? translateTitle(link.parentTitle).toLowerCase() : '';
      const titleMatch = title.includes(query);
      const captionMatch = caption.includes(query);
      const parentMatch = parentTitle.includes(query);
      if (!titleMatch && !captionMatch && !parentMatch) return null;
      return { link, rank: titleMatch ? 0 : 1 };
    })
    .filter((entry): entry is { link: FlattenedLink; rank: number } => entry !== null)
    .sort((a, b) => a.rank - b.rank)
    .map((entry) => entry.link);
});

watch(searchQuery, () => {
  activeIndex.value = 0;
});

const onPaletteShow = () => {
  setTimeout(() => {
    searchInputRef.value?.focus();
  }, 50);
};

const onPaletteHide = () => {
  searchQuery.value = '';
  activeIndex.value = 0;
};

const onInputKeydown = (e: KeyboardEvent) => {
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    activeIndex.value = (activeIndex.value + 1) % filteredLinks.value.length;
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    activeIndex.value =
      (activeIndex.value - 1 + filteredLinks.value.length) % filteredLinks.value.length;
  } else if (e.key === 'Enter') {
    e.preventDefault();
    const selectedLink = filteredLinks.value[activeIndex.value];
    if (selectedLink) {
      navigate(selectedLink);
    }
  } else if (e.key === 'Escape') {
    showCommandPalette.value = false;
  }
};

const navigate = (link: FlattenedLink) => {
  showCommandPalette.value = false;
  if (link.target === '_blank' && link.to) {
    window.open(link.to, '_blank');
  } else if (link.to) {
    void router.push(link.to);
  }
};

const handleKeyDown = (e: KeyboardEvent) => {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
    e.preventDefault();
    showCommandPalette.value = !showCommandPalette.value;
  }
};

onMounted(() => {
  window.addEventListener('keydown', handleKeyDown);
});

const themeClasses = computed(() => [`workspace-shell--${props.theme}`, `theme-${props.theme}`]);

const applyBodyThemeClass = (theme: 'platform' | 'app' | 'shop' | 'investor') => {
  if (typeof document === 'undefined') {
    return;
  }

  document.body.classList.remove(...WORKSPACE_THEME_CLASSES);
  document.body.classList.add(`theme-${theme}`);
};

watch(
  () => props.theme,
  (theme) => {
    applyBodyThemeClass(theme);
  },
  { immediate: true },
);

onBeforeUnmount(() => {
  window.removeEventListener('keydown', handleKeyDown);

  if (typeof document === 'undefined') {
    return;
  }

  document.body.classList.remove(...WORKSPACE_THEME_CLASSES);
});
const userName = computed(
  () => authStore.user?.fullName ?? authStore.user?.email ?? 'Workspace user',
);
const userEmail = computed(() => authStore.user?.email ?? 'No active session');
const userAvatarUrl = computed(() => authStore.user?.avatarUrl ?? null);
const currentRoleLabel = computed(() => {
  const role = authStore.matchedRole;
  if (!role) {
    return '';
  }

  return role
    .split('_')
    .map((part) => (part ? part[0]!.toUpperCase() + part.slice(1) : ''))
    .join(' ');
});
const contextLabel = computed(() => {
  if (authStore.scope === 'shop') {
    return 'Customer group';
  }

  if (authStore.scope === 'app') {
    return 'Tenant';
  }

  return '';
});
const contextValue = computed(() => {
  if (authStore.scope === 'shop') {
    return authStore.customerGroup?.name ?? '';
  }

  if (authStore.scope === 'app') {
    return authStore.selectedTenant?.name ?? authStore.tenant?.name ?? '';
  }

  return '';
});
const userInitials = computed(() => {
  const source = userName.value?.trim() || userEmail.value?.trim();
  if (!source) return '?';

  const parts = source.split(/\s+/).filter(Boolean);
  if (parts.length >= 2) {
    return `${parts[0]?.[0] ?? ''}${parts[1]?.[0] ?? ''}`.toUpperCase();
  }

  return source.slice(0, 2).toUpperCase();
});

const handleLogout = () => {
  showLogoutDialog.value = true;
};

const handleOpenCommandPalette = () => {
  showCommandPalette.value = true;
};

defineExpose({
  openSignOutDialog: handleLogout,
  openCommandPalette: handleOpenCommandPalette,
});

const confirmLogout = async () => {
  showLogoutDialog.value = false;
  drawerOpen.value = false;

  try {
    await supabase.auth.signOut();
  } catch (error) {
    console.error('[auth] Failed to sign out from Supabase session', error);
  } finally {
    authStore.clearAccess();

    try {
      await router.replace(props.logoutTo);
    } catch (error) {
      console.error('[auth] Failed to redirect after sign out', error);
    }
  }
};
</script>

<style scoped>
.workspace-shell {
  min-height: 100vh;
  --workspace-header-offset: 54px;
  --shell-base: var(--bw-neutral-canvas);
  --shell-surface: var(--bw-neutral-surface);
  --shell-border: var(--bw-neutral-border);
  --shell-shadow: var(--bw-theme-shadow);
  --shell-ink: var(--bw-neutral-ink);
  --shell-muted: var(--bw-neutral-muted);
  --shell-accent: var(--bw-brand-accent);
  --shell-accent-soft: var(--bw-theme-primary-soft);
  background: var(--shell-base);
  color: var(--shell-ink);
}

.workspace-shell__header {
  background: color-mix(in srgb, var(--shell-surface) 88%, transparent);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--shell-border);
}

.workspace-shell__toolbar {
  min-height: 54px;
  height: 54px;
  gap: 0.5rem;
  padding: 0 1rem;
}

.workspace-shell__menu {
  color: var(--bw-neutral-muted);
  background: transparent;
  border-radius: 8px;
  width: 32px;
  height: 32px;
  transition: all 0.15s ease-in-out;
}

.workspace-shell__menu:hover {
  color: var(--bw-neutral-ink);
  background: color-mix(in srgb, var(--bw-neutral-ink) 5%, transparent);
}

.workspace-shell__header-divider {
  width: 1px;
  height: 16px;
  background: var(--shell-border);
  margin: 0 4px;
}

.workspace-shell__context {
  min-width: 0;
  flex: 0 1 auto;
}

.workspace-shell__center {
  flex: 0 1 auto;
  display: flex;
  justify-content: center;
  align-items: center;
  max-width: 260px;
  margin: 0 auto;
}

.workspace-shell__center--shop {
  flex: 1 1 auto;
  max-width: min(100%, 320px);
  min-width: 0;
}

.workspace-shell__actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.workspace-shell__drawer {
  background: transparent;
}

.workspace-shell :deep(.q-drawer) {
  position: fixed !important;
  top: var(--workspace-header-offset) !important;
  bottom: 0 !important;
}

.workspace-shell :deep(.q-drawer__content) {
  height: calc(100vh - var(--workspace-header-offset)) !important;
  overflow: hidden;
}

.workspace-shell__drawer-inner {
  height: 100%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  background: var(--shell-surface);
  border-right: 1px solid var(--shell-border);
}

.workspace-shell__drawer-top {
  height: 54px;
  padding: 0 0.85rem;
  border-bottom: 1px solid var(--shell-border);
}

.workspace-shell__drawer-brand {
  gap: 0.5rem;
  min-width: 0;
}

.workspace-shell__drawer-title {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--bw-neutral-muted);
}

.workspace-shell__app-mark {
  width: 22px;
  height: 22px;
  flex-shrink: 0;
}

.workspace-shell__app-mark--mini {
  width: 24px;
  height: 24px;
  margin-bottom: 0.15rem;
}

.workspace-shell__pin-btn {
  border-radius: 8px;
  width: 28px;
  height: 28px;
  color: var(--bw-neutral-chrome);
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}

.workspace-shell__pin-btn:hover {
  color: var(--bw-neutral-ink);
  background: color-mix(in srgb, var(--bw-neutral-ink) 5%, transparent);
}

.workspace-shell__pin-btn--pinned {
  color: var(--shell-accent) !important;
}

.workspace-shell__drawer-scroll {
  flex: 1;
  min-height: 0;
}

.workspace-shell__drawer-scroll :deep(.q-scrollarea__content) {
  padding-bottom: 80px;
}

.workspace-shell__nav {
  padding: 0.5rem 0.5rem 0.75rem;
}

.workspace-shell__nav-list {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.workspace-shell__nav-item {
  min-height: 36px;
  height: 36px;
  padding: 0 10px;
  border-radius: 8px;
  color: var(--bw-neutral-muted);
  font-size: 13px;
  font-weight: 500;
  transition: all 0.15s ease-in-out;
}

.workspace-shell__nav-item:hover {
  color: var(--bw-neutral-ink);
  background: color-mix(in srgb, var(--bw-neutral-ink) 4%, transparent);
}

.workspace-shell__nav-item--active {
  background: var(--shell-accent-soft) !important;
  color: var(--shell-accent) !important;
  font-weight: 600;
  box-shadow: none !important;
  border: none !important;
}

.workspace-shell__nav-group {
  overflow: visible;
  border: none;
  margin-bottom: 2px;
}

.workspace-shell__nav-group :deep(.q-expansion-item__container) {
  border-radius: 8px;
}

.workspace-shell__nav-group :deep(.q-item) {
  min-height: 36px;
  height: 36px;
  padding: 0 10px;
  border-radius: 8px;
}

.workspace-shell__nav-sub-list {
  margin: 2px 0 4px 18px;
  padding-left: 8px;
  border-left: 1px solid var(--shell-border);
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.workspace-shell__nav-sub-item {
  border-radius: 6px;
  min-height: 32px;
  height: 32px;
  padding: 0 8px;
  font-size: 12.5px;
  color: var(--bw-neutral-muted);
  transition: all 0.15s ease-in-out;
}

.workspace-shell__nav-sub-item:hover {
  color: var(--bw-neutral-ink);
  background: color-mix(in srgb, var(--bw-neutral-ink) 4%, transparent);
}

.workspace-shell__nav-sub-item.workspace-shell__nav-item--active {
  background: var(--shell-accent-soft) !important;
  color: var(--shell-accent) !important;
  font-weight: 600;
  box-shadow: none !important;
  border: none !important;
}

.workspace-shell__nav-sub-header {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.08em;
  color: var(--bw-neutral-chrome);
  text-transform: uppercase;
  padding: 8px 8px 3px;
  display: flex;
  align-items: center;
}

.workspace-shell__nav-group-label {
  padding-top: 12px;
}

.workspace-shell__nav-group-label:first-child {
  padding-top: 4px;
}

.workspace-shell__page-container {
  padding: 0;
  background: var(--bw-neutral-canvas);
}

.workspace-shell__drawer-bottom {
  margin-top: auto;
  flex-shrink: 0;
  position: sticky;
  bottom: 0;
  z-index: 1;
  padding: 8px 10px calc(8px + env(safe-area-inset-bottom, 0px));
  background: var(--shell-surface);
  border-top: 1px solid var(--shell-border);
}

.workspace-shell__logout {
  width: 100%;
  height: 36px;
  border-radius: 8px;
  font-weight: 500;
  font-size: 13px;
  color: var(--bw-neutral-muted);
  transition: all 0.15s ease-in-out;
}

.workspace-shell__logout:hover {
  color: var(--bw-neutral-ink);
  background: color-mix(in srgb, var(--bw-neutral-ink) 4%, transparent);
}

.command-palette-card {
  --shell-surface: var(--bw-neutral-surface);
  --shell-border: var(--bw-neutral-border);
  border: 1px solid var(--shell-border);
  background: var(--shell-surface);
  border-radius: 12px !important;
  box-shadow: 0 20px 50px -10px rgba(0, 0, 0, 0.25);
  overflow: hidden;
}

.command-palette-search-row {
  background: var(--bw-neutral-surface);
}

.command-palette-search-icon {
  color: var(--bw-neutral-chrome);
}

.command-palette-input :deep(.q-field__control) {
  background: transparent !important;
  padding: 0;
}

.command-palette-esc-kbd {
  font-size: 10px;
  font-family: var(--bw-font-mono);
  font-weight: 600;
  padding: 2px 6px;
  border-radius: 4px;
  background: var(--bw-neutral-canvas);
  border: 1px solid var(--bw-neutral-border);
  color: var(--bw-neutral-chrome);
}

.command-palette-sep {
  height: 1px;
  background: var(--shell-border);
}

.command-palette-item {
  border-radius: 8px;
  transition: all 0.15s ease-in-out;
  padding: 6px 10px;
  margin: 2px 8px;
  font-size: 13px;
}

.command-palette-item--active {
  background: var(--shell-accent-soft) !important;
  color: var(--bw-neutral-ink) !important;
}

:deep(.command-palette-match) {
  background: transparent;
  color: var(--shell-accent) !important;
  border-radius: 2px;
  padding: 0 1px;
  font-weight: 700;
}

/* Sign-out Dialog */
.signout-dialog :deep(.q-dialog__backdrop) {
  background: rgba(0, 0, 0, 0.45);
  backdrop-filter: blur(8px);
}

.signout-card {
  width: min(92vw, 24rem);
  border-radius: 14px;
  padding: 1.5rem;
  background: var(--bw-neutral-surface);
  border: 1px solid var(--bw-neutral-border);
  box-shadow: 0 20px 50px -10px rgba(0, 0, 0, 0.25);
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.signout-card__identity {
  display: flex;
  align-items: center;
  gap: 0.85rem;
}

.signout-card__avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
  background: var(--shell-accent-soft);
  border: 1px solid color-mix(in srgb, var(--shell-accent) 20%, transparent);
  color: var(--shell-accent);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.85rem;
  font-weight: 700;
}

.signout-card__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.signout-card__name {
  font-size: 0.95rem;
  font-weight: 600;
  color: var(--bw-neutral-ink);
  line-height: 1.2;
}

.signout-card__email {
  font-size: 0.8rem;
  color: var(--bw-neutral-muted);
  margin-top: 0.15rem;
}

.signout-card__sep {
  height: 1px;
  background: var(--bw-neutral-border);
}

.signout-card__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
}

.signout-card__pill {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.2rem 0.6rem;
  border-radius: 999px;
  background: var(--shell-accent-soft);
  color: var(--shell-accent);
  font-size: 0.72rem;
  font-weight: 600;
  border: 1px solid color-mix(in srgb, var(--shell-accent) 20%, transparent);
}

.signout-card__message {
  margin: 0;
  font-size: 0.85rem;
  color: var(--bw-neutral-muted);
  line-height: 1.5;
}

.signout-card__actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
  margin-top: 0.25rem;
}

.signout-card__btn {
  padding: 0.55rem 0;
  border-radius: 8px;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  transition: all 0.15s ease-in-out;
}

.signout-card__btn--cancel {
  background: var(--bw-neutral-canvas);
  color: var(--bw-neutral-ink);
  border: 1px solid var(--bw-neutral-border);
}

.signout-card__btn--cancel:hover {
  background: color-mix(in srgb, var(--bw-neutral-ink) 5%, transparent);
}

.signout-card__btn--confirm {
  background: var(--bw-brand-accent);
  color: #ffffff;
  border: none;
}

.signout-card__btn--confirm:hover {
  background: color-mix(in srgb, var(--bw-brand-accent) 85%, black);
  box-shadow: 0 4px 12px color-mix(in srgb, var(--bw-brand-accent) 30%, transparent);
}

/* Mini Mode Specific Styles */
.workspace-shell--mini .workspace-shell__drawer-top,
.workspace-shell--mini .workspace-shell__drawer-bottom {
  padding: 0.5rem 0.25rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.workspace-shell--mini .workspace-shell__nav {
  padding: 0.5rem 0.25rem 0.75rem;
}

.workspace-shell--mini .workspace-shell__nav-list {
  align-items: center;
}

.workspace-shell--mini .workspace-shell__nav-item,
.workspace-shell--mini .workspace-shell__nav-group {
  width: 100%;
  justify-content: center;
}

.workspace-shell--mini .workspace-shell__nav-item :deep(> .q-item),
.workspace-shell--mini .workspace-shell__nav-group :deep(.q-expansion-item__container > .q-item) {
  display: flex;
  justify-content: center;
  align-items: center;
  padding-left: 0;
  padding-right: 0;
}

.workspace-shell--mini .workspace-shell__nav-item :deep(.q-item__section--main),
.workspace-shell--mini .workspace-shell__nav-group :deep(.q-item__section--main),
.workspace-shell--mini .workspace-shell__nav-group :deep(.q-expansion-item__toggle-icon),
.workspace-shell--mini .workspace-shell__nav-group :deep(.q-item__section--side) {
  display: none !important;
}

.workspace-shell--mini .workspace-shell__nav-item :deep(.q-item__section--avatar),
.workspace-shell--mini .workspace-shell__nav-group :deep(.q-item__section--avatar) {
  min-width: 0 !important;
  padding-right: 0 !important;
  margin-inline: auto;
  justify-content: center;
}

.workspace-shell--mini .workspace-shell__nav-sub-list {
  display: none;
}

.workspace-shell--mini .workspace-shell__logout {
  min-width: 0;
  padding-left: 0;
  padding-right: 0;
}
</style>
