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
          icon="menu"
          class="workspace-shell__menu"
          @click="toggleDrawerOrPin"
        />

        <q-btn v-else flat round dense class="workspace-shell__menu" padding="none">
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
                  <q-icon name="shield" size="xs" color="grey-6" />
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-caption text-weight-medium">Role</q-item-label>
                  <q-item-label caption>{{ currentRoleLabel }}</q-item-label>
                </q-item-section>
              </q-item>
              <q-item v-if="contextLabel && contextValue">
                <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                  <q-icon name="apartment" size="xs" color="grey-6" />
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
                  <q-icon name="density_medium" size="xs" color="grey-6" />
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

              <q-separator class="q-my-xs" />
              <q-item clickable v-close-popup @click="handleLogout">
                <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                  <q-icon name="logout" size="xs" color="negative" />
                </q-item-section>
                <q-item-section class="text-negative text-weight-medium">Sign out</q-item-section>
              </q-item>
            </q-list>
          </q-menu>
        </q-btn>

        <div class="workspace-shell__context">
          <slot name="header-left" />
        </div>

        <q-space />

        <div class="workspace-shell__actions">
          <q-btn
            outline
            dense
            no-caps
            color="primary"
            class="locale-selector-btn q-mr-sm"
            padding="xs sm"
            icon="translate"
          >
            <span class="locale-selector-btn__label">{{ localeLabel }}</span>
            <q-icon name="arrow_drop_down" size="sm" />
            <q-menu auto-close style="min-width: 140px">
              <q-list dense class="q-py-xs">
                <q-item
                  clickable
                  :active="locale === 'en-US'"
                  active-class="bg-primary text-white"
                  @click="setLocale('en-US')"
                >
                  <q-item-section>Eng</q-item-section>
                </q-item>
                <q-item
                  clickable
                  :active="locale === 'bn'"
                  active-class="bg-primary text-white"
                  @click="setLocale('bn')"
                >
                  <q-item-section class="locale-bn">বাংলা</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>
          <slot name="header-extra" />
        </div>
      </q-toolbar>
    </q-header>

    <q-drawer
      v-if="!useMobileBottomNav"
      v-model="drawerOpen"
      :mini="isMini"
      mini-to-overlay
      :mini-width="64"
      :width="300"
      show-if-above
      bordered
      class="workspace-shell__drawer"
      @mouseenter="drawerHovered = true"
      @mouseleave="drawerHovered = false"
    >
      <div class="workspace-shell__drawer-inner">
        <div class="workspace-shell__drawer-top">
          <!-- Pin/Unpin Toggle Button -->
          <div v-if="!isMini" class="row justify-end q-mb-xs">
            <q-btn
              flat
              round
              dense
              icon="push_pin"
              size="sm"
              :color="navPinned ? 'primary' : 'grey-7'"
              :style="
                !navPinned
                  ? 'transform: rotate(45deg); transition: transform 0.2s;'
                  : 'transition: transform 0.2s;'
              "
              @click="togglePin"
            >
              <q-tooltip>{{ navPinned ? 'Collapse sidebar' : 'Pin sidebar' }}</q-tooltip>
            </q-btn>
          </div>

          <div
            class="row items-center no-wrap rounded-borders profile-card"
            :class="isMini ? 'justify-center q-pa-xs cursor-pointer' : 'q-gutter-sm q-pa-sm'"
            :style="isMini ? 'border-color: transparent; background: transparent;' : ''"
          >
            <q-avatar size="36px" class="workspace-shell__avatar">
              <img
                v-if="userAvatarUrl"
                :src="userAvatarUrl"
                class="workspace-shell__avatar-image"
                referrerpolicy="no-referrer"
                alt=""
              />
              <span v-else class="workspace-shell__avatar-fallback">{{ userInitials }}</span>
            </q-avatar>
            <div v-if="!isMini" class="col ellipsis">
              <div class="text-subtitle2 text-weight-bold ellipsis text-black leading-tight">
                {{ userName }}
              </div>
              <div class="text-caption text-grey-7 ellipsis leading-tight">{{ userEmail }}</div>
            </div>

            <q-btn v-if="!isMini" flat round dense icon="more_vert" size="sm" color="grey-7">
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
                      <q-icon name="shield" size="xs" color="grey-6" />
                    </q-item-section>
                    <q-item-section>
                      <q-item-label class="text-caption text-weight-medium">Role</q-item-label>
                      <q-item-label caption>{{ currentRoleLabel }}</q-item-label>
                    </q-item-section>
                  </q-item>
                  <q-item v-if="contextLabel && contextValue">
                    <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                      <q-icon name="apartment" size="xs" color="grey-6" />
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
                      <q-icon
                        :name="darkMode ? 'dark_mode' : 'light_mode'"
                        size="xs"
                        color="grey-6"
                      />
                    </q-item-section>
                    <q-item-section>Dark Mode</q-item-section>
                    <q-item-section side>
                      <q-toggle
                        :model-value="darkMode"
                        @update:model-value="toggleDarkMode"
                        dense
                      />
                    </q-item-section>
                  </q-item>
                  <q-item clickable @click="toggleDensity">
                    <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                      <q-icon name="density_medium" size="xs" color="grey-6" />
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

                  <q-separator class="q-my-xs" />
                  <q-item clickable v-close-popup @click="handleLogout">
                    <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                      <q-icon name="logout" size="xs" color="negative" />
                    </q-item-section>
                    <q-item-section class="text-negative text-weight-medium"
                      >Sign out</q-item-section
                    >
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
            <q-menu v-if="isMini" style="min-width: 200px">
              <q-list dense class="q-py-xs">
                <q-item-label
                  header
                  class="text-uppercase text-weight-bold text-grey-7"
                  style="font-size: 10px; letter-spacing: 0.1em"
                  >Session Info</q-item-label
                >
                <q-item v-if="currentRoleLabel">
                  <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                    <q-icon name="shield" size="xs" color="grey-6" />
                  </q-item-section>
                  <q-item-section>
                    <q-item-label class="text-caption text-weight-medium">Role</q-item-label>
                    <q-item-label caption>{{ currentRoleLabel }}</q-item-label>
                  </q-item-section>
                </q-item>
                <q-item v-if="contextLabel && contextValue">
                  <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                    <q-icon name="apartment" size="xs" color="grey-6" />
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
                    <q-icon
                      :name="darkMode ? 'dark_mode' : 'light_mode'"
                      size="xs"
                      color="grey-6"
                    />
                  </q-item-section>
                  <q-item-section>Dark Mode</q-item-section>
                  <q-item-section side>
                    <q-toggle :model-value="darkMode" @update:model-value="toggleDarkMode" dense />
                  </q-item-section>
                </q-item>
                <q-item clickable @click="toggleDensity">
                  <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                    <q-icon name="density_medium" size="xs" color="grey-6" />
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

                <q-separator class="q-my-xs" />
                <q-item clickable v-close-popup @click="handleLogout">
                  <q-item-section avatar class="q-pr-none" style="min-width: 24px">
                    <q-icon name="logout" size="xs" color="negative" />
                  </q-item-section>
                  <q-item-section class="text-negative text-weight-medium">Sign out</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </div>
        </div>

        <q-scroll-area class="workspace-shell__drawer-scroll">
          <div class="workspace-shell__nav">
            <div v-if="!isMini" class="workspace-shell__drawer-search q-mb-md">
              <q-input
                filled
                dense
                readonly
                model-value=""
                placeholder="Search pages... (⌘K)"
                class="soft-input cursor-pointer"
                @click="showCommandPalette = true"
              >
                <template #prepend>
                  <q-icon name="search" size="xs" />
                </template>
                <template #append>
                  <div class="shortcut-badge">⌘K</div>
                </template>
              </q-input>
            </div>

            <div v-if="!isMini" class="workspace-shell__nav-label">Workspace</div>

            <q-list class="workspace-shell__nav-list">
              <template v-for="link in links" :key="link.to || link.title">
                <!-- Group with children in mini mode (flyout menu) -->
                <q-item
                  v-if="link.children?.length && isMini"
                  clickable
                  class="workspace-shell__nav-item"
                >
                  <q-item-section avatar>
                    <q-icon :name="link.icon" />
                  </q-item-section>

                  <q-tooltip anchor="center right" self="center left" :offset="[10, 10]">
                    {{ translateTitle(link.title) }}
                  </q-tooltip>

                  <q-menu
                    anchor="top right"
                    self="top left"
                    :offset="[8, 0]"
                    class="workspace-shell__flyout-menu"
                  >
                    <q-list dense class="q-py-xs" style="min-width: 180px">
                      <q-item-label
                        header
                        class="text-uppercase text-weight-bold text-grey-7 q-py-xs"
                        style="font-size: 10px; letter-spacing: 0.05em"
                      >
                        {{ translateTitle(link.title) }}
                      </q-item-label>
                      <q-separator class="q-mb-xs" />
                      <q-item
                        v-for="child in link.children"
                        :key="child.to ?? child.title"
                        clickable
                        :to="child.to!"
                        exact
                        v-close-popup
                        class="workspace-shell__flyout-sub-item q-mx-xs q-my-xs rounded-borders"
                        active-class="workspace-shell__nav-item--active"
                      >
                        <q-item-section>
                          <q-item-label>{{ translateTitle(child.title) }}</q-item-label>
                        </q-item-section>
                      </q-item>
                    </q-list>
                  </q-menu>
                </q-item>

                <!-- Group with children in standard mode (expansion item) -->
                <q-expansion-item
                  v-else-if="link.children?.length"
                  :icon="link.icon"
                  :label="translateTitle(link.title)"
                  class="workspace-shell__nav-item workspace-shell__nav-group"
                  expand-separator
                >
                  <div class="workspace-shell__nav-sub-list">
                    <q-item
                      v-for="child in link.children"
                      :key="child.to ?? child.title"
                      clickable
                      :to="child.to!"
                      exact
                      class="workspace-shell__nav-sub-item"
                      active-class="workspace-shell__nav-item--active"
                    >
                      <q-item-section>
                        <q-item-label>{{ translateTitle(child.title) }}</q-item-label>
                      </q-item-section>
                    </q-item>
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
                  active-class="workspace-shell__nav-item--active"
                >
                  <q-item-section avatar>
                    <q-icon :name="link.icon" />
                  </q-item-section>

                  <q-item-section v-if="!isMini">
                    <q-item-label>{{ translateTitle(link.title) }}</q-item-label>
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

        <div class="workspace-shell__drawer-bottom">
          <q-btn
            flat
            dense
            no-caps
            icon="logout"
            :label="isMini ? '' : 'Sign out'"
            color="negative"
            class="workspace-shell__logout"
            @click="handleLogout"
          >
            <q-tooltip v-if="isMini" anchor="center right" self="center left" :offset="[10, 10]">
              Sign out
            </q-tooltip>
          </q-btn>
        </div>
      </div>
    </q-drawer>

    <q-footer v-if="useMobileBottomNav" elevated class="workspace-shell__bottom-nav">
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
        style="width: 600px; max-width: 90vw; margin-top: 10vh"
        class="floating-surface shadow-5 command-palette-card"
      >
        <q-card-section class="q-pa-sm">
          <q-input
            ref="searchInputRef"
            v-model="searchQuery"
            placeholder="Type a page name to navigate..."
            outlined
            dense
            autofocus
            class="soft-input command-palette-input"
            @keydown="onInputKeydown"
          >
            <template #prepend>
              <q-icon name="search" />
            </template>
            <template #append>
              <q-btn
                v-if="searchQuery"
                flat
                round
                dense
                icon="close"
                size="sm"
                @click="searchQuery = ''"
              />
              <q-badge color="grey-4" text-color="grey-8" class="q-ml-xs">ESC</q-badge>
            </template>
          </q-input>
        </q-card-section>

        <q-separator />

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
                <q-item-label
                  class="text-weight-medium"
                  v-html="highlightMatch(translateTitle(link.title), searchQuery)"
                />
                <q-item-label
                  v-if="link.caption"
                  caption
                  v-html="highlightMatch(translateCaption(link.title, link.caption), searchQuery)"
                />
              </q-item-section>
              <q-item-section side v-if="link.parentTitle">
                <q-badge
                  outline
                  color="primary"
                  size="sm"
                  v-html="highlightMatch(translateTitle(link.parentTitle), searchQuery)"
                />
              </q-item-section>
            </q-item>
          </q-list>
          <div v-else class="flex flex-center text-grey-6 q-pa-lg">
            <q-icon name="search_off" size="md" />
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
            <q-icon name="shield" size="0.8rem" />
            {{ currentRoleLabel }}
          </span>
          <span v-if="contextValue" class="signout-card__pill">
            <q-icon name="apartment" size="0.8rem" />
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
            <q-icon name="logout" size="1rem" />
            Sign out
          </button>
        </div>
      </div>
    </q-dialog>
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

