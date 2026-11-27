export type PpPurchaseRequestStatus = 'draft' | 'post';
export type PpOrderLineStatus = 'draft' | 'pending_review';

export interface PpPurchaseRequestListItem {
  id: number;
  request_number: string | null;
  status: PpPurchaseRequestStatus;
  created_at: string;
  updated_at: string;
  line_count: number;
}

export interface PpPurchaseRequest {
  id: number;
  tenant_id: number;
  people_group_id: number;
  created_by_member_id: number;
  status: PpPurchaseRequestStatus;
  request_number: string | null;
  bucket_description: string | null;
  created_at: string;
  updated_at: string;
}

export interface PpOrderLine {
  id: number;
  purchase_request_id: number;
  url: string;
  needed_qty: number;
  description: string | null;
  status: PpOrderLineStatus;
  created_at: string;
}