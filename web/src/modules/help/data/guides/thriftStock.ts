import type { ModuleGuide } from '../../types';

export const thriftStockGuide: ModuleGuide = {
  id: 'thrift_stock',
  title: { en: 'Thrift Stock Management', bn: 'থ্রিফ্ট স্টক ব্যবস্থাপনা' },
  caption: {
    en: 'Manage thrift inventory items, cost breakdowns, status, and tag printing',
    bn: 'থ্রিফ্ট ইনভেন্টরি আইটেম, খরচ বিভাজন, স্ট্যাটাস এবং ট্যাগ প্রিন্ট পরিচালনা করুন',
  },
  icon: 'ph ph-package',
  scopes: ['app'],
  audiences: ['admin', 'staff'],
  routeMatchers: ['/app/thrift/stock'],
  overview: {
    en: 'Thrift Stock Management allows staff and tenant administrators to register thrift inventory, monitor real-time cost breakdown allocations, edit item attributes inline, track stock status, and export or print inventory tags.',
    bn: 'থ্রিফ্ট স্টক ম্যানেজমেন্টের মাধ্যমে স্টাফ ও টেন্যান্ট অ্যাডমিনিস্ট্রেটররা থ্রিফ্ট ইনভেন্টরি নিবন্ধন করতে, রিয়েল-টাইম খরচের হিসাব দেখতে, সরাসরি আইটেমের তথ্য সম্পাদনা করতে, স্টকের অবস্থা ট্র্যাক করতে এবং ইনভেন্টরি ট্যাগ এক্সপোর্ট বা প্রিন্ট করতে পারেন।',
  },
  workflows: [
    {
      id: 'register-stock',
      title: {
        en: 'Register a new thrift stock item',
        bn: 'নতুন থ্রিফ্ট স্টক আইটেম নিবন্ধন করুন',
      },
      steps: [
        {
          en: 'Click the "Register Stock" button in the page header.',
          bn: 'পেজ হেডারে থাকা "Register Stock" বাটনে ক্লিক করুন।',
        },
        {
          en: 'Select the associated Shipment and enter item details (Code, Name, Category, Section, Condition).',
          bn: 'সংশ্লিষ্ট শিপমেন্ট নির্বাচন করুন এবং আইটেমের বিবরণ (কোড, নাম, ক্যাটাগরি, সেকশন, কন্ডিশন) লিখুন।',
        },
        {
          en: 'Enter origin unit price and pricing overrides if necessary, then click "Save" to generate stock record.',
          bn: 'মূল কেনা দাম এবং প্রয়োজনে মূল্যের ওভাররাইড প্রদান করুন, তারপর স্টক রেকর্ড তৈরি করতে "Save" বাটনে ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'inline-edit-costing',
      title: {
        en: 'Inline edit & cost breakdown management',
        bn: 'ইনলাইন এডিট ও খরচের হিসাব পরিচালনা',
      },
      steps: [
        {
          en: 'Double-click or tap on editable table fields (e.g. Origin Unit Price, Item Markup %, Listed Price).',
          bn: 'সম্পাদনাযোগ্য টেবিল ফিল্ডে (যেমন কেনা দাম, মার্কআপ %, তালিকাভুক্ত মূল্য) ডাবল ক্লিক বা ট্যাপ করুন।',
        },
        {
          en: 'Enter the updated value and press "Enter" or click outside to apply inline changes instantly.',
          bn: 'আপডেট করা মানটি দিন এবং ইনলাইন পরিবর্তন তাত্ক্ষণিকভাবে প্রয়োগ করতে "Enter" চাপুন বা বাইরে ক্লিক করুন।',
        },
        {
          en: 'Expand or hover cost breakdown badges to inspect shipment cost allocation per item.',
          bn: 'প্রতি আইটেমে শিপমেন্টের খরচের বণ্টন পরীক্ষা করতে কস্ট ব্রেকডাউন ব্যাজ সংপ্রসারণ বা হোভার করুন।',
        },
      ],
    },
    {
      id: 'filter-export-print',
      title: {
        en: 'Filter, export CSV, & print barcode tags',
        bn: 'ফিল্টার, সিএসভি এক্সপোর্ট এবং বারকোড ট্যাগ প্রিন্ট',
      },
      steps: [
        {
          en: 'Use the top search bar or open the Filter Drawer to filter by status or condition.',
          bn: 'অবস্থা বা কন্ডিশন অনুযায়ী ফিল্টার করতে উপরের সার্চ বার ব্যবহার করুন বা ফিল্টার ড্রয়ার খুলুন।',
        },
        {
          en: 'Click "Download CSV" on the toolbar to export the current filtered inventory.',
          bn: 'বর্তমান ফিল্টার করা ইনভেন্টরি ফাইল সংরক্ষণ করতে টুলবারের "Download CSV" এ ক্লিক করুন।',
        },
        {
          en: 'Click the barcode icon on any row preview barcode or select items for bulk tag printing.',
          bn: 'বারকোড প্রাকদর্শন করতে যেকোনো সারির বারকোড আইকনে ক্লিক করুন বা বাল্ক ট্যাগ প্রিন্ট করতে আইটেম সিলেক্ট করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Origin Unit Price', bn: 'অরিজিন ইউনিট প্রাইজ' },
      definition: {
        en: 'The base purchase price of the item before shipment cost allocations and markups.',
        bn: 'শিপমেন্ট কস্ট বণ্টন এবং মার্কআপ যোগ করার পূর্বে আইটেমটির মূল ক্রয়মূল্য।',
      },
    },
    {
      term: { en: 'Cost Breakdown', bn: 'কস্ট ব্রেকডাউন' },
      definition: {
        en: 'Dynamic breakdown of land cost, shipping overheads, customs, and allocated shipment expenses per stock item.',
        bn: 'প্রতি স্টক আইটেমে ল্যান্ড কস্ট, শিপিং ওভারহেড, কাস্টমস এবং বরাদ্দকৃত শিপমেন্ট খরচের ডায়নামিক হিসাব।',
      },
    },
    {
      term: { en: 'Item Markup %', bn: 'আইটেম মার্কআপ %' },
      definition: {
        en: 'Custom percentage added above the base landed cost to calculate final suggested selling price.',
        bn: 'চূড়ান্ত প্রস্তাবিত বিক্রয় মূল্য নির্ধারণের জন্য বেস ল্যান্ডেড কস্টের সাথে যোগ করা কাস্টম শতাংশ।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why is the suggested price different from listed unit price?',
        bn: 'প্রস্তাবিত মূল্য এবং তালিকাভুক্ত ইউনিটের বিক্রয় মূল্যের মধ্যে পার্থক্য কেন?',
      },
      answer: {
        en: 'Suggested price is automatically computed based on landed cost and markup %, while Listed Unit Price can be manually overridden for specific promotional items.',
        bn: 'প্রস্তাবিত মূল্যটি ল্যান্ডেড কস্ট এবং মার্কআপ % এর ভিত্তিতে স্বয়ংক্রিয়ভাবে হিসাব করা হয়, যেখানে তালিকাভুক্ত বিক্রয় মূল্যটি নির্দিষ্ট প্রমোশন বা বিশেষ প্রয়োজনে ম্যানুয়ালি পরিবর্তন করা যায়।',
      },
    },
    {
      question: {
        en: 'How do I bulk print stock tags?',
        bn: 'আমি কীভাবে একসাথে অনেক স্টকের ট্যাগ প্রিন্ট করব?',
      },
      answer: {
        en: 'Select the desired items using the row checkboxes and use the print tags option, or click the barcode preview icon on individual items to view and copy barcodes.',
        bn: 'সারি চেকবক্সগুলো ব্যবহার করে কাঙ্ক্ষিত আইটেমগুলো নির্বাচন করুন এবং প্রিন্ট ট্যাগ অপশনটি ব্যবহার করুন, অথবা একক বারকোড দেখতে এবং কপি করতে আইটেমের বারকোড প্রিভিউ আইকনে ক্লিক করুন।',
      },
    },
  ],
};
