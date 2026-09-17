/**
 * Dashboard & Insights Stubs & Mock Data Provider
 * Used for isolated dashboard shell testing and customer home verification.
 */

export interface DashboardAttentionItemStub {
  id: string;
  category: 'invoice' | 'shipment' | 'dropship' | 'task';
  title: string;
  description: string;
  action_route: string;
  severity: 'urgent' | 'warning' | 'info';
}

export const mockAttentionItems: DashboardAttentionItemStub[] = [
  {
    id: 'att-001',
    category: 'invoice',
    title: '4 Invoices Overdue',
    description: 'Metro Mega Mart has 145,000 BDT overdue > 15 days',
    action_route: '/app/sales/invoices',
    severity: 'urgent',
  },
  {
    id: 'att-002',
    category: 'shipment',
    title: 'Inbound Batch Arrived at Port',
    description: 'SHP-202609-001 ready for physical receiving & landed cost freeze',
    action_route: '/app/procurement/shipment',
    severity: 'warning',
  },
  {
    id: 'att-003',
    category: 'dropship',
    title: '3 Dropship Orders Ready for Stock Pick',
    description: 'Orders need item assignment in Processing stage',
    action_route: '/app/dropship/orders',
    severity: 'info',
  },
];

export async function fetchMockAttentionItems(): Promise<DashboardAttentionItemStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockAttentionItems];
}
