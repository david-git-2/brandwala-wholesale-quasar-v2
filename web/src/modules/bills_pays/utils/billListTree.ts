import type { BillListRow } from '../types/billList';

export type BillListTreeNode = {
  row: BillListRow;
  children: BillListRow[];
};

const isNestedNote = (row: BillListRow, parentIds: Set<number>) => {
  const kind = row.document_kind ?? 'standard';
  if (kind === 'standard') return false;
  const parentId = row.parent_bill_id;
  return parentId != null && parentIds.has(parentId);
};

/** Group credit/debit notes under their parent bill when both appear in the loaded page. */
export function buildBillListTree(rows: BillListRow[]): BillListTreeNode[] {
  if (!rows.length) return [];

  const parentIds = new Set(rows.map((r) => r.id));
  const childIds = new Set<number>();
  const childrenByParent = new Map<number, BillListRow[]>();

  for (const row of rows) {
    if (!isNestedNote(row, parentIds)) continue;
    const parentId = row.parent_bill_id as number;
    childIds.add(row.id);
    const list = childrenByParent.get(parentId) ?? [];
    list.push(row);
    childrenByParent.set(parentId, list);
  }

  for (const kids of childrenByParent.values()) {
    kids.sort((a, b) => b.id - a.id);
  }

  const nodes: BillListTreeNode[] = [];
  for (const row of rows) {
    if (childIds.has(row.id)) continue;
    nodes.push({
      row,
      children: childrenByParent.get(row.id) ?? [],
    });
  }
  return nodes;
}
