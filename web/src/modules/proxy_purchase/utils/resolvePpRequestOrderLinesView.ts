import type { AccessRole } from 'src/modules/workspace/submodules/auth/guards/accessGuard';
import type { PpPurchaseRequestStatus } from '../types/ppPurchaseRequest';
import type { PpRequestOrderLinesViewKey } from '../types/ppRequestOrderLinesView';

const CUSTOMER_ROLES: AccessRole[] = ['proxy_customer_admin', 'proxy_customer_staff'];

export function resolvePpRequestOrderLinesView(
  matchedRole: AccessRole | null | undefined,
  requestStatus: PpPurchaseRequestStatus | null | undefined,
): PpRequestOrderLinesViewKey {
  if (!matchedRole || requestStatus == null) {
    return 'unsupported';
  }

  if (!CUSTOMER_ROLES.includes(matchedRole)) {
    return 'unsupported';
  }

  if (requestStatus === 'draft') {
    return 'customer_draft';
  }

  if (requestStatus === 'post') {
    return 'customer_posted';
  }

  return 'unsupported';
}