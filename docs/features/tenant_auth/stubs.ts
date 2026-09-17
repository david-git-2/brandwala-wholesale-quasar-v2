/**
 * Tenant Auth & Access Control Stubs & Mock Data Provider
 * Used for isolated login flow testing and membership permission verification.
 */

export interface TenantStub {
  id: string;
  name: string;
  slug: string;
  parent_id: string | null;
  role: 'admin' | 'staff' | 'investor';
  is_active: boolean;
}

export const mockTenants: TenantStub[] = [
  {
    id: 'ten-001',
    name: 'Brandwala Wholesale Parent',
    slug: 'brandwala',
    parent_id: null,
    role: 'admin',
    is_active: true,
  },
  {
    id: 'ten-002',
    name: 'Brandwala Retail Desk (Brand A)',
    slug: 'brandwala-retail',
    parent_id: 'ten-001',
    role: 'admin',
    is_active: true,
  },
  {
    id: 'ten-003',
    name: 'Dropship Commerce Network (Brand B)',
    slug: 'dropship-bd',
    parent_id: 'ten-001',
    role: 'staff',
    is_active: true,
  },
];

export async function fetchMockTenants(): Promise<TenantStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockTenants];
}
