export interface ShipmentReportListRow {
  id: number;
  tenant_shipment_id: number | null;
  name: string;
  status: string;
  created_at: string;
  /** Formatted tenant document number (e.g. SHP-0001), like bill invoice_no. */
  shipment_no: string | null;
  vendor_name?: string | null;
  type?: string | null;
}

export interface ShipmentReportListPageMeta {
  nextCursor: number | null;
  hasMore: boolean;
}
