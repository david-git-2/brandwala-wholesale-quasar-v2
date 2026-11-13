import type { Json } from 'src/types/database.types';
import type { SalesInvoiceFromPayloadInput, SalesInvoicePayloadItem } from '../repositories/billsRepository';

function lineItemKind(item: SalesInvoicePayloadItem): string {
  if (item.global_stock_id != null && item.global_stock_id > 0) return 'stock';
  return 'charge';
}

function mapLine(item: SalesInvoicePayloadItem, currencyCode: string) {
  const qty = item.quantity ?? 1;
  const price = item.sell_price_amount ?? 0;
  const lineTotal =
    item.line_total_amount ?? Math.max(0, qty * price - (item.line_discount_amount ?? 0));
  return {
    item_kind: lineItemKind(item),
    description: item.name_snapshot ?? 'Line',
    quantity: qty,
    unit_price: price,
    line_total: lineTotal,
    product_id: item.product_id ?? undefined,
    global_stock_id: item.global_stock_id ?? undefined,
    shipment_item_id: item.shipment_item_id ?? undefined,
    meta: {
      currency_code: currencyCode,
      ...(item.line_meta ?? {}),
    },
  };
}

function resolveKind(invoiceType: string): string {
  if (invoiceType === 'ap') return 'shipment_cost_ap';
  if (invoiceType === 'retail') return 'sales_invoice_retail';
  return 'sales_invoice_wholesale';
}

export function composePayloadHasStock(payload: SalesInvoiceFromPayloadInput): boolean {
  return payload.items.some(
    (i) => i.global_stock_id != null && Number(i.global_stock_id) > 0,
  );
}

export function buildKernelCreateBillPayload(
  tenantId: number,
  payload: SalesInvoiceFromPayloadInput,
  options?: { autoIssue?: boolean },
): Json {
  const inv = payload.invoice;
  const invoiceType = inv.invoice_type ?? 'wholesale';
  const kind = resolveKind(invoiceType);
  const currencyCode = 'BDT';

  const channelMeta = (inv.channel_meta ?? {}) as Record<string, unknown>;
  const letterheadProfileId = channelMeta.letterhead_profile_id;

  let fromProfileId: number | undefined;
  let toProfileId: number | undefined;
  if (invoiceType === 'ap') {
    fromProfileId = inv.profile_id > 0 ? inv.profile_id : undefined;
    toProfileId =
      typeof letterheadProfileId === 'number' ? letterheadProfileId : undefined;
  } else {
    toProfileId = inv.profile_id > 0 ? inv.profile_id : undefined;
    fromProfileId =
      typeof letterheadProfileId === 'number' ? letterheadProfileId : undefined;
  }

  const meta: Record<string, unknown> = {
    channel_meta: channelMeta,
    ...(invoiceType === 'retail' && inv.retail_billing_mode
      ? { retail_billing_mode: inv.retail_billing_mode }
      : {}),
    ...(invoiceType === 'ap'
      ? { ap_kind: 'desk_compose', shipment_id: 0, delivery_kind: 'take' }
      : { delivery_kind: channelMeta.delivery_kind ?? 'take' }),
  };

  const lines = payload.items.map((item) => mapLine(item, currencyCode));

  return {
    tenant_id: tenantId,
    kind,
    invoice_date: inv.invoice_date,
    due_date: inv.due_date ?? null,
    from_profile_id: fromProfileId,
    to_profile_id: toProfileId,
    counterparty_profile_id: inv.profile_id > 0 ? inv.profile_id : null,
    currency_code: currencyCode,
    note: inv.note ?? null,
    source_type: 'compose',
    source_id: null,
    source_key: null,
    meta,
    lines,
    auto_issue: options?.autoIssue === true,
  } as Json;
}

export function buildKernelUpdateDraftPayload(
  payload: SalesInvoiceFromPayloadInput,
): Json {
  const inv = payload.invoice;
  const currencyCode = 'BDT';
  const lines = payload.items.map((item) => mapLine(item, currencyCode));
  return {
    invoice_date: inv.invoice_date,
    due_date: inv.due_date ?? null,
    note: inv.note ?? null,
    currency_code: currencyCode,
    lines,
    meta: {
      channel_meta: inv.channel_meta ?? {},
    },
  } as Json;
}
