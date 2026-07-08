import type { ThriftStock } from '../types';
import { isStockTagPrintEligible } from './isStockTagPrintEligible';

export function expandStocksForTagPrint(stocks: ThriftStock[]): ThriftStock[] {
  return stocks
    .filter(isStockTagPrintEligible)
    .flatMap((s) => Array(Math.max(s.quantity || 1, 1)).fill(s));
}
