import type { ModuleGuide } from '../../types';

export const shopOrderMerchantGuide: ModuleGuide = {
  id: 'shop_order_merchant',
  title: { en: 'Shop & Orders (Merchant)', bn: 'শপ ও অর্ডার (মার্চেন্ট)' },
  caption: {
    en: 'Place orders and track deliveries',
    bn: 'অর্ডার দিন এবং ডেলিভারি ট্র্যাক করুন',
  },
  icon: 'ph ph-shopping-bag',
  scopes: ['shop'],
  audiences: ['merchant'],
  routeMatchers: ['/shop/browse', '/shop/orders', '/shop/cart', '/shop/checkout'],
  overview: {
    en: 'As a merchant you browse the catalog, set recipient selling prices, checkout to a recipient, and track order status. Money details appear on your wallet page when enabled.',
    bn: 'মার্চেন্ট হিসেবে আপনি ক্যাটালগ ব্রাউজ করেন, প্রাপকের বিক্রয় মূল্য সেট করেন, প্রাপকের কাছে চেকআউট করেন এবং অর্ডার স্ট্যাটাস ট্র্যাক করেন। ওয়ালেট চালু থাকলে অর্থের বিবরণ ওয়ালেট পৃষ্ঠায় দেখা যায়।',
  },
  workflows: [
    {
      id: 'place-order',
      title: { en: 'Place a dropship order', bn: 'ড্রপশিপ অর্ডার দিন' },
      steps: [
        {
          en: 'Browse the shop catalog and add items to cart.',
          bn: 'শপ ক্যাটালগ ব্রাউজ করে কার্টে আইটেম যোগ করুন।',
        },
        {
          en: 'Set the recipient selling price where allowed.',
          bn: 'অনুমোদিত হলে প্রাপকের বিক্রয় মূল্য সেট করুন।',
        },
        {
          en: 'Enter recipient shipping details and submit the order.',
          bn: 'প্রাপকের শিপিং বিবরণ লিখে অর্ডার সাবমিট করুন।',
        },
        {
          en: 'Track progress under Orders.',
          bn: 'Orders এর অধীনে অগ্রগতি ট্র্যাক করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Selling price', bn: 'বিক্রয় মূল্য' },
      definition: {
        en: 'The amount your recipient pays (COD). Your profit is selling price minus wholesale cost.',
        bn: 'আপনার প্রাপক যে পরিমাণ পরিশোধ করেন (COD)। আপনার লাভ = বিক্রয় মূল্য − হোলসেল খরচ।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why can I not set a price below a certain amount?',
        bn: 'কেন নির্দিষ্ট পরিমাণের নিচে মূল্য সেট করতে পারি না?',
      },
      answer: {
        en: 'The shop enforces a minimum dropship price (floor) set by the supplier.',
        bn: 'শপ সরবরাহকারীর নির্ধারিত ন্যূনতম ড্রপশিপ মূল্য (ফ্লোর) প্রয়োগ করে।',
      },
    },
  ],
};
