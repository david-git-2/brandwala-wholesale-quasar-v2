export interface DocHeading {
  level: number;
  text: string;
  id: string;
}

export interface DocItem {
  id: string;
  path: string;
  title: string;
  category: string;
  subgroup?: string | undefined;
  badge?: string | undefined;
  summary?: string | undefined;
  rawContent: string;
  headings: DocHeading[];
  wordCount: number;
  readingTimeMinutes: number;
}

export interface DocCategoryGroup {
  name: string;
  icon: string;
  description: string;
  docs: DocItem[];
  subgroups?: Record<string, DocItem[]> | undefined;
}

// Vite glob loader to eagerly load all markdown files across docs/ and doc/
const rawDocFiles = import.meta.glob<string>(
  ['../../../docs/**/*.md', '../../../doc/**/*.md'],
  { query: '?raw', import: 'default', eager: true }
);

function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-');
}

function parseMarkdownMetadata(rawPath: string, content: string): DocItem {
  // Normalize path relative to project root
  const cleanPath = rawPath.replace(/^\.\.\/\.\.\//, '').replace(/^\.\.\//, '');
  const id = slugify(cleanPath.replace(/\.md$/, ''));

  // Extract first H1 title
  const h1Match = content.match(/^#\s+(.+)$/m);
  const fileName = cleanPath.split('/').pop()?.replace(/\.md$/, '') || 'Document';
  const title = h1Match && h1Match[1]
    ? h1Match[1].trim().replace(/\s*—\s*/g, ' — ')
    : fileName.replace(/[-_]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());

  // Extract headings for Table of Contents
  const headings: DocHeading[] = [];
  const headingRegex = /^(#{2,3})\s+(.+)$/gm;
  let match: RegExpExecArray | null;
  while ((match = headingRegex.exec(content)) !== null) {
    const levelStr = match[1];
    const textStr = match[2];
    if (levelStr && textStr) {
      const level = levelStr.length;
      const text = textStr.trim().replace(/\[([^\]]+)\]\([^)]+\)/g, '$1'); // strip md links
      const headId = slugify(text);
      headings.push({ level, text, id: headId });
    }
  }

  // Word count & reading time
  const words = content.trim().split(/\s+/).length;
  const readingTimeMinutes = Math.max(1, Math.ceil(words / 200));

  // Auto-detect badge
  let badge = 'Guide';
  const lowerPath = cleanPath.toLowerCase();
  const lowerTitle = title.toLowerCase();

  if (lowerPath.includes('prd') || lowerTitle.includes('prd') || lowerTitle.includes('product requirement')) {
    badge = 'PRD';
  } else if (lowerPath.includes('data-model') || lowerTitle.includes('data model') || lowerTitle.includes('schema')) {
    badge = 'Data Model';
  } else if (lowerPath.includes('api-contract') || lowerTitle.includes('api contract') || lowerTitle.includes('rpc')) {
    badge = 'API Contract';
  } else if (lowerPath.includes('tdd') || lowerTitle.includes('technical design') || lowerTitle.includes('tdd')) {
    badge = 'TDD';
  } else if (lowerPath.includes('matrix') || lowerTitle.includes('matrix')) {
    badge = 'Matrix';
  } else if (lowerPath.includes('architecture') || lowerTitle.includes('architecture')) {
    badge = 'Architecture';
  } else if (lowerPath.includes('fix') || lowerTitle.includes('fix')) {
    badge = 'Fix Plan';
  } else if (lowerPath.includes('plan') || lowerTitle.includes('plan')) {
    badge = 'Plan';
  }

  // Determine Category & Subgroup
  let category = 'Operations & Modules';
  let subgroup: string | undefined = undefined;

  if (cleanPath.startsWith('docs/architecture') || cleanPath === 'docs/README.md' || cleanPath === 'doc/MASTER_PLAN.md' || cleanPath === 'doc/BRAND_THEME_PLAN.md') {
    category = 'Architecture & Standards';
    subgroup = 'Core Standards';
  } else if (cleanPath.startsWith('docs/features/')) {
    category = 'Features & Specifications';
    const parts = cleanPath.split('/');
    if (parts.length > 2 && parts[2]) {
      subgroup = parts[2].replace(/[-_]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
    }
  } else if (cleanPath.startsWith('doc/fix/')) {
    category = 'System, Schemas & Fixes';
    subgroup = 'UI & Logic Fixes';
  } else if (cleanPath.startsWith('doc/')) {
    const parts = cleanPath.split('/');
    if (parts.length > 2 && parts[1]) {
      const folder = parts[1];
      subgroup = folder.replace(/[-_]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
      category = 'Operations & Modules';
    } else {
      category = 'Architecture & Standards';
      subgroup = 'System Architecture';
    }
  }

  // Summary snippet (first paragraph after title)
  let summary = '';
  const paragraphs = content.split(/\n\n+/);
  for (const p of paragraphs) {
    const trimmed = p.trim();
    if (trimmed && !trimmed.startsWith('#') && !trimmed.startsWith('>') && !trimmed.startsWith('```')) {
      summary = trimmed.slice(0, 160) + (trimmed.length > 160 ? '...' : '');
      break;
    }
  }

  return {
    id,
    path: cleanPath,
    title,
    category,
    subgroup,
    badge,
    summary,
    rawContent: content,
    headings,
    wordCount: words,
    readingTimeMinutes,
  };
}

export function getAllDocs(): DocItem[] {
  const docs: DocItem[] = [];

  for (const [rawPath, content] of Object.entries(rawDocFiles)) {
    if (typeof content === 'string') {
      docs.push(parseMarkdownMetadata(rawPath, content));
    }
  }

  // Sort order: Architecture & Standards first, docs/README.md at the very top, then alphabetized
  return docs.sort((a, b) => {
    if (a.path === 'docs/README.md') return -1;
    if (b.path === 'docs/README.md') return 1;
    if (a.category !== b.category) {
      const order = ['Architecture & Standards', 'Features & Specifications', 'Operations & Modules', 'System, Schemas & Fixes'];
      return order.indexOf(a.category) - order.indexOf(b.category);
    }
    if (a.subgroup && b.subgroup && a.subgroup !== b.subgroup) {
      return a.subgroup.localeCompare(b.subgroup);
    }
    return a.path.localeCompare(b.path);
  });
}

export function groupDocsByCategory(docs: DocItem[]): DocCategoryGroup[] {
  const categoryMap: Record<string, { icon: string; description: string; docs: DocItem[]; subgroups: Record<string, DocItem[]> }> = {
    'Architecture & Standards': {
      icon: 'ph-buildings',
      description: 'System architectural guides, database conventions, state management, and design rules.',
      docs: [],
      subgroups: {},
    },
    'Features & Specifications': {
      icon: 'ph-sparkle',
      description: 'Standardized 6-phase specifications for upcoming and active features.',
      docs: [],
      subgroups: {},
    },
    'Operations & Modules': {
      icon: 'ph-stack',
      description: 'Operational domain modules, procurement, sales invoices, shop orders, wallet, and reporting.',
      docs: [],
      subgroups: {},
    },
    'System, Schemas & Fixes': {
      icon: 'ph-wrench',
      description: 'Database schema splits, auth resets, bugfixes, and utility documentation.',
      docs: [],
      subgroups: {},
    },
  };

  for (const doc of docs) {
    let group = categoryMap[doc.category];
    if (!group) {
      group = {
        icon: 'ph-file-text',
        description: 'Module documentation',
        docs: [],
        subgroups: {},
      };
      categoryMap[doc.category] = group;
    }

    group.docs.push(doc);

    const sub = doc.subgroup || 'General';
    if (!group.subgroups) {
      group.subgroups = {};
    }
    if (!group.subgroups[sub]) {
      group.subgroups[sub] = [];
    }
    group.subgroups[sub].push(doc);
  }

  return Object.entries(categoryMap)
    .filter(([, group]) => group.docs.length > 0)
    .map(([name, group]) => ({
      name,
      icon: group.icon,
      description: group.description,
      docs: group.docs,
      subgroups: group.subgroups,
    }));
}
