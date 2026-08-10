import { supabase } from 'src/boot/supabase';

export interface ThriftCourierProvider {
  id: number;
  tenantId: number | null;
  code: string;
  name: string;
  countryCode: string;
  isSystem: boolean;
  isActive: boolean;
  sortOrder: number;
  meta: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface ThriftCourierProviderInput {
  name: string;
  code?: string | undefined;
  sortOrder?: number | undefined;
  isActive?: boolean | undefined;
  meta?: Record<string, unknown> | undefined;
}

function slugifyCode(name: string): string {
  return (
    name
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .slice(0, 64) || `courier_${Date.now()}`
  );
}

function mapRow(row: any): ThriftCourierProvider {
  return {
    id: Number(row.id),
    tenantId: row.tenant_id == null ? null : Number(row.tenant_id),
    code: String(row.code ?? ''),
    name: String(row.name ?? ''),
    countryCode: String(row.country_code ?? 'BD'),
    isSystem: Boolean(row.is_system),
    isActive: Boolean(row.is_active),
    sortOrder: Number(row.sort_order ?? 100),
    meta: (row.meta && typeof row.meta === 'object' ? row.meta : {}) as Record<
      string,
      unknown
    >,
    createdAt: String(row.created_at ?? ''),
    updatedAt: String(row.updated_at ?? ''),
  };
}

export const thriftCourierRepository = {
  async listForPicker(tenantId: number): Promise<ThriftCourierProvider[]> {
    const { data, error } = await supabase
      .from('thrift_courier_providers')
      .select('*')
      .eq('is_active', true)
      .or(`tenant_id.is.null,tenant_id.eq.${tenantId}`)
      .order('is_system', { ascending: false })
      .order('sort_order', { ascending: true })
      .order('name', { ascending: true });

    if (error) throw error;
    return (data || []).map(mapRow);
  },

  async listForManage(tenantId: number): Promise<ThriftCourierProvider[]> {
    const { data, error } = await supabase
      .from('thrift_courier_providers')
      .select('*')
      .or(`tenant_id.is.null,tenant_id.eq.${tenantId}`)
      .order('is_system', { ascending: false })
      .order('sort_order', { ascending: true })
      .order('name', { ascending: true });

    if (error) throw error;
    return (data || []).map(mapRow);
  },

  async createCustom(
    tenantId: number,
    input: ThriftCourierProviderInput,
  ): Promise<ThriftCourierProvider> {
    const name = input.name.trim();
    if (!name) throw new Error('Courier name is required');
    const code = (input.code?.trim() || slugifyCode(name)).toLowerCase();

    const { data, error } = await supabase
      .from('thrift_courier_providers')
      .insert({
        tenant_id: tenantId,
        code,
        name,
        country_code: 'BD',
        is_system: false,
        is_active: input.isActive !== false,
        sort_order: input.sortOrder ?? 200,
        meta: input.meta ?? {},
      } as any)
      .select('*')
      .single();

    if (error) throw error;
    return mapRow(data);
  },

  async updateCustom(
    tenantId: number,
    id: number,
    input: Partial<ThriftCourierProviderInput>,
  ): Promise<ThriftCourierProvider> {
    const patch: Record<string, unknown> = {};
    if (input.name != null) patch.name = input.name.trim();
    if (input.code != null) patch.code = input.code.trim().toLowerCase();
    if (input.sortOrder != null) patch.sort_order = input.sortOrder;
    if (input.isActive != null) patch.is_active = input.isActive;
    if (input.meta != null) patch.meta = input.meta;

    const { data, error } = await supabase
      .from('thrift_courier_providers')
      .update(patch as any)
      .eq('id', id)
      .eq('tenant_id', tenantId)
      .eq('is_system', false)
      .select('*')
      .single();

    if (error) throw error;
    return mapRow(data);
  },

  async deleteCustom(tenantId: number, id: number): Promise<void> {
    const { error } = await supabase
      .from('thrift_courier_providers')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenantId)
      .eq('is_system', false);

    if (error) throw error;
  },
};
