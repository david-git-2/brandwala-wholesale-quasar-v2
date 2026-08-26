export interface DropshipCartUiItem {
  id: number;
  name: string;
  imageUrl: string | null;
  quantity: number;
  price: number;
  currencySymbol: string;
}

export interface DropshipReviewUiItem {
  id: number;
  name: string;
  imageUrl: string | null;
  quantity: number;
  purchasePrice: number;
  resellPrice: number;
  minResellPrice: number;
  currencySymbol: string;
}

export const DROPSHIP_CART_UI_MOCK_ITEMS: DropshipCartUiItem[] = [
  {
    id: 1,
    name: 'Premium Cotton T-Shirt — Black / L',
    imageUrl: null,
    quantity: 2,
    price: 520,
    currencySymbol: '৳',
  },
  {
    id: 2,
    name: 'Wireless Earbuds Pro — White',
    imageUrl: null,
    quantity: 1,
    price: 980,
    currencySymbol: '৳',
  },
];

export const DROPSHIP_REVIEW_UI_MOCK_ITEMS: DropshipReviewUiItem[] = [
  {
    id: 1,
    name: 'Premium Cotton T-Shirt — Black / L',
    imageUrl: null,
    quantity: 2,
    purchasePrice: 520,
    resellPrice: 850,
    minResellPrice: 650,
    currencySymbol: '৳',
  },
  {
    id: 2,
    name: 'Wireless Earbuds Pro — White',
    imageUrl: null,
    quantity: 1,
    purchasePrice: 980,
    resellPrice: 1450,
    minResellPrice: 1100,
    currencySymbol: '৳',
  },
];

export const DROPSHIP_CART_UI_MOCK_SHOP = {
  shop_id: 1,
  shop_name: 'Demo Dropship Store',
  currency_symbol: '৳',
};

export const DROPSHIP_UI_MOCK_CHARGES = {
  printCharge: 10,
  packingChargePerItem: 5,
  deliveryChargeMin: 60,
  deliveryChargeMax: 130,
  codPercent: 1,
};

export function formatDropshipUiMoney(amount: number, symbol = '৳') {
  return `${symbol}${Number(amount).toFixed(2)}`;
}
