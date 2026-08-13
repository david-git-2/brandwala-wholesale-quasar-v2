export type CargoCompany = {
  id: number;
  tenant_id: number | null;
  parent_tenant_id: number | null;
  name: string;
  code: string;
  is_default: boolean;
  is_active: boolean;
  phone: string | null;
  email: string | null;
  address: string | null;
  notes: string | null;
  wallet_entity_id: number | null;
  created_at?: string;
  updated_at?: string;
};

export type CargoCompanyCreateInput = {
  tenant_id: number;
  name: string;
  code: string;
  email?: string | null;
  phone?: string | null;
  address?: string | null;
  notes?: string | null;
};

export type CargoCompanyUpdateInput = {
  id: number;
  tenant_id: number;
  name: string;
  code: string;
  email?: string | null;
  phone?: string | null;
  address?: string | null;
  notes?: string | null;
  is_active?: boolean;
};
