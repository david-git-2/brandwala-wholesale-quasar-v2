<template>
  <nav class="app-breadcrumbs row items-center no-wrap" aria-label="Breadcrumb">
    <ol class="app-breadcrumbs__list row items-center no-wrap q-pa-none q-ma-none">
      <template v-if="useCollapsedTrail">
        <li class="app-breadcrumbs__item row items-center no-wrap">
          <router-link
            v-if="headCrumb?.to"
            :to="headCrumb.to"
            class="app-breadcrumbs__link row items-center no-wrap"
          >
            <q-icon
              v-if="headCrumb.icon"
              :name="headCrumb.icon"
              size="13px"
              class="q-mr-xs breadcrumb-icon"
            />
            <span class="app-breadcrumbs__label ellipsis">{{ headCrumb.label }}</span>
          </router-link>
          <div v-else class="app-breadcrumbs__current row items-center no-wrap">
            <q-icon
              v-if="headCrumb?.icon"
              :name="headCrumb.icon"
              size="13px"
              class="q-mr-xs breadcrumb-icon"
            />
            <span class="app-breadcrumbs__label ellipsis app-breadcrumbs__parent">{{
              headCrumb?.label
            }}</span>
          </div>
        </li>

        <li class="app-breadcrumbs__separator row items-center q-px-xs" aria-hidden="true">
          <q-icon name="ph ph-caret-right" size="12px" />
        </li>

        <li class="app-breadcrumbs__item row items-center no-wrap app-breadcrumbs__item--menu">
          <q-btn flat dense round size="xs" class="app-breadcrumbs__ellipsis" aria-label="More breadcrumb levels">
            <q-icon name="ph ph-dots-three" size="14px" />
            <q-menu anchor="bottom left" self="top left" :offset="[0, 6]">
              <q-list dense class="q-py-xs" style="min-width: 180px">
                <q-item
                  v-for="(item, midIndex) in middleCrumbs"
                  :key="midIndex"
                  clickable
                  :to="item.to"
                  v-close-popup
                  class="app-breadcrumbs__menu-item"
                >
                  <q-item-section>
                    <q-item-label class="text-caption">{{ item.label }}</q-item-label>
                  </q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>
        </li>

        <li class="app-breadcrumbs__separator row items-center q-px-xs" aria-hidden="true">
          <q-icon name="ph ph-caret-right" size="12px" />
        </li>

        <li
          v-if="tailCrumb"
          class="app-breadcrumbs__item row items-center no-wrap app-breadcrumbs__item--active"
        >
          <div class="app-breadcrumbs__current row items-center no-wrap">
            <span class="app-breadcrumbs__label ellipsis app-breadcrumbs__leaf">{{ tailCrumb.label }}</span>
            <span
              v-if="tailCrumb.badge"
              class="app-breadcrumbs__badge row items-center no-wrap"
            >
              <q-icon v-if="tailCrumb.badge.icon" :name="tailCrumb.badge.icon" size="11px" class="q-mr-xs" />
              {{ tailCrumb.badge.label }}
            </span>
          </div>
        </li>
      </template>

      <template v-for="(item, index) in breadcrumbs" v-else :key="index">
        <!-- Separator -->
        <li
          v-if="index > 0"
          class="app-breadcrumbs__separator row items-center q-px-xs"
          aria-hidden="true"
        >
          <q-icon name="ph ph-caret-right" size="12px" />
        </li>

        <!-- Breadcrumb item -->
        <li
          class="app-breadcrumbs__item row items-center no-wrap"
          :class="{ 'app-breadcrumbs__item--active': index === breadcrumbs.length - 1 }"
        >
          <!-- Clickable Link (Intermediate section) -->
          <router-link
            v-if="item.to && index < breadcrumbs.length - 1"
            :to="item.to"
            class="app-breadcrumbs__link row items-center no-wrap"
          >
            <q-icon v-if="item.icon && index === 0" :name="item.icon" size="13px" class="q-mr-xs breadcrumb-icon" />
            <span class="app-breadcrumbs__label ellipsis">{{ item.label }}</span>
          </router-link>

          <!-- Non-clickable Group Item OR Active Leaf Item -->
          <div v-else class="app-breadcrumbs__current row items-center no-wrap">
            <q-icon
              v-if="item.icon && index === 0"
              :name="item.icon"
              size="13px"
              class="q-mr-xs breadcrumb-icon"
            />
            <span
              class="app-breadcrumbs__label ellipsis"
              :class="index === breadcrumbs.length - 1 ? 'app-breadcrumbs__leaf' : 'app-breadcrumbs__parent'"
            >{{ item.label }}</span>

            <!-- Status Badge if present -->
            <span
              v-if="item.badge"
              class="app-breadcrumbs__badge row items-center no-wrap"
            >
              <q-icon v-if="item.badge.icon" :name="item.badge.icon" size="11px" class="q-mr-xs" />
              {{ item.badge.label }}
            </span>
          </div>
        </li>
      </template>
    </ol>
  </nav>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useQuasar } from 'quasar';

