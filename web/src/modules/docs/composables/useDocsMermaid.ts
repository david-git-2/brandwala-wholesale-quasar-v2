import { useQuasar } from 'quasar';
import { nextTick, watch, type Ref } from 'vue';

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Extract ```mermaid fences before marked runs (custom code renderer skips lang). */
export function stripMermaidFences(markdown: string): {
  markdown: string;
  blocks: string[];
} {
  const blocks: string[] = [];
  const fenceRe = /```mermaid[^\n]*\n([\s\S]*?)```/g;
  const stripped = markdown.replace(fenceRe, (_match, src: string) => {
    const i = blocks.length;
    blocks.push(String(src).trim());
    return `\n\nMERMAID_PLACEHOLDER_${i}\n\n`;
  });
  return { markdown: stripped, blocks };
}

export function injectMermaidPlaceholders(html: string, blocks: string[]): string {
  let out = html;
  blocks.forEach((src, i) => {
    const escaped = escapeHtml(src);
    const figure = `<div class="docs-mermaid-wrap"><pre class="docs-mermaid">${escaped}</pre></div>`;
    out = out.replace(`<p>MERMAID_PLACEHOLDER_${i}</p>`, figure);
    out = out.replace(`MERMAID_PLACEHOLDER_${i}`, figure);
  });
  return out;
}

function unescapeHtml(text: string): string {
  return text
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

export function useDocsMermaidPaint(rootRef: Ref<HTMLElement | null>, html: Ref<string>) {
  const $q = useQuasar();

  async function paint(force = false) {
    await nextTick();
    await nextTick();
    const root = rootRef.value;
    if (!root) return;
    const nodes = root.querySelectorAll<HTMLElement>('.docs-mermaid');
    if (!nodes.length) return;

    try {
      const mermaidMod = await import('mermaid');
      const mermaid = mermaidMod.default;
      mermaid.initialize({
        startOnLoad: false,
        securityLevel: 'loose',
        theme: $q.dark.isActive ? 'dark' : 'neutral',
      });

      let index = 0;
      for (const el of nodes) {
        if (!force && el.getAttribute('data-rendered') === '1') continue;
        const stored = el.getAttribute('data-src');
        const src = (stored ? unescapeHtml(stored) : (el.textContent ?? '')).trim();
        if (!src) continue;
        if (!stored) {
          el.setAttribute('data-src', escapeHtml(src));
        }
        try {
          const id = `docs-mermaid-${index++}-${Date.now()}`;
          const { svg } = await mermaid.render(id, src);
          el.innerHTML = svg;
          el.setAttribute('data-rendered', '1');
          const svgEl = el.querySelector('svg');
          if (svgEl) {
            svgEl.removeAttribute('width');
            svgEl.removeAttribute('height');
            svgEl.style.width = '100%';
            svgEl.style.height = 'auto';
            svgEl.setAttribute('preserveAspectRatio', 'xMidYMid meet');
          }
        } catch (err) {
          console.error('[docs mermaid]', err);
        }
      }
    } catch (err) {
      console.error('[docs mermaid] load', err);
    }
  }

  watch(
    () => [html.value, rootRef.value] as const,
    () => {
      void paint(false);
    },
    { flush: 'post', immediate: true },
  );

  watch(
    () => $q.dark.isActive,
    () => {
      const root = rootRef.value;
      root?.querySelectorAll<HTMLElement>('.docs-mermaid').forEach((el) => {
        el.removeAttribute('data-rendered');
      });
      void paint(true);
    },
  );
}
