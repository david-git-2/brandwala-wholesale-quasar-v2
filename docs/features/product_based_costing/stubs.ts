/**
 * Product-Based Costing (PBC) Stubs & Mock Data Provider
 * Used for isolated quotation sheet testing and formula validation.
 */

export interface CostingFileStub {
  id: string;
  file_no: string;
  title: string;
  status: 'pending' | 'offered' | 'confirmed' | 'procuring' | 'ready_for_shipment' | 'delivered' | 'cancelled';
  customer_name: string;
  base_currency: string;
  fx_rate: number;
  markup_percentage: number;
  total_quoted_amount_bdt: number;
  total_items_count: number;
  created_at: string;
}

export const mockCostingFiles: CostingFileStub[] = [
  {
    id: 'pbc-stub-001',
    file_no: 'PBC-202609-001',
    title: 'Autumn Outerwear & Knitwear Sourcing',
    status: 'confirmed',
    customer_name: 'Metro Mega Mart (Dhanmondi)',
    base_currency: 'GBP',
    fx_rate: 154.5,
    markup_percentage: 0.18,
    total_quoted_amount_bdt: 384200.0,
    total_items_count: 14,
    created_at: new Date(Date.now() - 86400000 * 3).toISOString(),
  },
  {
    id: 'pbc-stub-002',
    file_no: 'PBC-202609-002',
    title: 'Winter Fleece & Hoodie Collection',
    status: 'offered',
    customer_name: 'Apex Retailers Chittagong',
    base_currency: 'GBP',
    fx_rate: 154.5,
    markup_percentage: 0.15,
    total_quoted_amount_bdt: 215000.0,
    total_items_count: 8,
    created_at: new Date(Date.now() - 86400000).toISOString(),
  },
];

export async function fetchMockCostingFiles(): Promise<CostingFileStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockCostingFiles];
}
