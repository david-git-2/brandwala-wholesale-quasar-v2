export interface ThriftType {
  id: number;
  tenant_id: number | null;
  is_global: boolean;
  name: string;
  description?: string | undefined;
  icon?: string | null;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}
