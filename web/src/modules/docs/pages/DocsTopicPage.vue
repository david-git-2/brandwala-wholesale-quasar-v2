<template>
  <DocsPageShell :title="pageTitle" :lead="pageLead" :hide-header="hasMarkdownTitle">
    <DocsMarkdown v-if="bodyMarkdown" toc-owner="topic" :source="bodyMarkdown" />
    <div v-else class="docs-topic-missing">
      Missing markdown: {{ docsFile }}
    </div>
  </DocsPageShell>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { getDocsMarkdown } from '../content/docsMarkdownRegistry';
import DocsMarkdown from '../components/DocsMarkdown.vue';
import DocsPageShell from '../components/DocsPageShell.vue';
import { extractMarkdownTitle } from '../utils/parsePlatformVpcMd';

const route = useRoute();

const docsFile = computed(() => {
  const raw = route.meta.docsMd;
  return typeof raw === 'string' ? raw : '';
});

const fullMarkdown = computed(() => {
  const file = docsFile.value;
  if (!file) return '';
  return getDocsMarkdown(file) ?? '';
});

const hasMarkdownTitle = computed(() => Boolean(extractMarkdownTitle(fullMarkdown.value)));

const pageTitle = computed(() => {
  if (hasMarkdownTitle.value) return '';
  const raw = route.meta.docsTitle;
  return typeof raw === 'string' ? raw : 'Platform guide';
});

const pageLead = computed(() => {
  if (hasMarkdownTitle.value) return undefined;
  const raw = route.meta.docsLead;
  return typeof raw === 'string' ? raw : undefined;
});

const bodyMarkdown = computed(() => fullMarkdown.value);
</script>

<style scoped>
.docs-topic-missing {
  padding: 16px;
  font-size: 13px;
  color: var(--tf-neutral-muted);
  border: 1px dashed var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
}
</style>
