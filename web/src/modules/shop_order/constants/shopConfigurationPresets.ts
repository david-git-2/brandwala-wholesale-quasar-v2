import type { ShopType, ShopOrderMode } from '../types';

export type ShopConfigurationPresetId = 'A' | 'B' | 'C' | 'D' | 'E' | 'F';

export interface ShopConfigurationPreset {
  id: ShopConfigurationPresetId;
  name: string;
  nameBn: string;
  description: string;
  descriptionBn: string;
  downstream: string;
  fields: {
    shop_type: ShopType;
    order_mode: ShopOrderMode;
    is_negotiable: boolean;
    pricing_method: 'direct_cost' | 'markup';
    markup_percentage: number;
    quantity_display_mode: 'original' | 'custom_override';
    show_stock_quantity: boolean;
  };
}

export const SHOP_CONFIGURATION_PRESETS: ShopConfigurationPreset[] = [
  {
    id: 'A',
    name: 'Scenario A — Supplier Catalog / Procurement Portal',
    nameBn: 'সিনারিও A — সাপ্লায়ার ক্যাটালগ / ক্রয় পোর্টাল',
    description: "A B2B procurement portal where the customer browses a supplier's catalog for products not yet in local inventory. Customers with negotiation permission can counter-offer on line prices.",
    descriptionBn: 'একটি B2B ক্রয় পোর্টাল যেখানে কাস্টমার স্থানীয় স্টকে নেই এমন পণ্যের জন্য সাপ্লায়ারের ক্যাটালগ ব্রাউজ করে। দরকষাকষির পারমিশন থাকলে কাস্টমার লাইন প্রাইসে দরকষাকষি করতে পারে।',
    downstream: 'Negotiate → placed → procurement pull',
    fields: {
      shop_type: 'vendor_catalog',
      order_mode: 'procurement_intent',
      is_negotiable: true,
      pricing_method: 'direct_cost',
      markup_percentage: 0,
      quantity_display_mode: 'original',
      show_stock_quantity: true,
    },
  },
  {
    id: 'B',
    name: 'Scenario B — Direct Catalog Order',
    nameBn: 'সিনারিও B — সরাসরি ক্যাটালগ অর্ডার',
    description: 'A supplier catalog where customers submit intent-to-buy requests without negotiating. Staff review each order, set final prices, confirm with the customer, then place the order.',
    descriptionBn: 'একটি সাপ্লায়ার ক্যাটালগ যেখানে কাস্টমার দরকষাকষি ছাড়াই ক্রয়ের অনুরোধ জমা দেয়। স্টাফ প্রতিটি অর্ডার পর্যালোচনা করে চূড়ান্ত দাম নির্ধারণ করে এবং নিশ্চিত করে।',
    downstream: 'Staff prices → confirmed → placed → procurement pull',
    fields: {
      shop_type: 'vendor_catalog',
      order_mode: 'procurement_intent',
      is_negotiable: false,
      pricing_method: 'direct_cost',
      markup_percentage: 0,
      quantity_display_mode: 'original',
      show_stock_quantity: true,
    },
  },
  {
    id: 'C',
    name: 'Scenario C — Retail Storefront (markup)',
    nameBn: 'সিনারিও C — খুচরা দোকান (মার্কআপ সহ)',
    description: 'A stock-backed retail storefront where checkout prices are calculated by applying a percentage markup over the allocation cost. Customers add items to cart, confirm, and receive an invoice.',
    descriptionBn: 'একটি স্টক-ব্যাকড খুচরা দোকান যেখানে চেকআউট দাম অ্যালোকেশন খরচের উপর পার্সেন্টেজ মার্কআপ যোগ করে গণনা করা হয়। কাস্টমার কার্ট থেকে সরাসরি কেনাকাটা করে।',
    downstream: 'confirmed → fulfilled → global_invoice (retail)',
    fields: {
      shop_type: 'fixed_price',
      order_mode: 'checkout_fixed',
      is_negotiable: false,
      pricing_method: 'markup',
      markup_percentage: 25,
      quantity_display_mode: 'original',
      show_stock_quantity: true,
    },
  },
  {
    id: 'D',
    name: 'Scenario D — Retail Storefront (direct cost)',
    nameBn: 'সিনারিও D — খুচরা দোকান (সরাসরি খরচ)',
    description: 'A stock-backed retail storefront where checkout prices display the baseline allocation cost directly — no markup applied. Useful for internal transfers or cost-recovery sales.',
    descriptionBn: 'একটি স্টক-ব্যাকড খুচরা দোকান যেখানে চেকআউট দাম সরাসরি বেসলাইন অ্যালোকেশন খরচে দেখানো হয় — কোনো মার্কআপ প্রয়োগ হয় না। অভ্যন্তরীণ স্থানান্তরের জন্য উপযোগী।',
    downstream: 'confirmed → fulfilled → global_invoice (retail)',
    fields: {
      shop_type: 'fixed_price',
      order_mode: 'checkout_fixed',
      is_negotiable: false,
      pricing_method: 'direct_cost',
      markup_percentage: 0,
      quantity_display_mode: 'original',
      show_stock_quantity: true,
    },
  },
  {
    id: 'E',
    name: 'Scenario E — Wholesale Account Shop',
    nameBn: 'সিনারিও E — পাইকারি অ্যাকাউন্ট দোকান',
    description: 'An account-based wholesale storefront for registered trade customers. Orders follow the wholesale invoice path instead of retail checkout — suitable for B2B buyers with credit terms.',
    descriptionBn: 'নিবন্ধিত ট্রেড কাস্টমারদের জন্য অ্যাকাউন্ট-ভিত্তিক পাইকারি দোকান। অর্ডার খুচরা চেকআউটের পরিবর্তে পাইকারি ইনভয়েস পথ অনুসরণ করে — B2B ক্রেতাদের জন্য উপযুক্ত।',
    downstream: 'global_invoice (wholesale)',
    fields: {
      shop_type: 'fixed_price',
      order_mode: 'checkout_wholesale',
      is_negotiable: false,
      pricing_method: 'direct_cost',
      markup_percentage: 0,
      quantity_display_mode: 'original',
      show_stock_quantity: true,
    },
  },
  {
    id: 'F',
    name: 'Scenario F — Dropship Reseller Portal',
    nameBn: 'সিনারিও F — ড্রপশিপ রিসেলার পোর্টাল',
    description: 'A reseller portal where the buyer sets their own customer-facing sell price on each line (subject to a minimum sell price floor). The storefront shows both suggested and floor prices. Supports configuring default shop charges (COD %, delivery, print, packing) which auto-apply during checkout.',
    descriptionBn: 'একটি রিসেলার পোর্টাল যেখানে ক্রেতা প্রতিটি লাইনে নিজের বিক্রয়মূল্য সেট করতে পারে (ন্যূনতম বিক্রয়মূল্য ফ্লোর সাপেক্ষে)। স্টোরফ্রন্টে দুটি মূল্যই দেখানো হয়। ডিফল্ট শপ চার্জ (COD %, ডেলিভারি, প্রিন্ট, প্যাকিং) কনফিগার করা সমর্থন করে যা চেকআউটের সময় স্বয়ংক্রিয়ভাবে প্রয়োগ হয়।',
    downstream: 'global_invoice type dropship (dual amounts)',
    fields: {
      shop_type: 'dropship',
      order_mode: 'checkout_fixed',
      is_negotiable: false,
      pricing_method: 'direct_cost',
      markup_percentage: 0,
      quantity_display_mode: 'original',
      show_stock_quantity: true,
    },
  },
];

