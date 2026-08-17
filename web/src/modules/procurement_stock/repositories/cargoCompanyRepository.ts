import { supabase } from 'src/boot/supabase';
import type {
  CargoCompany,
  CargoCompanyCreateInput,
  CargoCompanyUpdateInput,
} from '../types/cargoCompany';

const db = supabase as any;

const normalizeCode = (code: string) => code.trim().toUpperCase();

const listCargoCompanies = async (
  tenantId: number,
  includeInactive = true,
): Promise<CargoCompany[]> => {
  let query = db
    .from('cargo_companies')
    .select('*')
    .or(`parent_tenant_id.eq.${tenantId},tenant_id.eq.${tenantId}`)
    .order('is_default', { ascending: false })
    .order('name', { ascending: true });

  if (!includeInactive) {
    query = query.eq('is_active', true);
  }

  const { data, error } = await query;
  if (error) throw error;
  return (data as CargoCompany[] | null) ?? [];
};

const isCodeAvailable = async (
  code: string,
  tenantId: number,
  excludeId?: number | null,
): Promise<boolean> => {
  let query = db
    .from('cargo_companies')
    .select('id', { count: 'exact', head: true })
    .eq('tenant_id', tenantId)
    .eq('code', normalizeCode(code));

  if (typeof excludeId === 'number') {
    query = query.neq('id', excludeId);
  }

  const { count, error } = await query;
  if (error) throw error;
  return (count ?? 0) === 0;
};

const createCargoCompany = async (payload: CargoCompanyCreateInput): Promise<CargoCompany> => {
  const { data, error } = await db.rpc('create_cargo_company_with_wallet', {
    p_tenant_id: payload.tenant_id,
    p_name: payload.name.trim(),
    p_code: normalizeCode(payload.code),
    p_email: payload.email?.trim() || null,
    p_phone: payload.phone?.trim() || null,
    p_address: payload.address?.trim() || null,
    p_notes: payload.notes?.trim() || null,
  });
  if (error) throw error;
  const row = (data as { cargo_company?: CargoCompany } | null)?.cargo_company;
  if (!row) throw new Error('Cargo company was not created.');
  return row;
};

const updateCargoCompany = async (payload: CargoCompanyUpdateInput): Promise<CargoCompany> => {
  const { data, error } = await db
    .from('cargo_companies')
    .update({
      name: payload.name.trim(),
      code: normalizeCode(payload.code),
      email: payload.email?.trim() || null,
      phone: payload.phone?.trim() || null,
      address: payload.address?.trim() || null,
      notes: payload.notes?.trim() || null,
      ...(typeof payload.is_active === 'boolean' ? { is_active: payload.is_active } : {}),
    })
    .eq('id', payload.id)
    .eq('tenant_id', payload.tenant_id)
    .select('*')
    .single();

  if (error) throw error;
  return data as CargoCompany;
};

const deleteCargoCompany = async (id: number, tenantId: number): Promise<void> => {
  const { data: row, error: fetchError } = await db
    .from('cargo_companies')
    .select('id, is_default, code')
    .eq('id', id)
    .eq('tenant_id', tenantId)
    .maybeSingle();

  if (fetchError) throw fetchError;
  if (!row) throw new Error('Cargo company not found.');
  if (row.is_default || String(row.code).toUpperCase() === 'DEFAULT') {
    throw new Error('Cannot delete the default cargo company.');
  }

  const { error } = await db.from('cargo_companies').delete().eq('id', id).eq('tenant_id', tenantId);
  if (error) throw error;
};

const ensureDefaultCargoCompany = async (tenantId: number): Promise<number> => {
  const { data, error } = await db.rpc('ensure_default_cargo_company', {
    p_tenant_id: tenantId,
  });
  if (error) throw error;
  return data as number;
};

export const cargoCompanyRepository = {
  listCargoCompanies,
  isCodeAvailable,
  createCargoCompany,
  updateCargoCompany,
  deleteCargoCompany,
  ensureDefaultCargoCompany,
};
