export interface SchemaColumn {
  name: string;
  type: string;
  isNullable: boolean;
}

export interface SchemaRelationship {
  foreignKeyName: string;
  columns: string[];
  isOneToOne: boolean;
  referencedRelation: string;
  referencedColumns: string[];
}

export interface SchemaTable {
  name: string;
  columns: SchemaColumn[];
  relationships: SchemaRelationship[];
}

export interface SchemaMetadata {
  tables: SchemaTable[];
}

/** Prefix / exact names for the Schema tab filter. Full public schema is too large to draw. */
export const SCHEMA_MODULES: { id: string; label: string; match: (name: string) => boolean }[] = [
  {
    id: 'tenant_auth',
    label: 'Tenant / auth',
    match: (name) =>
      name === 'tenants' ||
      name === 'memberships' ||
      name === 'membership_grants' ||
      name === 'modules' ||
      name === 'module_actions' ||
      name === 'tenant_modules' ||
      name === 'system_role_templates',
  },
  {
    id: 'global_reference',
    label: 'Global reference',
    match: (name) =>
      name === 'global_currencies' ||
      name === 'markets' ||
      name === 'payment_methods' ||
      name === 'bd_banks' ||
      name === 'units_of_measure',
  },
  {
    id: 'koba',
    label: 'Koba',
    match: (name) => name.startsWith('koba_'),
  },
  {
    id: 'procurement',
    label: 'Procurement',
    match: (name) =>
      name.startsWith('global_shipment') ||
      name === 'global_stocks' ||
      name === 'global_stock_types' ||
      name.startsWith('global_stock_allocation') ||
      name.startsWith('stock_location') ||
      name.startsWith('stock_movement') ||
      name.startsWith('preorder_demand') ||
      name.startsWith('batch_code_') ||
      name.startsWith('shipment_progress_') ||
      name === 'vendors' ||
      name.startsWith('cargo_compan'),
  },
  {
    id: 'products',
    label: 'Products',
    match: (name) =>
      name === 'products' ||
      name.startsWith('product_brands') ||
      name.startsWith('product_categories') ||
      name.startsWith('product_sync_snapshots') ||
      name === 'tags' ||
      name.startsWith('tag_categories') ||
      name === 'entity_tags' ||
      name === 'item_tags',
  },
  {
    id: 'product_based_costing',
    label: 'Pre-order (PBC)',
    match: (name) =>
      name.startsWith('product_based_costing_') || name.startsWith('costing_file'),
  },
  {
    id: 'bills_pays',
    label: 'Bills & pays',
    match: (name) =>
      name === 'bills' ||
      name === 'bill_lines' ||
      name === 'bill_charges' ||
      name === 'pays' ||
      name.startsWith('pay_') ||
      name.startsWith('cashbook_') ||
      name === 'profiles' ||
      name.startsWith('billing_profile') ||
      name.startsWith('invoice_brands') ||
      name.startsWith('invoice_write_offs') ||
      name.startsWith('sales_invoice_counters') ||
      name.startsWith('courier_remittance_'),
  },
  {
    id: 'after_sales',
    label: 'After-sales',
    match: (name) => name.startsWith('sales_return'),
  },
  {
    id: 'shop_order',
    label: 'Shop order',
    match: (name) =>
      name.startsWith('shop_order') ||
      name.startsWith('shop_cart') ||
      name.startsWith('shop_product_') ||
      name.startsWith('shop_categories') ||
      name.startsWith('shop_customer_group') ||
      name.startsWith('shop_pricing') ||
      name.startsWith('shop_stock_') ||
      name.startsWith('dropship_') ||
      name === 'pickup_locations' ||
      name.startsWith('customer_demand_bucket') ||
      name === 'shops',
  },
  {
    id: 'customer',
    label: 'Customer',
    match: (name) =>
      name.startsWith('customer_group') ||
      name === 'recipient_profiles' ||
      name.startsWith('customer_order_backlog'),
  },
  {
    id: 'notifications',
    label: 'Notifications',
    match: (name) => name.startsWith('notification'),
  },
  {
    id: 'investor_capital',
    label: 'Investor',
    match: (name) => name === 'investors' || name === 'shipment_investments',
  },
  {
    id: 'thrift',
    label: 'Thrift',
    match: (name) => name.startsWith('thrift_'),
  },
];

