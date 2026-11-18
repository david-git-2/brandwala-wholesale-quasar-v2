import { describe, expect, test, vi } from 'vitest';

vi.mock('../../repositories/shipmentMoneyKernelRepository', () => ({
  fetchShipmentMoneyKernelBundle: vi.fn(),
  syncShipmentApBills: vi.fn(),
  issueShipmentApBillForKind: vi.fn(),
}));

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

const shipment54ApFx = (): ShipmentApFxSnapshot => ({
  product_conversion_rate: 168,
  cargo_conversion_rate: 166,
  cargo_rate: 6.745996,
  transaction_rate: 167.391981,
  goods_bdt: 788760,
  freight_bdt: 340429.48,
  freight_bdt_per_kg: 1119.835289,
  kg_basis: 304,
  product_foreign: 4695,
  cargo_foreign: 2050.78,
  material: {
    bdt_paid: 788760,
    foreign_paid: 4695,
    conversion_rate: 168,
    payment_count: 1,
  },
  freight: {
    bdt_paid: 340429.48,
    foreign_paid: 2050.78,
    conversion_rate: 166,
    payment_count: 1,
  },
  customs: emptyBucketPaid(),
  handling: emptyBucketPaid(),
  finance: emptyBucketPaid(),
  other: emptyBucketPaid(),
});

const materialBill = (): ShipmentApBillRow => ({
  id: 36,
  invoice_no: 'AP-SC-20261118-00029',
  ap_kind: 'material',
  source_key: 'material:GBP',
  source_type: 'shipment_cost',
  source_id: '54',
  invoice_status: 'issued',
  payment_status: 'paid',
  total_amount: 4695,
  due_amount: 0,
});

const freightBill = (): ShipmentApBillRow => ({
  id: 37,
  invoice_no: 'AP-SC-20261118-00030',
  ap_kind: 'freight',
  source_key: 'freight:GBP',
  source_type: 'shipment_cost',
  source_id: '54',
  invoice_status: 'issued',
  payment_status: 'paid',
  total_amount: 2050.78,
  due_amount: 0,
});

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
    expect(grand).toBe(1129189.48);
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