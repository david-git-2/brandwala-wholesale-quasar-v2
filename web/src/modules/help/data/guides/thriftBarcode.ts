import type { ModuleGuide } from '../../types';

export const thriftBarcodeGuide: ModuleGuide = {
  id: 'thrift_barcode',
  title: { en: 'Thrift Barcode Management', bn: 'থ্রিফ্ট বারকোড ব্যবস্থাপনা' },
  caption: {
    en: 'Generate, filter, preview, and print sequential thrift inventory barcodes',
    bn: 'ধারাবাহিক থ্রিফ্ট ইনভেন্টরি বারকোড জেনারেট, ফিল্টার, প্রিভিউ এবং প্রিন্ট করুন',
  },
  icon: 'ph ph-barcode',
  scopes: ['app'],
  audiences: ['admin', 'staff'],
  routeMatchers: ['/app/thrift/barcodes', '/app/thrift/barcodes/print'],
  overview: {
    en: 'Thrift Barcode Management enables staff and administrators to generate unique sequential barcodes (formatted by tenant, prefix, year, and sequence), search and filter generated barcodes, preview barcode layouts, and batch print barcode labels.',
    bn: 'থ্রিফ্ট বারকোড ম্যানেজমেন্টের মাধ্যমে স্টাফ এবং অ্যাডমিনিস্ট্রেটররা ইউনিক ধারাবাহিক বারকোড (ট্যালেন্ট, প্রফিক্স, বছর এবং ক্রম অনুযায়ী বিন্যস্ত) তৈরি করতে, ফিল্টার ও সার্চ করতে, বারকোডের প্রিভিউ দেখতে এবং একসাথে লেবেল প্রিন্ট করতে পারেন।',
  },
  workflows: [
    {
      id: 'bulk-generate',
      title: {
        en: 'Bulk generate sequential barcodes',
        bn: 'একসাথে ধারাবাহিক বারকোড জেনারেট করুন',
      },
      steps: [
        {
          en: 'In the Bulk Barcode Generator section, select the desired quantity to generate (e.g. 50, 100, 200).',
          bn: 'বাল্ক বারকোড জেনারেটর সেকশনে, কতগুলো বারকোড জেনারেট করতে চান তা সিলেক্ট করুন (যেমন ৫০, ১০০, ২০০)।',
        },
        {
          en: 'Click the "Generate" button to trigger the confirmation dialog.',
          bn: 'কনফার্মেশন ডায়ালগটি দেখতে "Generate" বাটনে ক্লিক করুন।',
        },
        {
          en: 'Review the estimated barcode range and current count metrics, then confirm to generate the batch.',
          bn: 'আনুমানিক বারকোড রেঞ্জ এবং বর্তমান হিসেব পর্যালোচনা করে ব্যাচ জেনারেট নিশ্চিত করুন।',
        },
      ],
    },
    {
      id: 'filter-preview',
      title: {
        en: 'Search, filter & preview barcodes',
        bn: 'বারকোড সার্চ, ফিল্টার এবং প্রিভিউ করুন',
      },
      steps: [
        {
          en: 'Use the search input to filter barcodes by code sequence or prefix (e.g. 01-AA-26-).',
          bn: 'কোড সিকোয়েন্স বা প্রফিক্স দিয়ে বারকোড ফিল্টার করতে সার্চ ইনপুট ব্যবহার করুন।',
        },
        {
          en: 'Filter by Printed Status (Printed / Not Printed) or Barcode Status (Available / Used).',
          bn: 'প্রিন্ট স্ট্যাটাস (প্রিন্ট করা / না করা) অথবা বারকোড স্ট্যাটাস (অ্যাভেইলএবল / ব্যবহৃত) দিয়ে ফিল্টার করুন।',
        },
        {
          en: 'Click the eye icon (Preview) on any row to view the rendered barcode visual.',
          bn: 'যেকোনো সারির আইকন (প্রিভিউ)-এ ক্লিক করে বারকোড ভিজ্যুয়াল দৃশ্যটি দেখুন।',
        },
      ],
    },
    {
      id: 'print-barcodes',
      title: {
        en: 'Print barcodes (Selected or Bulk)',
        bn: 'বারকোড প্রিন্ট করুন (সিলেক্ট করা বা একসাথে)',
      },
      steps: [
        {
          en: 'Click the "Print Barcodes" button in the header to open the Print Setup dialog.',
          bn: 'প্রিন্ট সেটআপ ডায়ালগটি খুলতে হেডারের "Print Barcodes" বাটনে ক্লিক করুন।',
        },
        {
          en: 'To print specific barcodes, select them in the table using row checkboxes and click "Print Selected Only".',
          bn: 'নির্দিষ্ট বারকোড প্রিন্ট করতে, টেবিলে চেকবক্স দিয়ে সিলেক্ট করুন এবং "Print Selected Only" এ ক্লিক করুন।',
        },
        {
          en: 'Alternatively, enter a quantity for Bulk Print (eligible Available + Not Printed barcodes) and click "Proceed to Print Preview".',
          bn: 'অথবা, বাল্ক প্রিন্টের জন্য পরিমাণ নির্ধারণ করুন এবং "Proceed to Print Preview" এ ক্লিক করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Barcode Sequence Code', bn: 'বারকোড সিকোয়েন্স কোড' },
      definition: {
        en: 'A unique identification string formatted as {TenantID}-{Prefix}-{Year}-{Sequence} (e.g. 01-AA-26-000001).',
        bn: '{TenantID}-{Prefix}-{Year}-{Sequence} ফরম্যাটে তৈরি একটি ইউনিক কোড (যেমন 01-AA-26-000001)।',
      },
    },
    {
      term: { en: 'Print Eligibility', bn: 'প্রিন্ট উপযোগিতা' },
      definition: {
        en: 'Only barcodes with Status = AVAILABLE and Printed = No (0) are eligible to be sent to printer label batches.',
        bn: 'কেবলমাত্র যে বারকোডগুলোর স্ট্যাটাস = AVAILABLE এবং Printed = No (0), সেগুলোই প্রিন্টিং লেবেলে পাঠানো যায়।',
      },
    },
    {
      term: { en: 'Barcode Prefix & Year', bn: 'বারকোড প্রফিক্স ও সাল' },
      definition: {
        en: 'Alphabetical series counter (starting from AA) combined with the two-digit creation year code (e.g., 26 for 2026).',
        bn: 'বর্ণমালার সিরিজ কাউন্টার (AA দিয়ে শুরু) এবং দুই ডিজিটের তৈরির সালের কোড (যেমন ২০২৬ সালের জন্য ২৬)।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why are some selected barcodes skipped during printing?',
        bn: 'প্রিন্ট করার সময় সিলেক্ট করা কিছু বারকোড স্কিপ হয় কেন?',
      },
      answer: {
        en: 'Barcodes that have already been printed (Printed = Yes) or marked as USED cannot be re-printed in normal batches to avoid duplicate tagging.',
        bn: 'যেসব বারকোড ইতিমধ্যেই প্রিন্ট করা হয়ে গেছে (Printed = Yes) বা ব্যবহৃত (USED) হিসেবে চিহ্নিত, সেগুলোকে ডুপ্লিকেট রোধে নতুন করে প্রিন্ট করা হয় না।',
      },
    },
    {
      question: {
        en: 'How are sequential barcode numbers calculated?',
        bn: 'ধারাবাহিক বারকোড নম্বর কীভাবে হিসাব করা হয়?',
      },
      answer: {
        en: 'The system automatically detects the last generated sequence code for the active year and continues numbering incrementally from the next sequence.',
        bn: 'সিস্টেম স্বয়ংক্রিয়ভাবে চলতি বছরের শেষ জেনারেট করা সিকোয়েন্স কোড শনাক্ত করে এবং পরবর্তী নম্বর থেকে ক্রমান্বয়ে কোড তৈরি করে।',
      },
    },
  ],
};
