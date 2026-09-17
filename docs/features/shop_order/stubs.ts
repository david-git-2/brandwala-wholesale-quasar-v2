/**
 * Shop Order & Dropship Stubs & Mock Data Provider
 * Used for isolated fulfillment desk testing and storefront negotiation demos.
 */

export interface DropshipOrderStub {
  id: string;
  order_no: string;
  status: 'placed' | 'processing' | 'ready_for_pickup' | 'in_transit' | 'delivered' | 'cancelled';
  merchant_name: string;
  recipient_name: string;
  recipient_phone: string;
  recipient_city: string;
  courier_name?: string;
  courier_awb?: string;
  wholesale_total: number;
  resell_total: number;
  reseller_profit: number;
  profit_settled: boolean;
  created_at: string;
}

export const mockDropshipOrders: DropshipOrderStub[] = [
  {
    id: 'ord-stub-001',
    order_no: 'DS-ORD-202609-1001',
    status: 'processing',
    merchant_name: 'Glamour Closet BD',
    recipient_name: 'Tanvir Hossain',
    recipient_phone: '01711223344',
    recipient_city: 'Dhaka (Uttara)',
    wholesale_total: 2400.0,
    resell_total: 3200.0,
    reseller_profit: 800.0,
    profit_settled: false,
    created_at: new Date(Date.now() - 3600000 * 4).toISOString(),
  },
  {
    id: 'ord-stub-002',
    order_no: 'DS-ORD-202609-1002',
    status: 'ready_for_pickup',
    merchant_name: 'Urban Trendz Reseller',
    recipient_name: 'Samira Akter',
    recipient_phone: '01822334455',
    recipient_city: 'Chittagong (GEC)',
    courier_name: 'Steadfast Courier',
    courier_awb: 'ST-889124',
    wholesale_total: 1100.0,
    resell_total: 1650.0,
    reseller_profit: 550.0,
    profit_settled: false,
    created_at: new Date(Date.now() - 3600000 * 12).toISOString(),
  },
  {
    id: 'ord-stub-003',
    order_no: 'DS-ORD-202609-0994',
    status: 'delivered',
    merchant_name: 'Fashion Hub Sylhet',
    recipient_name: 'Mahmudur Rahman',
    recipient_phone: '01933445566',
    recipient_city: 'Sylhet Sadar',
    courier_name: 'Pathao Courier',
    courier_awb: 'PT-998811',
    wholesale_total: 4500.0,
    resell_total: 5800.0,
    reseller_profit: 1300.0,
    profit_settled: true,
    created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
  },
];

export async function fetchMockDropshipOrders(): Promise<DropshipOrderStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockDropshipOrders];
}
