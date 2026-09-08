import { afterSalesRepositoryStub } from '../repositories/afterSalesRepository.stub';
import type { AfterSalesReasonCode, PolicyPreviewResult } from '../types/afterSales.types';

export async function resolveMockPolicyPreview(
  invoiceItemId: number,
  reasonCode: AfterSalesReasonCode,
): Promise<PolicyPreviewResult> {
  return afterSalesRepositoryStub.resolvePolicyPreview(invoiceItemId, reasonCode);
}
