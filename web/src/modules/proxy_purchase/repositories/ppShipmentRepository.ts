import { supabase } from 'src/boot/supabase';
import type { PpShipment, PpShipmentStatus } from '../types/ppShipment';

const VALID_STATUSES = new Set<string>(['draft', 'in_transit', 'received', 'cancelled']);

function asJsonArray(data: unknown): unknown[] {
  if (Array.isArray(data)) return data;
  if (typeof data === 'string') {
    try {
      const parsed: unknown = JSON.parse(data);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

function parseStatus(value: unknown): PpShipmentStatus {
  if (typeof value === 'string' && VALID_STATUSES.has(value)) {
    return value as PpShipmentStatus;
  }
  return 'draft';
}

function parseShipment(row: unknown): PpShipment | null {
  if (row == null || typeof row !== 'object') return null;
  const r = row as Record<string, unknown>;
  if (typeof r.id !== 'number' || typeof r.name !== 'string' || typeof r.shipment_code !== 'string') {
    return null;
  }
  return {
    id: r.id,
    tenant_id: typeof r.tenant_id === 'number' ? r.tenant_id : 0,
    name: r.name,
    shipment_code: r.shipment_code,
    status: parseStatus(r.status),
    created_at: typeof r.created_at === 'string' ? r.created_at : '',
  };
}

function parseShipments(data: unknown): PpShipment[] {
  return asJsonArray(data)
    .map(parseShipment)
    .filter((row): row is PpShipment => row != null);
}

function parseShipmentOne(data: unknown): PpShipment {
  const row = parseShipment(data);
  if (!row) throw new Error('Invalid shipment response.');
  return row;
}

const listShipments = async (tenantId: number): Promise<PpShipment[]> => {
  const { data, error } = await supabase.rpc('list_pp_shipments', {
    p_tenant_id: tenantId,
  });
  if (error) throw error;
  return parseShipments(data);
};

const createShipment = async (tenantId: number, name: string): Promise<PpShipment> => {
  const { data, error } = await supabase.rpc('create_pp_shipment', {
    p_tenant_id: tenantId,
    p_name: name,
  });
  if (error) throw error;
  return parseShipmentOne(data);
};

export const ppShipmentRepository = {
  listShipments,
  createShipment,
};