export interface CustomerAccount {
  id: number;
  customer_group_id: number;
  billing_profile_id: number | null;
  group_name: string;
  admin_name: string;
  email: string | null;
  phone: string | null;
  address: string | null;
  accent_color: string;
  is_active: boolean;
  member_count: number;
  wallet_available_balance: number;
  created_at: string;
}

export interface CreateCustomerInput {
  tenant_id: number;
  group_name: string;
  admin_name: string;
  admin_email?: string | null;
  phone?: string | null;
  address?: string | null;
  accent_color?: string | null;
}

export interface CustomerGroupMember {
  id: number;
  customer_group_id: number;
  name: string;
  email: string;
  role: 'admin' | 'manager' | 'staff';
  is_active: boolean;
  tenant_role_id?: number | null;
  created_at?: string;
  updated_at?: string;
}

export interface CustomerGroupMemberCreateInput {
  customer_group_id: number;
  name: string;
  email: string;
  role: 'admin' | 'manager' | 'staff';
  is_active: boolean;
  tenant_role_id?: number | null;
}

export interface CustomerGroupMemberUpdateInput {
  id: number;
  customer_group_id?: number;
  name?: string;
  email?: string;
  role?: 'admin' | 'manager' | 'staff';
  is_active?: boolean;
  tenant_role_id?: number | null;
}

export interface UpdateCustomerInput {
  id: number;
  tenant_id: number;
  customer_group_id: number;
  billing_profile_id?: number | null;
  group_name: string;
  admin_name: string;
  email?: string | null;
  phone?: string | null;
  address?: string | null;
  accent_color?: string | null;
  is_active?: boolean;
}
