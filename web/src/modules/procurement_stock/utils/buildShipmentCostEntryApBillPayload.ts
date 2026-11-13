import type { GlobalShipment } from '../repositories/globalShipmentRepository';
import type {
  BuildShipmentCostEntryBillPayloadResult,
  RpcCreateBillPayload,
  ShipmentCostEntryBillPayloadSource,
} from '../types/shipmentCostEntryApBillPayload';

const roundMoney = (value: number): number => Math.round(value * 100) / 100;

/** Mirrors `_build_shipment_ap_cost_entry_paper` description fallback. */
export const shipmentCostEntryApLineDescription = (
  entry: Pick<
    ShipmentCostEntryBillPayloadSource,
    'description' | 'metadata' | 'cost_component'
  >,
): string => {
  const meta = entry.metadata ?? {};
  const fromMeta =
    typeof meta.description === 'string' ? meta.description.trim() : '';
  const fromRow = entry.description?.trim() ?? '';
  if (fromRow) return fromRow;
  if (fromMeta) return fromMeta;
  const component = String(entry.cost_component ?? 'subtotal');
  return component
    .split('_')
    .map((w) => (w ? w.charAt(0).toUpperCase() + w.slice(1) : w))
    .join(' ');
};

export const resolveShipmentCostEntryCurrencyCode = (
  currencyId: number | null | undefined,
  currencyCodeById: ReadonlyMap<number, string>,
  shipment: Pick<
    GlobalShipment,
    'shipment_cost_currency_id' | 'shipment_purchase_currency_id'
  >,
  fallback = 'BDT',
): string => {
  const resolvedId =
    currencyId ??
    shipment.shipment_cost_currency_id ??
    shipment.shipment_purchase_currency_id ??
    null;
  if (resolvedId != null) {
    const code = currencyCodeById.get(resolvedId);
    if (code) return code.toUpperCase();
  }
  return fallback;
};

export const buildShipmentCostEntryApBillPayload = (params: {
  booksTenantId: number;
  shipment: Pick<GlobalShipment, 'id' | 'name' | 'tenant_id'>;
  entry: ShipmentCostEntryBillPayloadSource;
  currencyCode: string;
  fromProfileId: number | null;
  toProfileId: number | null;
  diagnostics?: string[];
}): BuildShipmentCostEntryBillPayloadResult => {
  const diagnostics = [...(params.diagnostics ?? [])];
  const amount = roundMoney(Number(params.entry.amount));
  if (!Number.isFinite(amount) || amount <= 0) {
    diagnostics.push('amount must be greater than zero');
  }

  const apKind = params.entry.cost_bucket;
  const kindLabel = apKind.charAt(0).toUpperCase() + apKind.slice(1);
  const entryId = params.entry.id;
  const sourceKey = apKind;
  const description = shipmentCostEntryApLineDescription(params.entry);

  const line = {
    item_kind: 'charge' as const,
    description,
    quantity: 1,
    unit_price: amount,
    line_total: amount,
    meta: { cost_entry_id: entryId },
  };

  const apPaper = {
    paper: apKind,
    lines: [
      {
        description,
        amount,
        currency_code: params.currencyCode,
        currency_symbol: params.currencyCode,
        cost_entry_id: entryId,
      },
    ],
    foreign_total: amount,
    currency_code: params.currencyCode,
    currency_symbol: params.currencyCode,
    bdt_amount:
      params.currencyCode === 'BDT' || params.currencyCode === '' ? amount : null,
    cost_entry_id: entryId,
    mixed_currencies: false,
  };

  if (params.fromProfileId == null) {
    diagnostics.push('from_profile_id (tenant self) is missing');
  }
  if (params.toProfileId == null) {
    diagnostics.push('to_profile_id (vendor/cargo/local payee) is missing');
  }

  const payload: RpcCreateBillPayload = {
    tenant_id: params.booksTenantId,
    kind: 'shipment_cost_ap',
    source_entity: 'public.global_shipments',
    source_type: 'shipment_cost',
    source_id: String(params.shipment.id),
    source_key: sourceKey,
    idempotency_key: `shipment-${params.shipment.id}-bucket-${apKind}-issue`,
    currency_code: params.currencyCode,
    from_profile_id: params.fromProfileId,
    to_profile_id: params.toProfileId,
    counterparty_profile_id: params.toProfileId,
    auto_issue: true,
    note: `Shipment ${params.shipment.name || params.shipment.id} — ${kindLabel} AP (${sourceKey})`,
    meta: {
      ap_kind: apKind,
      shipment_id: params.shipment.id,
      ap_paper: apPaper,
    },
    lines: [line],
  };

  return { payload, diagnostics };
};
