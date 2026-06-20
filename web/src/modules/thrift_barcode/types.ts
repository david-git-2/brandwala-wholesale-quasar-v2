export interface ThriftBarcode {
  id: number;
  tenant_id: number;
  barcode_id: string;
  status: string;
  is_printed: number;
  inserted_by: string;
  created_at: string;
  updated_at: string;
}

export interface ThriftBarcodeListMeta {
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
  unprinted_total: number;
  available_total: number;
  printable_total: number;
  latest_current_year_barcode_id: string | null;
}

export function isBarcodePrintEligible(barcode: Pick<ThriftBarcode, 'is_printed' | 'status'>): boolean {
  return barcode.is_printed === 0 && barcode.status === 'AVAILABLE';
}

export interface ThriftBarcodeListParams {
  tenantId: number;
  page?: number;
  pageSize?: number;
  search?: string;
  isPrinted?: number | null;
  status?: string | null;
}

export interface ThriftBarcodeListResult {
  data: ThriftBarcode[];
  meta: ThriftBarcodeListMeta;
}
