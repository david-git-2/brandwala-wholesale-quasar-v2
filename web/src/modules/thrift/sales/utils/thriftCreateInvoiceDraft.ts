const DRAFT_VERSION = 1 as const;

export type ThriftCreateInvoiceDraftForm = {
  saleChannel: 'IN_STORE' | 'ONLINE';
  customerName: string;
  customerPhone: string;
  customerSecondaryPhone: string;
  customerAddress: string;
  district: string;
  thana: string;
  postCode: string;
  date: string;
  notes: string;
  courierProviderId: number | null;
  trackingId: string;
  courierAmount: number;
  courierPaidBy: 'CUSTOMER' | 'SHOP' | null;
  packingAmount: number;
  packingPaidBy: 'CUSTOMER' | 'SHOP' | null;
  codFeeAmount: number;
  codFeePaidBy: 'CUSTOMER' | 'SHOP' | null;
};

export type ThriftCreateInvoiceDraftLine = {
  stockId: number;
  name: string;
  brandName?: string | undefined;
  barcode: string;
  category: string;
  type?: string | undefined;
  color?: string | undefined;
  size?: string | undefined;
  condition?: string | undefined;
  shelfCode?: string | undefined;
  boxName?: string | undefined;
  imageUrl?: string | undefined;
  shipmentId: number;
  shipmentName?: string | undefined;
  sellPrice: number;
  discountAmount: number;
  quantity: number;
  availableQuantity: number;
};

export type ThriftCreateInvoiceDraft = {
  v: typeof DRAFT_VERSION;
  updatedAt: string;
  form: ThriftCreateInvoiceDraftForm;
  items: ThriftCreateInvoiceDraftLine[];
  onlineStep: number;
};

function draftKey(tenantId: number): string {
  return `thrift:create-invoice-draft:v${DRAFT_VERSION}:${tenantId}`;
}

export function readThriftCreateInvoiceDraft(
  tenantId: number,
): ThriftCreateInvoiceDraft | null {
  if (!tenantId || typeof localStorage === 'undefined') return null;
  try {
    const raw = localStorage.getItem(draftKey(tenantId));
    if (!raw) return null;
    const parsed = JSON.parse(raw) as ThriftCreateInvoiceDraft;
    if (!parsed || parsed.v !== DRAFT_VERSION || !parsed.form) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function writeThriftCreateInvoiceDraft(
  tenantId: number,
  draft: Omit<ThriftCreateInvoiceDraft, 'v' | 'updatedAt'>,
): void {
  if (!tenantId || typeof localStorage === 'undefined') return;
  const payload: ThriftCreateInvoiceDraft = {
    v: DRAFT_VERSION,
    updatedAt: new Date().toISOString(),
    form: draft.form,
    items: draft.items,
    onlineStep: draft.onlineStep,
  };
  localStorage.setItem(draftKey(tenantId), JSON.stringify(payload));
}

export function clearThriftCreateInvoiceDraft(tenantId: number): void {
  if (!tenantId || typeof localStorage === 'undefined') return;
  localStorage.removeItem(draftKey(tenantId));
}

export function thriftCreateInvoiceDraftHasContent(
  draft: Pick<ThriftCreateInvoiceDraft, 'form' | 'items'>,
): boolean {
  if (draft.items.length > 0) return true;
  const f = draft.form;
  return Boolean(
    f.customerName.trim() ||
      f.customerPhone.trim() ||
      f.customerAddress.trim() ||
      f.district.trim() ||
      f.notes.trim() ||
      f.courierProviderId ||
      f.trackingId.trim() ||
      f.courierAmount > 0 ||
      f.packingAmount > 0 ||
      f.codFeeAmount > 0,
  );
}
