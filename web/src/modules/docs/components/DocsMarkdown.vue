<template>
  <article ref="rootEl" class="docs-markdown" v-html="html" @click="onClick" />
</template>

<script setup lang="ts">
import { Marked } from 'marked';
import { computed, ref, watch } from 'vue';
import {
  injectMermaidPlaceholders,
  stripMermaidFences,
  useDocsMermaidPaint,
} from '../composables/useDocsMermaid';
import {
  createDocsHeadingIdQueue,
  extractDocsToc,
  slugifyHeading,
  useDocsTocOwner,
} from '../composables/useDocsToc';

const props = defineProps<{
  source: string;
  tocOwner?: string;
}>();

const owner = props.tocOwner ?? `md-${Math.random().toString(36).slice(2)}`;
const { setItems } = useDocsTocOwner(owner);

function renderMarkdownSource(raw: string): string {
  const { markdown, blocks } = stripMermaidFences(raw);
  const nextHeadingId = createDocsHeadingIdQueue(markdown);
  const markedLocal = new Marked({ gfm: true, breaks: false });
  markedLocal.use({
    renderer: {
      heading(token) {
        const text = token.text;
        const depth = token.depth;
        if (depth === 1) {
          return `<h1>${text}</h1>\n`;
        }
        const id = nextHeadingId() ?? slugifyHeading(text);
        return `<h${depth} id="${id}">${text}</h${depth}>\n`;
      },
      code(token) {
        const escaped = token.text
          .replace(/&/g, '&amp;')
          .replace(/</g, '&lt;')
          .replace(/>/g, '&gt;');
        return `<div class="docs-code"><button type="button" class="docs-code__copy" data-copy-code aria-label="Copy code">Copy</button><pre><code>${escaped}</code></pre></div>\n`;
      },
    },
  });
  let rendered = markedLocal.parse(markdown) as string;
  rendered = injectMermaidPlaceholders(rendered, blocks);
  rendered = rendered.replace(/<blockquote>\s*<p>([\s\S]*?)<\/p>/gi, (_m, inner: string) => {
    const plain = inner.replace(/<[^>]+>/g, '');
    let kind = 'note';
    if (/^tip\b/i.test(plain)) kind = 'tip';
    else if (/^warning\b/i.test(plain)) kind = 'warning';
    else if (/^danger\b/i.test(plain)) kind = 'danger';
    return `<blockquote class="docs-callout docs-callout--${kind}"><p>${inner}`;
  });
  return rendered;
}

const rootEl = ref<HTMLElement | null>(null);

const html = computed(() => {
  const raw = props.source.trim();
  if (!raw) return '';
  return renderMarkdownSource(raw);
});

useDocsMermaidPaint(rootEl, html);

watch(
  () => props.source,
  (source) => {
    setItems(extractDocsToc(source));
  },
  { immediate: true },
);

function onClick(event: MouseEvent) {
  const target = event.target as HTMLElement | null;
  const button = target?.closest('[data-copy-code]') as HTMLButtonElement | null;
  if (!button) return;
  const block = button.parentElement?.querySelector('code');
  const text = block?.textContent ?? '';
  void navigator.clipboard.writeText(text).then(() => {
    button.textContent = 'Copied';
    window.setTimeout(() => {
      button.textContent = 'Copy';
    }, 1200);
  });
}
</script>

<style scoped>
.docs-markdown :deep(h1) {
  margin: 0 0 16px;
  font-size: 30px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
  color: var(--tf-theme-heading, var(--tf-theme-ink));
}

.docs-markdown :deep(h2) {
  margin: 48px 0 12px;
  padding-bottom: 8px;
  font-size: 22px;
  font-weight: 650;
  line-height: 1.3;
  color: var(--tf-theme-heading, var(--tf-theme-ink));
  border-bottom: 1px solid var(--tf-theme-border);
  scroll-margin-top: 72px;
}

.docs-markdown :deep(h3) {
  margin: 24px 0 8px;
  font-size: 17px;
  font-weight: 600;
  line-height: 1.35;
  color: var(--tf-theme-heading, var(--tf-theme-ink));
  scroll-margin-top: 72px;
}