export function parseDatabaseTypes(content: string): SchemaMetadata {
  const tables: SchemaTable[] = [];
  const publicIdx = content.indexOf('  public: {\n    Tables: {');
  const viewsIdx = content.indexOf('    Views: {', publicIdx);
  if (publicIdx === -1 || viewsIdx === -1) {
    return { tables };
  }

  const tablesContent = content.substring(publicIdx + 25, viewsIdx);
  const lines = tablesContent.split('\n');

  let currentTable: Partial<SchemaTable> | null = null;
  let currentSection: 'none' | 'row' | 'relationships' = 'none';
  let currentRelBlock: string[] = [];

  function flushTable() {
    if (currentTable?.name) {
      tables.push({
        name: currentTable.name,
        columns: currentTable.columns || [],
        relationships: currentTable.relationships || [],
      });
    }
  }

  for (const line of lines) {
    const trimmed = line.trim();
    const tableMatch = line.match(/^ {6}([a-z0-9_]+):\s*\{/);
    if (tableMatch) {
      flushTable();
      currentTable = { name: tableMatch[1], columns: [], relationships: [] };
      currentSection = 'none';
      continue;
    }
    if (!currentTable) continue;

    if (trimmed.startsWith('Row: {')) {
      currentSection = 'row';
      continue;
    }
    if (trimmed.startsWith('Insert: {') || trimmed.startsWith('Update: {')) {
      currentSection = 'none';
      continue;
    }
    if (trimmed.startsWith('Relationships: [')) {
      currentSection = 'relationships';
      currentRelBlock = [];
      continue;
    }

    if (trimmed === '}' || trimmed === '},' || trimmed === ']') {
      if (currentSection === 'relationships' && currentRelBlock.length > 0) {
        parseRelBlock(currentRelBlock.join(' '), currentTable);
        currentRelBlock = [];
      }
      currentSection = 'none';
      continue;
    }

    if (currentSection === 'row') {
      const colMatch = trimmed.match(/^([a-z0-9_]+):\s*(.+)$/);
      if (colMatch) {
        let colType = colMatch[2].replace(/;$/, '').trim();
        colType = colType.replace(/Database\["public"\]\["Enums"\]\["([^"]+)"\]/g, '$1');
        currentTable.columns = currentTable.columns || [];
        currentTable.columns.push({
          name: colMatch[1],
          type: colType,
          isNullable: colType.includes('null'),
        });
      }
    }

    if (currentSection === 'relationships') {
      currentRelBlock.push(trimmed);
      if (trimmed === '},' || trimmed === '}') {
        parseRelBlock(currentRelBlock.join(' '), currentTable);
        currentRelBlock = [];
      }
    }
  }

  flushTable();
  tables.sort((a, b) => a.name.localeCompare(b.name));
  return { tables };
}

function parseRelBlock(blockStr: string, targetTable: Partial<SchemaTable>) {
  const fkMatch = blockStr.match(/foreignKeyName:\s*"([^"]+)"/);
  const colsMatch = blockStr.match(/columns:\s*\[([^\]]+)\]/);
  const oneToOneMatch = blockStr.match(/isOneToOne:\s*(true|false)/);
  const refRelMatch = blockStr.match(/referencedRelation:\s*"([^"]+)"/);
  const refColsMatch = blockStr.match(/referencedColumns:\s*\[([^\]]+)\]/);
  if (!fkMatch || !refRelMatch) return;
  targetTable.relationships = targetTable.relationships || [];
  targetTable.relationships.push({
    foreignKeyName: fkMatch[1],
    columns: colsMatch ? colsMatch[1].replace(/["'\s]/g, '').split(',').filter(Boolean) : [],
    isOneToOne: oneToOneMatch ? oneToOneMatch[1] === 'true' : false,
    referencedRelation: refRelMatch[1],
    referencedColumns: refColsMatch
      ? refColsMatch[1].replace(/["'\s]/g, '').split(',').filter(Boolean)
      : [],
  });
}

export function filterTables(
  tables: SchemaTable[],
  moduleId: string,
  search: string,
): SchemaTable[] {
  const mod = SCHEMA_MODULES.find((m) => m.id === moduleId);
  let list = mod ? tables.filter((t) => mod.match(t.name)) : tables;
  const q = search.toLowerCase().trim();
  if (q) {
    list = list.filter(
      (t) =>
        t.name.includes(q) ||
        t.columns.some((c) => c.name.includes(q) || c.type.toLowerCase().includes(q)),
    );
  }
  return list;
}

export interface ErdSlice {
  title: string;
  tables: SchemaTable[];
}

function tableGroup(name: string): 'inbound' | 'warehouse' | 'demand' | 'other' {
  if (name.startsWith('preorder_demand')) return 'demand';
  if (
    name === 'global_stocks' ||
    name.startsWith('global_stock_allocation') ||
    name.startsWith('stock_location') ||
    name.startsWith('stock_movement')
  ) {
    return 'warehouse';
  }
  if (
    name.startsWith('global_shipment') ||
    name.startsWith('batch_code_') ||
    name === 'vendors' ||
    name.startsWith('cargo_compan')
  ) {
    return 'inbound';
  }
  return 'other';
}

function rankColumn(tables: SchemaTable[]): SchemaTable[] {
  const names = new Set(tables.map((t) => t.name));
  const incoming = new Map<string, number>();
  for (const t of tables) incoming.set(t.name, 0);
  for (const table of tables) {
    for (const rel of table.relationships) {
      if (!names.has(rel.referencedRelation)) continue;
      incoming.set(table.name, (incoming.get(table.name) ?? 0) + 1);
    }
  }
  return [...tables].sort(
    (a, b) => (incoming.get(a.name) ?? 0) - (incoming.get(b.name) ?? 0) || a.name.localeCompare(b.name),
  );
}

export function keyColumns(table: SchemaTable): SchemaColumn[] {
  const fkCols = new Set(table.relationships.flatMap((r) => r.columns));
  return table.columns.filter(
    (c) => c.name === 'id' || fkCols.has(c.name) || c.name.endsWith('_id'),
  );
}

export interface ErdNodeLayout {
  table: SchemaTable;
  x: number;
  y: number;
  w: number;
  h: number;
  cols: SchemaColumn[];
}

export interface ErdEdgeLayout {
  id: string;
  fromTable: string;
  fromCol: string;
  toTable: string;
  toCol: string;
}

export interface ErdCanvasLayout {
  nodes: ErdNodeLayout[];
  edges: ErdEdgeLayout[];
  width: number;
  height: number;
}

const CARD_W = 248;
const HEADER_H = 40;
const ROW_H = 28;
const GAP_X = 72;
const GAP_Y = 28;
const PAD = 32;

export function layoutErdCanvas(tables: SchemaTable[], keysOnly: boolean): ErdCanvasLayout {
  const names = new Set(tables.map((t) => t.name));
  const depth = new Map<string, number>();
  for (const t of tables) depth.set(t.name, 0);
  let changed = true;
  let guard = 0;
  while (changed && guard++ < 24) {
    changed = false;
    for (const t of tables) {
      let d = 0;
      for (const rel of t.relationships) {
        if (!names.has(rel.referencedRelation) || rel.referencedRelation === t.name) continue;
        d = Math.max(d, (depth.get(rel.referencedRelation) ?? 0) + 1);
      }
      if (d !== depth.get(t.name)) {
        depth.set(t.name, d);
        changed = true;
      }
    }
  }
  const maxDepth = Math.max(0, ...[...depth.values()]);
  const buckets = new Map<number, SchemaTable[]>();
  for (const t of tables) {
    const col = maxDepth - (depth.get(t.name) ?? 0);
    const list = buckets.get(col) ?? [];
    list.push(t);
    buckets.set(col, list);
  }

  const nodes: ErdNodeLayout[] = [];
  let maxX = PAD;
  let maxY = PAD;
  const colCount = maxDepth + 1;
  for (let c = 0; c < colCount; c++) {
    const list = (buckets.get(c) ?? []).slice().sort((a, b) => a.name.localeCompare(b.name));
    let y = PAD;
    for (const table of list) {
      const cols = keysOnly ? keyColumns(table) : table.columns;
      const h = HEADER_H + Math.max(cols.length, 1) * ROW_H;
      const x = PAD + c * (CARD_W + GAP_X);
      nodes.push({ table, x, y, w: CARD_W, h, cols });
      y += h + GAP_Y;
      maxX = Math.max(maxX, x + CARD_W + PAD);
      maxY = Math.max(maxY, y + PAD);
    }
  }

  const byName = new Map(nodes.map((n) => [n.table.name, n]));
  const edges: ErdEdgeLayout[] = [];
  for (const node of nodes) {
    for (const rel of node.table.relationships) {
      if (!byName.has(rel.referencedRelation)) continue;
      const fromCol = rel.columns[0] ?? 'id';
      const toCol = rel.referencedColumns[0] ?? 'id';
      edges.push({
        id: `${node.table.name}.${fromCol}->${rel.referencedRelation}.${toCol}`,
        fromTable: node.table.name,
        fromCol,
        toTable: rel.referencedRelation,
        toCol,
      });
    }
  }

  return { nodes, edges, width: Math.max(maxX, 640), height: Math.max(maxY, 360) };
}

export function erdAnchor(
  node: ErdNodeLayout,
  colName: string,
  side: 'left' | 'right',
): { x: number; y: number } {
  const idx = Math.max(0, node.cols.findIndex((c) => c.name === colName));
  const y = node.y + HEADER_H + idx * ROW_H + ROW_H / 2;
  const x = side === 'left' ? node.x : node.x + node.w;
  return { x, y };
}

export function erdElbowPath(
  from: { x: number; y: number },
  to: { x: number; y: number },
): string {
  const mid = (from.x + to.x) / 2;
  return `M ${from.x} ${from.y} C ${mid} ${from.y}, ${mid} ${to.y}, ${to.x} ${to.y}`;
}

export function tablesToErdSlices(tables: SchemaTable[], moduleId: string): ErdSlice[] {
  if (tables.length === 0) return [];

  const pack = (title: string, list: SchemaTable[]): ErdSlice | null =>
    list.length ? { title, tables: rankColumn(list) } : null;

  if (moduleId === 'procurement') {
    return [
      pack(
        'Inbound (shipment → outcomes)',
        tables.filter((t) => tableGroup(t.name) === 'inbound'),
      ),
      pack(
        'Warehouse (lots, bins, moves)',
        tables.filter((t) => tableGroup(t.name) === 'warehouse'),
      ),
      pack(
        'Demand / delivery paper',
        tables.filter((t) => tableGroup(t.name) === 'demand'),
      ),
      pack(
        'Other',
        tables.filter((t) => tableGroup(t.name) === 'other'),
      ),
    ].filter((s): s is ErdSlice => s !== null);
  }

  if (moduleId === 'all') return [];

  return [{ title: 'Tables', tables: rankColumn(tables) }];
}