import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';

const { breadcrumbs } = useBreadcrumbs();
const $q = useQuasar();

const useCollapsedTrail = computed(
  () => $q.screen.lt.md && breadcrumbs.value.length > 3,
);

const headCrumb = computed(() => breadcrumbs.value[0] ?? null);
const tailCrumb = computed(() => breadcrumbs.value[breadcrumbs.value.length - 1] ?? null);
const middleCrumbs = computed(() =>
  useCollapsedTrail.value ? breadcrumbs.value.slice(1, -1) : [],
);
</script>

<style scoped>
.app-breadcrumbs {
  max-width: 100%;
  overflow: hidden;
}

.app-breadcrumbs__list {
  list-style: none;
}

.app-breadcrumbs__item {
  min-width: 0;
  max-width: 240px;
}

.app-breadcrumbs__item--menu {
  max-width: none;
  flex-shrink: 0;
}

.app-breadcrumbs__ellipsis {
  color: var(--tf-neutral-muted);
  width: 24px;
  height: 24px;
  min-height: 24px;
}

.app-breadcrumbs__menu-item {
  min-height: 32px;
}

@media (max-width: 1023px) {
  .app-breadcrumbs__item {
    max-width: min(42vw, 200px);
  }

  .app-breadcrumbs__item--active {
    max-width: min(52vw, 240px);
  }
}

@media (min-width: 1024px) {
  .app-breadcrumbs__item {
    max-width: 340px;
  }
}

.app-breadcrumbs__link {
  text-decoration: none;
  font-size: 13px;
  font-weight: 500;
  line-height: 1.25;
  color: var(--tf-neutral-muted);
  padding: 3px 6px;
  border-radius: 6px;
  transition: all 0.15s ease-in-out;
}

.app-breadcrumbs__link:hover {
  color: var(--tf-neutral-ink);
  background: color-mix(in srgb, var(--tf-neutral-ink) 5%, transparent);
}

.app-breadcrumbs__current {
  font-size: 13px;
  line-height: 1.25;
  padding: 3px 4px;
}

.app-breadcrumbs__label {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.app-breadcrumbs__leaf {
  font-weight: 600;
  color: var(--tf-neutral-ink);
  letter-spacing: -0.01em;
}

.app-breadcrumbs__parent {
  font-weight: 500;
  color: var(--tf-neutral-muted);
}

.app-breadcrumbs__separator {
  user-select: none;
  color: var(--tf-neutral-chrome);
  opacity: 0.7;
}

.breadcrumb-icon {
  color: var(--tf-neutral-muted);
}

.app-breadcrumbs__badge {
  margin-left: 6px;
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  padding: 1.5px 7px;
  border-radius: 999px;
  background: var(--tf-theme-primary-soft);
  color: var(--tf-brand-accent);
  border: 1px solid color-mix(in srgb, var(--tf-brand-accent) 22%, transparent);
}
</style>
