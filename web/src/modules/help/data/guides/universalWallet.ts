import type { ModuleGuide } from '../../types';

export const universalWalletGuide: ModuleGuide = {
  id: 'universal_wallet',
  title: { en: 'Universal Wallet', bn: 'ইউনিভার্সাল ওয়ালেট' },
  caption: {
    en: 'Balances, ledgers, and payouts',
    bn: 'ব্যালেন্স, লেজার এবং পেআউট',
  },
  icon: 'ph ph-wallet',
  scopes: ['app'],
  audiences: ['admin', 'staff', 'viewer'],
  routeMatchers: ['/app/wallet'],
  overview: {
    en: 'Universal Wallet shows balances and ledger activity for tenants, merchants, couriers, and other parties. Use it to review money movement after shop settlements.',
    bn: 'ইউনিভার্সাল ওয়ালেট টেন্যান্ট, মার্চেন্ট, কুরিয়ার এবং অন্যান্য পক্ষের ব্যালেন্স ও লেজার কার্যক্রম দেখায়। শপ সেটেলমেন্টের পর অর্থ চলাচল পর্যালোচনা করতে এটি ব্যবহার করুন।',
  },
  workflows: [
    {
      id: 'review-balance',
      title: { en: 'Review a balance', bn: 'ব্যালেন্স পর্যালোচনা করুন' },
      steps: [
        {
          en: 'Open Universal Wallet from the sidebar.',
          bn: 'সাইডবার থেকে Universal Wallet খুলুন।',
        },
        {
          en: 'Select the party type and profile you need.',
          bn: 'প্রয়োজনীয় পক্ষের ধরন ও প্রোফাইল নির্বাচন করুন।',
        },
        {
          en: 'Scan recent ledger lines for credits and deductions.',
          bn: 'ক্রেডিট ও ডিডাকশনের জন্য সাম্প্রতিক লেজার লাইন দেখুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Pending balance', bn: 'পেন্ডিং ব্যালেন্স' },
      definition: {
        en: 'Profit or credit recorded but not yet paid out.',
        bn: 'রেকর্ড করা লাভ বা ক্রেডিট যা এখনো পেআউট হয়নি।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why does a balance look different from an order screen?',
        bn: 'কেন ব্যালেন্স অর্ডার স্ক্রিন থেকে আলাদা দেখায়?',
      },
      answer: {
        en: 'Order screens show ops status. Wallet reflects confirmed money events after costing, remittance, or payout steps.',
        bn: 'অর্ডার স্ক্রিন অপারেশন স্ট্যাটাস দেখায়। ওয়ালেট কস্টিং, রেমিট্যান্স বা পেআউটের পর নিশ্চিত অর্থ ইভেন্ট প্রতিফলিত করে।',
      },
    },
  ],
};
