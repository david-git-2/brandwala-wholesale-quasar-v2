import type { ValuePropositionCanvasNote } from 'src/components/ui/valuePropositionCanvas.types';

export type VpcMappingRow = {
  left: string;
  right: string;
};

export type PlatformVpcData = {
  labels: {
    valueProposition?: string;
    customerSegment?: string;
  };
  jobs: ValuePropositionCanvasNote[];
  pains: ValuePropositionCanvasNote[];
  gains: ValuePropositionCanvasNote[];
  products: ValuePropositionCanvasNote[];
  painRelievers: ValuePropositionCanvasNote[];
  gainCreators: ValuePropositionCanvasNote[];
  fit: VpcMappingRow[];
};

const SECTION_ALIASES: Record<string, keyof PlatformVpcData | 'skip'> = {
  labels: 'labels',
  'customer jobs': 'jobs',
  'customer pains': 'pains',
  'customer gains': 'gains',
  'products and services': 'products',
  'pain relievers': 'painRelievers',
  'gain creators': 'gainCreators',
  fit: 'fit',
};

const NOTE_BULLET =
  /^- (?:\*\*(.+?)\*\*|(.+?))(?:\s*[:—–]\s*|\s+—\s+)(.+)$/;

function parseNotes(block: string): ValuePropositionCanvasNote[] {
  const table = parseMarkdownTable(block);
  if (table.length > 0) {
    return table.map((row) => ({ title: row.left, note: row.right }));
  }

  const notes: ValuePropositionCanvasNote[] = [];
  for (const line of block.split('\n')) {
    const trimmed = line.trim();
    const match = trimmed.match(NOTE_BULLET);
    if (match) {
      notes.push({
        title: (match[1] ?? match[2] ?? '').trim(),
        note: (match[3] ?? '').trim(),
      });
      continue;
    }
    if (trimmed.startsWith('- ')) {
      const text = trimmed.slice(2).trim().replace(/^\*\*(.+)\*\*$/, '$1');
      notes.push({ title: text, note: '' });
    }
  }
  return notes;
}

function parseMarkdownTable(block: string): VpcMappingRow[] {
  const rows: VpcMappingRow[] = [];
  let headerSkipped = false;
  for (const line of block.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    if (/^\|?\s*[-:| ]+\s*\|?$/.test(trimmed)) continue;
    const cells = trimmed
      .split('|')
      .map((c) => c.trim())
      .filter((c) => c.length > 0);
    if (cells.length < 2) continue;
    if (!headerSkipped) {
      headerSkipped = true;
      continue;
    }
    rows.push({ left: cells[0], right: cells[1] });
  }
  return rows;
}

function parseLabels(block: string): PlatformVpcData['labels'] {
  const notes = parseNotes(block);
  const labels: PlatformVpcData['labels'] = {};
  for (const note of notes) {
    const key = note.title.toLowerCase();
    if (key.includes('value proposition')) labels.valueProposition = note.note || note.title;
    if (key.includes('customer segment')) labels.customerSegment = note.note || note.title;
  }
  return labels;
}

function splitSections(markdown: string): Map<string, string> {
  const sections = new Map<string, string>();
  const parts = markdown.replace(/\r\n/g, '\n').split(/^## /m);
  for (const part of parts.slice(1)) {
    const newline = part.indexOf('\n');
    if (newline === -1) continue;
    const title = part.slice(0, newline).trim().toLowerCase();
    const body = part.slice(newline + 1).trim();
    sections.set(title, body);
  }
  return sections;
}

export function parsePlatformVpcMd(markdown: string): PlatformVpcData {
  const sections = splitSections(markdown);
  const empty: PlatformVpcData = {
    labels: {},
    jobs: [],
    pains: [],
    gains: [],
    products: [],
    painRelievers: [],
    gainCreators: [],
    fit: [],
  };

  for (const [title, body] of sections) {
    const key = SECTION_ALIASES[title];
    if (!key || key === 'skip') continue;
    if (key === 'labels') {
      empty.labels = parseLabels(body);
      continue;
    }
    if (key === 'fit') {
      empty.fit = parseMarkdownTable(body);
      continue;
    }
    empty[key] = parseNotes(body);
  }

  return empty;
}

export const VPC_CHART_MARKER = '<!-- vpc-chart -->';

export function splitMarkdownAtVpcChart(markdown: string): { before: string; after: string } {
  const normalized = markdown.replace(/\r\n/g, '\n');
  const index = normalized.indexOf(VPC_CHART_MARKER);
  if (index === -1) {
    return { before: normalized, after: '' };
  }
  return {
    before: normalized.slice(0, index).trimEnd(),
    after: normalized.slice(index + VPC_CHART_MARKER.length).trimStart(),
  };
}

export function extractMarkdownTitle(markdown: string): string | undefined {
  const match = markdown.match(/^#\s+(.+)$/m);
  return match?.[1]?.trim();
}

export function extractMarkdownLead(markdown: string): string | undefined {
  const withoutTitle = markdown.replace(/^#\s+.+\n+/, '');
  const paragraph = withoutTitle.split(/\n## /)[0]?.trim() ?? '';
  const lines = paragraph
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l.length > 0 && !l.startsWith('<!--'));
  return lines.join(' ') || undefined;
}
