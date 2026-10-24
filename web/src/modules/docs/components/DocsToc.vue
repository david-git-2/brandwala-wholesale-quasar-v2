<template>
  <nav v-if="groups.length" class="docs-toc" aria-label="On this page">
    <p class="docs-toc__label">On this page</p>
    <div class="docs-toc__groups">
      <section v-for="group in groups" :key="group.id" class="docs-toc__group">
        <a
          :href="`#${group.id}`"
          class="docs-toc__link docs-toc__link--h2"
          :class="{ 'docs-toc__link--active': group.id === activeId }"
          @click="onClick($event, group.id)"
        >
          {{ group.text }}
        </a>
        <ol v-if="group.children.length" class="docs-toc__sublist">
          <li v-for="child in group.children" :key="child.id" class="docs-toc__item">
            <a
              :href="`#${child.id}`"
              class="docs-toc__link docs-toc__link--h3"
              :class="{ 'docs-toc__link--active': child.id === activeId }"
              @click="onClick($event, child.id)"
            >
              {{ child.text }}
            </a>
          </li>
        </ol>
      </section>
    </div>
  </nav>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import {
  groupDocsTocItems,
  type DocsTocItem,
} from '../composables/useDocsToc';

const props = defineProps<{
  items: DocsTocItem[];
}>();

const groups = computed(() => groupDocsTocItems(props.items));

const activeId = ref('');
let observer: IntersectionObserver | null = null;

function onClick(event: MouseEvent, id: string) {
  const el = document.getElementById(id);
  if (!el) return;
  event.preventDefault();
  el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  activeId.value = id;
  history.replaceState(null, '', `#${id}`);
}

function observe(items: DocsTocItem[]) {
  observer?.disconnect();
  const nodes = items
    .map((item) => document.getElementById(item.id))
    .filter((node): node is HTMLElement => Boolean(node));
  if (!nodes.length) return;
  observer = new IntersectionObserver(
    (entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
      const id = visible[0]?.target.id;
      if (id) activeId.value = id;
    },
    { rootMargin: '-80px 0px -55% 0px', threshold: [0, 0.25, 1] },
  );
  nodes.forEach((node) => observer?.observe(node));
  if (!activeId.value && items[0]) activeId.value = items[0].id;
}

onMounted(() => observe(props.items));
watch(
  () => props.items,
  (items) => {
    activeId.value = '';
    requestAnimationFrame(() => observe(items));
  },
);
onUnmounted(() => observer?.disconnect());
</script>

<style scoped>
.docs-toc {
  position: sticky;
  top: 72px;
  max-height: calc(100vh - 88px);
  overflow: auto;
  padding: 40px 0 48px 20px;
  border-left: 1px solid var(--tf-theme-border);
}

.docs-toc__label {
  margin: 0 0 14px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--tf-theme-muted);
}

.docs-toc__groups {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.docs-toc__group {
  min-width: 0;
}

.docs-toc__sublist {
  list-style: none;
  margin: 6px 0 0;
  padding: 0;
}

.docs-toc__link {
  display: block;
  padding: 2px 0 2px 10px;
  border-left: 2px solid transparent;
  color: var(--tf-theme-muted);
  font-size: 13px;
  line-height: 1.45;
  text-decoration: none;
  overflow-wrap: anywhere;
}

.docs-toc__link--h2 {
  font-weight: 600;
  color: var(--tf-theme-ink);
  font-size: 13px;
}

.docs-toc__link--h3 {
  font-size: 12px;
  padding-left: 18px;
}

.docs-toc__link:hover {
  color: var(--tf-theme-ink);
}

.docs-toc__link--active {
  color: var(--tf-theme-primary);
  border-left-color: var(--tf-theme-primary);
}

.docs-toc__link:focus-visible {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}
</style>
