import type { ThriftStock } from '../types';
import type { ThriftMarketingTagConfig } from '../../shipment/types/marketingTag';

export interface PrintableTagCounts {
  itemCount: number;
  stickerCount: number;
}

export interface ShipmentTagPrintRow {
  shipmentId: number;
  shipmentName: string;
  itemCount: number;
  stickerCount: number;
}

export interface StockTagPrintSticker {
  stock: ThriftStock;
  tagConfig: ThriftMarketingTagConfig;
  listedSellFormatted: string;
}
