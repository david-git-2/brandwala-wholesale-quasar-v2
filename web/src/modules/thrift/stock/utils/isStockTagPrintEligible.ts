import type { ThriftStock } from '../types';

export function isStockTagPrintEligible(stock: ThriftStock): boolean {
  return stock.status === 'AVAILABLE' && !!stock.barcode?.trim();
}
