import { shipmentApKindLabel } from 'src/modules/procurement_stock/constants/shipmentApBuckets';
import { resolveShipmentApBillKind } from 'src/modules/procurement_stock/repositories/shipmentApBillsRepository';

const SHIPMENT_BUCKET_SHORT: Record<string, string> = {
  vendor: 'Vendor',
  cargo: 'Cargo',
  local: 'Local',
  material: 'Material',
  freight: 'Freight',
  customs: 'Customs',
  handling: 'Handling',
  finance: 'Finance',
  other: 'Other',
};

function bucketShortLabel(kind: string | null | undefined): string | null {
  if (!kind) return null;
  return SHIPMENT_BUCKET_SHORT[kind] ?? shipmentApKindLabel(kind).replace(/ AP$/i, '');
}

/** User-facing label for kernel `source_type` (not raw enum). */
export function formatBillKernelSourceType(sourceType: string | null | undefined): string | null {
  const t = sourceType?.trim();
  if (!t) return null;
  if (t === 'shipment_cost') return null;
  if (t === 'shop_order') return 'Shop order';
  if (t === 'compose') return 'Desk compose';
  return t.replace(/_/g, ' ');
}

/**
 * Human label for `source_key` (e.g. `material:GBP:abc` → `Material · GBP`).
 */
export function formatBillKernelSourceKey(
  sourceType: string | null | undefined,
  sourceKey: string | null | undefined,
  apKind?: string | null,
): string | null {
  const key = sourceKey?.trim();
  const kindFallback = apKind?.trim();
  if (!key && !kindFallback) return null;

  if (sourceType === 'shipment_cost') {
    const kind = resolveShipmentApBillKind(key, kindFallback);
    const parts = key?.split(':') ?? [];
    const currency = parts[1]?.trim().toUpperCase();
    const bucket = bucketShortLabel(kind ?? parts[0] ?? kindFallback);
    if (bucket && currency && currency.length === 3) return `${bucket} · ${currency}`;
    if (bucket) return bucket;
    return kindFallback ? shipmentApKindLabel(kindFallback) : null;
  }

  if (!key) return kindFallback ?? null;

  const parts = key.split(':');
  if (parts.length >= 3 && /^[a-f0-9]{6,}$/i.test(parts[parts.length - 1] ?? '')) {
    const head = parts.slice(0, -1).map((p, i) => (i === 0 ? bucketShortLabel(p) ?? p : p));
    return head.filter(Boolean).join(' · ');
  }

  return key;
}

/** Fallback when no resolved entity name is available yet. */
export function formatBillKernelSourceEntityFallback(
  sourceType: string | null | undefined,
  sourceId: string | null | undefined,
): string | null {
  const id = sourceId?.trim();
  if (!id) return null;
  if (sourceType === 'shipment_cost') return null;
  if (sourceType === 'shop_order') return `Order ${id}`;
  return null;
}
