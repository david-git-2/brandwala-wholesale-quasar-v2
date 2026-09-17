/**
 * After-Sales & Returns Stubs & Mock Data Provider
 * Used for isolated Returns Hub testing and RMA case workflow verification.
 */

export interface AfterSalesCaseStub {
  id: string;
  case_no: string;
  source_channel: 'wholesale' | 'dropship';
  program: 'return_credit' | 'doa' | 'replacement' | 'warranty';
  status: 'draft' | 'pending_approval' | 'approved' | 'awaiting_receipt' | 'inspecting' | 'executing' | 'closed' | 'rejected';
  reason_code: string;
  counterparty_name: string;
  document_ref_no: string;
  requested_items_count: number;
  created_at: string;
}

export const mockAfterSalesCases: AfterSalesCaseStub[] = [
  {
    id: 'case-stub-001',
    case_no: 'RMA-WS-202609-001',
    source_channel: 'wholesale',
    program: 'return_credit',
    status: 'inspecting',
    reason_code: 'wrong_item',
    counterparty_name: 'Metro Mega Mart (Dhanmondi)',
    document_ref_no: 'INV-WS-20260917-0001',
    requested_items_count: 5,
    created_at: new Date(Date.now() - 3600000 * 6).toISOString(),
  },
  {
    id: 'case-stub-002',
    case_no: 'RMA-DS-202609-002',
    source_channel: 'dropship',
    program: 'doa',
    status: 'approved',
    reason_code: 'doa',
    counterparty_name: 'Tanvir Hossain (via Glamour Closet)',
    document_ref_no: 'DS-ORD-202609-1001',
    requested_items_count: 1,
    created_at: new Date(Date.now() - 3600000 * 18).toISOString(),
  },
];

export async function fetchMockAfterSalesCases(): Promise<AfterSalesCaseStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockAfterSalesCases];
}
