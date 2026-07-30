import type { ModuleGuide } from '../../types';

export const gettingStartedGuide: ModuleGuide = {
  id: 'getting_started',
  title: { en: 'Getting Started', bn: 'শুরু করুন' },
  caption: {
    en: 'Find help for the screen you are on',
    bn: 'আপনি যে স্ক্রিনে আছেন তার জন্য সাহায্য খুঁজুন',
  },
  icon: 'ph ph-compass',
  scopes: ['platform', 'app', 'shop', 'investor'],
  audiences: ['superadmin', 'admin', 'staff', 'viewer', 'merchant', 'investor'],
  routeMatchers: ['/help'],
  overview: {
    en: 'Use the ? button in the header for a guide about the current page, or open Help Center to browse all guides available to your role.',
    bn: 'বর্তমান পৃষ্ঠার গাইডের জন্য হেডারের ? বাটন ব্যবহার করুন, অথবা আপনার রোলের জন্য উপলব্ধ সব গাইড ব্রাউজ করতে হেল্প সেন্টার খুলুন।',
  },
  workflows: [
    {
      id: 'open-guide',
      title: { en: 'Open a module guide', bn: 'মডিউল গাইড খুলুন' },
      steps: [
        {
          en: 'Click the ? icon in the top bar.',
          bn: 'উপরের বারে ? আইকনে ক্লিক করুন।',
        },
        {
          en: 'Read Overview, Workflows, Key Terms, or FAQs.',
          bn: 'Overview, Workflows, Key Terms অথবা FAQs পড়ুন।',
        },
        {
          en: 'Open Help Center from the drawer if you need to search other topics.',
          bn: 'অন্য বিষয় খুঁজতে হলে ড্রয়ার থেকে হেল্প সেন্টার খুলুন।',
        },
      ],
    },
  ],
  terms: [
    {
      term: { en: 'Module Guide', bn: 'মডিউল গাইড' },
      definition: {
        en: 'Short help for the area of the product you are using right now.',
        bn: 'আপনি এখন যে পণ্য এলাকা ব্যবহার করছেন তার সংক্ষিপ্ত সাহায্য।',
      },
    },
    {
      term: { en: 'Help Center', bn: 'হেল্প সেন্টার' },
      definition: {
        en: 'Searchable list of all guides you are allowed to see.',
        bn: 'আপনি যেসব গাইড দেখতে পারবেন তার অনুসন্ধানযোগ্য তালিকা।',
      },
    },
  ],
  faqs: [
    {
      question: {
        en: 'Why do I see fewer guides than a coworker?',
        bn: 'সহকর্মীর চেয়ে আমি কম গাইড দেখি কেন?',
      },
      answer: {
        en: 'Guides are filtered by your role. Staff may see operations help that merchants or investors do not.',
        bn: 'গাইড আপনার রোল অনুযায়ী ফিল্টার হয়। স্টাফ এমন অপারেশন সাহায্য দেখতে পারে যা মার্চেন্ট বা ইনভেস্টর দেখেন না।',
      },
    },
  ],
};
