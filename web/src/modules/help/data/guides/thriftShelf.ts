import type { ModuleGuide } from '../../types';

export const thriftShelfGuide: ModuleGuide = {
  id: 'thrift_shelf',
  title: { en: 'Thrift Shelves Management', bn: 'থ্রিফ্ট সেলফ ব্যবস্থাপনা' },
  caption: {
    en: 'Organize warehouse bays, shelf codes, and physical inventory locations',
    bn: 'ওয়ারহাউস বে, সেলফ কোড এবং ফিজিক্যাল ইনভেন্টরি স্থান বিন্যস্ত করুন',
  },
  icon: 'ph ph-books',
  scopes: ['app'],
  audiences: ['admin', 'staff'],
  routeMatchers: ['/app/thrift/shelf'],
  overview: {
    en: 'Thrift Shelves Management enables warehouse staff and administrators to define, update, and manage physical storage shelves and location bays. Creating unique shelf codes simplifies stock placement, item tracking, and quick retrieval during sales fulfillment.',
    bn: 'থ্রিফ্ট সেলফ ম্যানেজমেন্টের মাধ্যমে ওয়ারহাউস স্টাফ এবং অ্যাডমিনগণ ফিজিক্যাল স্টোরেজ সেলফ এবং লোকেশন বে তৈরি, আপডেট ও পরিচালনা করতে পারেন। ইউনিক সেলফ কোড ব্যবহারের মাধ্যমে পণ্যের অবস্থান চিহ্নিতকরণ, স্টক ট্র্যাকিং এবং বিক্রয়ের সময় দ্রুত পণ্য খুঁজে পাওয়া সহজ হয়।',
  },
  workflows: [
    {
      id: 'create-shelf',
      title: {
        en: 'Create a new storage shelf',
        bn: 'নতুন স্টোরেজ সেলফ তৈরি করুন',
      },
      steps: [
        {
          en: 'Click the "Add Shelf" button in the page header.',
          bn: 'পেজ হেডারে থাকা "Add Shelf" বাটনে ক্লিক করুন।',
        },
        {
          en: 'Fill in the required "Shelf Name" and "Shelf Code" (e.g. SHELF-A1).',
          bn: 'প্রয়োজনীয় "Shelf Name" এবং "Shelf Code" (যেমন SHELF-A1) লিখুন।',
        },
        {
          en: 'Optionally specify the "Location / Bay" area and click "Save Shelf".',
          bn: 'ঐচ্ছিক হিসেবে "Location / Bay" এলাকা উল্লেখ করুন এবং "Save Shelf" বাটনে ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'edit-delete-shelf',
      title: {
        en: 'Edit or remove an existing shelf',
        bn: 'বিদ্যমান সেলফ সম্পাদনা বা মুছে ফেলুন',
      },
      steps: [
        {
          en: 'Locate the target shelf row in the shelves table.',
          bn: 'সেলফ টেবিল থেকে নির্দিষ্ট সেলফের সারিটি খুঁজে বের করুন।',
        },
        {
          en: 'Click the yellow pencil icon to modify the name, shelf code, or location bay.',
          bn: 'নাম, সেলফ কোড বা লোকেশন বে পরিবর্তন করতে হলুদ পেন্সিল আইকনে ক্লিক করুন।',
        },
        {
          en: 'Click the red trash icon to delete an unneeded shelf and confirm when prompted.',
          bn: 'অপ্রয়োজনীয় সেলফ মুছে ফেলতে লাল ট্র্যাশ আইকনে ক্লিক করুন এবং নিশ্চিতকরণ বার্তা অনুযায়ী মুছে ফেলুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Shelf Code', bn: 'সেলফ কোড' },
      definition: {
        en: 'A unique identifier assigned to a shelf for barcode scanning, sorting, and fast inventory matching.',
        bn: 'বারকোড স্ক্যানিং, বাছাই এবং দ্রুত ইনভেন্টরি মেলানোর জন্য সেলফে দেওয়া এক অনন্য আইডি।',
      },
    },
    {
      term: { en: 'Location / Bay', bn: 'লোকেশন / বে' },
      definition: {
        en: 'The physical zone, aisle, or warehouse section where the shelf is stationed.',
        bn: 'যে ফিজিক্যাল জোন, আইল বা ওয়্যারহাউস সেকশনে সেলফটি স্থাপন করা রয়েছে।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why is shelf code mandatory when creating a shelf?',
        bn: 'সেলফ তৈরি করার সময় সেলফ কোড দেওয়া কেন বাধ্যতামূলক?',
      },
      answer: {
        en: 'Shelf codes ensure precise physical location mapping across inventory tags and stock picking lists.',
        bn: 'ইনভেন্টরি ট্যাগ এবং পণ্য সংগ্রহের তালিকার সাথে ফিজিক্যাল অবস্থান সঠিক রাখার জন্য সেলফ কোড প্রয়োজন।',
      },
    },
    {
      question: {
        en: 'Can I delete a shelf that currently holds active inventory?',
        bn: 'বর্তমানে সক্রিয় পণ্য থাকা সেলফ কি মুছে ফেলা সম্ভব?',
      },
      answer: {
        en: 'Deleting a shelf removes its reference. Make sure to re-assign or relocate items before deleting a shelf.',
        bn: 'সেলফ মুছে ফেললে এর রেফারেন্স মুছে যায়। তাই সেলফ ডিলিট করার আগে পণ্যগুলো অন্য স্থানে স্থানান্তর বা রি-অ্যাসাইন করুন।',
      },
    },
  ],
};
