/**
 * Procurement & Stock Stubs & Mock Data Provider
 * For isolated frontend testing, storybooks, and layout validation.
 */

export interface ShipmentStub {
  id: string;
  shipment_no: string;
  status: 'draft' | 'in_transit' | 'received' | 'cancelled';
  vendor_id: string;
  vendor_name: string;
  vendor_code: string;
  cargo_company_name: string;
  progress_tag_name?: string;
  progress_tag_color?: string;
  costs_locked: boolean;
  is_archived: boolean;
  total_weight_kg: number;
  landed_cost_total_bdt: number;
  items_count: number;
  created_at: string;
}

export const mockShipments: ShipmentStub[] = [
  {
    id: 'shp-stub-001',
    shipment_no: 'SHP-202609-001',
    status: 'received',
    vendor_id: 'ven-001',
    vendor_name: 'Yiwu Direct Sourcing Co.',
    vendor_code: 'YIWU-CN',
    cargo_company_name: 'FastWing Express Cargo',
    progress_tag_name: 'Customs Cleared',
    progress_tag_color: 'positive',
    costs_locked: true,
    is_archived: false,
    total_weight_kg: 420.5,
    landed_cost_total_bdt: 540200.0,
    items_count: 38,
    created_at: new Date(Date.now() - 86400000 * 5).toISOString(),
  },
  {
    id: 'shp-stub-002',
    shipment_no: 'SHP-202609-002',
    status: 'in_transit',
    vendor_id: 'ven-002',
    vendor_name: 'Guangzhou Textile Ltd.',
    vendor_code: 'GZ-TEX',
    cargo_company_name: 'Dragon Air Express',
    progress_tag_name: 'Air Freight En Route',
    progress_tag_color: 'amber-8',
    costs_locked: false,
    is_archived: false,
    total_weight_kg: 110.0,
    landed_cost_total_bdt: 185000.0,
    items_count: 14,
    created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
  },
  {
    id: 'shp-stub-003',
    shipment_no: 'SHP-202609-003',
    status: 'draft',
    vendor_id: 'ven-003',
    vendor_name: 'Shenzhen Electronics Group',
    vendor_code: 'SZ-ELEC',
    cargo_company_name: 'Skyline Logistics',
    progress_tag_name: 'PO Prepared',
    progress_tag_color: 'grey-7',
    costs_locked: false,
    is_archived: false,
    total_weight_kg: 85.0,
    landed_cost_total_bdt: 92400.0,
    items_count: 6,
    created_at: new Date().toISOString(),
  },
];

export async function fetchMockShipments(): Promise<{
  rows: ShipmentStub[];
  total_count: number;
  archived_total: number;
}> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return {
    rows: [...mockShipments],
    total_count: mockShipments.length,
    archived_total: 12,
  };
}
