import { supabase } from 'src/boot/supabase';
import type { GlobalShipment } from './globalShipmentRepository';
import type { BuildShipmentCostEntryBillPayloadResult } from '../types/shipmentCostEntryApBillPayload';
import type { GlobalShipmentCostBucket } from '../types/shipmentCostEntry';
import {
  buildShipmentCostEntryApBillPayload,
  resolveShipmentCostEntryCurrencyCode,
} from '../utils/buildShipmentCostEntryApBillPayload';
import type { ShipmentCostEntryBillPayloadSource } from '../types/shipmentCostEntryApBillPayload';

const db = supabase as any;

type ProfilePartyType = 'vendor' | 'cargo' | 'tenant' | 'company';

async function loadTenantName(tenantId: number): Promise<string> {
  const { data, error } = await db.from('tenants').select('name').eq('id', tenantId).maybeSingle();
  if (error) throw error;
  return data?.name?.trim() || `Tenant #${tenantId}`;
}

async function loadVendorName(vendorId: number): Promise<string> {
  const { data, error } = await db.from('vendors').select('name').eq('id', vendorId).maybeSingle();
  if (error) throw error;
  return data?.name?.trim() || `Vendor #${vendorId}`;
}

async function loadCargoName(cargoCompanyId: number): Promise<string> {
  const { data, error } = await db
    .from('cargo_companies')
    .select('name')
    .eq('id', cargoCompanyId)
    .maybeSingle();
  if (error) throw error;
  return data?.name?.trim() || `Cargo #${cargoCompanyId}`;
}

async function ensureProfileForParty(
  tenantId: number,
  profileType: ProfilePartyType,
  subjectId: number,
  name: string,
): Promise<number> {
  const existing = await findProfileId(tenantId, profileType, subjectId);
  if (existing != null) return existing;

  const { data, error } = await db.rpc('upsert_profile_for_party', {
    p_tenant_id: tenantId,
    p_profile_type: profileType,
    p_subject_id: subjectId,
    p_name: name,
    p_phone_country_code: '+880',
    p_is_active: true,
  });
  if (error) throw error;
  const id = Number(data);
  if (!Number.isFinite(id) || id <= 0) {
    throw new Error(`Could not provision ${profileType} profile`);
  }
  return id;
}

async function resolveFromProfileId(booksTenantId: number): Promise<number | null> {
  const tenantMirror = await findProfileId(booksTenantId, 'tenant', booksTenantId);
  if (tenantMirror != null) return tenantMirror;

  const { data, error } = await db
    .from('profiles')
    .select('id')
    .eq('tenant_id', booksTenantId)
    .eq('is_tenant_self', true)
    .order('id', { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  if (data?.id != null) return Number(data.id);

  try {
    const name = await loadTenantName(booksTenantId);
    return await ensureProfileForParty(booksTenantId, 'tenant', booksTenantId, name);
  } catch {
    return null;
  }
}

/**
 * Payee profile per bucket — matches `issue_shipment_cost_entry_ap` (vendor / cargo / local company).
 */
async function resolveToProfileId(
  entry: ShipmentCostEntryBillPayloadSource,
  shipment: GlobalShipment,
): Promise<{ id: number | null; diagnostic: string | null }> {
  const booksTenantId = shipment.tenant_id;
  const payee = payeeSubjectForBucket(entry.cost_bucket, shipment);

  if (payee == null) {
    if (entry.cost_bucket === 'material') {
      return { id: null, diagnostic: 'shipment vendor_id is required for material AP' };
    }
    if (entry.cost_bucket === 'freight' || entry.cost_bucket === 'customs') {
      return { id: null, diagnostic: 'shipment cargo_company_id is required for freight/customs AP' };
    }
    return { id: null, diagnostic: `no payee mapping for bucket ${entry.cost_bucket}` };
  }

  try {
    const name =
      payee.profileType === 'vendor'
        ? shipment.vendor_name?.trim() || (await loadVendorName(payee.subjectId))
        : payee.profileType === 'cargo'
          ? await loadCargoName(payee.subjectId)
          : await loadTenantName(booksTenantId);

    const displayName =
      payee.profileType === 'company' ? 'Local opex' : name;

    const id = await ensureProfileForParty(
      booksTenantId,
      payee.profileType,
      payee.subjectId,
      displayName,
    );
    return { id, diagnostic: null };
  } catch (err: unknown) {
    return {
      id: null,
      diagnostic: (err as Error).message || `Could not resolve ${payee.profileType} profile`,
    };
  }
}

async function findProfileId(
  tenantId: number,
  profileType: ProfilePartyType,
  subjectId: number,
): Promise<number | null> {
  const { data, error } = await db
    .from('profiles')
    .select('id')
    .eq('tenant_id', tenantId)
    .eq('profile_type', profileType)
    .eq('subject_id', subjectId)
    .eq('is_active', true)
    .order('id', { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return data?.id != null ? Number(data.id) : null;
}

function payeeSubjectForBucket(
  bucket: GlobalShipmentCostBucket,
  shipment: Pick<GlobalShipment, 'vendor_id' | 'cargo_company_id' | 'tenant_id'>,
): { profileType: ProfilePartyType; subjectId: number } | null {
  switch (bucket) {
    case 'material':
      if (shipment.vendor_id == null) return null;
      return { profileType: 'vendor', subjectId: shipment.vendor_id };
    case 'freight':
    case 'customs':
      if (shipment.cargo_company_id == null) return null;
      return { profileType: 'cargo', subjectId: shipment.cargo_company_id };
    default:
      return { profileType: 'company', subjectId: shipment.tenant_id };
  }
}

/**
 * Resolves profiles + builds `rpc_create_bill` payload for a single cost entry (preview / issue).
 */
const buildRpcCreateBillPayloadForCostEntry = async (
  shipment: GlobalShipment,
  entry: ShipmentCostEntryBillPayloadSource,
  currencyCodeById: ReadonlyMap<number, string>,
): Promise<BuildShipmentCostEntryBillPayloadResult> => {
  const booksTenantId = shipment.tenant_id;
  const diagnostics: string[] = [];

  const fromProfileId = await resolveFromProfileId(booksTenantId);
  if (fromProfileId == null) {
    diagnostics.push(
      `no tenant self profile (profile_type=tenant, subject_id=${booksTenantId})`,
    );
  }

  const toResolved = await resolveToProfileId(entry, shipment);
  const toProfileId = toResolved.id;
  if (toResolved.diagnostic) {
    diagnostics.push(toResolved.diagnostic);
  }

  const currencyCode = resolveShipmentCostEntryCurrencyCode(
    entry.currency_id,
    currencyCodeById,
    shipment,
  );

  return buildShipmentCostEntryApBillPayload({
    booksTenantId,
    shipment,
    entry,
    currencyCode,
    fromProfileId,
    toProfileId,
    diagnostics,
  });
};

export const shipmentCostEntryBillPayloadRepository = {
  buildRpcCreateBillPayloadForCostEntry,
};
