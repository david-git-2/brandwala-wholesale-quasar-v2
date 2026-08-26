import { ref, type Ref } from 'vue';
import { roundUpToNearest50or100 } from '../utils/shopPricingRound';

export function roundListingPrice(value: number): number {
  return Math.round(value * 100) / 100;
}

export function markupPctFromBase(
  base: number,
  price: number | null | undefined,
): number | null {
  if (!Number.isFinite(base) || base <= 0) return null;
  const amount = Number(price);
  if (!Number.isFinite(amount)) return null;
  return roundListingPrice(((amount - base) / base) * 100);
}

export function priceFromMarkupPct(
  base: number,
  pct: number | null | undefined,
): number | null {
  const markup = Number(pct);
  if (!Number.isFinite(base) || base <= 0 || !Number.isFinite(markup)) return null;
  return roundUpToNearest50or100(base * (1 + markup / 100));
}

function coerceNumber(raw: number | string | null | undefined): number | null {
  if (raw === null || raw === undefined || raw === '') return null;
  const value = Number(raw);
  return Number.isFinite(value) ? value : null;
}

type PriceFieldSource =
  | 'sellPrice'
  | 'sellPct'
  | 'resellPrice'
  | 'resellPctCost'
  | 'resellPctSell';

export function useLinkedListingPriceFields(baseCost: Ref<number>) {
  const sellPrice = ref<number | null>(null);
  const sellMarkupPctOnCost = ref<number | null>(null);
  const resellPrice = ref<number | null>(null);
  const resellMarkupPctOnCost = ref<number | null>(null);
  const resellMarkupPctOnSell = ref<number | null>(null);

  let activeSource: PriceFieldSource | null = null;

  const getCost = () => {
    const cost = Number(baseCost.value);
    return Number.isFinite(cost) && cost > 0 ? cost : null;
  };

  const getSell = () => {
    const sell = Number(sellPrice.value);
    return Number.isFinite(sell) && sell > 0 ? sell : null;
  };

  const syncSellMarkupPct = () => {
    const cost = getCost();
    sellMarkupPctOnCost.value =
      cost !== null ? markupPctFromBase(cost, sellPrice.value) : null;
  };

  const syncResellMarkupPcts = () => {
    const cost = getCost();
    const sell = getSell();
    const resell = Number(resellPrice.value);
    const hasResell = Number.isFinite(resell);

    resellMarkupPctOnCost.value =
      cost !== null && hasResell ? markupPctFromBase(cost, resell) : null;
    resellMarkupPctOnSell.value =
      sell !== null && hasResell ? markupPctFromBase(sell, resell) : null;
  };

  const runLocked = (source: PriceFieldSource, fn: () => void) => {
    activeSource = source;
    fn();
    activeSource = null;
  };

  const initialize = (sell: number | null, resell: number | null) => {
    runLocked('sellPrice', () => {
      sellPrice.value = sell;
      resellPrice.value = resell;
      syncSellMarkupPct();
      syncResellMarkupPcts();
    });
  };

  const updateSellPrice = (raw: number | string | null | undefined) => {
    if (activeSource && activeSource !== 'sellPrice') return;
    runLocked('sellPrice', () => {
      sellPrice.value = coerceNumber(raw);
      syncSellMarkupPct();
      syncResellMarkupPcts();
    });
  };

  const updateSellMarkupPct = (raw: number | string | null | undefined) => {
    if (activeSource && activeSource !== 'sellPct') return;
    runLocked('sellPct', () => {
      const pct = coerceNumber(raw);
      sellMarkupPctOnCost.value = pct;
      const cost = getCost();
      if (cost !== null && pct !== null) {
        sellPrice.value = priceFromMarkupPct(cost, pct);
      }
      syncResellMarkupPcts();
    });
  };

  const updateResellPrice = (raw: number | string | null | undefined) => {
    if (activeSource && activeSource !== 'resellPrice') return;
    runLocked('resellPrice', () => {
      resellPrice.value = coerceNumber(raw);
      syncResellMarkupPcts();
    });
  };

  const updateResellMarkupPctOnCost = (raw: number | string | null | undefined) => {
    if (activeSource && activeSource !== 'resellPctCost') return;
    runLocked('resellPctCost', () => {
      const pct = coerceNumber(raw);
      resellMarkupPctOnCost.value = pct;
      const cost = getCost();
      if (cost !== null && pct !== null) {
        resellPrice.value = priceFromMarkupPct(cost, pct);
      }
      syncResellMarkupPcts();
    });
  };

  const updateResellMarkupPctOnSell = (raw: number | string | null | undefined) => {
    if (activeSource && activeSource !== 'resellPctSell') return;
    runLocked('resellPctSell', () => {
      const pct = coerceNumber(raw);
      resellMarkupPctOnSell.value = pct;
      const sell = getSell();
      if (sell !== null && pct !== null) {
        resellPrice.value = priceFromMarkupPct(sell, pct);
      }
      syncResellMarkupPcts();
    });
  };

  const roundSellPriceField = () => {
    if (sellPrice.value === null) return;
    const rounded = roundUpToNearest50or100(sellPrice.value);
    if (rounded === sellPrice.value) {
      syncSellMarkupPct();
      syncResellMarkupPcts();
      return;
    }
    updateSellPrice(rounded);
  };

  const roundResellPriceField = () => {
    if (resellPrice.value === null) return;
    const rounded = roundUpToNearest50or100(resellPrice.value);
    if (rounded === resellPrice.value) {
      syncResellMarkupPcts();
      return;
    }
    updateResellPrice(rounded);
  };

  return {
    sellPrice,
    sellMarkupPctOnCost,
    resellPrice,
    resellMarkupPctOnCost,
    resellMarkupPctOnSell,
    initialize,
    updateSellPrice,
    updateSellMarkupPct,
    updateResellPrice,
    updateResellMarkupPctOnCost,
    updateResellMarkupPctOnSell,
    roundSellPriceField,
    roundResellPriceField,
  };
}
