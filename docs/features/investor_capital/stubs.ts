/**
 * Investor Portal & Capital Stubs & Mock Data Provider
 * Used for isolated capital partner testing and investor portal verification.
 */

export interface InvestorProfileStub {
  id: string;
  name: string;
  email?: string;
  phone?: string;
  total_deposited: number;
  current_balance: number;
  active_investments_count: number;
  lifetime_roi_percent: number;
  is_active: boolean;
}

export const mockInvestors: InvestorProfileStub[] = [
  {
    id: 'inv-001',
    name: 'Kabir Capital Holdings Ltd.',
    email: 'invest@kabircapital.com',
    phone: '+880 1711-556677',
    total_deposited: 2500000.0,
    current_balance: 2980000.0,
    active_investments_count: 4,
    lifetime_roi_percent: 19.2,
    is_active: true,
  },
  {
    id: 'inv-002',
    name: 'Nexus Angel Syndicate Alpha',
    email: 'syndicate@nexusbd.com',
    phone: '+880 1822-667788',
    total_deposited: 1200000.0,
    current_balance: 1410000.0,
    active_investments_count: 2,
    lifetime_roi_percent: 17.5,
    is_active: true,
  },
];

export async function fetchMockInvestors(): Promise<InvestorProfileStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockInvestors];
}
