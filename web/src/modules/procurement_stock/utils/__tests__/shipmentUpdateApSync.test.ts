import { describe, expect, test } from 'vitest';
import {
  isShipmentWeightOnlyUpdate,
  shouldRefetchOverviewAfterWorkflowStatusChange,
  shouldSyncShipmentApBills,
} from '../shipmentUpdateApSync';

describe('shouldSyncShipmentApBills', () => {
  test.each([
    [{ status: 'in_transit' }, false],
    [{ status: 'draft' }, false],
    [{ status: 'received' }, false],
    [{ status: 'cancelled' }, true],
    [{ status: 'draft', stock_ready: false }, false],
    [{ vendor_id: 1 }, true],
    [{ type: 'local' }, false],
    [{ received_weight: 10, total_weight_kg: 10 }, false],
    [{ received_weight: 10, vendor_id: 2 }, true],
  ] as const)('%j → %s', (payload, expected) => {
    expect(shouldSyncShipmentApBills(payload as Record<string, unknown>)).toBe(expected);
  });

  test('empty payload', () => {
    expect(shouldSyncShipmentApBills({})).toBe(false);
  });
});

describe('isShipmentWeightOnlyUpdate', () => {
  test('weight-only', () => {
    expect(isShipmentWeightOnlyUpdate({ received_weight: 1, total_weight_kg: 1 })).toBe(true);
  });
});

describe('shouldRefetchOverviewAfterWorkflowStatusChange', () => {
  test('cancelled refetches', () => {
    expect(shouldRefetchOverviewAfterWorkflowStatusChange('cancelled')).toBe(true);
  });

  test.each(['draft', 'in_transit', 'received'] as const)('%s skips refetch', (status) => {
    expect(shouldRefetchOverviewAfterWorkflowStatusChange(status)).toBe(false);
  });
});