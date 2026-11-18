import { describe, expect, test, vi } from 'vitest';

vi.mock('../../repositories/shipmentMoneyKernelRepository', () => ({
  fetchShipmentMoneyKernelBundle: vi.fn(),
  syncShipmentApBills: vi.fn(),
  issueShipmentApBillForKind: vi.fn(),
}));

import golden from 'src/shared/shipment-engine/fixtures/shipment_golden_s54.json';
import type { ShipmentApBillRow, ShipmentApFxSnapshot } from '../../repositories/shipmentApBillsRepository';
import {
  buildSummaryApBillsByBucket,
  displayBillBooksBdtAmount,
  summaryApBillsGrandBdt,
} from '../shipmentSummaryApBills';

const emptyBucketPaid = () => ({
  bdt_paid: 0,
  foreign_paid: 0,
  conversion_rate: 1,
  payment_count: 0,
});

const shipment54ApFx = (): ShipmentApFxSnapshot => {
  const apFx = golden.apFx as ShipmentApFxSnapshot;
  return {
    ...apFx,
    customs: emptyBucketPaid(),
    handling: emptyBucketPaid(),
    finance: emptyBucketPaid(),
    other: emptyBucketPaid(),
  };
};

const materialBill = (): ShipmentApBillRow => golden.bills[0] as ShipmentApBillRow;
const freightBill = (): ShipmentApBillRow => golden.bills[1] as ShipmentApBillRow;

describe('shipmentSummaryApBills', () => {
  test('displayBillBooksBdtAmount converts GBP paid pools to BDT', () => {
    const apFx = shipment54ApFx();
    expect(displayBillBooksBdtAmount(materialBill(), apFx.material)).toBe(788760);
    expect(displayBillBooksBdtAmount(freightBill(), apFx.freight)).toBe(340429.48);
  });

  test('buildSummaryApBillsByBucket grand total is books BDT not foreign sum', () => {
    const groups = buildSummaryApBillsByBucket(
      [materialBill(), freightBill()],
      shipment54ApFx(),
    );
    const grand = summaryApBillsGrandBdt(groups);
    expect(grand).toBe(golden.expected.apBooksGrandTotal);
    expect(grand).not.toBe(6745.78);

    const material = groups.find((g) => g.bucket === 'material');
    const freight = groups.find((g) => g.bucket === 'freight');
    expect(material?.rows[0]?.bdtAmount).toBe(788760);
    expect(freight?.rows[0]?.bdtAmount).toBe(340429.48);
  });

  test('BDT bill books column equals origin amount', () => {
    const bill: ShipmentApBillRow = {
      id: 1,
      invoice_no: 'AP-BDT',
      ap_kind: 'customs',
      source_key: 'customs:BDT',
      source_type: 'shipment_cost',
      source_id: '1',
      invoice_status: 'issued',
      payment_status: 'paid',
      total_amount: 1000,
      due_amount: 0,
    };
    expect(displayBillBooksBdtAmount(bill, null)).toBe(1000);
  });

  test('unpaid foreign preview uses conversion_rate', () => {
    const bill: ShipmentApBillRow = {
      id: 2,
      invoice_no: 'AP-DRAFT',
      ap_kind: 'material',
      source_key: 'material:GBP',
      source_type: 'shipment_cost',
      source_id: '1',
      invoice_status: 'issued',
      payment_status: 'due',
      total_amount: 100,
      due_amount: 100,
    };
    expect(
      displayBillBooksBdtAmount(bill, {
        bdt_paid: 0,
        foreign_paid: 0,
        conversion_rate: 168,
        payment_count: 0,
      }),
    ).toBe(16800);
  });
});