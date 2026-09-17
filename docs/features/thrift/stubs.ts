/**
 * Thrift Vertical Stubs & Mock Data Provider
 * Used for isolated thrift inventory testing and POS checkout verification.
 */

export interface ThriftStockStub {
  id: string;
  barcode: string;
  name: string;
  brand?: string;
  category: string;
  size?: string;
  landed_cost_bdt: number;
  retail_price_bdt: number;
  status: 'registered' | 'tagged' | 'in_stock' | 'reserved' | 'sold' | 'damaged' | 'returned';
  shelf_location?: string;
}

export const mockThriftStocks: ThriftStockStub[] = [
  {
    id: 'th-stk-001',
    barcode: 'TH-100293',
    name: "Vintage Levi's 501 Straight Leg",
    brand: "Levi's",
    category: 'Bottoms > Jeans',
    size: 'W32 L30',
    landed_cost_bdt: 850.0,
    retail_price_bdt: 1800.0,
    status: 'in_stock',
    shelf_location: 'Rack B-04',
  },
  {
    id: 'th-stk-002',
    barcode: 'TH-100294',
    name: 'Ralph Lauren Classic Polo Shirt',
    brand: 'Ralph Lauren',
    category: 'Tops > Polos',
    size: 'L',
    landed_cost_bdt: 420.0,
    retail_price_bdt: 950.0,
    status: 'in_stock',
    shelf_location: 'Rack A-12',
  },
  {
    id: 'th-stk-003',
    barcode: 'TH-100295',
    name: 'Carhartt Detroit Duck Canvas Jacket',
    brand: 'Carhartt',
    category: 'Outerwear',
    size: 'XL',
    landed_cost_bdt: 1450.0,
    retail_price_bdt: 3200.0,
    status: 'sold',
    shelf_location: 'Rack C-01',
  },
];

export async function fetchMockThriftStocks(): Promise<ThriftStockStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockThriftStocks];
}
