/**
 * Investor capital stubs — identity on profile; cash and batch separate.
 */

export interface InvestorProfileStub {
  id: string;
  name: string;
  email?: string;
  phone?: string;
  address?: string;
  is_active: boolean;
  currency_code: string;
}

export interface InvestorWalletStub {
  investor_id: string;
  available_balance: number;
  pending_balance: number;
  total_capital_in: number;
  total_withdrawn: number;
}

export interface ShipmentInvestmentStub {
  investor_id: string;
  global_shipment_id: string;
  invested_amount: number;
  cost_share_pct: number;
  profit_status: 'open' | 'partial' | 'realized';
}

export const mockInvestors: InvestorProfileStub[] = [
  {
    id: 'inv-001',
    name: 'Kabir Capital Holdings Ltd.',
    email: 'invest@kabircapital.com',
    phone: '+880 1711-556677',
    is_active: true,
    currency_code: 'BDT',
  },
  {
    id: 'inv-002',
    name: 'Nexus Angel Syndicate Alpha',
    email: 'syndicate@nexusbd.com',
    phone: '+880 1822-667788',
    is_active: true,
    currency_code: 'BDT',
  },
];

export const mockInvestorWallets: InvestorWalletStub[] = [
  {
    investor_id: 'inv-001',
    available_balance: 650000,
    pending_balance: 120000,
    total_capital_in: 2500000,
    total_withdrawn: 0,
  },
];

export async function fetchMockInvestors(): Promise<InvestorProfileStub[]> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return [...mockInvestors];
}
