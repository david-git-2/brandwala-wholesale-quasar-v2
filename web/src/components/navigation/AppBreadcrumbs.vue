<template>
  <nav class="app-breadcrumbs row items-center no-wrap" aria-label="Breadcrumb">
    <ol class="app-breadcrumbs__list row items-center no-wrap q-pa-none q-ma-none">
      <template v-for="(item, index) in breadcrumbs" :key="index">
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
  max-width: 240px;
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
  color: var(--bw-neutral-muted);
  padding: 3px 6px;
  border-radius: 6px;
  transition: all 0.15s ease-in-out;
}

.app-breadcrumbs__link:hover {
  color: var(--bw-neutral-ink);
  background: color-mix(in srgb, var(--bw-neutral-ink) 5%, transparent);
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
  color: var(--bw-neutral-ink);
  letter-spacing: -0.01em;
}

.app-breadcrumbs__parent {
  font-weight: 500;
  color: var(--bw-neutral-muted);
}

.app-breadcrumbs__separator {
  user-select: none;
  color: var(--bw-neutral-chrome);
  opacity: 0.7;
}

.breadcrumb-icon {
  color: var(--bw-neutral-muted);
}

.app-breadcrumbs__badge {
  margin-left: 6px;
  font-size: 9.5px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  padding: 1.5px 7px;
  border-radius: 999px;
  background: var(--bw-theme-primary-soft);
  color: var(--bw-brand-accent);
  border: 1px solid color-mix(in srgb, var(--bw-brand-accent) 22%, transparent);
}
</style>
