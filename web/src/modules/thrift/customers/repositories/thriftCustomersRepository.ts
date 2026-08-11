import { supabase } from 'src/boot/supabase';

export interface ThriftCustomerAddressParts {
  district?: string;
  thana?: string;
  post_code?: string;
}

export interface ThriftCustomerListItem {
  id: number;
  name: string;
  phone: string;
  phoneNormalized: string;
  secondaryPhone: string | null;
  address: string | null;
  addressParts: ThriftCustomerAddressParts;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ListThriftCustomersParams {
  tenantId: number;
  search?: string;
  page: number;
  pageSize: number;
}

export interface ListThriftCustomersResult {
  items: ThriftCustomerListItem[];
  total: number;
}

function mapAddressParts(raw: unknown): ThriftCustomerAddressParts {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const o = raw as Record<string, unknown>;
  const parts: ThriftCustomerAddressParts = {};
  if (typeof o.district === 'string' && o.district.trim()) parts.district = o.district.trim();
  if (typeof o.thana === 'string' && o.thana.trim()) parts.thana = o.thana.trim();
  if (typeof o.post_code === 'string' && o.post_code.trim()) parts.post_code = o.post_code.trim();
  return parts;
}

function mapRow(row: Record<string, unknown>): ThriftCustomerListItem {
  return {
    id: Number(row.id),
    name: String(row.name ?? ''),
    phone: String(row.phone ?? ''),
    phoneNormalized: String(row.phone_normalized ?? ''),
    secondaryPhone: (row.secondary_phone as string | null) ?? null,
    address: (row.address as string | null) ?? null,
    addressParts: mapAddressParts(row.address_parts),
    notes: (row.notes as string | null) ?? null,
    createdAt: String(row.created_at ?? ''),
    updatedAt: String(row.updated_at ?? ''),
  };
}

export const thriftCustomersRepository = {
  async list(params: ListThriftCustomersParams): Promise<ListThriftCustomersResult> {
    const page = Math.max(1, params.page);
    const pageSize = Math.min(100, Math.max(1, params.pageSize));
    const from = (page - 1) * pageSize;
    const to = from + pageSize - 1;

    let query = supabase
      .from('thrift_customers')
      .select(
        'id, name, phone, phone_normalized, secondary_phone, address, address_parts, notes, created_at, updated_at',
        { count: 'exact' },
      )
      .eq('tenant_id', params.tenantId)
      .order('updated_at', { ascending: false })
      .range(from, to);

    const needle = (params.search ?? '').trim().replace(/[%_(),]/g, ' ');
    if (needle) {
      const digits = needle.replace(/\D/g, '');
      const orParts = [`phone.ilike.%${needle}%`, `name.ilike.%${needle}%`];
      if (digits) orParts.push(`phone_normalized.ilike.%${digits}%`);
      query = query.or(orParts.join(','));
    }

    const { data, error, count } = await query;
    if (error) throw error;

    return {
      items: (data ?? []).map((row) => mapRow(row as Record<string, unknown>)),
      total: count ?? 0,
    };
  },
};
