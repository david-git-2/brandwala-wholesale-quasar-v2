<template>
  <DocsPageShell :hide-header="useMarkdownTitle">
    <DocsMarkdown v-if="markdownBefore" toc-owner="overview-before" :source="markdownBefore" />
    <div v-if="vpc" class="docs-overview__breakout">
      <DocsVpcChart class="docs-overview__chart" :show-header="false" v-bind="vpc" />
    </div>
    <DocsMarkdown v-if="markdownAfter" toc-owner="overview-after" :source="markdownAfter" />
  </DocsPageShell>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { getDocsMarkdown } from '../content/docsMarkdownRegistry';
import DocsMarkdown from '../components/DocsMarkdown.vue';
import DocsPageShell from '../components/DocsPageShell.vue';
import DocsVpcChart from '../components/DocsVpcChart.vue';
import {
  extractMarkdownTitle,
  parsePlatformVpcMd,
  splitMarkdownAtVpcChart,
} from '../utils/parsePlatformVpcMd';

const overviewMd = getDocsMarkdown('what-is-tradeflow.md') ?? '';
const vpcMd = getDocsMarkdown('platform-vpc.md') ?? '';

const split = computed(() => splitMarkdownAtVpcChart(overviewMd));
const markdownBefore = computed(() => split.value.before);
const markdownAfter = computed(() => split.value.after);
const vpc = computed(() => (vpcMd ? parsePlatformVpcMd(vpcMd) : null));
const useMarkdownTitle = computed(() => Boolean(extractMarkdownTitle(overviewMd)));
</script>

<style scoped>
.docs-overview__breakout {
  width: 100%;
  max-width: 100%;
  min-width: 0;
  margin: 24px 0 32px;
  overflow-x: auto;
}
</style>