export interface WorkspaceLink {
  title: string;
  caption: string;
  icon: string;
  to?: string;
  target?: string;
  children?: WorkspaceLink[];
}

const props = defineProps<{
  logoutTo: string;
  theme: 'platform' | 'app' | 'shop' | 'investor';
  links: WorkspaceLink[];
}>();

const WORKSPACE_THEME_CLASSES = ['theme-platform', 'theme-app', 'theme-shop', 'theme-investor'];

const drawerOpen = ref(false);
const showLogoutDialog = ref(false);
const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

const $q = useQuasar();
const { navPinned, setNavPinned, darkMode, setDarkMode, density, setDensity } = useAppearance();
const drawerHovered = ref(false);

const i18n = useI18n();
const { locale } = i18n;

const localeLabel = computed(() => (locale.value === 'bn' ? 'বাংলা' : 'Eng'));

const setLocale = (lang: string) => {
  locale.value = lang;
  localStorage.setItem('locale', lang);
};

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
  () => !useMobileBottomNav.value && !navPinned.value && !drawerHovered.value && !$q.screen.lt.md,
);

const isBottomNavLinkActive = (link: WorkspaceLink) => {
  if (!link.to || link.target) return false;
  return route.path === link.to || route.path.startsWith(`${link.to}/`);
};

