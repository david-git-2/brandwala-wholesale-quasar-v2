import type { ModuleGuide } from '../../types';

export const customerDashboardGuide: ModuleGuide = {
  id: 'customer_dashboard',
  title: {
    en: 'Customer Dashboard',
    bn: 'কাস্টমার ড্যাশবোর্ড',
  },
  caption: {
    en: 'Overview of wholesale shops, global search, recent orders, and quick actions',
    bn: 'পাইকারি শপ, গ্লোবাল সার্চ, সাম্প্রতিক অর্ডার এবং কুইক অ্যাকশনের ওভারভিউ',
  },
  icon: 'ph ph-squares-four',
  scopes: ['shop'],
  audiences: ['merchant'],
  routeMatchers: ['/shop/dashboard', '/shop'],
  overview: {
    en: 'The Customer Dashboard serves as your central command hub for B2B wholesale operations. Search products across all authorized wholesale shop catalogs, monitor active shops and recent orders, view financial outlay summaries, and perform quick operational actions.',
    bn: 'কাস্টমার ড্যাশবোর্ড হল আপনার B2B পাইকারি পরিচালনার সেন্ট্রাল কমান্ড হাব। আপনার অনুমোদিত সমস্ত পাইকারি শপ ক্যাটালগ জুড়ে পণ্য অনুসন্ধান করুন, সক্রিয় শপ এবং সাম্প্রতিক অর্ডার মনিটর করুন, আর্থিক খরচের সারসংক্ষেপ দেখুন এবং দ্রুত অপারেশনাল কাজ পরিচালনা করুন।',
  },
  workflows: [
    {
      id: 'search-catalog',
      title: {
        en: 'Search Across Wholesale Catalogs',
        bn: 'পাইকারি ক্যাটালগ জুড়ে অনুসন্ধান করুন',
      },
      steps: [
        {
          en: 'Locate the global search bar in the top hero section.',
          bn: 'শীর্ষ হিরো সেকশনে গ্লোবাল সার্চ বারটি খুঁজুন।',
        },
        {
          en: 'Enter a product title, SKU, or keyword and click Search or press Enter.',
          bn: 'পণ্যের শিরোনাম, এসকেইউ বা কিওয়ার্ড লিখুন এবং সার্চ বাটনে ক্লিক করুন বা ইন্টার চাপুন।',
        },
        {
          en: 'Review the search modal displaying matching items across all accessible shops.',
          bn: 'সব অ্যাক্সেসযোগ্য শপজুড়ে মিলে যাওয়া আইটেম প্রদর্শনকারী সার্চ মোডালটি রিভিউ করুন।',
        },
        {
          en: 'Click any product to navigate directly to its storefront catalog page.',
          bn: 'যেকোনো পণ্যে ক্লিক করে সরাসরি এর স্টোরফ্রন্ট ক্যাটালগ পৃষ্ঠায় যান।',
        },
      ],
    },
    {
      id: 'browse-shops-categories',
      title: {
        en: 'Explore Shops and Categories',
        bn: 'শপ এবং ক্যাটাগরি এক্সপ্লোর করুন',
      },
      steps: [
        {
          en: 'Scroll to the Wholesale Shops & Categories section.',
          bn: 'পাইকারি শপ এবং ক্যাটাগরি সেকশনে স্ক্রোল করুন।',
        },
        {
          en: 'View all wholesale supplier shops available to your group account.',
          bn: 'আপনার গ্রুপ অ্যাকাউন্টে উপলব্ধ সমস্ত পাইকারি সাপ্লায়ার শপ দেখুন।',
        },
        {
          en: 'Click on a shop card or category tag to open that specific shop storefront.',
          bn: 'নির্দিষ্ট শপ স্টোরফ্রন্ট খুলতে একটি শপ কার্ড বা ক্যাটাগরি ট্যাগে ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'track-orders-outlay',
      title: {
        en: 'Monitor Orders and Financial Outlay',
        bn: 'অর্ডার এবং আর্থিক খরচ ট্র্যাক করুন',
      },
      steps: [
        {
          en: 'Check the summary cards for active shops count, recent order count, and total outlay.',
          bn: 'সক্রিয় শপের সংখ্যা, সাম্প্রতিক অর্ডারের সংখ্যা এবং মোট খরচের জন্য সামারি কার্ডগুলো দেখুন।',
        },
        {
          en: 'Review the Recent Activity card for your latest 3 orders and their real-time statuses.',
          bn: 'আপনার সাম্প্রতিক ৩টি অর্ডার এবং সেগুলোর রিয়েল-টাইম স্ট্যাটাসের জন্য Recent Activity কার্ডটি দেখুন।',
        },
        {
          en: 'Click View Details on any order card to see full shipment and item information.',
          bn: 'সম্পূর্ণ শিপমেন্ট ও আইটেমের তথ্য দেখতে যেকোনো অর্ডার কার্ডের View Details এ ক্লিক করুন।',
        },
      ],
    },
    {
      id: 'use-action-hub',
      title: {
        en: 'Use the Operational Action Hub',
        bn: 'অপারেশনাল অ্যাকশন হাব ব্যবহার করুন',
      },
      steps: [
        {
          en: 'Navigate to the Action Hub on the lower left of your dashboard.',
          bn: 'আপনার ড্যাশবোর্ডের নিচে বামে অ্যাকশন হাবে যান।',
        },
        {
          en: 'Use Browse Catalogs to jump straight to shop listings.',
          bn: 'সরাসরি শপ লিস্টিংয়ে যেতে Browse Catalogs ব্যবহার করুন।',
        },
        {
          en: 'Click View All Orders or Track Latest Order to manage fulfillment.',
          bn: 'ফুলফিলমেন্ট ম্যানেজ করতে View All Orders বা Track Latest Order এ ক্লিক করুন।',
        },
        {
          en: 'Click Documentation to access operational guides and help topics.',
          bn: 'অপারেশনাল গাইড এবং হেল্প টপিক অ্যাক্সেস করতে Documentation এ ক্লিক করুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: {
        en: 'Active Shops',
        bn: 'সক্রিয় শপ',
      },
      definition: {
        en: 'Wholesale storefronts that your customer group is granted access to order from.',
        bn: 'পাইকারি স্টোরফ্রন্টগুলো যেখান থেকে অর্ডার করার জন্য আপনার ক্যাটালগ গ্রুপকে অ্যাক্সেস দেওয়া হয়েছে।',
      },
    },
    {
      term: {
        en: 'Total Outlay',
        bn: 'মোট খরচ (আউটলে)',
      },
      definition: {
        en: 'The aggregated financial value of your recent wholesale purchase orders.',
        bn: 'আপনার সাম্প্রতিক পাইকারি ক্রয় অর্ডারগুলোর একত্রিত আর্থিক মূল্য।',
      },
    },
    {
      term: {
        en: 'Action Hub',
        bn: 'অ্যাকশন হাব',
      },
      definition: {
        en: 'A quick-launch panel for common operational tasks like browsing, order tracking, and docs.',
        bn: 'ব্রাউজিং, অর্ডার ট্র্যাকিং এবং ডকুমেন্টেশনের মতো সাধারণ কাজের জন্য একটি কুইক-লঞ্চ প্যানেল।',
      },
    },
    {
      term: {
        en: 'Global Catalog Search',
        bn: 'গ্লোবাল ক্যাটালগ সার্চ',
      },
      definition: {
        en: 'Cross-catalog search tool that queries all accessible shops simultaneously.',
        bn: 'ক্রস-ক্যাটালগ সার্চ টুল যা সমস্ত অ্যাক্সেসযোগ্য শপ জুড়ে একসাথে অনুসন্ধান করে।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why do some products show "Price Hidden"?',
        bn: 'কিছু পণ্যে "Price Hidden" দেখায় কেন?',
      },
      answer: {
        en: 'Price visibility is configured per wholesale shop permission. Contact your supplier if price access is needed.',
        bn: 'মূল্য দেখার অনুমতি পাইকারি শপ পারমিশন অনুযায়ী কনফিগার করা হয়। মূল্য দেখার অ্যাক্সেস প্রয়োজন হলে আপনার সাপ্লায়ারের সাথে যোগাযোগ করুন।',
      },
    },
    {
      question: {
        en: 'How do I switch between different wholesale shops?',
        bn: 'বিভিন্ন পাইকারি শপের মধ্যে সুইচ করব কীভাবে?',
      },
      answer: {
        en: 'Open Catalog. If you have more than one shop, switch from the shop name at the top. You can also open a shop from Home.',
        bn: 'ক্যাটালগ খুলুন। একাধিক শপ থাকলে উপরে শপের নাম থেকে বদলান। হোম থেকেও একটি শপ খুলতে পারেন।',
      },
    },
    {
      question: {
        en: 'Where can I see my full order history beyond the recent 3 orders?',
        bn: 'সাম্প্রতিক ৩টি অর্ডারের বাইরে আমার সম্পূর্ণ অর্ডার হিস্ট্রি কোথায় দেখতে পাব?',
      },
      answer: {
        en: 'Click "View All Orders" in the Action Hub or recent orders header to navigate to the complete Orders page.',
        bn: 'সম্পূর্ণ অর্ডার্স পৃষ্ঠায় যেতে অ্যাকশন হাব বা সাম্প্রতিক অর্ডার্স হেডারের "View All Orders" এ ক্লিক করুন।',
      },
    },
  ],
};
