type MarkedOptions = {
  breaks?: boolean;
  gfm?: boolean;
};

const state: Required<MarkedOptions> = {
  breaks: false,
  gfm: true,
};

const escapeHtml = (value: string) =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const escapeAttr = (value: string) => escapeHtml(value).replace(/`/g, '&#96;');

const inlineMarkdown = (value: string) => {
  let output = escapeHtml(value);

  output = output.replace(/`([^`]+)`/g, '<code>$1</code>');
  output = output.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_match, text: string, href: string) => {
    return `<a href="${escapeAttr(href)}" target="_blank" rel="noreferrer noopener">${text}</a>`;
  });
  output = output.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  output = output.replace(/\*([^*]+)\*/g, '<em>$1</em>');

  if (state.breaks) {
    output = output.replace(/\n/g, '<br />\n');
  }

  return output;
};

const parse = (markdown: string): string => {
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  const blocks: string[] = [];
  let index = 0;

  const flushParagraph = (paragraph: string[]) => {
    if (!paragraph.length) return;
    blocks.push(`<p>${inlineMarkdown(paragraph.join(' '))}</p>`);
    paragraph.length = 0;
  };

  while (index < lines.length) {
    const line = lines[index] ?? '';

    if (!line.trim()) {
      index += 1;
      continue;
    }

    const headingMatch = line.match(/^(#{1,6})\s+(.*)$/);
    if (headingMatch) {
      const level = (headingMatch[1] ?? '').length;
      const headingText = headingMatch[2] ?? '';
      blocks.push(`<h${level}>${inlineMarkdown(headingText)}</h${level}>`);
      index += 1;
      continue;
    }

    if (line.startsWith('```')) {
      const language = line.slice(3).trim();
      const codeLines: string[] = [];
      index += 1;

      while (index < lines.length && !(lines[index] ?? '').startsWith('```')) {
        codeLines.push(lines[index] ?? '');
        index += 1;
      }

      if (index < lines.length) {
        index += 1;
      }

      const classAttr = language ? ` class="language-${escapeAttr(language)}"` : '';
      blocks.push(`<pre><code${classAttr}>${escapeHtml(codeLines.join('\n'))}</code></pre>`);
      continue;
    }

    if (/^(\s*[-*+]\s+|\s*\d+\.\s+)/.test(line)) {
      const isOrdered = /^\s*\d+\.\s+/.test(line);
      const tagName = isOrdered ? 'ol' : 'ul';
      const items: string[] = [];

      while (index < lines.length) {
        const current = lines[index] ?? '';
        if (!current.trim()) break;
        const itemMatch = current.match(/^\s*(?:[-*+]|(\d+)\.)\s+(.*)$/);
        if (!itemMatch) break;
        items.push(`<li>${inlineMarkdown(itemMatch[2] ?? '')}</li>`);
        index += 1;
      }

      blocks.push(`<${tagName}>${items.join('')}</${tagName}>`);
      continue;
    }

    if (/^\s*>\s?/.test(line)) {
      const quoteLines: string[] = [];
      while (index < lines.length) {
        const current = lines[index] ?? '';
        if (!/^\s*>\s?/.test(current)) break;
        quoteLines.push(current.replace(/^\s*>\s?/, ''));
        index += 1;
      }
      blocks.push(`<blockquote><p>${inlineMarkdown(quoteLines.join(' '))}</p></blockquote>`);
      continue;
    }

    const paragraph: string[] = [];
    while (index < lines.length) {
      const current = lines[index] ?? '';
      if (!current.trim()) break;
      if (
        current.startsWith('```') ||
        /^(#{1,6})\s+/.test(current) ||
        /^(\s*[-*+]\s+|\s*\d+\.\s+)/.test(current) ||
        /^\s*>\s?/.test(current)
      ) {
        break;
      }
      paragraph.push(current.trim());
      index += 1;
    }

    flushParagraph(paragraph);
  }

  return blocks.join('\n');
};

export const marked = {
  setOptions(options: MarkedOptions) {
    state.breaks = Boolean(options.breaks);
    state.gfm = options.gfm ?? state.gfm;
  },
  parse(markdown: string) {
    return parse(markdown);
  },
};

export type { MarkedOptions };
