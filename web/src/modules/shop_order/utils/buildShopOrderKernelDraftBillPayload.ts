import type { Json } from 'src/types/database.types';

export type ShopOrderKernelDraftBillInput = {
  booksTenantId: number;
  orderId: number;
  customerProfileId: number;
  tenantMirrorProfileId: number;
  sourceKey: string;
  recipientName?: string | null;
  recipientPhone?: string | null;
  recipientAddress?: string | null;
};

/** `rpc_create_bill` payload for an empty wholesale draft linked to a catalog shop order. */
export function buildShopOrderKernelDraftBillPayload(
  input: ShopOrderKernelDraftBillInput,
): Json {
  const trim = (v: string | null | undefined) => {
    const t = v?.trim();
    return t ? t : undefined;
  };

  return {
    tenant_id: input.booksTenantId,
    kind: 'sales_invoice_wholesale',
    currency_code: 'BDT',
    from_profile_id: input.customerProfileId,
    to_profile_id: input.tenantMirrorProfileId,
    counterparty_profile_id: input.customerProfileId,
    source_entity: 'public.shop_orders',
    source_type: 'shop_order',
    source_id: String(input.orderId),
    source_key: input.sourceKey,
    auto_issue: false,
    lines: [],
    meta: {
      shop_order_id: input.orderId,
      delivery_kind: 'take',
      subtotal_amount: 0,
      recipient_name: trim(input.recipientName),
      recipient_phone: trim(input.recipientPhone),
      recipient_address: trim(input.recipientAddress),
    },
  } as Json;
}