export interface ThriftCategory {
  id: number;
  tenant_id: number | null;
  is_global: boolean;
  name: string;
  description?: string | undefined;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}
