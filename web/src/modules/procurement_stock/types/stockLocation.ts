export type StockLocationKind =
  | 'warehouse'
  | 'zone'
  | 'shelf'
  | 'level'
  | 'bin'
  | 'returns';

export interface StockLocation {
  id: number;
  parent_tenant_id: number;
  code: string;
  name: string;
  kind: StockLocationKind;
  parent_location_id: number | null;
  is_default: boolean;
  is_pickable: boolean;
  sort_order: number;
  is_active: boolean;
}

export interface StockLocationTreeNode extends StockLocation {
  children: StockLocationTreeNode[];
  depth: number;
  isLeaf: boolean;
}

export interface UpsertStockLocationPayload {
  id?: number | null;
  code: string;
  name: string;
  kind: StockLocationKind;
  parent_location_id: number | null;
  sort_order: number;
  is_pickable: boolean;
  is_active: boolean;
  is_default: boolean;
}
