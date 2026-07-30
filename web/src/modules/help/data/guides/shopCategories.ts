import type { ModuleGuide } from '../../types';

export const shopCategoriesGuide: ModuleGuide = {
  id: 'shop_categories',
  title: { en: 'Shop Categories', bn: 'শপ ক্যাটাগরি' },
  caption: {
    en: 'Organize tenant products into categories for the customer storefront',
    bn: 'গ্রাহক স্টোরফ্রন্টের জন্য টেন্যান্ট পণ্যসমূহ ক্যাটাগরিতে সাজান',
  },
  icon: 'ph ph-squares-four',
  scopes: ['app'],
  audiences: ['admin', 'staff'],
  routeMatchers: ['/app/shop/categories'],
  overview: {
    en: 'Shop Categories helps tenant administrators and staff group products for storefront display, manage URL slugs, set visual icons, and control active visibility.',
    bn: 'শপ ক্যাটাগরি টেন্যান্ট অ্যাডমিনিস্ট্রেটর ও স্টাফদের স্টোরফ্রন্টে প্রদর্শনের জন্য পণ্যসমূহ শ্রেণীভিত্তিক সাজাতে, URL স্লাগ পরিচালনা করতে, ভিজ্যুয়াল আইকন সেট করতে এবং সক্রিয় দৃশ্যমানতা নির্বাচন করতে সহায়তা করে।',
  },
  workflows: [
    {
      id: 'create-category',
      title: {
        en: 'Create a new shop category',
        bn: 'নতুন শপ ক্যাটাগরি তৈরি করুন',
      },
      steps: [
        {
          en: 'Click "+ Add Category" in the top header.',
          bn: 'উপরের হেডার থেকে "+ ক্যাটাগরি যোগ করুন" বাটনে ক্লিক করুন।',
        },
        {
          en: 'Enter the category name (URL slug is generated automatically).',
          bn: 'ক্যাটাগরির নাম লিখুন (URL স্লাগ স্বয়ংক্রিয়ভাবে তৈরি হবে)।',
        },
        {
          en: 'Choose a visible icon and optional category description.',
          bn: 'একটি দৃশ্যমান আইকন এবং ঐচ্ছিক ক্যাটাগরি বিবরণ নির্বাচন করুন।',
        },
        {
          en: 'Confirm "Active Category" is on, then click "Create Shop Category".',
          bn: '"সক্রিয় ক্যাটাগরি" টগল চালু আছে কিনা নিশ্চিত করুন, তারপর "শপ ক্যাটাগরি তৈরি করুন" এ ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'edit-category',
      title: {
        en: 'Edit or deactivate an existing category',
        bn: 'বিদ্যমান ক্যাটাগরি সম্পাদনা বা নিষ্ক্রিয় করুন',
      },
      steps: [
        {
          en: 'Find the category with the search bar.',
          bn: 'অনুসন্ধান বার ব্যবহার করে কাঙ্ক্ষিত ক্যাটাগরি খুঁজুন।',
        },
        {
          en: 'Click the pencil (edit) icon on the category row or card.',
          bn: 'ক্যাটাগরি রো বা কার্ডে থাকা পেন্সিল (সম্পাদনা) আইকনে ক্লিক করুন।',
        },
        {
          en: 'Change details, icon, or set status to inactive.',
          bn: 'বিবরণ, আইকন বা স্ট্যাটাস নিষ্ক্রিয়তে পরিবর্তন করুন।',
        },
        {
          en: 'Click "Save Changes" to apply the update.',
          bn: 'আপডেট প্রয়োগ করতে "পরিবর্তন সংরক্ষণ করুন" এ ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'delete-category',
      title: { en: 'Delete a shop category', bn: 'শপ ক্যাটাগরি মুছুন' },
      steps: [
        {
          en: 'Find the category you want to remove.',
          bn: 'যে ক্যাটাগরি সরাতে চান তা খুঁজুন।',
        },
        {
          en: 'Click the trash (delete) icon on the row or card.',
          bn: 'রো বা কার্ডে থাকা ট্র্যাশ (মুছুন) আইকনে ক্লিক করুন।',
        },
        {
          en: 'Confirm deletion in the popup dialog.',
          bn: 'পপ-আপ ডায়ালগে ক্যাটাগরি মোছা নিশ্চিত করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Slug', bn: 'স্লাগ' },
      definition: {
        en: 'URL-friendly identifier used in storefront navigation links.',
        bn: 'স্টোরফ্রন্ট নেভিগেশন লিংকে ব্যবহৃত URL-বান্ধব শনাক্তকারী।',
      },
    },
    {
      term: { en: 'Active Status', bn: 'সক্রিয় স্ট্যাটাস' },
      definition: {
        en: 'Controls whether a category and its products appear on the public storefront.',
        bn: 'পাবলিক স্টোরফ্রন্টে একটি ক্যাটাগরি এবং এর আওতাধীন পণ্য দেখা যাবে কিনা তা নিয়ন্ত্রণ করে।',
      },
    },
    {
      term: { en: 'Category Icon', bn: 'ক্যাটাগরি আইকন' },
      definition: {
        en: 'Phosphor visual icon shown with the category in the navigation menu.',
        bn: 'নেভিগেশন মেনুতে ক্যাটাগরির সাথে যুক্ত Phosphor দৃশ্যমান আইকন।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'What happens when I deactivate a category?',
        bn: 'ক্যাটাগরি নিষ্ক্রিয় করলে কী ঘটে?',
      },
      answer: {
        en: 'Inactive categories stay in the system but are hidden from customer storefront navigation.',
        bn: 'নিষ্ক্রিয় ক্যাটাগরি সিস্টেমে সংরক্ষিত থাকে তবে গ্রাহক স্টোরফ্রন্ট নেভিগেশনে লুকানো থাকে।',
      },
    },
    {
      question: {
        en: 'Can I change the category slug after creating it?',
        bn: 'তৈরি করার পর কি ক্যাটাগরি স্লাগ পরিবর্তন করা যাবে?',
      },
      answer: {
        en: 'Yes. Edit the category and update the slug input manually before saving.',
        bn: 'হ্যাঁ, ক্যাটাগরি সম্পাদনা করে সেভ করার আগে ম্যানুয়ালি স্লাগ ইনপুট আপডেট করুন।',
      },
    },
  ],
};
