import type { ModuleGuide } from '../types';

/**
 * Stub guides for Help Center scaffolding.
 * Full copy is added later via docs/OPTIMIZE_HELP_CENTER.md + attached pages.
 */
export const MODULE_GUIDE_REGISTRY: readonly ModuleGuide[] = [
  {
    id: 'getting_started',
    title: 'Getting Started',
    caption: 'Find help for the screen you are on',
    icon: 'ph ph-compass',
    scopes: ['platform', 'app', 'shop', 'investor'],
    audiences: ['superadmin', 'admin', 'staff', 'viewer', 'merchant', 'investor'],
    routeMatchers: ['/help'],
    overview:
      'Use the ? button in the header for a guide about the current page, or open Help Center to browse all guides available to your role.',
    workflows: [
      {
        id: 'open-guide',
        title: 'Open a module guide',
        steps: [
          'Click the ? icon in the top bar.',
          'Read Overview, Workflows, Key Terms, or FAQs.',
          'Open Help Center from the drawer if you need to search other topics.',
        ],
      },
    ],
    terms: [
      {
        term: 'Module Guide',
        definition: 'Short help for the area of the product you are using right now.',
      },
      {
        term: 'Help Center',
        definition: 'Searchable list of all guides you are allowed to see.',
      },
    ],
    faqs: [
      {
        question: 'Why do I see fewer guides than a coworker?',
        answer:
          'Guides are filtered by your role. Staff may see operations help that merchants or investors do not.',
      },
    ],
  },
  {
    id: 'platform_admin',
    title: 'Platform Admin',
    caption: 'Tenants, modules, and platform controls',
    icon: 'ph ph-shield',
    scopes: ['platform'],
    audiences: ['superadmin'],
    routeMatchers: ['/platform/tenants', '/platform/modules', '/platform/superadmins'],
    overview:
      'Platform Admin covers tenant provisioning, feature catalog activation, and superadmin access. Content will expand as guides are added.',
    workflows: [
      {
        id: 'open-tenants',
        title: 'Open tenants',
        steps: [
          'From the sidebar, open Tenants.',
          'Select a business to review status and access.',
        ],
      },
    ],
    terms: [
      {
        term: 'Feature Catalog',
        definition: 'Controls which product modules a tenant can use.',
      },
    ],
    faqs: [
      {
        question: 'Where do I turn a module on for a tenant?',
        answer: 'Use Feature Catalog (Modules) in the platform sidebar, then assign modules to the tenant.',
      },
    ],
  },
  {
    id: 'shop_categories',
    title: 'শপ ক্যাটাগরি (Shop Categories)',
    caption: 'গ্রাহক স্টোরফ্রন্টের জন্য টেন্যান্ট পণ্যসমূহ ক্যাটাগরিতে সাজান',
    icon: 'ph ph-squares-four',
    scopes: ['app'],
    audiences: ['admin', 'staff'],
    routeMatchers: ['/app/shop/categories'],
    overview:
      'শপ ক্যাটাগরি টেন্যান্ট অ্যাডমিনিস্ট্রেটর ও স্টাফদের স্টোরফ্রন্টে প্রদর্শনের জন্য পণ্যসমূহ শ্রেণীভিত্তিক সাজাতে, URL স্লাগ পরিচালনা করতে, ভিজ্যুয়াল আইকন সেট করতে এবং সক্রিয় দৃশ্যমানতা নির্বাচন করতে সহায়তা করে।',
    workflows: [
      {
        id: 'create-category',
        title: 'নতুন শপ ক্যাটাগরি তৈরি করুন',
        steps: [
          'উপরের হেডার থেকে "+ ক্যাটাগরি যোগ করুন" বাটনে ক্লিক করুন।',
          'ক্যাটাগরির নাম লিখুন (URL স্লাগ স্বয়ংক্রিয়ভাবে তৈরি হবে)।',
          'একটি দৃশ্যমান আইকন এবং ঐচ্ছিক ক্যাটাগরি বিবরণ নির্বাচন করুন।',
          '"সক্রিয় ক্যাটাগরি" টগল চালু আছে কিনা নিশ্চিত করুন, তারপর "শপ ক্যাটাগরি তৈরি করুন" এ ক্লিক করুন।',
        ],
      },
      {
        id: 'edit-category',
        title: 'বিদ্যমান ক্যাটাগরি সম্পাদনা বা নিষ্ক্রিয় করুন',
        steps: [
          'অনুসন্ধান বার ব্যবহার করে কাঙ্ক্ষিত ক্যাটাগরি খুঁজুন।',
          'ক্যাটাগরি রো বা কার্ডে থাকা পেন্সিল (সম্পাদনা) আইকনে ক্লিক করুন।',
          'বিবরণ, আইকন বা স্ট্যাটাস নিষ্ক্রিয়তে পরিবর্তন করুন।',
          'আপডেট প্রয়োগ করতে "পরিবর্তন সংরক্ষণ করুন" এ ক্লিক করুন।',
        ],
      },
      {
        id: 'delete-category',
        title: 'শপ ক্যাটাগরি মুছুন',
        steps: [
          'যে ক্যাটাগরি সরাতে চান তা খুঁজুন।',
          'রো বা কার্ডে থাকা ট্র্যাশ (মুছুন) আইকনে ক্লিক করুন।',
          'পপ-আপ ডায়ালগে ক্যাটাগরি মোছা নিশ্চিত করুন।',
        ],
      },
    ],
    terms: [
      {
        term: 'স্লাগ (Slug)',
        definition: 'স্টোরফ্রন্ট নেভিগেশন লিংকে ব্যবহৃত URL-বান্ধব শনাক্তকারী।',
      },
      {
        term: 'সক্রিয় স্ট্যাটাস (Active Status)',
        definition: 'পাবলিক স্টোরফ্রন্টে একটি ক্যাটাগরি এবং এর আওতাধীন পণ্য দেখা যাবে কিনা তা নিয়ন্ত্রণ করে।',
      },
      {
        term: 'ক্যাটাগরি আইকন (Category Icon)',
        definition: 'নেভিগেশন মেনুতে ক্যাটাগরির সাথে যুক্ত Phosphor দৃশ্যমান আইকন।',
      },
    ],
    faqs: [
      {
        question: 'ক্যাটাগরি নিষ্ক্রিয় (Inactive) করলে কী ঘটে?',
        answer: 'নিষ্ক্রিয় ক্যাটাগরি সিস্টেমে সংরক্ষিত থাকে তবে গ্রাহক স্টোরফ্রন্ট নেভিগেশনে লুকানো থাকে।',
      },
      {
        question: 'তৈরি করার পর কি ক্যাটাগরি স্লাগ পরিবর্তন করা যাবে?',
        answer: 'হ্যাঁ, ক্যাটাগরি সম্পাদনা করে সেভ করার আগে ম্যানুয়ালি স্লাগ ইনপুট আপডেট করুন।',
      },
    ],
  },
  {
    id: 'shop_order_staff',
    title: 'Shop & Orders (Staff)',
    caption: 'Process orders, dropship, and settlements',
    icon: 'ph ph-storefront',
    scopes: ['app'],
    audiences: ['admin', 'staff', 'viewer'],
    routeMatchers: [
      '/app/shop/dropship',
      '/app/shop/orders',
      '/app/shop/fulfillment',
      '/app/shop/shops',
    ],
    overview:
      'Staff use Shop & Orders to process dropship consignments, confirm costing, and settle courier remittances. Detailed page guides will be added per screen.',
    workflows: [
      {
        id: 'open-dropship-desk',
        title: 'Open the Dropship Desk',
        steps: [
          'Go to Shop → Dropship in the sidebar.',
          'Open an order to assign courier and advance status.',
          'Use Finance Hub for costing and remittance when the order is delivered.',
        ],
      },
    ],
    terms: [
      {
        term: 'Finance Hub',
        definition: 'The desk where delivered costing, courier remittance, and payouts are handled.',
      },
      {
        term: 'Remittance',
        definition: 'Recording cash the courier deposited for delivered COD orders.',
      },
    ],
    faqs: [
      {
        question: 'Why can I not remittance an order yet?',
        answer:
          'Usually delivered costing must be confirmed first. Open the order or Finance Hub and complete costing, then try remittance again.',
      },
    ],
  },
  {
    id: 'shop_order_merchant',
    title: 'Shop & Orders (Merchant)',
    caption: 'Place orders and track deliveries',
    icon: 'ph ph-shopping-bag',
    scopes: ['shop'],
    audiences: ['merchant'],
    routeMatchers: ['/shop/browse', '/shop/orders', '/shop/cart', '/shop/checkout'],
    overview:
      'As a merchant you browse the catalog, set recipient selling prices, checkout to a recipient, and track order status. Money details appear on your wallet page when enabled.',
    workflows: [
      {
        id: 'place-order',
        title: 'Place a dropship order',
        steps: [
          'Browse the shop catalog and add items to cart.',
          'Set the recipient selling price where allowed.',
          'Enter recipient shipping details and submit the order.',
          'Track progress under Orders.',
        ],
      },
    ],
    terms: [
      {
        term: 'Selling price',
        definition: 'The amount your recipient pays (COD). Your profit is selling price minus wholesale cost.',
      },
    ],
    faqs: [
      {
        question: 'Why can I not set a price below a certain amount?',
        answer: 'The shop enforces a minimum dropship price (floor) set by the supplier.',
      },
    ],
  },
  {
    id: 'universal_wallet',
    title: 'Universal Wallet',
    caption: 'Balances, ledgers, and payouts',
    icon: 'ph ph-wallet',
    scopes: ['app'],
    audiences: ['admin', 'staff', 'viewer'],
    routeMatchers: ['/app/wallet'],
    overview:
      'Universal Wallet shows balances and ledger activity for tenants, merchants, couriers, and other parties. Use it to review money movement after shop settlements.',
    workflows: [
      {
        id: 'review-balance',
        title: 'Review a balance',
        steps: [
          'Open Universal Wallet from the sidebar.',
          'Select the party type and profile you need.',
          'Scan recent ledger lines for credits and deductions.',
        ],
      },
    ],
    terms: [
      {
        term: 'Pending balance',
        definition: 'Profit or credit recorded but not yet paid out.',
      },
    ],
    faqs: [
      {
        question: 'Why does a balance look different from an order screen?',
        answer:
          'Order screens show ops status. Wallet reflects confirmed money events after costing, remittance, or payout steps.',
      },
    ],
  },
  {
    id: 'investor_portal',
    title: 'Investor Portal',
    caption: 'Portfolio, allocations, and profit',
    icon: 'ph ph-piggy-bank',
    scopes: ['investor'],
    audiences: ['investor'],
    routeMatchers: [
      '/investor/portfolio',
      '/investor/allocations',
      '/investor/profit',
      '/investor/activity',
    ],
    overview:
      'The investor portal is read-only. Review portfolio balances, shipment allocations, profit status, and activity history.',
    workflows: [
      {
        id: 'review-portfolio',
        title: 'Review your portfolio',
        steps: [
          'Open Portfolio Dashboard for balances and overview.',
          'Check Capital Deployment for shipment allocations.',
          'Open Profit Report for earnings status.',
        ],
      },
    ],
    terms: [
      {
        term: 'Allocation',
        definition: 'How your capital is assigned across shipments or pools.',
      },
    ],
    faqs: [
      {
        question: 'Can I request a withdrawal here?',
        answer: 'Not in this portal version. Contact your administrator for withdrawal handling.',
      },
    ],
  },
];