.docs-markdown :deep(p),
.docs-markdown :deep(ul),
.docs-markdown :deep(ol) {
  margin: 0 0 16px;
  font-size: 16px;
  line-height: 1.65;
  color: var(--tf-theme-ink);
}

.docs-markdown :deep(li) {
  margin-bottom: 8px;
}

.docs-markdown :deep(strong) {
  font-weight: 600;
}

.docs-markdown {
  min-width: 0;
  overflow-wrap: anywhere;
}

.docs-markdown :deep(table) {
  display: block;
  width: 100%;
  max-width: 100%;
  border-collapse: collapse;
  margin: 0 0 24px;
  font-size: 14px;
  overflow-x: auto;
}

.docs-markdown :deep(th) {
  padding: 8px 12px;
  text-align: left;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-theme-muted);
  border-bottom: 1px solid var(--tf-theme-border);
  background: transparent;
}

.docs-markdown :deep(td) {
  padding: 12px;
  vertical-align: top;
  border-bottom: 1px solid var(--tf-theme-border);
  color: var(--tf-theme-ink);
}

.docs-markdown :deep(a) {
  color: var(--tf-theme-primary);
  text-decoration: none;
  text-underline-offset: 2px;
}

.docs-markdown :deep(a:hover) {
  text-decoration: underline;
}

.docs-markdown :deep(a:focus-visible) {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}

.docs-markdown :deep(code) {
  font-family: var(--tf-font-mono);
  font-size: 0.9em;
  padding: 0 4px;
  border: 1px solid var(--tf-theme-border);
  border-radius: 4px;
  background: var(--tf-docs-code-bg);
}

.docs-markdown :deep(.docs-code) {
  position: relative;
  margin: 0 0 16px;
}

.docs-markdown :deep(.docs-code pre) {
  margin: 0;
  padding: 12px 16px;
  overflow: auto;
  border: 1px solid var(--tf-theme-border);
  border-radius: 8px;
  background: var(--tf-docs-code-bg);
}

.docs-markdown :deep(.docs-code pre code) {
  padding: 0;
  border: 0;
  background: transparent;
  font-size: 14px;
}

.docs-markdown :deep(.docs-code__copy) {
  position: absolute;
  top: 8px;
  right: 8px;
  padding: 4px 8px;
  border: 1px solid var(--tf-theme-border);
  border-radius: 4px;
  background: var(--tf-theme-surface);
  color: var(--tf-theme-muted);
  font-size: 12px;
  opacity: 0;
  cursor: pointer;
}

.docs-markdown :deep(.docs-code:hover .docs-code__copy),
.docs-markdown :deep(.docs-code__copy:focus-visible) {
  opacity: 1;
}

.docs-markdown :deep(.docs-code__copy:focus-visible) {
  outline: none;
  box-shadow: var(--tf-focus-ring);
}

.docs-markdown :deep(blockquote),
.docs-markdown :deep(.docs-callout) {
  margin: 0 0 16px;
  padding: 12px 16px;
  border-left: 3px solid var(--tf-docs-callout-border);
  background: var(--tf-docs-callout-bg);
  color: var(--tf-theme-ink);
}

.docs-markdown :deep(.docs-callout--warning) {
  border-left-color: var(--tf-warning);
}

.docs-markdown :deep(.docs-callout--danger) {
  border-left-color: var(--tf-error);
}

.docs-markdown :deep(blockquote p:last-child) {
  margin-bottom: 0;
}

.docs-markdown :deep(.docs-mermaid-wrap) {
  margin: 0 0 24px;
  padding: 16px;
  overflow-x: auto;
  border: 1px solid var(--tf-theme-border);
  border-radius: 8px;
  background: var(--tf-docs-code-bg);
}

.docs-markdown :deep(.docs-mermaid) {
  margin: 0;
  font-family: inherit;
  font-size: 14px;
  white-space: pre-wrap;
}

.docs-markdown :deep(.docs-mermaid svg) {
  display: block;
  max-width: 100%;
  height: auto;
  margin: 0 auto;
}
</style>
