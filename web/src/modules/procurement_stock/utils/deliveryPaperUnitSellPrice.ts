import type { DeliveryPaperDetailItem } from '../repositories/procurementDemandRepository';
import { formatBdtTaka } from 'src/utils/currency';

export const getDeliveryPaperUnitSellPrice = (
  item: Pick<DeliveryPaperDetailItem, 'unit_sell_price_amount'>,
): number => {
  const amount = Number(item.unit_sell_price_amount ?? 0);
  return Number.isFinite(amount) ? amount : 0;
};

export const formatDeliveryPaperUnitSellPrice = (
  item: Pick<DeliveryPaperDetailItem, 'unit_sell_price_amount'>,
): string => formatBdtTaka(getDeliveryPaperUnitSellPrice(item));

export const deliveryPaperSellPriceHint = (
  item: Pick<DeliveryPaperDetailItem, 'is_negotiable_snapshot'>,
): string =>
  item.is_negotiable_snapshot ? 'Final offer' : 'First offer';
