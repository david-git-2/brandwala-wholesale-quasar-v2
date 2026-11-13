import type { GlobalShipmentCostBucket } from './shipmentCostEntry';

export type ShipmentApIssuePayeeBucket = {
  /** Global public.profiles.id (kernel bill party). */
  profile_id: number | null;
  ready: boolean;
  diagnostic?: string | null;
};

export type ShipmentApIssueParties = {
  books_tenant_id: number;
  from_profile_id: number | null;
  payees_by_bucket: Partial<Record<GlobalShipmentCostBucket, ShipmentApIssuePayeeBucket>>;
};

const numOrNull = (v: unknown): number | null => {
  if (v == null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : null;
};

export const parseShipmentApIssueParties = (raw: unknown): ShipmentApIssueParties | null => {
  if (!raw || typeof raw !== 'object') return null;
  const o = raw as Record<string, unknown>;
  const payeesRaw = o.payees_by_bucket;
  const payees: ShipmentApIssueParties['payees_by_bucket'] = {};
  if (payeesRaw && typeof payeesRaw === 'object') {
    for (const [key, val] of Object.entries(payeesRaw as Record<string, unknown>)) {
      if (!val || typeof val !== 'object') continue;
      const p = val as Record<string, unknown>;
      payees[key as GlobalShipmentCostBucket] = {
        profile_id: numOrNull(p.profile_id) ?? numOrNull(p.public_profile_id),
        ready: Boolean(p.ready),
        diagnostic: typeof p.diagnostic === 'string' ? p.diagnostic : null,
      };
    }
  }
  return {
    books_tenant_id: Number(o.books_tenant_id) || 0,
    from_profile_id: numOrNull(o.from_profile_id) ?? numOrNull(o.from_public_profile_id),
    payees_by_bucket: payees,
  };
};

export const isCostBucketApIssueReady = (
  parties: ShipmentApIssueParties | null | undefined,
  bucket: GlobalShipmentCostBucket,
): boolean => {
  if (parties == null || parties.from_profile_id == null) return false;
  const payee = parties.payees_by_bucket[bucket];
  return Boolean(payee?.ready && payee.profile_id != null);
};