export function getPresetById(id: ShopConfigurationPresetId): ShopConfigurationPreset | undefined {
  return SHOP_CONFIGURATION_PRESETS.find((p) => p.id === id);
}

export function getAllowedOrderModes(shopType: ShopType): ShopOrderMode[] {
  switch (shopType) {
    case 'vendor_catalog':
      return ['procurement_intent'];
    case 'fixed_price':
      return ['checkout_fixed', 'checkout_wholesale'];
    case 'dropship':
      return ['checkout_fixed'];
    default:
      return [];
  }
}

export function applyPresetToForm(form: any, presetId: ShopConfigurationPresetId): void {
  const preset = getPresetById(presetId);
  if (!preset) return;

  form.shop_type = preset.fields.shop_type;
  form.order_mode = preset.fields.order_mode;
  form.is_negotiable = preset.fields.is_negotiable;
  form.pricing_method = preset.fields.pricing_method;
  form.markup_percentage = preset.fields.markup_percentage;
  form.quantity_display_mode = preset.fields.quantity_display_mode;
  form.show_stock_quantity = preset.fields.show_stock_quantity;

  // Defensive dropship constraints
  if (form.shop_type === 'dropship') {
    form.is_negotiable = false;
    form.order_mode = 'checkout_fixed';
  }
}

export function detectPresetFromShop(shop: any): ShopConfigurationPresetId | null {
  if (!shop) return null;

  for (const preset of SHOP_CONFIGURATION_PRESETS) {
    const isE = preset.id === 'E';
    const matches =
      shop.shop_type === preset.fields.shop_type &&
      shop.order_mode === preset.fields.order_mode &&
      (shop.pricing_method ?? 'direct_cost') === preset.fields.pricing_method &&
      (shop.markup_percentage ?? 0) === preset.fields.markup_percentage &&
      (shop.quantity_display_mode ?? 'original') === preset.fields.quantity_display_mode &&
      (shop.show_stock_quantity ?? true) === preset.fields.show_stock_quantity &&
      (isE || shop.is_negotiable === preset.fields.is_negotiable);

    if (matches) {
      return preset.id;
    }
  }
  return null;
}

export function formMatchesPreset(form: any, presetId: ShopConfigurationPresetId): boolean {
  if (!form) return false;
  const preset = getPresetById(presetId);
  if (!preset) return false;

  const isE = presetId === 'E';
  return (
    form.shop_type === preset.fields.shop_type &&
    form.order_mode === preset.fields.order_mode &&
    (form.pricing_method ?? 'direct_cost') === preset.fields.pricing_method &&
    (form.markup_percentage ?? 0) === preset.fields.markup_percentage &&
    (form.quantity_display_mode ?? 'original') === preset.fields.quantity_display_mode &&
    (form.show_stock_quantity ?? true) === preset.fields.show_stock_quantity &&
    (isE || form.is_negotiable === preset.fields.is_negotiable)
  );
}
