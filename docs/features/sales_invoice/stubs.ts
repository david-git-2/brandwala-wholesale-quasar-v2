/**
 * Sales Invoice Stubs & Mock Data Provider
 * Used for zero-backend UI testing, print preview stories, and invoice component testing.
 */

export interface SalesInvoiceStub {
  id: string;
  invoice_no: string;
  invoice_type: 'wholesale' | 'retail' | 'dropship';
  invoice_status: 'draft' | 'proforma_generated' | 'issued' | 'voided';
  payment_status: 'due' | 'partially_paid' | 'paid' | 'refunded';
  customer_name: string;
  invoice_date: string;
  total_amount: number;
  paid_amount: number;
  due_amount: number;
  items_count: number;
}

export const mockSalesInvoices: SalesInvoiceStub[] = [
  {
    id: 'inv-stub-001',
    invoice_no: 'INV-WS-20260917-0001',
    invoice_type: 'wholesale',
    invoice_status: 'issued',
    payment_status: 'due',
    customer_name: 'Metro Mega Mart (Dhanmondi)',
    invoice_date: '2026-09-17',
    total_amount: 145000.0,
    paid_amount: 0.0,
    due_amount: 145000.0,
    items_count: 12,
  },
  {
    id: 'inv-stub-002',
    invoice_no: 'INV-WS-20260916-0004',
    invoice_type: 'wholesale',
    invoice_status: 'issued',
    payment_status: 'partially_paid',
    customer_name: 'Apex Retailers Chittagong',
    invoice_date: '2026-09-16',
    total_amount: 88500.0,
    paid_amount: 50000.0,
    due_amount: 38500.0,
    items_count: 8,
  },
  {
    id: 'inv-stub-003',
    invoice_no: 'INV-RT-20260917-0002',
    invoice_type: 'retail',
    invoice_status: 'issued',
    payment_status: 'paid',
    customer_name: 'Direct Counter Walk-in',
    invoice_date: '2026-09-17',
    total_amount: 3400.0,
    paid_amount: 3400.0,
    due_amount: 0.0,
    items_count: 2,
  },
];

export async function fetchMockSalesInvoices(): Promise<SalesInvoiceStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockSalesInvoices];
}
