import { describe, test, expect } from 'vitest';
import {
  lineMargin,
  chargeEffect,
  invoiceGrossProfit,
  batchPnl,
  dropshipColumns,
  type LineInput,
  type InvoiceInput,
  type ReturnInput,
  type ShipmentItemInput,
  type SoldLineInput,
} from './margin';

describe('Reporting Treasury Margin Formulas', () => {
  // 1. Line Margin
  describe('lineMargin', () => {
    test('calculates correct margin without discount', () => {
      const line: LineInput = {
        sell_price_amount: 150,
        unit_cost_price: 100,
        quantity: 5,
        line_discount_amount: 0,
      };
      // (150 - 100) * 5 - 0 = 250
      expect(lineMargin(line)).toBe(250);
    });

    test('calculates correct margin with discount and alternative field names', () => {
      const line: LineInput = {
        sell_price: 200,
        unit_cost: 120,
        qty: 10,
        line_discount: 50,
      };
      // (200 - 120) * 10 - 50 = 750
      expect(lineMargin(line)).toBe(750);
    });
  });

  // 2. Charge Effect
  describe('chargeEffect', () => {
    const invoice: InvoiceInput = {
      invoice_type: 'wholesale',
      shipping_charge: 150,
      cod_charge: 50,
      print_charge: 20,
      wrapping_charge: 30,
    };

    test('wholesale only includes shipping_charge', () => {
      expect(chargeEffect({ ...invoice, invoice_type: 'wholesale' })).toBe(150);
    });

    test('retail includes all charges', () => {
      expect(chargeEffect({ ...invoice, invoice_type: 'retail' })).toBe(250); // 150 + 50 + 20 + 30
    });

    test('dropship includes shipping_charge only (accounting charges)', () => {
      expect(chargeEffect({ ...invoice, invoice_type: 'dropship' })).toBe(150);
    });
  });

  // 3. Invoice Gross Profit (Wholesale)
  describe('invoiceGrossProfit - Wholesale', () => {
    const invoice: InvoiceInput = {
      invoice_type: 'wholesale',
      shipping_charge: 100,
      discount_amount: 50,
      invoice_status: 'posted',
    };

    const lines: (LineInput & { id: number })[] = [
      {
        id: 1,
        sell_price_amount: 120,
        unit_cost_price: 80,
        quantity: 10,
        line_discount_amount: 20,
      }, // GP: 380
      { id: 2, sell_price_amount: 200, unit_cost_price: 150, quantity: 5, line_discount_amount: 0 }, // GP: 250
    ];

    test('calculates correct wholesale gross profit', () => {
      // Σ line margins: 380 + 250 = 630
      // minus invoice discount: - 50 = 580
      // plus charges: + 100 = 680
      expect(invoiceGrossProfit(invoice, lines)).toBe(680);
    });

    test('gating: returns 0 when invoice is draft or voided', () => {
      expect(invoiceGrossProfit({ ...invoice, invoice_status: 'draft' }, lines)).toBe(0);
      expect(invoiceGrossProfit({ ...invoice, invoice_status: 'voided' }, lines)).toBe(0);
    });
  });

  // 4. Invoice Gross Profit (Retail)
  describe('invoiceGrossProfit - Retail', () => {
    const invoice: InvoiceInput = {
      invoice_type: 'retail',
      shipping_charge: 120, // delivery
      cod_charge: 40,
      print_charge: 15,
      wrapping_charge: 25,
      discount_amount: 0,
      invoice_status: 'posted',
    };

    const lines: (LineInput & { id: number })[] = [
      { id: 1, sell_price_amount: 500, unit_cost_price: 300, quantity: 2, line_discount_amount: 0 }, // GP: 400
    ];

    test('calculates correct retail gross profit including all charges', () => {
      // Σ line margins: 400
      // charges effect: 120 + 40 + 15 + 25 = 200
      // total: 400 - 0 + 200 = 600
      expect(invoiceGrossProfit(invoice, lines)).toBe(600);
    });
  });

  // 5. Returns Margin Reversal
  describe('invoiceGrossProfit with Returns', () => {
    const invoice: InvoiceInput = {
      invoice_type: 'wholesale',
      shipping_charge: 0,
      discount_amount: 0,
      invoice_status: 'posted',
    };

    const lines: (LineInput & { id: number })[] = [
      {
        id: 1,
        sell_price_amount: 150,
        unit_cost_price: 100,
        quantity: 10,
        line_discount_amount: 0,
      }, // GP: 500, cost: 100
    ];

    test('deducts correct return margins', () => {
      // Returned 3 units of line 1. return_accounting_amount = 450 (which matches 150 * 3)
      // return_margin = 450 - (100 * 3) = 150
      // expected GP = 500 - 150 = 350
      const returns: ReturnInput[] = [
        { invoice_item_id: 1, quantity: 3, return_accounting_amount: 450 },
      ];
      expect(invoiceGrossProfit(invoice, lines, returns)).toBe(350);
    });
  });

  // 6. Dropship Columns
  describe('dropshipColumns', () => {
    const invoice: InvoiceInput = {
      invoice_type: 'dropship',
      shipping_charge: 100,
      discount_amount: 0,
      invoice_status: 'posted',
    };

    const lines: (LineInput & { id: number })[] = [
      {
        id: 1,
        sell_price_amount: 500, // what we bill the dropshipper
        recipient_price_amount: 700, // face COD price billed to end customer
        unit_cost_price: 350,
        quantity: 2,
        line_discount_amount: 0,
      },
    ];

    test('calculates correct splits, middle-man spread, and accounting margin', () => {
      const res = dropshipColumns(invoice, lines);

      // accounting subtotal = 500 * 2 = 1000
      expect(res.accountingSubtotal).toBe(1000);
      // face subtotal = 700 * 2 = 1400
      expect(res.faceSubtotal).toBe(1400);
      // middle man payout = (700 - 500) * 2 = 400
      expect(res.middleManPayout).toBe(400);
      // accounting margin = line_margin (500 - 350)*2 + charges (100) = 300 + 100 = 400
      expect(res.accountingMargin).toBe(400);
    });
  });

  // 7. Batch P&L
  describe('batchPnl', () => {
    const shipment = {
      type: 'domestic' as const,
      product_conversion_rate: 1.0,
      cargo_conversion_rate: 1.0,
      cargo_rate: 0.0,
      received_weight: null,
      transaction_rate: null,
    };

    const shipmentItems: ShipmentItemInput[] = [{ id: 1, received_qty: 10, landed_unit_cost: 80 }];

    const soldLines: SoldLineInput[] = [
      { id: 101, shipment_item_id: 1, unit_cost_price: 80, sell_price_amount: 120, quantity: 6 },
    ];

    test('calculates correct batch metrics without returns', () => {
      // batch_landed_cost = 10 * 80 = 800
      // batch_sold_cost = 6 * 80 = 480
      // batch_revenue = 6 * 120 = 720
      // gross_profit = 720 - 480 = 240
      // unsold_value = (10 - 6) * 80 = 320
      const res = batchPnl(shipment, shipmentItems, soldLines);

      expect(res.landedCost).toBe(800);
      expect(res.soldCost).toBe(480);
      expect(res.revenue).toBe(720);
      expect(res.grossProfit).toBe(240);
      expect(res.unsoldValue).toBe(320);
    });

    test('calculates correct batch metrics with returns included', () => {
      // Returned 2 units of line 101. return_accounting_amount = 240 (120 * 2)
      // active sold qty = 6 - 2 = 4
      // batch_sold_cost = 4 * 80 = 320
      // batch_revenue = 6 * 120 - 240 = 480
      // gross_profit = 480 - 320 = 160
      // unsold_value = (10 - 4) * 80 = 480
      const returns: ReturnInput[] = [
        { invoice_item_id: 101, quantity: 2, return_accounting_amount: 240 },
      ];
      const res = batchPnl(shipment, shipmentItems, soldLines, returns);

      expect(res.landedCost).toBe(800);
      expect(res.soldCost).toBe(320);
      expect(res.revenue).toBe(480);
      expect(res.grossProfit).toBe(160);
      expect(res.unsoldValue).toBe(480);
    });

    test('calculates correct batch metrics with explicit disposition quantities', () => {
      const customShipmentItems: ShipmentItemInput[] = [
        {
          id: 1,
          received_qty: 10,
          landed_unit_cost: 80,
          sellable_qty: 2,
          stolen_qty: 1,
          box_damage_qty: 1,
          expired_qty: 0,
        },
      ];
      const res = batchPnl(shipment, customShipmentItems, soldLines);

      expect(res.landedCost).toBe(800);
      expect(res.soldCost).toBe(480);
      expect(res.revenue).toBe(720);
      expect(res.grossProfit).toBe(240);
      expect(res.sellableOnHandValue).toBe(160);
      expect(res.stolenValue).toBe(80);
      expect(res.boxDamageValue).toBe(80);
      expect(res.expiredValue).toBe(0);
      expect(res.shrinkageValue).toBe(160);
      expect(res.unsoldValue).toBe(160);
    });
  });
});
