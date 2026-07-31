import type { ModuleGuide } from '../../types';

export const thriftShipmentGuide: ModuleGuide = {
  id: 'thrift_shipment',
  title: {
    en: 'Thrift Shipments & Landed Costing',
    bn: 'থ্রিফ্ট শিপমেন্ট ও ল্যান্ডেড কস্টিং',
  },
  caption: {
    en: 'Manage wholesale shipments, cargo costs, landed unit pricing, and currency conversions',
    bn: 'হোলসেল শিপমেন্ট, কার্গো খরচ, ল্যান্ডেড ইউনিট প্রাইসিং এবং কারেন্সি কনভার্সন পরিচালনা করুন',
  },
  icon: 'ph ph-truck',
  scopes: ['app'],
  audiences: ['admin', 'staff'],
  routeMatchers: ['/app/thrift/shipments'],
  overview: {
    en: 'The Thrift Shipments module lets wholesale managers track imported thrift shipments, configure exchange rates, record cargo weight and operating costs (labor, transport, washing), and view real-time landed cost breakdowns for items in each batch.',
    bn: 'থ্রিফ্ট শিপমেন্ট মডিউলের মাধ্যমে হোলসেল ম্যানেজাররা ইমপোর্ট করা থ্রিফ্ট শিপমেন্ট ট্র্যাক করতে পারেন, এক্সচেঞ্জ রেট কনফিগার করতে পারেন, কার্গো ওজন ও অপারেটিং খরচ (লেবার, ট্রান্সপোর্ট, ওয়াশিং) রেকর্ড করতে পারেন এবং প্রতিটি ব্যাচের আইটেমগুলির জন্য রিয়েল-টাইম ল্যান্ডেড কস্ট ব্রেকডাউন দেখতে পারেন।',
  },
  workflows: [
    {
      id: 'create_shipment',
      title: {
        en: 'Creating a New Shipment',
        bn: 'নতুন শিপমেন্ট তৈরি করা',
      },
      steps: [
        {
          en: 'Click the Add Shipment button in the top right header.',
          bn: 'হেডারের উপরে ডানের Add Shipment বাটনে ক্লিক করুন।',
        },
        {
          en: 'Enter a descriptive Shipment Name for the batch (e.g. Winter Clothes Batch #1).',
          bn: 'ব্যাচের জন্য একটি উপযুক্ত Shipment Name দিন (যেমনঃ Winter Clothes Batch #1)।',
        },
        {
          en: 'Select the Purchase Currency (e.g., USD, CNY) and Cost Currency (e.g., BDT) used for acquiring the inventory.',
          bn: 'ইনভেন্টরি কেনার কাজে ব্যবহৃত Purchase Currency (যেমনঃ USD, CNY) এবং Cost Currency (যেমনঃ BDT) নির্বাচন করুন।',
        },
        {
          en: 'Input Product Conversion Rate, Cargo Rate, total weight in kg, and operating costs (Labor, Transportation, Washing).',
          bn: 'প্রোডাক্ট কনভার্সন রেট, কার্গো রেট, মোট কার্গো ওজন (কেজি) এবং অপারেটিং খরচ (লেবার, ট্রান্সপোর্টেশন, ওয়াশিং) এন্ট্রি করুন।',
        },
        {
          en: 'Set Default Markup (%) and click Save Shipment to record.',
          bn: 'Default Markup (%) সেট করে সেভ করতে Save Shipment এ ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'configure_shipment_costs',
      title: {
        en: 'Managing Shipment Costs & Exchange Rates',
        bn: 'শিপমেন্ট খরচ ও এক্সচেঞ্জ রেট পরিচালনা করা',
      },
      steps: [
        {
          en: 'Click on a shipment name from the table to open its Shipment Details page.',
          bn: 'শিপমেন্ট ডিটেইলস পেজ খুলতে শিপমেন্ট টেবিল থেকে শিপমেন্টের নামের ওপর ক্লিক করুন।',
        },
        {
          en: 'Use the left Cost Inputs panel to update total cargo weight, cargo rate, conversion rates, or labor/transport/washing costs.',
          bn: 'মোট কার্গো ওজন, কার্গো রেট, কনভার্সন রেট বা লেবার/ট্রান্সপোর্ট/ওয়াশিং খরচ আপডেট করতে বামপাশের Cost Inputs প্যানেল ব্যবহার করুন।',
        },
        {
          en: 'Click Save Shipment Costs to persist rate changes and automatically recalculate landed costs across all stocks.',
          bn: 'রেট পরিবর্তন সংরক্ষণ এবং সমস্ত স্টকের ল্যান্ডেড কস্ট স্বয়ংক্রিয়ভাবে পুনরায় গণনা করতে Save Shipment Costs-এ ক্লিক করুন।',
        },
        {
          en: 'Review the Cost Breakdown summary card at the bottom to audit per-unit cargo share, operating share, and total expenses.',
          bn: 'প্রতি ইউনিটের কার্গো শেয়ার, অপারেটিং শেয়ার এবং মোট খরচ অডিট করতে নিচে অবস্থিত Cost Breakdown সামারি কার্ড রিভিউ করুন।',
        },
      ],
    },
    {
      id: 'item_landed_costs_pricing',
      title: {
        en: 'Customizing Item Prices, Markups & Measurements',
        bn: 'আইটেম প্রাইস, মার্কআপ ও মেজারমেন্ট কাস্টমাইজ করা',
      },
      steps: [
        {
          en: 'View all stock items assigned to the shipment in the main Shipment Items table.',
          bn: 'মূল Shipment Items টেবিলে এই শিপমেন্টের সাথে যুক্ত সকল স্টক আইটেম দেখুন।',
        },
        {
          en: 'Click the Info icon next to Landed Cost to inspect the item landed cost breakdown popup.',
          bn: 'আইটেমের ল্যান্ডেড কস্ট ব্রেকডাউন পপআপ দেখতে Landed Cost-এর পাশে Info আইকনে ক্লিক করুন।',
        },
        {
          en: 'Edit Listed Unit Price directly in the table row to set a manual selling price and lock it from auto-recalculations.',
          bn: 'ম্যানুয়াল বিক্রয়মূল্য সেট করতে এবং স্বয়ংক্রিয় পুনঃগণনা বন্ধ করতে টেবিল রো-তে সরাসরি Listed Unit Price এডিট করুন।',
        },
        {
          en: 'Click Measurements to update garment chest, length, sleeve, and shoulder dimensions.',
          bn: 'পোশাকের বুক, দৈর্ঘ্য, হাতা এবং কাঁধের মাপ আপডেট করতে Measurements-এ ক্লিক করুন।',
        },
        {
          en: 'Use the Columns dropdown in the toolbar to show or hide specific cost breakdown columns.',
          bn: 'নির্দিষ্ট কস্ট ব্রেকডাউন কলাম হাইড বা শো করতে টুলবারের Columns ড্রপডাউন ব্যবহার করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Purchase Currency', bn: 'পারচেজ কারেন্সি' },
      definition: {
        en: 'The currency used when purchasing the stock items from foreign or local suppliers.',
        bn: 'বিদেশি বা স্থানীয় সরবরাহকারীদের থেকে স্টক কেনার সময় ব্যবহৃত কারেন্সি।',
      },
    },
    {
      term: { en: 'Cost Currency', bn: 'কস্ট কারেন্সি' },
      definition: {
        en: 'The base currency used for calculating final landed costs and local inventory pricing.',
        bn: 'চূড়ান্ত ল্যান্ডেড কস্ট এবং স্থানীয় ইনভেন্টরি মূল্য নির্ধারণের জন্য ব্যবহৃত কারেন্সি।',
      },
    },
    {
      term: { en: 'Cargo Conversion Rate', bn: 'কার্গো কনভার্সন রেট' },
      definition: {
        en: 'Exchange rate multiplier applied to convert cargo shipping charges into the base cost currency.',
        bn: 'কার্গো শিপিং খরচকে বেস কস্ট কারেন্সিতে রূপান্তর করার জন্য ব্যবহৃত এক্সচেঞ্জ রেট মাল্টিপ্লায়ার।',
      },
    },
    {
      term: { en: 'Product Conversion Rate', bn: 'প্রোডাক্ট কনভার্সন রেট' },
      definition: {
        en: 'Exchange rate multiplier used to convert purchase unit prices into the base cost currency.',
        bn: 'ক্রয়মূল্যকে বেস কস্ট কারেন্সিতে রূপান্তর করার জন্য ব্যবহৃত এক্সচেঞ্জ রেট মাল্টিপ্লায়ার।',
      },
    },
    {
      term: { en: 'Landed Unit Cost', bn: 'ল্যান্ডেড ইউনিট কস্ট' },
      definition: {
        en: 'The true final cost of an item including product price, per-unit cargo share, per-unit operating costs, and extra expenses (e.g. tag/sticker/washing).',
        bn: 'একটি আইটেমের প্রকৃত চূড়ান্ত খরচ যার মধ্যে প্রোডাক্ট মূল্য, প্রতি ইউনিটের কার্গো শেয়ার, অপারেটিং খরচ এবং অতিরিক্ত খরচ (যেমনঃ ট্যাগ/স্টিকার/ওয়াশিং) অন্তর্ভুক্ত।',
      },
    },
    {
      term: { en: 'Default Markup (%)', bn: 'ডিফল্ট মার্কআপ (%)' },
      definition: {
        en: 'Percentage markup automatically applied onto landed cost to calculate suggested selling prices for stock items.',
        bn: 'স্টক আইটেমের প্রস্তাবিত বিক্রয়মূল্য নির্ধারণের জন্য ল্যান্ডেড কস্টের ওপর স্বয়ংক্রিয়ভাবে হিসাব করা মার্কআপ শতাংশ।',
      },
    },
    {
      term: { en: 'Manual Price Lock', bn: 'ম্যানুয়াল প্রাইস লক' },
      definition: {
        en: 'When Listed Sell Price is manually edited on a stock item, it locks the price so future shipment cost recalculations do not overwrite it.',
        bn: 'যখন কোনো স্টক আইটেমের Listed Sell Price ম্যানুয়ালি এডিট করা হয়, এটি প্রাইস লক করে দেয় যাতে ভবিষ্যতে শিপমেন্ট কস্টের পুনঃগণনা এটিকে ওভাররাইট না করে।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'How are operating costs distributed across items in a shipment?',
        bn: 'একটি শিপমেন্টের পরিচালন খরচ কীভাবে আইটেমগুলির মধ্যে বন্টিত হয়?',
      },
      answer: {
        en: 'Total cargo cost, labor, transportation, and washing costs are shared evenly across all items (U = total inventory count) or proportional cargo weight to establish landed unit costs.',
        bn: 'মোট কার্গো খরচ, লেবার, ট্রান্সপোর্টেশন এবং ওয়াশিং খরচ সকল আইটেমের (U = মোট ইনভেন্টরি সংখ্যা) মধ্যে সমানভাবে বা কার্গো ওজনের আনুপাতিক হারে ল্যান্ডেড কস্ট নির্ধারণে বন্টিত হয়।',
      },
    },
    {
      question: {
        en: 'What happens when I click Save Shipment Costs in Shipment Details?',
        bn: 'শিপমেন্ট ডিটেইলসে Save Shipment Costs এ ক্লিক করলে কী ঘটে?',
      },
      answer: {
        en: 'Saving shipment costs updates the batch rates and recalculates landed costs for all items. Non-locked items will automatically update their listed selling prices based on default markup.',
        bn: 'শিপমেন্ট কস্ট সেভ করলে ব্যাচের রেট আপডেট হয় এবং সকল আইটেমের ল্যান্ডেড কস্ট পুনর্গণনা করা হয়। আন-লক করা আইটেমগুলির বিক্রয়মূল্য স্বয়ংক্রিয়ভাবে ডিফল্ট মার্কআপ অনুযায়ী আপডেট হবে।',
      },
    },
    {
      question: {
        en: 'How do I override the selling price for a specific item?',
        bn: 'নির্দিষ্ট আইটেমের বিক্রয়মূল্য কীভাবে ওভাররাইড করব?',
      },
      answer: {
        en: 'Edit the Listed Unit Price cell directly in the table row. This switches the item pricing mode to manual and locks the listed price from automatic recalculations.',
        bn: 'টেবিল রো-তে সরাসরি Listed Unit Price সেলটি এডিট করুন। এটি আইটেমের প্রাইসিং মোডকে ম্যানুয়ালে সুইচে এবং অটোমেটিক পুনঃগণনা থেকে প্রাইস লক করে দেয়।',
      },
    },
    {
      question: {
        en: 'Can I delete a shipment after items have been assigned to it?',
        bn: 'আইটেম অ্যাসাইন করার পর কি শিপমেন্ট ডিলিট করা সম্ভব?',
      },
      answer: {
        en: 'Deleting a shipment requires caution. If stock items or boxes are tied to the shipment, delete confirmation will ask to verify or prevent orphaned stock records.',
        bn: 'শিপমেন্ট ডিলিট করার ক্ষেত্রে সতর্কতা অবলম্বন করা দরকার। যদি স্টক আইটেম বা বক্স শিপমেন্টের সাথে যুক্ত থাকে, তবে ডিলিট নিশ্চিতকরণ স্বয়ংক্রিয়ভাবে তা যাচাই করবে।',
      },
    },
  ],
};

