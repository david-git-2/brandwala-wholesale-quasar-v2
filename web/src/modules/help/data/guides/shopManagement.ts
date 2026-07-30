import type { ModuleGuide } from '../../types';

export const shopManagementGuide: ModuleGuide = {
  id: 'shop_management',
  title: { en: 'Shop Management', bn: 'শপ ম্যানেজমেন্ট' },
  caption: {
    en: 'Create shops, configure ordering modes, pricing rules, and access matrix',
    bn: 'শপ তৈরি, কনফিগারেশন, অর্ডারিং মোড, প্রাইসিং রুলস এবং অ্যাক্সেস ম্যাট্রিক্স পরিচালনা',
  },
  icon: 'ph ph-storefront',
  scopes: ['app'],
  audiences: ['admin', 'staff'],
  routeMatchers: ['/app/shop/shops'],
  overview: {
    en: 'From Shop Management, tenant administrators and staff can create and configure shop types (Vendor Catalog, Fixed Price, Dropship), adjust ordering modes, and control custom pricing rules and access permissions.',
    bn: 'শপ ম্যানেজমেন্ট পৃষ্ঠা থেকে টেন্যান্ট অ্যাডমিনিস্ট্রেটর ও স্টাফগণ বিভিন্ন টাইপের শপ (যেমন: Vendor Catalog, Fixed Price, Dropship) তৈরি ও কনফিগার করতে পারেন, অর্ডারিং মোড সামঞ্জস্য করতে পারেন, কাস্টম প্রাইসিং রুলস এবং অ্যাক্সেস পারমিশন কন্ট্রোল করতে পারেন।',
  },
  workflows: [
    {
      id: 'create-shop',
      title: {
        en: 'Create or configure a new shop',
        bn: 'নতুন শপ তৈরি বা কনফিগার করুন',
      },
      steps: [
        {
          en: 'Click "+ New Shop" in the top header.',
          bn: 'উপরের হেডার থেকে "+ নতুন শপ" বাটনে ক্লিক করুন।',
        },
        {
          en: 'Enter the shop name, unique slug, and shop type (Vendor Catalog, Fixed Price, or Dropship).',
          bn: 'শপের নাম, ইউনিক স্লাগ এবং শপ টাইপ (Vendor Catalog, Fixed Price, বা Dropship) নির্বাচন করুন।',
        },
        {
          en: 'Configure vendor code, ordering mode, negotiable pricing, and active status.',
          bn: 'ভেন্ডর কোড, অর্ডারিং মোড, দরদাম সুবিধা (Is Negotiable) এবং সক্রিয় স্ট্যাটাস কনফিগার করুন।',
        },
        {
          en: 'Click "Save" to finish creating the shop.',
          bn: '"সংরক্ষণ করুন" এ ক্লিক করে শপ তৈরি সম্পন্ন করুন।',
        },
      ],
    },
    {
      id: 'manage-pricing-and-access',
      title: {
        en: 'Manage pricing rules and access matrix',
        bn: 'প্রাইসিং রুলস ও অ্যাক্সেস ম্যাট্রিক্স ব্যবস্থাপনা',
      },
      steps: [
        {
          en: 'Look at the action icons on the right side of the shop card.',
          bn: 'কাঙ্ক্ষিত শপ কার্ডটির ডান পাশের একশন আইকনসমূহ লক্ষ্য করুন।',
        },
        {
          en: 'Click the orange "Manage Pricing" (tag) icon to configure pricing.',
          bn: 'প্রাইসিং কনফিগার করতে কমলা রঙের "Manage Pricing" (ট্যাগ) আইকনে ক্লিক করুন।',
        },
        {
          en: 'Click the teal "Manage Access Matrix" (shield) icon to set permissions by customer group and role.',
          bn: 'কাস্টমার গ্রুপ ও রোল অনুযায়ী পারমিশন সেট করতে টিল রঙের "Manage Access Matrix" (শীর্ষক/শিল্ড) আইকনে ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'dropship-readiness',
      title: {
        en: 'Check Dropship Go-Live Readiness',
        bn: 'ড্রপশিপ গো-লাইভ রেডিনেস চেক',
      },
      steps: [
        {
          en: 'For dropship shops, review the "Go-Live Readiness" section under the card.',
          bn: 'ড্রপশিপ শপের ক্ষেত্রে কার্ডের নিচে "Go-Live Readiness" সেকশনটি পরীক্ষা করুন।',
        },
        {
          en: 'Confirm payment methods, default courier, category mapping, and pricing rules are ready.',
          bn: 'পেমেন্ট মেথড, ডিফল্ট কুরিয়ার, ক্যাটাগরি ম্যাপিং এবং প্রাইসিং রুলস প্রস্তুত আছে কিনা নিশ্চিত করুন।',
        },
        {
          en: 'Complete required configuration, then set the shop status to Active.',
          bn: 'প্রয়োজনীয় কনফিগারেশন সম্পূর্ণ করে শপ স্ট্যাটাস Active করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Shop Type', bn: 'শপ টাইপ' },
      definition: {
        en: 'Sets Vendor Catalog, Fixed Price, or Dropship mode.',
        bn: 'Vendor Catalog (সরবরাহকারী ক্যাটালগ), Fixed Price (নির্দিষ্ট মূল্য), অথবা Dropship (ড্রপশিপ resell) মোড নির্ধারণ করে।',
      },
    },
    {
      term: { en: 'Order Mode', bn: 'অর্ডার মোড' },
      definition: {
        en: 'Controls order style: Procurement Intent, Checkout Fixed, or Checkout Wholesale.',
        bn: 'অর্ডারের ধরণ নিয়ন্ত্রণ করে: Procurement Intent, Checkout Fixed, নাকি Checkout Wholesale।',
      },
    },
    {
      term: { en: 'Access Matrix', bn: 'অ্যাক্সেস ম্যাট্রিক্স' },
      definition: {
        en: 'Controls shop access and visibility for specific customer groups or users.',
        bn: 'নির্দিষ্ট কাস্টমার গ্রুপ বা ব্যবহারকারীদের জন্য শপের অ্যাক্সেস ও দৃশ্যমানতা নিয়ন্ত্রণ করে।',
      },
    },
    {
      term: { en: 'Go-Live Readiness', bn: 'গো-লাইভ রেডিনেস' },
      definition: {
        en: 'Required configuration checklist before activating a dropship shop.',
        bn: 'ড্রপশিপ শপ সক্রিয় করার পূর্বে আবশ্যকীয় কনফিগারেশন চেকলিস্ট।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why is "Manage Pricing" missing on a shop?',
        bn: 'কেন একটি শপে "Manage Pricing" অপশনটি দেখাবে না?',
      },
      answer: {
        en: 'Vendor Catalog shops do not need custom pricing rules, so Manage Pricing appears only on Fixed Price and Dropship shops.',
        bn: 'Vendor Catalog টাইপের শপে কাস্টম প্রাইসিং রুলসের প্রয়োজন হয় না, তাই শুধুমাত্র Fixed Price ও Dropship শপে এই অপশন পাওয়া যায়।',
      },
    },
    {
      question: {
        en: 'What happens when a shop is Inactive?',
        bn: 'একটি শপ Inactive অবস্থায় থাকলে কী ঘটে?',
      },
      answer: {
        en: 'Inactive shops are hidden from customers or merchants on the storefront and stop accepting new orders.',
        bn: 'নিষ্ক্রিয় শপ স্টোরফ্রন্টে গ্রাহক বা মার্চেন্টদের জন্য দৃশ্যমান থাকে না এবং নতুন অর্ডার গ্রহণ করা বন্ধ থাকে।',
      },
    },
  ],
};
