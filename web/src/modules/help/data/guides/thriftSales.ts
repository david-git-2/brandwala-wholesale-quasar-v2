import type { ModuleGuide } from '../../types';

export const thriftSalesGuide: ModuleGuide = {
  id: 'thrift_sales',
  title: { en: 'Thrift Sales & Invoicing', bn: 'থ্রিফ্ট সেলস ও ইনভয়েসিং' },
  caption: {
    en: 'Create sales invoices, search available inventory by barcode, apply discounts, and track profits',
    bn: 'সেলস ইনভয়েস তৈরি করুন, বারকোড দিয়ে ইনভেন্টরি খুঁজুন, ডিসকাউন্ট দিন এবং প্রফিট ট্র্যাক করুন',
  },
  icon: 'ph ph-receipt',
  scopes: ['app'],
  audiences: ['admin', 'staff'],
  routeMatchers: ['/app/thrift/sales'],
  overview: {
    en: 'Thrift Sales & Invoicing enables store staff and managers to create point-of-sale invoices for thrift inventory, auto-assign barcodes, customize prices and discounts, calculate real-time net profits based on landed costs, and update stock status automatically upon saving.',
    bn: 'থ্রিফ্ট সেলস ও ইনভয়েসিংয়ের মাধ্যমে স্টোর স্টাফ ও ম্যানেজাররা থ্রিফ্ট ইনভেন্টরির জন্য পয়েন্ট-অফ-সেল ইনভয়েস তৈরি করতে, বারকোড স্ক্যান করতে, মূল্য ও ডিসকাউন্ট নির্ধারণ করতে, ল্যান্ডেড কস্টের ভিত্তিতে রিয়েল-টাইম নিট প্রফিট দেখতে এবং সেভ করার পর স্বয়ংক্রিয়ভাবে স্টকের স্ট্যাটাস আপডেট করতে পারেন।',
  },
  workflows: [
    {
      id: 'create-invoice',
      title: {
        en: 'Create a new thrift sales invoice',
        bn: 'নতুন থ্রিফ্ট সেলস ইনভয়েস তৈরি করুন',
      },
      steps: [
        {
          en: 'Navigate to Thrift / Sales and click the "Create Sales Invoice" button.',
          bn: 'Thrift / Sales পেজে যান এবং "Create Sales Invoice" বাটনে ক্লিক করুন।',
        },
        {
          en: 'Fill in optional customer information (Name, Phone) and select the payment method and status.',
          bn: 'ঐচ্ছিক কাস্টমারের তথ্য (নাম, ফোন) লিখুন এবং পেমেন্ট মেথড ও স্ট্যাটাস নির্বাচন করুন।',
        },
        {
          en: 'Scan an item barcode or type the tag/item name in the search box and press Enter to find available inventory.',
          bn: 'ইনভেন্টরি খুঁজতে সার্চ বক্সে বারকোড স্ক্যান করুন বা ট্যাগের নাম লিখে Enter চাপুন।',
        },
        {
          en: 'Click "Add" on matching items to move them into the invoice line items table.',
          bn: 'ইনভয়েস আইটেম টেবিলে যুক্ত করতে ম্যাচিং আইটেমের পাশে "Add" বাটনে ক্লিক করুন।',
        },
        {
          en: 'Adjust selling price or apply item-level discounts (if allowed by your role permissions).',
          bn: 'বিক্রয় মূল্য পরিবর্তন করুন অথবা আইটেমভিত্তিক ডিসকাউন্ট দিন (যদি আপনার রোল পারমিশন থাকে)।',
        },
        {
          en: 'Review total invoice summary, landed COGS, and estimated net profit margin on the side panel.',
          bn: 'সাইড প্যানেলে মোট ইনভয়েস সামারি, ল্যান্ডেড কস্ট (COGS) এবং আনুমানিক নিট প্রফিট মার্জিন পরীক্ষা করুন।',
        },
        {
          en: 'Click "Save Invoice" to generate the invoice record, mark items as SOLD, and log accounting entry.',
          bn: 'ইনভয়েস তৈরি করতে, আইটেম SOLD করতে এবং একাউন্টিং এন্ট্রি যোগ করতে "Save Invoice" এ ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'item-pricing-discounts',
      title: {
        en: 'Manage item pricing & line discounts',
        bn: 'আইটেম মূল্য এবং ডিসকাউন্ট পরিচালনা',
      },
      steps: [
        {
          en: 'Each added line item displays its computed Landed Cost for transparent margin reference.',
          bn: 'প্রতিটি যুক্ত করা আইটেমে স্বচ্ছতার জন্য গণনা করা ল্যান্ডেড কস্ট (Landed Cost) প্রদর্শিত হয়।',
        },
        {
          en: 'Edit the "Sell Price" field directly to override default pricing for specific negotiations.',
          bn: 'নির্দিষ্ট আলোচনার জন্য মূল মূল্য পরিবর্তন করতে সরাসরি "Sell Price" ফিল্ড সম্পাদন করুন।',
        },
        {
          en: 'Authorized staff can enter an amount in "Discount (৳)" to reduce final item price.',
          bn: 'অনুমোদিত স্টাফরা আইটেমের শেষ দাম কমাতে "Discount (৳)" ফিল্ডে ছাড়ের পরিমাণ দিতে পারেন।',
        },
        {
          en: 'The system instantly recalculates line-item Net Profit and overall Profit Margin %.',
          bn: 'সিস্টেম সাথে সাথে লাইনের নিট প্রফিট এবং সামগ্রিক প্রফিট মার্জিন % পুনরায় হিসাব করে।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Landed Cost', bn: 'ল্যান্ডেড কস্ট' },
      definition: {
        en: 'The total cost of acquiring and shipping an individual thrift stock unit before retail sale.',
        bn: 'খুচরা বিক্রয়ের পূর্বে প্রতিটি থ্রিফ্ট স্টক ইউনিট সংগ্রহ ও পরিবহন বাবদ মোট ব্যয়।',
      },
    },
    {
      term: { en: 'COGS (Cost of Goods Sold)', bn: 'বিক্রিত পণ্যের ব্যয় (COGS)' },
      definition: {
        en: 'Sum of landed costs for all items included in the sales invoice.',
        bn: 'সেলস ইনভয়েসে অন্তর্ভুক্ত সমস্ত আইটেমের মোট ল্যান্ডেড কস্টের সমষ্টি।',
      },
    },
    {
      term: { en: 'Est. Net Profit', bn: 'আনুমানিক নিট প্রফিট' },
      definition: {
        en: 'Final invoice revenue after discounts minus total landed COGS.',
        bn: 'ডিসকাউন্ট বাদ দেওয়ার পর মোট ইনভয়েসের রাজস্ব থেকে মোট ল্যান্ডেড কস্ট বিয়োগফল।',
      },
    },
    {
      term: { en: 'Payment Status', bn: 'পেমেন্ট স্ট্যাটাস' },
      definition: {
        en: 'Current payment state for the invoice (Paid, Pending, or Partial).',
        bn: 'ইনভয়েসের বর্তমান পেমেন্টের অবস্থা (Paid, Pending, অথবা Partial)।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why is the Discount field disabled or missing for me?',
        bn: 'আমার জন্য ডিসকাউন্ট ফিল্ডটি নিষ্ক্রিয় বা অনুপস্থিত কেন?',
      },
      answer: {
        en: 'Applying item discounts requires the "thrift_sales.apply_discount" permission. Contact your tenant administrator if access is required.',
        bn: 'আইটেমে ডিসকাউন্ট প্রয়োগের জন্য "thrift_sales.apply_discount" পারমিশন প্রয়োজন। প্রয়োজনে আপনার টেন্যান্ট অ্যাডমিনিস্ট্রেটরকে জানান।',
      },
    },
    {
      question: {
        en: 'Can I add an item that is already marked as SOLD?',
        bn: 'ইতিমধ্যে SOLD চিহ্নিত কোনো আইটেম কি ইনভয়েসে যোগ করা যাবে?',
      },
      answer: {
        en: 'No, only available active thrift stock items can be added to a sales invoice.',
        bn: 'না, কেবল এভেলেবল (Available) সক্রিয় থ্রিফ্ট স্টক আইটেমই ইনভয়েসে যুক্ত করা সম্ভব।',
      },
    },
    {
      question: {
        en: 'What happens to inventory when an invoice is saved?',
        bn: 'ইনভয়েস সেভ করার পর ইনভেন্টরির কি হয়?',
      },
      answer: {
        en: 'The system locks the sales transaction, marks all included stock items as SOLD, and posts financial records automatically.',
        bn: 'সিস্টেম সেলস ট্রানজ্যাকশন লক করে, যুক্ত হওয়া সমস্ত স্টক আইটেমকে SOLD হিসেবে চিহ্নিত করে এবং স্বয়ংক্রিয়ভাবে একাউন্টিং রেকর্ড তৈরি করে।',
      },
    },
  ],
};
