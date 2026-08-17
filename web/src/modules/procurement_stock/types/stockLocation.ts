export type StockLocationKind = 'shelf' | 'slot' | 'box' | 'returns';

export interface StockLocation {
  id: number;
  parent_tenant_id: number;
  parent_location_id: number | null;
  code: string;
  name: string;
  kind: StockLocationKind;
  is_default: boolean;
  is_pickable: boolean;
  sort_order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface UpsertStockLocationPayload {
  code: string;
  name: string;
  kind: StockLocationKind;
  parent_location_id?: number | null;
  is_pickable: boolean;
  sort_order: number;
  is_active: boolean;
  is_default?: boolean;
  id?: number | null;
}

export interface StockLocationTreeNode extends StockLocation {
  children: StockLocationTreeNode[];
  depth: number;
  isLeaf: boolean;
}