const isBottomNavGroupActive = (link: WorkspaceLink) =>
  !!link.children?.some((child) => isBottomNavLinkActive(child));

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

defineExpose({ openSignOutDialog: handleLogout });

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
  --workspace-header-offset: 58px;
  --shell-base: var(--bw-theme-base, #eef2f5);
  --shell-surface: var(--bw-theme-surface, rgb(255 255 255 / 0.92));
  --shell-border: var(--bw-theme-border, rgb(40 56 74 / 0.12));
  --shell-shadow: var(--bw-theme-shadow, rgb(25 35 47 / 0.08));
  --shell-ink: var(--bw-theme-ink, #1f2937);
  --shell-muted: var(--bw-theme-muted, #6b7280);
  --shell-accent: var(--bw-theme-primary, #2563eb);
  --shell-accent-soft: var(--bw-theme-primary-soft, rgb(37 99 235 / 0.12));
  background: var(--shell-base);
  color: var(--shell-ink);
}

.workspace-shell__header {
  background: color-mix(in srgb, var(--shell-surface) 90%, var(--color-mix-tint, white) 10%);
  border-bottom: 1px solid var(--shell-border);
}

.workspace-shell__toolbar {
  gap: 0.6rem;
  padding: 0.55rem 0.75rem;
}

.workspace-shell__menu {
  color: var(--shell-ink);
  background: var(--shell-accent-soft);
}

.workspace-shell__context {
  min-width: 0;
  flex: 1 1 auto;
}

.workspace-shell__actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.locale-selector-btn {
  border-width: 1.5px !important;
  font-weight: 700;
  letter-spacing: 0.02em;
  background: color-mix(in srgb, var(--q-primary) 12%, transparent);
}

.locale-selector-btn__label {
  margin-left: 0.15rem;
  margin-right: 0.05rem;
  font-size: 0.9rem;
  line-height: 1.2;
}

.locale-bn {
  font-size: 1.05rem;
  font-weight: 600;
  letter-spacing: 0.01em;
}

.workspace-shell__summary-label,
.workspace-shell__nav-label {
  font-size: 0.72rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--shell-muted);
}

.workspace-shell__summary-value {
  margin-top: 0.22rem;
  font-weight: 600;
}

.workspace-shell__summary-meta {
  margin-top: 0.28rem;
  color: var(--shell-muted);
  word-break: break-word;
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
  background: color-mix(in srgb, var(--shell-surface) 94%, var(--color-mix-tint, white) 6%);
  border-right: 1px solid var(--shell-border);
}

.workspace-shell__drawer-top,
.workspace-shell__drawer-bottom {
  padding: 0.75rem;
}

.profile-card {
  background: color-mix(in srgb, var(--shell-surface) 50%, transparent);
  border: 1px solid var(--shell-border);
  transition: background-color 0.2s ease;
}

.profile-card:hover {
  background: color-mix(in srgb, var(--shell-surface) 85%, transparent);
}

.leading-tight {
  line-height: 1.25;
}

.workspace-shell__avatar {
  overflow: hidden;
  border: 1px solid var(--shell-border);
  background: var(--shell-surface);
}

.workspace-shell__avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.workspace-shell__avatar-fallback {
  font-size: 0.72rem;
  font-weight: 700;
  color: var(--shell-ink);
}

.workspace-shell__drawer-scroll {
  flex: 1;
  min-height: 0;
}

.workspace-shell__drawer-scroll :deep(.q-scrollarea__content) {
  padding-bottom: 88px;
}

.workspace-shell__nav {
  padding: 0 0.6rem 0.75rem;
}

.workspace-shell__nav-list {
  margin-top: 0.45rem;
  display: grid;
  gap: 0.2rem;
}

.workspace-shell__nav-item {
  border-radius: 0.65rem;
  color: var(--shell-ink);
}

.workspace-shell__nav-group {
  overflow: visible;
  border: 1px solid transparent;
  margin-bottom: 0.45rem;
}

.workspace-shell__nav-group :deep(.q-expansion-item__container) {
  border-radius: 0.65rem;
}

.workspace-shell__nav-group :deep(.q-expansion-item__content) {
  overflow: visible;
  padding-bottom: 0.35rem;
}

.workspace-shell__nav-group :deep(.q-item) {
  min-height: 44px;
}

.workspace-shell__nav-sub-list {
  margin: 0.2rem 0.35rem 0.45rem 2.05rem;
  padding-left: 0.6rem;
  border-left: 1px solid var(--shell-border);
  display: grid;
  gap: 0.18rem;
}

.workspace-shell__nav-item--active {
  background: var(--shell-accent-soft);
  color: var(--shell-ink);
}

.workspace-shell__page-container {
  padding: clamp(0.5rem, 1.2vw, 0.9rem);
}

.workspace-shell__bottom-nav {
  background: color-mix(in srgb, var(--shell-surface) 94%, var(--color-mix-tint, white) 6%);
  border-top: 1px solid var(--shell-border);
  color: var(--shell-ink);
}

.workspace-shell__bottom-nav-inner {
  display: flex;
  align-items: stretch;
  justify-content: space-around;
  gap: 0.15rem;
  padding: 0.2rem 0.25rem calc(0.2rem + env(safe-area-inset-bottom, 0px));
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}

.workspace-shell__bottom-nav-item {
  flex: 1 1 0;
  min-width: 3.5rem;
  max-width: 6.5rem;
  min-height: 3.4rem;
  padding: 0.28rem 0.2rem;
  border-radius: 0.65rem;
  color: var(--shell-muted);
  font-size: 0.62rem;
  font-weight: 600;
  line-height: 1.15;
}

.workspace-shell__bottom-nav-item :deep(.q-icon) {
  font-size: 1.35rem;
  margin-bottom: 0.1rem;
}

.workspace-shell__bottom-nav-item :deep(.q-btn__content) {
  width: 100%;
}

.workspace-shell__bottom-nav-item :deep(.block) {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.workspace-shell__bottom-nav-item--active {
  color: var(--shell-ink);
  background: var(--shell-accent-soft);
}

@media (max-width: 599px) {
  .workspace-shell {
    --workspace-header-offset: 54px;
  }

  .workspace-shell__toolbar {
    padding: 0.4rem 0.5rem;
    gap: 0.3rem;
  }

  .workspace-shell__actions {
    gap: 0.25rem;
  }
}

.workspace-shell__nav-sub-item {
  border-radius: 0.5rem;
  min-height: 38px;
  padding-left: 0.55rem;
  margin-left: 0.15rem;
}

.workspace-shell__drawer-search {
  cursor: pointer;
}

.workspace-shell__drawer-search :deep(.q-field__control) {
  cursor: pointer;
}

.workspace-shell__drawer-search :deep(input) {
  cursor: pointer;
}

.shortcut-badge {
  font-size: 10px;
  padding: 2px 6px;
  background: rgba(0, 0, 0, 0.05);
  border-radius: 4px;
  color: var(--shell-muted);
  font-weight: 600;
}

.command-palette-card {
  --bw-theme-surface: var(--bw-brand-surface);
  --bw-theme-base: var(--bw-brand-base);
  --bw-theme-border: var(--bw-brand-border);
  --shell-surface: var(--bw-brand-surface);
  --shell-border: var(--bw-brand-border);
  border: 1px solid var(--shell-border);
  background: var(--shell-surface);
  border-radius: 12px;
}

.command-palette-item {
  transition: all 0.2s ease;
}

.command-palette-item--active {
  background: var(--shell-accent-soft) !important;
  color: var(--shell-ink) !important;
}

.command-palette-match {
  background: color-mix(in srgb, var(--q-primary) 28%, transparent);
  color: inherit;
  border-radius: 2px;
  padding: 0 1px;
  font-weight: 700;
}

.command-palette-input :deep(.q-field__control) {
  border-radius: 8px;
  background: var(--bw-brand-base) !important;
}

.workspace-shell__logout {
  width: 100%;
  padding: 0.45rem 0.6rem;
  border-radius: 0.5rem;
  font-weight: 600;
}

.workspace-shell__drawer-bottom {
  margin-top: auto;
  flex-shrink: 0;
  position: sticky;
  bottom: 0;
  z-index: 1;
  padding-bottom: calc(0.75rem + env(safe-area-inset-bottom, 0px));
  background: color-mix(in srgb, var(--shell-surface) 94%, var(--color-mix-tint, white) 6%);
  border-top: 1px solid var(--shell-border);
}

/* ══════════════════════════════════════════════════════
   SIGN-OUT DIALOG
   ══════════════════════════════════════════════════════ */

/* Kill Quasar dialog backdrop default bg so our blur shines */
.signout-dialog :deep(.q-dialog__backdrop) {
  background: rgb(0 0 0 / 0.35);
  backdrop-filter: blur(6px);
}

.signout-card {
  width: min(92vw, 26rem);
  border-radius: 1.5rem;
  padding: 1.75rem;
  --shell-surface: var(--bw-theme-surface, #ffffff);
  --shell-muted: var(--bw-theme-muted, #6b7280);
  --shell-ink: var(--bw-theme-ink, #1f2937);
  --shell-border: var(--bw-theme-border, rgb(40 56 74 / 0.12));
  background: var(--shell-surface);
  border: 1px solid color-mix(in srgb, var(--color-mix-tint, white) 30%, transparent);
  box-shadow:
    0 2px 0 color-mix(in srgb, var(--color-mix-tint, white) 60%, transparent) inset,
    0 20px 60px rgb(0 0 0 / 0.14),
    0 4px 16px rgb(0 0 0 / 0.08);
  display: flex;
  flex-direction: column;
  gap: 1.1rem;
}

/* Identity row */
.signout-card__identity {
  display: flex;
  align-items: center;
  gap: 0.85rem;
}

.signout-card__avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
  background: var(--shell-accent-soft);
  border: 2px solid rgb(255 255 255 / 0.8);
  box-shadow: 0 2px 8px rgb(0 0 0 / 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.85rem;
  font-weight: 700;
  color: var(--shell-accent);
}

.signout-card__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.signout-card__name {
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--shell-ink);
  line-height: 1.2;
}

.signout-card__email {
  font-size: 0.78rem;
  color: var(--shell-muted);
  margin-top: 0.15rem;
}

/* Separator */
.signout-card__sep {
  height: 1px;
  background: linear-gradient(
    90deg,
    transparent,
    var(--shell-border) 30%,
    var(--shell-border) 70%,
    transparent
  );
}

/* Meta pills */
.signout-card__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
}

.signout-card__pill {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.25rem 0.65rem;
  border-radius: 999px;
  background: var(--shell-accent-soft);
  color: var(--shell-accent);
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  border: 1px solid rgb(var(--bw-theme-primary-rgb, 100 100 100) / 0.15);
}

/* Message */
.signout-card__message {
  margin: 0;
  font-size: 0.85rem;
  color: var(--shell-muted);
  line-height: 1.55;
}

/* Buttons */
.signout-card__actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.6rem;
  margin-top: 0.25rem;
}

.signout-card__btn {
  padding: 0.6rem 0;
  border-radius: 0.65rem;
  border: none;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  transition: all 0.18s ease;
}

.signout-card__btn--cancel {
  background: rgb(0 0 0 / 0.06);
  color: var(--shell-ink);
  border: 1px solid var(--shell-border);
}

.signout-card__btn--cancel:hover {
  background: rgb(0 0 0 / 0.1);
}

.signout-card__btn--confirm {
  background: #dc2626;
  color: #ffffff;
}

.signout-card__btn--confirm:hover {
  background: #b91c1c;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgb(220 38 38 / 0.35);
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
  padding: 0 0.25rem 0.75rem;
}

.workspace-shell--mini .profile-card {
  border: 1px solid transparent;
  background: transparent;
  padding: 0;
  display: flex;
  justify-content: center;
  align-items: center;
}

.workspace-shell--mini .workspace-shell__nav-item {
  display: flex;
  justify-content: center;
}

.workspace-shell--mini .workspace-shell__nav-item :deep(.q-item__section--avatar) {
  min-width: unset;
  padding: 0;
}

.workspace-shell__flyout-sub-item {
  border-radius: 6px;
}

.workspace-shell__flyout-menu {
  background: color-mix(
    in srgb,
    var(--shell-surface) 95%,
    var(--color-mix-tint, white) 5%
  ) !important;
  border: 1px solid var(--shell-border);
  box-shadow: var(--shell-shadow);
}
</style>
