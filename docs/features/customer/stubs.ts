/**
 * Customer Hub Stubs & Mock Data Provider
 * Used for isolated customer directory testing and detail drawer validation.
 */

export interface CustomerGroupStub {
  customer_group_id: string;
  billing_profile_id: string;
  name: string;
  phone: string;
  email?: string;
  accent_color: string;
  is_active: boolean;
  active_shops_count: number;
  total_open_due_bdt: number;
  store_credit_balance_bdt: number;
}

export const mockCustomerGroups: CustomerGroupStub[] = [
  {
    customer_group_id: 'grp-001',
    billing_profile_id: 'bp-001',
    name: 'Metro Mega Mart (Dhanmondi)',
    phone: '+880 1711-223344',
    email: 'purchasing@metromart.bd',
    accent_color: '#2563EB',
    is_active: true,
    active_shops_count: 3,
    total_open_due_bdt: 145000.0,
    store_credit_balance_bdt: 45000.0,
  },
  {
    customer_group_id: 'grp-002',
    billing_profile_id: 'bp-002',
    name: 'Apex Retailers Chittagong',
    phone: '+880 1822-334455',
    email: 'accounts@apexctg.com',
    accent_color: '#16A34A',
    is_active: true,
    active_shops_count: 1,
    total_open_due_bdt: 38500.0,
    store_credit_balance_bdt: 0.0,
  },
  {
    customer_group_id: 'grp-003',
    billing_profile_id: 'bp-003',
    name: 'Sylhet Fashion House',
    phone: '+880 1933-445566',
    email: 'info@sylhetfashion.com',
    accent_color: '#D97706',
    is_active: true,
    active_shops_count: 2,
    total_open_due_bdt: 0.0,
    store_credit_balance_bdt: 12400.0,
  },
];

export async function fetchMockCustomerGroups(): Promise<CustomerGroupStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockCustomerGroups];
}
