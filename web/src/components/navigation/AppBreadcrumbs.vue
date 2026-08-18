<template>
  <nav class="app-breadcrumbs row items-center no-wrap" aria-label="Breadcrumb">
    <ol class="app-breadcrumbs__list row items-center no-wrap q-pa-none q-ma-none">
      <template v-for="(item, index) in breadcrumbs" :key="index">
        <!-- Separator -->
        <li
          v-if="index > 0"
          class="app-breadcrumbs__separator row items-center text-grey-5 q-px-xs"
          aria-hidden="true"
        >
          <q-icon name="ph ph-caret-right" size="13px" />
        </li>

        <!-- Breadcrumb item -->
        <li class="app-breadcrumbs__item row items-center no-wrap" :class="{ 'app-breadcrumbs__item--active': index === breadcrumbs.length - 1 }">
          <!-- Clickable Link (Intermediate section) -->
          <router-link
            v-if="item.to && index < breadcrumbs.length - 1"
            :to="item.to"
            class="app-breadcrumbs__link row items-center no-wrap text-grey-7"
          >
            <q-icon v-if="item.icon && index === 0" :name="item.icon" size="14px" class="q-mr-xs text-grey-6" />
            <span class="app-breadcrumbs__label ellipsis">{{ item.label }}</span>
          </router-link>

          <!-- Non-clickable Group Item OR Active Leaf Item -->
          <div v-else class="app-breadcrumbs__current row items-center no-wrap">
            <q-icon
              v-if="item.icon && index === 0"
              :name="item.icon"
              size="14px"
              class="q-mr-xs"
              :class="index === breadcrumbs.length - 1 ? 'text-grey-8' : 'text-grey-6'"
            />
            <span
              class="app-breadcrumbs__label ellipsis"
              :class="index === breadcrumbs.length - 1 ? 'text-weight-bold text-grey-9' : 'text-grey-6 text-weight-medium'"
            >{{ item.label }}</span>

            <!-- Status Badge if present -->
            <q-badge
              v-if="item.badge"
              :color="item.badge.color || 'primary'"
              :text-color="item.badge.textColor || 'white'"
              class="q-ml-sm text-bold text-uppercase"
              style="font-size: 10px; padding: 2px 6px; border-radius: 6px; letter-spacing: 0.05em"
            >
              <q-icon v-if="item.badge.icon" :name="item.badge.icon" size="11px" class="q-mr-xs" />
              {{ item.badge.label }}
            </q-badge>
          </div>
        </li>
      </template>
    </ol>
  </nav>
</template>

<script setup lang="ts">
import { useBreadcrumbs } from 'src/composables/useBreadcrumbs';

const { breadcrumbs } = useBreadcrumbs();
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
  max-width: 220px;
}

@media (min-width: 1024px) {
  .app-breadcrumbs__item {
    max-width: 320px;
  }
}

.app-breadcrumbs__link {
  text-decoration: none;
  font-size: 0.875rem;
  font-weight: 500;
  line-height: 1.25;
  padding: 3px 6px;
  border-radius: 6px;
  transition: all 0.15s ease-in-out;
}

.app-breadcrumbs__link:hover {
  color: var(--q-primary, #2563eb) !important;
  background: color-mix(in srgb, var(--q-primary, #2563eb) 8%, transparent);
}

.app-breadcrumbs__current {
  font-size: 0.875rem;
  line-height: 1.25;
  padding: 3px 6px;
}

.app-breadcrumbs__label {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.app-breadcrumbs__separator {
  user-select: none;
}

/* Dark mode support */
body.body--dark .app-breadcrumbs__link {
  color: #94a3b8 !important;
}

body.body--dark .app-breadcrumbs__link:hover {
  color: #60a5fa !important;
  background: rgba(96, 165, 250, 0.12);
}

body.body--dark .app-breadcrumbs__current .text-grey-9 {
  color: #f8fafc !important;
}

body.body--dark .app-breadcrumbs__separator {
  color: #64748b !important;
}
</style>
