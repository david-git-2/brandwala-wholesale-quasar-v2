export interface TagCategory {
  id: number;
  module_key: string;
  code: string;
  name: string;
  cardinality: 'single' | 'many';
  is_system: boolean;
  tenant_id: number | null;
  sort_order: number | null;
  is_active: boolean;
  created_at?: string;
}

export interface TagMetadata {
  maps_to_availability?: 'sellable' | 'unsellable';
  [key: string]: unknown;
}

export interface Tag {
  id: number;
  category_id: number | null;
  slug: string;
  name: string;
  color: string | null;
  metadata: TagMetadata;
  sort_order: number | null;
  is_system: boolean;
  is_active: boolean;
  tenant_id: number | null;
  group_name?: string | null;
  type?: string | null;
}
