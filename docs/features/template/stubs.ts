/**
 * Feature Stubs & Mock Data Provider
 * Used for zero-backend UI development, storybooks, and test suites.
 */

export interface FeatureEntityStub {
  id: string;
  tenant_id: string;
  title: string;
  status: 'draft' | 'active' | 'completed' | 'cancelled';
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export const mockFeatureEntities: FeatureEntityStub[] = [
  {
    id: 'f001-stub-001',
    tenant_id: 'tenant-brandwala-01',
    title: 'Spring Season Batch Clearance',
    status: 'active',
    metadata: { itemCount: 120, estimatedValue: 45000 },
    created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    updated_at: new Date().toISOString(),
  },
  {
    id: 'f001-stub-002',
    tenant_id: 'tenant-brandwala-01',
    title: 'Overstock Return Processing',
    status: 'draft',
    metadata: { itemCount: 42, estimatedValue: 12800 },
    created_at: new Date(Date.now() - 86400000 * 5).toISOString(),
    updated_at: new Date().toISOString(),
  },
];

export async function fetchMockFeatureList(): Promise<FeatureEntityStub[]> {
  // Simulate network latency
  await new Promise((resolve) => setTimeout(resolve, 200));
  return [...mockFeatureEntities];
}
