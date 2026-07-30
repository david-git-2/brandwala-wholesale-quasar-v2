import type { ModuleGuide } from '../../types';

export const shopOrderStaffGuide: ModuleGuide = {
  id: 'shop_order_staff',
  title: { en: 'Shop & Orders (Staff)', bn: 'শপ ও অর্ডার (স্টাফ)' },
  caption: {
    en: 'Process orders, dropship, and settlements',
    bn: 'অর্ডার প্রসেস, ড্রপশিপ এবং সেটেলমেন্ট',
  },
  icon: 'ph ph-storefront',
  scopes: ['app'],
  audiences: ['admin', 'staff', 'viewer'],
  routeMatchers: [
    '/app/shop/dropship',
    '/app/shop/orders',
    '/app/shop/fulfillment',
  ],
  overview: {
    en: 'Staff use Shop & Orders to process dropship consignments, confirm costing, and settle courier remittances. Detailed page guides will be added per screen.',
    bn: 'স্টাফ শপ ও অর্ডার ব্যবহার করে ড্রপশিপ কনসাইনমেন্ট প্রসেস করে, কস্টিং নিশ্চিত করে এবং কুরিয়ার রেমিট্যান্স সেটেল করে। প্রতিটি স্ক্রিনের জন্য বিস্তারিত গাইড পরে যোগ হবে।',
  },
  workflows: [
    {
      id: 'open-dropship-desk',
      title: { en: 'Open the Dropship Desk', bn: 'ড্রপশিপ ডেস্ক খুলুন' },
      steps: [
        {
          en: 'Go to Shop → Dropship in the sidebar.',
          bn: 'সাইডবার থেকে Shop → Dropship এ যান।',
        },
        {
          en: 'Open an order to assign courier and advance status.',
          bn: 'কুরিয়ার অ্যাসাইন ও স্ট্যাটাস এগিয়ে নিতে একটি অর্ডার খুলুন।',
        },
        {
          en: 'Use Finance Hub for costing and remittance when the order is delivered.',
          bn: 'অর্ডার ডেলিভার হলে কস্টিং ও রেমিট্যান্সের জন্য Finance Hub ব্যবহার করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Finance Hub', bn: 'ফাইন্যান্স হাব' },
      definition: {
        en: 'The desk where delivered costing, courier remittance, and payouts are handled.',
        bn: 'ডেলিভার্ড কস্টিং, কুরিয়ার রেমিট্যান্স এবং পেআউট পরিচালনার ডেস্ক।',
      },
    },
    {
      term: { en: 'Remittance', bn: 'রেমিট্যান্স' },
      definition: {
        en: 'Recording cash the courier deposited for delivered COD orders.',
        bn: 'ডেলিভার্ড COD অর্ডারের জন্য কুরিয়ার জমা দেওয়া নগদ রেকর্ড করা।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why can I not remittance an order yet?',
        bn: 'কেন এখনো অর্ডারে রেমিট্যান্স করতে পারছি না?',
      },
      answer: {
        en: 'Usually delivered costing must be confirmed first. Open the order or Finance Hub and complete costing, then try remittance again.',
        bn: 'সাধারণত আগে ডেলিভার্ড কস্টিং নিশ্চিত করতে হয়। অর্ডার বা Finance Hub খুলে কস্টিং সম্পন্ন করুন, তারপর আবার রেমিট্যান্স চেষ্টা করুন।',
      },
    },
  ],
};
