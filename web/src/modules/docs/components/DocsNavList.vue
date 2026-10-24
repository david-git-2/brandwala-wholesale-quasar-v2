<template>
  <nav class="docs-nav" aria-label="Docs">
    <ul class="docs-nav__list">
      <template v-for="(entry, index) in docsNav" :key="index">
        <li v-if="isDocsNavGroup(entry)" class="docs-nav__group">
          <div class="docs-nav__group-label">{{ entry.label }}</div>
          <ul class="docs-nav__list docs-nav__list--nested">
            <li v-for="child in entry.children" :key="child.name">
              <router-link
                :to="child.path"
                class="docs-nav__link"
                :class="{ 'docs-nav__link--active': isCurrent(child.name) }"
              >
                {{ child.label }}
              </router-link>
            </li>
          </ul>
        </li>
        <li v-else>
          <router-link
            :to="entry.path"
            class="docs-nav__link"
            :class="{ 'docs-nav__link--active': isCurrent(entry.name) }"
          >
            {{ entry.label }}
          </router-link>
        </li>
      </template>
    </ul>
  </nav>
</template>

<script setup lang="ts">
import { useRoute } from 'vue-router';
import { docsNav, isDocsNavGroup } from '../content/nav';

const route = useRoute();

function isCurrent(name: string) {
  return route.name === name;
}
</script>

<style scoped>
.docs-nav {
  padding: 16px 0 32px;
}

.docs-nav__list {
  list-style: none;
  margin: 0;
  padding: 0;
}

.docs-nav__group {
  margin-top: 24px;
}

.docs-nav__group:first-child {
  margin-top: 8px;
}

.docs-nav__group-label {
  padding: 0 16px 8px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tf-theme-muted);
}

.docs-nav__link {
  position: relative;
  display: flex;
  align-items: center;
  height: 36px;
  padding: 0 16px;
  font-size: 13px;
  font-weight: 500;
  color: var(--tf-theme-ink);
  text-decoration: none;
  transition: opacity var(--tf-dur-fast) var(--tf-ease);
}

.docs-nav__link:hover {
  background: var(--tf-hover-bg);
}

.docs-nav__link--active {
  background: var(--tf-hover-bg);
  color: var(--tf-theme-ink);
  font-weight: 600;
}

.docs-nav__link--active::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 3px;
  background: var(--tf-theme-ink);
}

.docs-nav__link:focus-visible {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}

@media (prefers-reduced-motion: reduce) {
  .docs-nav__link {
    transition: none;
  }
}
</style>
