import type { ModuleGuide } from '../../types';

export const shopOrderStaffGuide: ModuleGuide = {
  id: 'shop_order_staff',
  title: { en: 'Shop & Orders (Staff)', bn: 'শপ ও অর্ডার (স্টাফ)' },
  caption: {
    en: 'Process orders, shipping, and dropship settlement',
    bn: 'অর্ডার প্রসেস, শিপিং এবং ড্রপশিপ সেটেলমেন্ট',
  },
  icon: 'ph ph-storefront',
  scopes: ['app'],
  audiences: ['admin', 'staff', 'viewer'],
  routeMatchers: [
    '/app/shop/orders',
    '/app/shop/shipping',
    '/app/shop/dropship',
    '/app/shop/shops',
  ],
  overview: {
    en: 'Staff use Shops to set up storefronts, Orders to process every shop type (including dropship), and Shipping for shared couriers and COD remittance.',
    bn: 'স্টাফ শপস দিয়ে স্টোরফ্রন্ট সেটআপ করে, অর্ডারস দিয়ে সব ধরনের শপ অর্ডার (ড্রপশিপসহ) প্রসেস করে, এবং শিপিং দিয়ে শেয়ার্ড কুরিয়ার ও COD রেমিট্যান্স করে।',
  },
  workflows: [
    {
      id: 'process-orders',
      title: { en: 'Process an order', bn: 'অর্ডার প্রসেস করুন' },
      steps: [
        {
          en: 'Go to Shop & Order → Orders in the sidebar.',
          bn: 'সাইডবার থেকে Shop & Order → Orders এ যান।',
        },
        {
          en: 'Filter by shop type if you only want dropship (or retail) orders.',
          bn: 'শুধু ড্রপশিপ (বা খুচরা) দেখতে শপ টাইপ ফিল্টার ব্যবহার করুন।',
        },
        {
          en: 'Open the order. Dropship extra steps (recipient print, B2B invoice, payout) show on that page. Courier pick is the same block used for retail delivery.',
          bn: 'অর্ডার খুলুন। ড্রপশিপ অতিরিক্ত ধাপ সেই পেজেই আসে। কুরিয়ার পিক খুচরা ডেলিভারির মতোই।',
        },
      ],
    },
    {
      id: 'shipping-setup',
      title: { en: 'Set up couriers', bn: 'কুরিয়ার সেটআপ' },
      steps: [
        {
          en: 'Go to Shop & Order → Shipping.',
          bn: 'সাইডবার থেকে Shop & Order → Shipping এ যান।',
        },
        {
          en: 'Edit courier COD and return rules. Use COD remittance after delivery.',
          bn: 'কুরিয়ার COD ও রিটার্ন নিয়ম সম্পাদনা করুন। ডেলিভারির পর COD রেমিট্যান্স ব্যবহার করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Shipping', bn: 'শিপিং' },
      definition: {
        en: 'Shared courier catalog and COD money-in. Not dropship-only — retail delivery uses it too.',
        bn: 'শেয়ার্ড কুরিয়ার ক্যাটালগ এবং COD টাকা। শুধু ড্রপশিপ নয় — খুচরা ডেলিভারিও এটি ব্যবহার করে।',
      },
    },
    {
      term: { en: 'Dropship', bn: 'ড্রপশিপ' },
      definition: {
        en: 'A shop type (reseller + two prices + payout), not a separate menu.',
        bn: 'একটি শপ ধরন (রিসেলার + দুই দাম + পেআউট), আলাদা মেনু নয়।',
      },
    },
  ],
  faqs: [],
};
