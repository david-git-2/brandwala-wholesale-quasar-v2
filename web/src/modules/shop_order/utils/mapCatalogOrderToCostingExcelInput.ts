import type { BuildCostingExcelInput } from 'src/modules/product_based_costing/utils/buildCostingExcelWorkbook';
import type { ProductBasedCostingFile, ProductBasedCostingItem } from 'src/modules/product_based_costing/types';
import {
  PBC_FALLBACK_BUY_CURRENCY_CODE,
  PBC_FALLBACK_SELL_CURRENCY_CODE,
} from 'src/modules/product_based_costing/utils/pbcFileCurrencies';
import type { ShopOrder, ShopOrderItem } from '../types';
import {
  getFinalOfferUnitAmount,
  getPackageWeightGm,
  getProductWeightGm,
  type CatalogRatesParams,
} from './catalogPricingUtils';

const SYMBOL_TO_CODE: Record<string, string> = {
  '£': 'GBP',
  '৳': 'BDT',
  $: 'USD',
  '€': 'EUR',
};

function currencyCodeFromSymbol(symbol: string | null | undefined, fallback: string): string {
  const trimmed = symbol?.trim();
  if (!trimmed) return fallback;
  const mapped = SYMBOL_TO_CODE[trimmed];
  if (mapped) return mapped;
  if (/^[A-Za-z]{3}$/.test(trimmed)) return trimmed.toUpperCase();
  return fallback;
}

function ratesFromOrder(order: ShopOrder): CatalogRatesParams {
  return {
    conversion_rate: order.conversion_rate ?? 140,
    cargo_rate: order.cargo_rate ?? 0,
    first_offer_rate: order.first_offer_rate ?? order.profit_rate,
    final_offer_rate: order.final_offer_rate,
    profit_rate: order.profit_rate,
    profit_basis: order.profit_basis,
  };
}

function mapLineToPbcItem(
  item: ShopOrderItem,
  order: ShopOrder,
  fileId: number,
  rates: CatalogRatesParams,
  now: string,
): ProductBasedCostingItem {
  const packageKg = order.package_weight_kg;
  const purchasePrice = Number(item.cost_price_amount ?? item.unit_list_price_amount ?? 0);
  const offerPrice = getFinalOfferUnitAmount(item, rates, packageKg);

  return {
    id: item.id,
    product_based_costing_file_id: fileId,
    product_id: item.product_id,
    name: item.name,
    image_url: item.image_url,
    note: item.note,
    quantity: item.quantity,
    confirmed_quantity: item.confirmed_quantity ?? item.quantity,
    barcode: item.barcode,
    product_code: item.sku,
    brand: item.brand,
    vendor_code: null,
    market_code: null,
    web_link: null,
    price_gbp: purchasePrice,
    product_weight: getProductWeightGm(item),
    package_weight: getPackageWeightGm(item, packageKg),
    offer_price: offerPrice,
    status: item.negotiation_status ?? null,
    created_at: item.created_at || now,
    updated_at: item.updated_at || now,
  };
}

export function mapCatalogOrderToCostingExcelInput(
  order: ShopOrder,
  items: ShopOrderItem[],
): BuildCostingExcelInput {
  const now = new Date().toISOString();
  const buyCode = currencyCodeFromSymbol(
    order.shop_buy_currency_symbol,
    PBC_FALLBACK_BUY_CURRENCY_CODE,
  );
  const sellCode = currencyCodeFromSymbol(
    order.shop_sell_currency_symbol,
    PBC_FALLBACK_SELL_CURRENCY_CODE,
  );

  const file = {
    id: order.id,
    name: order.order_no || order.name,
    conversion_rate: order.conversion_rate ?? 140,
    cargo_rate_kg_gbp: order.cargo_rate ?? 0,
    buy_currency_code: buyCode,
    sell_currency_code: sellCode,
    created_at: order.created_at || now,
    updated_at: order.updated_at || now,
  } as ProductBasedCostingFile;

  const rates = ratesFromOrder(order);
  const pbcItems = items.map((item) => mapLineToPbcItem(item, order, order.id, rates, now));

  return { file, items: pbcItems };
}
